#!/usr/bin/env bash
#
# post_tool_call.sh — Circuit Breaker Interceptor (native PostToolUse hook).
#
# Watches Bash tool calls that run test/build commands. Consecutive failures
# are tracked in .claude/.strike_tracker (one attempt per line). On strike 3:
#   - a Diagnostic Incident Report (DIR) is written into docs/10-CHECKPOINT.md,
#   - the checkpoint STATUS is set to BLOCKED,
#   - the hook exits 2 so the failure is surfaced back into the conversation.
#
# A successful tracked command clears the strike state. Anything this hook
# cannot judge (non-Bash tool, untracked command, unparsable payload) passes
# through silently with exit 0 — the interceptor must never break a session.
#
# Input: Claude Code PostToolUse JSON on stdin.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

STRIKE_FILE="${REPO_ROOT}/.claude/.strike_tracker"
CHECKPOINT="${REPO_ROOT}/docs/10-CHECKPOINT.md"
MAX_STRIKES=3

# Commands whose exit codes count as test/build verdicts.
TRACKED_COMMAND_RE='(npm|pnpm|yarn|bun)( +run)? +(test|build)|pytest|go +test|cargo +(test|build)|^make +|gradlew? |mvn +|dotnet +(test|build)|(^|/)jest|vitest|tsc +|eslint +|ruff +|shellcheck +|markdownlint +'

log_warn() {
    printf '[circuit-breaker] %s\n' "$*" >&2
}

# Field results populated by extract_fields.
TOOL_NAME=""
CMD=""
CODE="null"

# split_record <joined> — splits a \x01-joined record into the field globals.
# \x01 is a byte that cannot occur in tool payloads, so multi-line commands
# survive intact across every extraction tier.
split_record() {
    local joined="$1"
    local rest

    TOOL_NAME="${joined%%$'\x01'*}"
    rest="${joined#*$'\x01'}"
    CMD="${rest%%$'\x01'*}"
    CODE="${rest#*$'\x01'}"
    [ "$CODE" = "$rest" ] && CODE="null"
    return 0
}

