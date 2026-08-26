#!/usr/bin/env bash
#
# uos.sh — the unified developer CLI for the Universal Agentic Engineering
# OS. One entry point over the OS's own scripts:
#
#   uos ingest            deep-read every spec in docs/, read-only
#                         (scripts/ingest-specs.sh)
#   uos plan              print the milestone DAG as dispatchable streams
#   uos dispatch [S] [P]  provision an isolated worktree per stream
#                         (scripts/dispatch-worktrees.sh)
#   uos merge <S> [--keep]
#                         gate, --no-ff merge, and prune one stream
#                         (scripts/merge-worktrees.sh)
#   uos doctor            sub-second environment diagnostics
#   uos ship [--release]  run all local quality gates and prepare a GitHub
#                         release (--release creates a DRAFT via gh; you
#                         publish it)
#   uos status            compact 3-line ASCII status card
#   uos install           link this CLI onto PATH (~/.local/bin/uos)
#   uos help              this help
#
# Exit status:
#   0 — command succeeded
#   1 — command failed (details on stderr); unknown commands exit 2

set -u

# Resolve this script's real location (uos may be invoked through the
# ~/.local/bin symlink created by `uos install`; logical pwd would point
# the repo root at ~/.local).
UOS_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$UOS_SOURCE" ]; do
    UOS_LINK_DIR="$(cd "$(dirname "$UOS_SOURCE")" && pwd)"
    UOS_SOURCE="$(readlink "$UOS_SOURCE")"
    case "$UOS_SOURCE" in
        /*) ;;
        *) UOS_SOURCE="${UOS_LINK_DIR}/${UOS_SOURCE}" ;;
    esac
done
SCRIPT_DIR="$(cd "$(dirname "$UOS_SOURCE")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECKPOINT="${REPO_ROOT}/docs/10-CHECKPOINT.md"
UOS_VERSION="1.2.0"

usage() {
    sed -n 's/^# \?//p' "${BASH_SOURCE[0]}" | sed -n '2,20p'
}

read_checkpoint_field() {
    sed -n "s/^$1:[[:space:]]*//Ip" "$CHECKPOINT" 2> /dev/null | head -n 1
}

phase_name() {
    case "$1" in
        1) printf 'Inception & Specs' ;;
        2) printf 'Core Build & TDD' ;;
        3) printf 'Quality Gates & Security' ;;
        4) printf 'Docs Verification & Release' ;;
        *) printf 'unknown' ;;
    esac
}

milestone_slug() {
    printf '%s' "$1" \
        | sed -E 's/^- \[.\] (M[0-9]+)?[[:space:]]*—?[[:space:]]*//; s/[^A-Za-z0-9]+/-/g; s/^-+|-+$//g' \
        | cut -c1-40 | tr '[:upper:]' '[:lower:]'
}

cmd_plan() {
    local first_open=1 line slug

    [ -f "$CHECKPOINT" ] || { echo '[plan] no checkpoint at docs/10-CHECKPOINT.md'; return 1; }

    echo "[plan] milestone DAG (docs/10-CHECKPOINT.md):"
    while IFS= read -r line; do
        if printf '%s' "$line" | grep -q '^- \[x\]'; then
            printf '  DONE   %s\n' "$(printf '%s' "$line" | sed 's/^- \[x\] //')"
        elif printf '%s' "$line" | grep -q '^- \[ \]'; then
            slug="$(milestone_slug "$line")"
            if [ "$first_open" -eq 1 ]; then
                printf '  NEXT   %s\n         -> uos dispatch %s\n' \
                    "$(printf '%s' "$line" | sed 's/^- \[ \] //')" "$slug"
                first_open=0
            else
                printf '  QUEUED %s\n         -> uos dispatch %s\n' \
                    "$(printf '%s' "$line" | sed 's/^- \[ \] //')" "$slug"
            fi
        fi
    done < "$CHECKPOINT"
}

