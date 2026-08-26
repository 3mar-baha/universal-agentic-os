#!/usr/bin/env bash
#
# merge-worktrees.sh — Automated integration for dispatched streams.
#
# For a stream provisioned by dispatch-worktrees.sh it:
#   1. Runs the regression gate over the stream's diff against the base
#      branch: `bash -n` + shellcheck (if installed) on changed shell
#      scripts, markdownlint (if installed) on changed markdown.
#   2. Merges the stream branch into the current branch with --no-ff so
#      history keeps one merge commit per stream.
#   3. Prunes the worktree and its feature branch (--keep to retain them).
#   4. Stamps docs/10-CHECKPOINT.md with one integration line; milestone
#      archiving clears these lines, keeping the checkpoint under 50 lines.
#
# Refuses when the checkpoint is BLOCKED, the stream does not exist, the
# repository index is dirty, or the regression gate fails.
#
# Usage:
#   ./scripts/merge-worktrees.sh <STREAM_NAME> [--keep] [-h | --help]
#
# Exit status:
#   0 — merged and cleaned up (or kept, with --keep)
#   1 — refused or gate failure; nothing was merged

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECKPOINT="${REPO_ROOT}/docs/10-CHECKPOINT.md"
WORKTREE_ROOT="${REPO_ROOT}/.worktrees"

log_info() { printf '[merge] %s\n' "$*"; }
log_error() { printf '[merge] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
merge-worktrees.sh — verify, integrate, and prune one dispatched stream.

Usage:
  ./scripts/merge-worktrees.sh <STREAM_NAME> [--keep]

  --keep    keep the worktree directory and feature branch after merging.

Exit status:
  0    Stream merged into the current branch with --no-ff.
  1    Refused (BLOCKED, dirty index, unknown stream) or the regression
       gate failed. Nothing is merged on failure.
EOF
}

read_checkpoint_field() {
    sed -n "s/^$1:[[:space:]]*//Ip" "$CHECKPOINT" 2> /dev/null | head -n 1
}

stamp_checkpoint() {
    # stamp_checkpoint <stream> <sha> — one line per integrated stream.
    printf 'integrated: %s @ %s (%s)\n' "$1" "$2" "$(date +%Y-%m-%d)" >> "$CHECKPOINT"
}

gate_changed_files() {
    # gate_changed_files <worktree_dir> <branch> — diff-scoped quality gate.
    # Diffs are computed from the repository (which knows both refs); files
    # are read at their branch-tip versions inside the worktree.
    local wt="$1"
    local branch="$2"
    local base sh_files md_files f rc=0

    base="$(git -C "$REPO_ROOT" merge-base HEAD "$branch")"
    sh_files="$(git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMR "$base" "$branch" -- '*.sh' '*.bash' || true)"
    md_files="$(git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMR "$base" "$branch" -- '*.md' || true)"

    for f in $sh_files; do
        log_info "gate bash -n: $f"
        bash -n "$wt/$f" || rc=1
        if command -v shellcheck > /dev/null 2>&1; then
            shellcheck "$wt/$f" || rc=1
        fi
    done

    if [ -n "$md_files" ] && command -v npx > /dev/null 2>&1; then
        # ponytail: lint only when node is present locally; CI always lints.
        # File list comes from git diff; paths have no spaces by repo convention.
        # shellcheck disable=SC2086
        (cd "$REPO_ROOT" && npx --yes markdownlint-cli $md_files) || rc=1
    fi

    if [ -z "$sh_files" ] && [ -z "$md_files" ]; then
        log_info 'no shell/markdown changes in stream diff; nothing to gate.'
    fi
    return "$rc"
}

main() {
    local stream="" keep=0 arg
    local wt branch short_sha

    while [ $# -gt 0 ]; do
        arg="$1"
        case "$arg" in
            -h|--help) usage; exit 0 ;;
            --keep)    keep=1 ;;
            *)         stream="$arg" ;;
        esac
        shift
    done

    if [ -z "$stream" ]; then
        log_error 'STREAM_NAME is required.'
        usage >&2
        exit 1
    fi

    if [ "$(read_checkpoint_field 'status')" = "BLOCKED" ]; then
        log_error 'checkpoint status is BLOCKED; resolve the DIR before integrating.'
        exit 1
    fi

    if [ -n "$(git -C "$REPO_ROOT" diff --cached --name-only)" ]; then
        log_error 'staged changes detected in the repository; commit them first.'
        exit 1
    fi

    wt="${WORKTREE_ROOT}/${stream}"
    branch="feature/${stream}"

    if [ ! -d "$wt" ] || ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
        log_error "unknown stream '$stream' (expected $wt on branch $branch)."
        exit 1
    fi

    log_info "running regression gate for '$stream'..."
    if ! gate_changed_files "$wt" "$branch"; then
        log_error "regression gate failed for '$stream'; nothing merged."
        exit 1
    fi

    log_info "merging $branch into $(git -C "$REPO_ROOT" branch --show-current) (--no-ff)"
    if ! git -C "$REPO_ROOT" merge --no-ff --no-edit "$branch"; then
        log_error 'merge conflict; resolve manually in the repository, then re-run.'
        exit 1
    fi

    short_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
    stamp_checkpoint "$stream" "$short_sha"

    if [ "$keep" -eq 1 ]; then
        log_info "--keep set; worktree and branch left intact."
    else
        git -C "$REPO_ROOT" worktree remove "$wt" || {
            log_error "could not remove worktree $wt; prune manually."
            exit 1
        }
        git -C "$REPO_ROOT" branch -d "$branch" > /dev/null
        log_info "pruned worktree and branch for '$stream'."
    fi

    log_info "stream '$stream' integrated @ $short_sha."
    exit 0
}

main "$@"
