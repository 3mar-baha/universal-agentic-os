#!/usr/bin/env bash
#
# session_start.sh — Native Claude Code SessionStart hook.
#
# Reads docs/10-CHECKPOINT.md, extracts ACTIVE_PHASE, orchestrates that
# phase's context kit via scripts/orchestrate-stage.sh, and emits a startup
# diagnostic banner (SessionStart stdout is injected into the conversation).
#
# This hook must never break a session: it exits 0 on every path.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CHECKPOINT="${REPO_ROOT}/docs/10-CHECKPOINT.md"

phase_name() {
    case "$1" in
        1) printf 'Inception & Specs' ;;
        2) printf 'Core Build & TDD' ;;
        3) printf 'Quality Gates & Security' ;;
        4) printf 'Docs Verification & Release' ;;
        *) printf 'unknown' ;;
    esac
}

read_checkpoint_field() {
    # read_checkpoint_field <FIELD> — first "FIELD: value" line of the checkpoint.
    local field="$1"
    local value=""

    if [ -f "$CHECKPOINT" ]; then
        value="$(sed -n "s/^${field}:[[:space:]]*//Ip" "$CHECKPOINT" | head -n 1)"
    fi
    printf '%s' "$value"
}

emit_banner() {
    local status="$1"
    local phase="$2"
    local kit_line="$3"
    local ecc_line="${4:-}"

    cat <<EOF
=======================================================================
 UNIVERSAL AGENTIC ENGINEERING OS - SESSION START
=======================================================================
 checkpoint    : docs/10-CHECKPOINT.md
 status        : ${status}
 active phase  : ${phase} - $(phase_name "$phase")
 context kit   : ${kit_line:-orchestrator output unavailable}
 ecc context   : ${ecc_line:-(not vendored)}
-----------------------------------------------------------------------
 autonomy      : resume the active milestone DAG immediately.
                 strict TDD; no confirmation prompts; archive completed
                 milestones to docs/archive/ to keep the checkpoint <50 lines.
=======================================================================
EOF

    if [ "$status" = "BLOCKED" ]; then
        cat <<'EOF'
 *** STATUS IS BLOCKED ***
 A Diagnostic Incident Report (DIR) is recorded in docs/10-CHECKPOINT.md.
 Per Invariant 4 (Three-Strike Circuit Breaker): do NOT attempt further
 fixes. Read the DIR, form a changed hypothesis, and wait for Guide approval.
=======================================================================
EOF
    fi
}

main() {
    local status
    local raw_phase
    local phase
    local orchestrate_out
    local kit_line
    local ecc_line=""

    status="$(read_checkpoint_field 'status')"
    status="${status:-UNKNOWN}"
    raw_phase="$(read_checkpoint_field 'ACTIVE_PHASE')"
    raw_phase="${raw_phase:-1}"

    case "$raw_phase" in
        1|2|3|4) phase="$raw_phase" ;;
        *)       phase=1 ;;
    esac

    if [ ! -f "$CHECKPOINT" ]; then
        emit_banner "$status" "$phase" "(checkpoint file missing — defaulted to phase ${phase})"
        exit 0
    fi

    if orchestrate_out="$(bash "${REPO_ROOT}/scripts/orchestrate-stage.sh" "$phase" 2>&1)"; then
        kit_line="$(printf '%s\n' "$orchestrate_out" | grep -E 'phase .* ready' | tail -n 1 | sed 's/^\[orchestrate\] //')"
        printf '%s\n' "$orchestrate_out"
    else
        kit_line="ORCHESTRATION FAILED — see stderr; toolkit may need scripts/setup-toolkit.sh"
        printf '%s\n' "$orchestrate_out" >&2
    fi

    # Upstream ECC context persistence (vendored by orchestration). Best
    # effort only: this hook must never break a session.
    if [ -f "${REPO_ROOT}/.claude/hooks/ecc/session-start.sh" ]; then
        if ecc_line="$(bash "${REPO_ROOT}/.claude/hooks/ecc/session-start.sh" 2>&1 \
            | grep '\[SessionStart\]' | tail -n 1 | sed 's/^\[SessionStart\] //')"; then
            [ -n "$ecc_line" ] || ecc_line="(vendored, no recent context)"
        else
            ecc_line="(vendored, probe failed)"
        fi
    fi

    emit_banner "$status" "$phase" "$kit_line" "$ecc_line"
    exit 0
}

main "$@"