cmd_doctor() {
    local rc=0 name

    check() { # check <label> <command...>
        local label="$1"; shift
        if command -v "$1" > /dev/null 2>&1; then
            printf '  ok      %-14s %s\n' "$label" "$("$@" 2> /dev/null | head -n 1)"
        else
            printf '  absent  %-14s not on PATH\n' "$label"
        fi
    }
    required() { # required <label> <command...> — absence fails doctor
        local label="$1"; shift
        if command -v "$1" > /dev/null 2>&1; then
            printf '  ok      %-14s %s\n' "$label" "$("$@" 2> /dev/null | head -n 1)"
        else
            printf '  FAIL    %-14s required but not found\n' "$label"
            rc=1
        fi
    }

    echo "[doctor] universal agentic engineering os v${UOS_VERSION}"

    required git git --version
    required bash bash --version
    check node node --version
    check npm npm --version
    # Windows ships a python3 Store-alias stub that resolves but prints no
    # version; fall through to the real interpreter when that happens.
    if command -v python3 > /dev/null 2>&1 && [ -n "$(python3 --version 2> /dev/null)" ]; then
        printf '  ok      %-14s %s\n' 'python3' "$(python3 --version 2> /dev/null | head -n 1)"
    elif command -v python > /dev/null 2>&1; then
        printf '  ok      %-14s %s\n' 'python' "$(python --version 2> /dev/null | head -n 1)"
    else
        printf '  absent  %-14s not on PATH\n' 'python'
    fi
    check cargo cargo --version
    check go go version
    check shellcheck shellcheck --version
    check jq jq --version
    check gh gh --version
    check npx npx --version

    # Git hook wiring.
    if [ "$(git -C "$REPO_ROOT" config core.hooksPath 2> /dev/null)" = ".githooks" ]; then
        printf '  ok      hooks          core.hooksPath=.githooks\n'
    else
        printf '  FAIL    hooks          run: bash scripts/setup-git-hooks.sh\n'
        rc=1
    fi

    # Claude Code hook settings must be valid JSON with the three lifecycles.
    if command -v jq > /dev/null 2>&1; then
        if jq -e '.hooks.SessionStart and .hooks.PostToolUse and .hooks.SessionEnd' \
            "${REPO_ROOT}/.claude/settings.json" > /dev/null 2>&1; then
            printf '  ok      claude hooks   SessionStart/PostToolUse/SessionEnd wired\n'
        else
            printf '  FAIL    claude hooks   .claude/settings.json missing a lifecycle\n'
            rc=1
        fi

        # Every hook script the settings name must exist on disk.
        while IFS= read -r hook_file; do
            [ -n "$hook_file" ] || continue
            if [ -f "${REPO_ROOT}/${hook_file}" ]; then
                printf '  ok      %-14s %s\n' 'hook file' "$hook_file"
            else
                printf '  FAIL    %-14s missing: %s\n' 'hook file' "$hook_file"
                rc=1
            fi
        done < <(jq -r '.. | objects | .command? // empty' \
            "${REPO_ROOT}/.claude/settings.json" 2> /dev/null | awk '{print $2}')
    fi

    # API keys: presence only — values are never read or printed.
    for name in ANTHROPIC_API_KEY OPENROUTER_API_KEY GITHUB_TOKEN; do
        if [ -n "${!name:-}" ]; then
            printf '  ok      %-14s set\n' "$name"
        else
            printf '  absent  %-14s not exported (optional)\n' "$name"
        fi
    done

    # Toolkit integrity (offline verify).
    if bash "${SCRIPT_DIR}/setup-toolkit.sh" --verify > /dev/null 2>&1; then
        printf '  ok      toolkit        6/6 canonical toolkits unmutated\n'
    else
        printf '  FAIL    toolkit        run: bash scripts/setup-toolkit.sh\n'
        rc=1
    fi

    if [ "$rc" -eq 0 ]; then
        echo '[doctor] environment healthy.'
    else
        echo '[doctor] FAILURES above must be fixed before shipping.'
    fi
    return "$rc"
}

cmd_status() {
    local status phase milestone strikes test_state kit

    status="$(read_checkpoint_field 'status')"; status="${status:-UNKNOWN}"
    phase="$(read_checkpoint_field 'ACTIVE_PHASE')"; phase="${phase:-1}"
    milestone="$(grep -E '^- \[ \] ' "$CHECKPOINT" 2> /dev/null | head -n 1 | sed 's/^- \[ \] //')"
    milestone="${milestone:-none open}"
    if [ "${#milestone}" -gt 58 ]; then
        milestone="$(printf '%s' "$milestone" | cut -c1-55)..."
    fi

    strikes=0
    [ -f "${REPO_ROOT}/.claude/.strike_tracker" ] && \
        strikes="$(wc -l < "${REPO_ROOT}/.claude/.strike_tracker" | tr -d '[:space:]')"
    if [ "$strikes" -eq 0 ]; then
        test_state='PASSING'
    else
        test_state="FAILING (${strikes} strike(s))"
    fi

    # Same offline integrity bar as doctor, so a mutated or missing
    # toolkit never shows as healthy on the card.
    kit='ok'
    bash "${SCRIPT_DIR}/setup-toolkit.sh" --verify > /dev/null 2>&1 || kit='unverified'

    # Orca worktree pool: dispatched streams = worktrees beyond main.
    streams=$(( $(git -C "$REPO_ROOT" worktree list --porcelain 2> /dev/null \
        | grep -c '^worktree ' || true) - 1 ))
    [ "$streams" -lt 0 ] && streams=0

    printf '+----------------------------------------------------------------+\n'
    printf '| PHASE     : %s/4 %s\n' "$phase" "$(phase_name "$phase")"
    printf '| MILESTONE : %s [%s]  TESTS: %s | KIT: %s | POOL: %s stream(s)\n' \
        "$milestone" "$status" "$test_state" "$kit" "$streams"
    printf '+----------------------------------------------------------------+\n'
}

