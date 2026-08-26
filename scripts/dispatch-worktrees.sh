#!/usr/bin/env bash
#
# dispatch-worktrees.sh — Orca-style parallel stream isolation for the
# Universal Agentic Engineering OS.
#
# Provisions one isolated git worktree per independent workstream, per
# Invariant 7 (Isolation): `git worktree add .worktrees/<stream>
# feature/<stream>`, then injects the phase context kit into that worktree
# and drops a STREAM briefing so a sub-agent can start TDD immediately.
#
# Refuses to run when:
#   - the checkpoint status is BLOCKED (circuit breaker owns the session),
#   - the stream name is unsafe or already dispatched,
#   - the working tree has staged changes (a worktree branches from HEAD;
#     uncommitted state must never cross a worktree boundary).
#
# Usage:
#   ./scripts/dispatch-worktrees.sh <STREAM_NAME> [PHASE_NUM]
#
#   STREAM_NAME  kebab-case identifier, e.g. "m2-orca-docs" (default when
#                omitted: slug of the first open milestone in the DAG)
#   PHASE_NUM    lifecycle phase for context injection, 1-4 (default: the
#                checkpoint's ACTIVE_PHASE)
#
# Exit status:
#   0 — worktree provisioned and phase kit injected
#   1 — refused (state above), or injection failed entirely

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECKPOINT="${REPO_ROOT}/docs/10-CHECKPOINT.md"
WORKTREE_ROOT="${REPO_ROOT}/.worktrees"

log_info() { printf '[dispatch] %s\n' "$*"; }
log_error() { printf '[dispatch] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
dispatch-worktrees.sh — provision an isolated git worktree for one
parallel workstream, with its phase context kit pre-injected.

Usage:
  ./scripts/dispatch-worktrees.sh <STREAM_NAME> [PHASE_NUM]

Examples:
  ./scripts/dispatch-worktrees.sh m2-orca-docs        # phase from checkpoint
  ./scripts/dispatch-worktrees.sh m3-automations 2    # explicit phase

Exit status:
  0    Worktree ready at .worktrees/<stream> on branch feature/<stream>.
  1    Refused (BLOCKED checkpoint, dirty index, bad name, duplicate) or
       every context injection failed.
EOF
}

read_checkpoint_field() {
    sed -n "s/^$1:[[:space:]]*//Ip" "$CHECKPOINT" 2> /dev/null | head -n 1
}

first_open_milestone_slug() {
    # Slug of the first open ("- [ ] M<n>") item in the checkpoint DAG.
    local line
    line="$(grep -E '^- \[ \] ' "$CHECKPOINT" 2> /dev/null | head -n 1)" || return 1
    printf '%s' "$line" \
        | sed -E 's/^- \[ \] (M[0-9]+)?[[:space:]]*—?[[:space:]]*//; s/[^A-Za-z0-9]+/-/g; s/^-+|-+$//g' \
        | cut -c1-40 | tr '[:upper:]' '[:lower:]'
}

validate_stream_name() {
    case "$1" in
        '' | *[!a-z0-9-]* | -* | *-)
            log_error "stream name must be lowercase kebab-case: '$1'"
            return 1
            ;;
        *) return 0 ;;
    esac
}

write_stream_briefing() {
    # write_stream_briefing <worktree_dir> <stream> <phase>
    # Lives under .claude/ (gitignored) so the worktree stays pristine
    # for automatic pruning at merge time.
    mkdir -p "$1/.claude"
    cat >"$1/.claude/STREAM.md" <<EOF
# Stream: $2 (phase $3)

Autonomous sub-agent briefing — resume strict TDD on this stream's single
concern without asking for confirmation (zero-prompt protocol).

## Read First
- docs/10-CHECKPOINT.md — mission, DAG, standing rules.
- CLAUDE.md — engineering constitution (all nine invariants bind here).

## Boundary Contract
- One concern per worktree. Do not edit outside this worktree.
- Context kit for phase $3 is already injected under .claude/.
- Integrate only via: bash scripts/merge-worktrees.sh $2
EOF
}

main() {
    local stream="${1:-}"
    local raw_phase="${2:-}"
    local phase
    local wt branch

    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        usage
        exit 0
    fi

    if ! command -v git > /dev/null 2>&1; then
        log_error 'git is not available.'
        exit 1
    fi

    if [ "$(read_checkpoint_field 'status')" = "BLOCKED" ]; then
        log_error 'checkpoint status is BLOCKED; circuit breaker owns this session.'
        log_error 'resolve the DIR in docs/10-CHECKPOINT.md before dispatching.'
        exit 1
    fi

    if [ -z "$stream" ]; then
        stream="$(first_open_milestone_slug)" || true
        if [ -z "$stream" ]; then
            log_error 'no STREAM_NAME given and no open milestone found in the DAG.'
            usage >&2
            exit 1
        fi
        log_info "no stream given; using first open milestone slug: '$stream'"
    fi

    validate_stream_name "$stream" || exit 1

    if [ -n "$raw_phase" ]; then
        case "$raw_phase" in
            1|2|3|4) phase="$raw_phase" ;;
            *) log_error "PHASE_NUM must be 1-4 (got: '$raw_phase')."; exit 1 ;;
        esac
    else
        phase="$(read_checkpoint_field 'ACTIVE_PHASE')"
        case "$phase" in 1|2|3|4) ;; *) phase=1 ;; esac
    fi

    if [ -n "$(git -C "$REPO_ROOT" diff --cached --name-only)" ]; then
        log_error 'staged changes detected; commit or stash before dispatching.'
        log_error 'uncommitted state never crosses a worktree boundary (Invariant 7).'
        exit 1
    fi

    wt="${WORKTREE_ROOT}/${stream}"
    branch="feature/${stream}"

    if [ -d "$wt" ] || git -C "$REPO_ROOT" worktree list --porcelain | grep -qF "$wt"; then
        log_error "stream already dispatched: $wt"
        exit 1
    fi

    mkdir -p "$WORKTREE_ROOT"
    if ! git -C "$REPO_ROOT" worktree add -b "$branch" "$wt"; then
        log_error "git worktree add failed for $branch -> $wt"
        exit 1
    fi

    # The worktree is a full checkout, so it carries its own copy of the
    # orchestration scripts; inject the phase kit against the worktree root.
    if ! (cd "$wt" && bash scripts/orchestrate-stage.sh "$phase"); then
        log_error "context injection failed inside $wt; removing worktree."
        git -C "$REPO_ROOT" worktree remove --force "$wt"
        git -C "$REPO_ROOT" branch -D "$branch" > /dev/null 2>&1 || true
        exit 1
    fi

    write_stream_briefing "$wt" "$stream" "$phase"

    log_info "stream '$stream' ready:"
    log_info "  worktree : $wt"
    log_info "  branch   : $branch"
    log_info "  phase    : $phase"
    log_info "integrate with: bash scripts/merge-worktrees.sh $stream"
    exit 0
}

main "$@"