# extract_fields <input> — populates TOOL_NAME, CMD, CODE ("null" when unknown).
extract_fields() {
    local input="$1"

    TOOL_NAME=""
    CMD=""
    CODE="null"

    if command -v jq > /dev/null 2>&1; then
        # @sh emits each field fully shell-quoted; eval assigns them safely,
        # whatever quoting the observed command contains.
        if eval "set -- $(printf '%s' "$input" | jq -r '
            [(.tool_name // ""),
             ((.tool_input.command // "") | tostring),
             ((.tool_response.exitCode
               // .tool_response.exit_code
               // .tool_response.returncode
               // .tool_response.return_code
               // .tool_output.exitCode
               // null) | tostring)] | @sh' 2> /dev/null)"; then
            TOOL_NAME="$1"
            CMD="$2"
            CODE="${3:-null}"
        fi
        return 0
    fi

    # ponytail: node fallback because Git Bash on Windows ships without jq;
    # drop this tier once jq is guaranteed on every dev machine.
    if command -v node > /dev/null 2>&1; then
        local joined
        if joined="$(printf '%s' "$input" | node -e '
          let d = "";
          process.stdin.on("data", c => { d += c; });
          process.stdin.on("end", () => {
            try {
              const j = JSON.parse(d);
              const r = j.tool_response || j.tool_output || {};
              let code = null;
              for (const k of ["exitCode","exit_code","returncode","return_code","code"]) {
                if (typeof r[k] === "number") { code = r[k]; break; }
              }
              const cmd = String((j.tool_input && j.tool_input.command) || "");
              process.stdout.write([String(j.tool_name || ""), cmd, code === null ? "null" : String(code)].join("\x01"));
            } catch (e) {
              process.stdout.write("\x01\x01null");
            }
          });
        ' 2> /dev/null)"; then
            split_record "$joined"
        fi
        return 0
    fi

    # Last-resort regex extraction: best effort, single-line values only.
    local tool cmd code
    tool="$(printf '%s' "$input" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"\(.*\)"$/\1/')"
    cmd="$(printf '%s' "$input" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]{0,400}' | head -n 1 | sed 's/.*:[[:space:]]*"//')"
    code="$(printf '%s' "$input" | grep -oE '"(exitCode|exit_code|returncode|return_code)"[[:space:]]*:[[:space:]]*[0-9]+' | head -n 1 | grep -oE '[0-9]+$')"
    TOOL_NAME="$tool"
    CMD="$cmd"
    CODE="${code:-null}"
    return 0
}

write_incident_report() {
    # write_incident_report <last_command>
    local last_command="$1"
    local ts
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    local target="$CHECKPOINT"
    if [ ! -f "$target" ]; then
        target="${REPO_ROOT}/docs/10-DIR-${ts}.md"
        log_warn "checkpoint missing; DIR written to docs/$(basename "$target") instead."
    fi

    # Flip the lifecycle status before appending the report.
    if ! sed -i.bak 's/^status:.*/status: BLOCKED/' "$target"; then
        log_warn "could not update the status line in ${target}."
    fi
    rm -f "${target}.bak"

    {
        printf '\n---\n\n'
        printf '# DIAGNOSTIC INCIDENT REPORT (auto-generated)\n\n'
        printf -- '- **Raised at**: %s\n' "$ts"
        printf -- '- **Trigger**: %d consecutive failed test/build commands (Invariant 4).\n' "$MAX_STRIKES"
        printf -- '- **Status**: BLOCKED — execution halted. Do not attempt a fourth fix.\n\n'
        printf '## Symptom\n\n'
        printf 'The same defect survived %d consecutive fix attempts. Final failing command:\n\n' "$MAX_STRIKES"
        printf '    %s\n\n' "$last_command"
        printf '## Attempt log (evidence)\n\n'
        printf '| Strike | Failing command |\n|---|---|\n'
        local n=0
        local line
        while IFS= read -r line; do
            n=$((n + 1))
            # shellcheck disable=SC2016  # printf format string; backticks are literal markdown
            printf '| %d | `%s` |\n' "$n" "$line"
        done < "$STRIKE_FILE"
        printf '\n## Hypothesis log & ranked root causes\n\n'
        printf '[Guide: complete from the attempt log above. One hypothesis per strike,\neach with evidence. Retrying an identical fix is strike inflation.]\n\n'
        printf '## Recommended unblock actions\n\n'
        printf -- '- Revert the last change set and re-run the suite to isolate the regression window.\n'
        printf -- '- Run the failing command manually and capture full output.\n'
        # shellcheck disable=SC2016  # printf format string; backticks are literal markdown
        printf -- '- Set `status: ACTIVE` only after the Guide approves a changed hypothesis.\n'
    } >> "$target"
}

main() {
    local input

    input="$(cat)" || exit 0
    [ -n "$input" ] || exit 0

    extract_fields "$input"

    [ "$TOOL_NAME" = "Bash" ] || exit 0
    case "$CODE" in
        null|"") exit 0 ;;   # no verdict to judge
    esac
    printf '%s' "$CMD" | grep -Eq "$TRACKED_COMMAND_RE" || exit 0

    mkdir -p "$(dirname "$STRIKE_FILE")"

    if [ "$CODE" -eq 0 ]; then
        if [ -s "$STRIKE_FILE" ]; then
            rm -f "$STRIKE_FILE"
            log_warn "tracked command passed; strike state cleared."
        fi
        exit 0
    fi

    printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CMD" >> "$STRIKE_FILE"

    local strikes
    strikes="$(wc -l < "$STRIKE_FILE" | tr -d '[:space:]')"

    if [ "$strikes" -ge "$MAX_STRIKES" ]; then
        write_incident_report "$CMD"
        rm -f "$STRIKE_FILE"
        log_warn "STRIKE ${strikes}: DIR written to docs/10-CHECKPOINT.md; status set to BLOCKED."
        printf 'STRIKE %s of %d — execution HALTED (Invariant 4). Diagnostic Incident Report appended to docs/10-CHECKPOINT.md. Do not attempt another fix; form a changed hypothesis and wait for Guide approval.\n' \
            "$strikes" "$MAX_STRIKES" >&2
        exit 2
    fi

    log_warn "strike ${strikes}/${MAX_STRIKES} recorded for: ${CMD}"
    exit 0
}

main "$@"