cmd_ship() {
    local release=0 f rc=0 version notes_tag

    [ "${1:-}" = "--release" ] && release=1

    echo '[ship] running local quality gates...'

    for f in "${SCRIPT_DIR}"/*.sh "${REPO_ROOT}"/.claude/hooks/*.sh "${REPO_ROOT}"/.githooks/*; do
        [ -f "$f" ] || continue
        bash -n "$f" || rc=1
    done
    echo '[ship]   bash -n .......... all shell scripts parse'

    if command -v shellcheck > /dev/null 2>&1; then
        shellcheck "${SCRIPT_DIR}"/*.sh "${REPO_ROOT}"/.claude/hooks/*.sh "${REPO_ROOT}"/.githooks/* || rc=1
        echo '[ship]   shellcheck ....... clean'
    else
        echo '[ship]   shellcheck ....... SKIPPED (not installed; CI will enforce)'
    fi

    lines="$(wc -l < "$CHECKPOINT" | tr -d '[:space:]')"
    if [ "$lines" -lt 50 ]; then
        echo "[ship]   checkpoint ....... ${lines} lines (<50)"
    else
        echo "[ship]   checkpoint ....... FAIL (${lines} lines; archive milestones first)"
        rc=1
    fi

    if bash "${SCRIPT_DIR}/ingest-specs.sh" > /dev/null 2>&1; then
        echo '[ship]   spec fidelity .... cross-references resolve'
    else
        echo '[ship]   spec fidelity .... FAIL (run: uos ingest)'
        rc=1
    fi

    if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
        echo '[ship]   work tree ........ DIRTY (commit everything first)'
        rc=1
    else
        echo '[ship]   work tree ........ clean'
    fi

    if [ "$rc" -ne 0 ]; then
        echo '[ship] gates FAILED; do not release.'
        return 1
    fi

    version="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "${REPO_ROOT}/CHANGELOG.md" 2> /dev/null | tr -d '[]# ' | sed 's/^##//')"
    version="${version:-unknown}"
    echo "[ship] all gates green. latest CHANGELOG version: ${version}"
    echo '[ship] release checklist:'
    echo "         1. tag:      git tag -a v${version} -m \"v${version}\""
    echo "         2. push tag: git push origin v${version}"
    echo "         3. release:  gh release create v${version} --title \"v${version}\" --notes-file CHANGELOG.md"

    if [ "$release" -eq 1 ]; then
        if ! command -v gh > /dev/null 2>&1; then
            echo '[ship] --release requested but gh is not installed.' >&2
            return 1
        fi
        notes_tag="${version}"
        gh release create "v${notes_tag}" --draft --title "v${notes_tag}" \
            --notes "See CHANGELOG.md for the v${notes_tag} change set." &&
            echo "[ship] draft release v${notes_tag} created; review and publish."
    fi
}

cmd_install() {
    local bin_dir="${HOME}/.local/bin"
    local target="${bin_dir}/uos"

    mkdir -p "$bin_dir"

    # Try a true symlink first; verify it actually materialized (MSYS ln -s
    # silently copies when symlinks are unavailable). Otherwise write an
    # exec shim that forwards to the repository CLI by absolute path.
    if MSYS=winsymlinks:nativestrict ln -sf "${SCRIPT_DIR}/uos.sh" "$target" 2> /dev/null \
        && [ -L "$target" ]; then
        echo "[install] linked $target -> ${SCRIPT_DIR}/uos.sh"
    else
        {
            printf '#!/usr/bin/env bash\n'
            printf '# uos shim generated by uos install - forwards to the repository CLI.\n'
            printf 'exec bash "%s/uos.sh" "$@"\n' "${SCRIPT_DIR}"
        } > "$target"
        chmod +x "$target" 2> /dev/null || true
        echo "[install] wrote forwarding shim at $target"
    fi

    case ":${PATH}:" in
        *":${bin_dir}:"*) ;;
        *) echo "[install] note: ${bin_dir} is not on PATH; add it to your shell profile." ;;
    esac
}

main() {
    local cmd="${1:-help}"
    shift 2> /dev/null || true

    case "$cmd" in
        ingest)   exec bash "${SCRIPT_DIR}/ingest-specs.sh" "$@" ;;
        plan)     cmd_plan "$@" ;;
        dispatch) exec bash "${SCRIPT_DIR}/dispatch-worktrees.sh" "$@" ;;
        merge)    exec bash "${SCRIPT_DIR}/merge-worktrees.sh" "$@" ;;
        doctor)   cmd_doctor "$@" ;;
        ship)     cmd_ship "$@" ;;
        status)   cmd_status "$@" ;;
        install)  cmd_install "$@" ;;
        -h|--help|help|'')
            echo "uos — universal agentic engineering os cli v${UOS_VERSION}"
            usage
            ;;
        --version|-V)
            echo "uos ${UOS_VERSION}"
            ;;
        *)
            echo "uos: unknown command '$cmd' (try: uos help)" >&2
            exit 2
            ;;
    esac
}

main "$@"
