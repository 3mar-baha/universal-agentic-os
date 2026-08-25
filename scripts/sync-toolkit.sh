#!/usr/bin/env bash
#
# sync-toolkit.sh — One-click update of the already-cloned canonical toolkits
# of the Universal Agentic Engineering OS.
#
# Difference from setup-toolkit.sh:
#   - setup-toolkit.sh INSTALLS: it creates CLAUDE_TOOLKIT_DIR, shallow-clones
#     any missing toolkit, and updates the existing ones.
#   - sync-toolkit.sh only UPDATES: it never clones, never creates anything,
#     and pulls with "git pull --ff-only" so a diverged history fails loudly
#     instead of producing surprise merge commits.
#
# Behaviour per canonical toolkit directory:
#   - missing .................... SKIP, with a pointer to setup-toolkit.sh
#   - present, not a git repo .... FAIL
#   - dirty working tree ......... DIRTY, pull skipped (never overwrite or
#                                  merge away local changes)
#   - clean ...................... "git pull --ff-only", reported OK or FAIL
#
# Canonical toolkits (processed in this order):
#   1. everything-claude-code   github.com/worldflowai/everything-claude-code
#   2. mattpocock-skills        github.com/mattpocock/skills
#   3. ponytail                 github.com/dietrichgebert/ponytail
#   4. guard-skills             github.com/amElnagdy/guard-skills
#   5. cybersecurity-skills     github.com/mukul975/Anthropic-Cybersecurity-Skills
#   6. agency-agents            github.com/msitarzewski/agency-agents
#
# Requirements:
#   - bash
#   - git available on PATH
#
# Usage:
#   ./scripts/sync-toolkit.sh [--dir PATH] [-h | --help]
#
# Exit status:
#   0 — at least one toolkit was updated, or nothing actually failed
#       (missing toolkits are SKIP, dirty trees are DIRTY, not failures)
#   1 — no toolkit was updated and at least one present toolkit failed,
#       git is missing, or the command line was invalid

set -u

SCRIPT_NAME="sync-toolkit.sh"

if [ -z "${HOME:-}" ]; then
    printf 'ERROR: HOME is not set; cannot resolve the default toolkit directory.\n' >&2
    exit 1
fi

TOOLKIT_DIR="${CLAUDE_TOOLKIT_DIR:-${HOME}/ai-agent-toolkit}"

readonly -a TOOLKIT_NAMES=(
    "everything-claude-code"
    "mattpocock-skills"
    "ponytail"
    "guard-skills"
    "cybersecurity-skills"
    "agency-agents"
)

# Per-toolkit result, indexed like TOOLKIT_NAMES ("OK", "FAIL", "SKIP", "DIRTY").
RESULT_STATUS=()
OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
DIRTY_COUNT=0

usage() {
    cat <<EOF
${SCRIPT_NAME} — update the already-cloned toolkits of the
Universal Agentic Engineering OS (fast-forward only; never clones).

Usage:
  ./${SCRIPT_NAME} [options]

Options:
  --dir PATH    Toolkit directory to sync.
                Default: \$CLAUDE_TOOLKIT_DIR or \$HOME/ai-agent-toolkit
  --dir=PATH    Same as --dir PATH.
  -h, --help    Show this help and exit.

Environment:
  CLAUDE_TOOLKIT_DIR   Base directory for the toolkits (overridden by --dir).

Notes:
  Missing toolkits are reported as SKIP — install them with
  scripts/setup-toolkit.sh. Dirty working trees are reported and their
  pull is skipped, so local changes are never overwritten.

Exit status:
  0    At least one toolkit was updated, or nothing actually failed.
  1    Every present toolkit failed to update, git is missing, or the
       command line was invalid.
EOF
}

log_info() {
    printf '[sync] %s\n' "$*"
}

log_error() {
    printf '[sync] ERROR: %s\n' "$*" >&2
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --dir)
                if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                    log_error "--dir requires a non-empty path argument."
                    usage >&2
                    exit 1
                fi
                TOOLKIT_DIR="$2"
                shift 2
                ;;
            --dir=*)
                if [ -z "${1#--dir=}" ]; then
                    log_error "--dir requires a non-empty path argument."
                    usage >&2
                    exit 1
                fi
                TOOLKIT_DIR="${1#--dir=}"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage >&2
                exit 1
                ;;
        esac
    done
}

require_git() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required but was not found on PATH."
        exit 1
    fi
}

record_status() {
    local index="$1"
    local status="$2"

    RESULT_STATUS[index]="$status"
    case "$status" in
        OK) OK_COUNT=$((OK_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
        DIRTY) DIRTY_COUNT=$((DIRTY_COUNT + 1)) ;;
    esac
}

sync_repo() {
    local index="$1"
    local name
    local target_dir
    local pending_changes

    name="${TOOLKIT_NAMES[$index]}"
    target_dir="${TOOLKIT_DIR}/${name}"

    if [ ! -d "$target_dir" ]; then
        record_status "$index" "SKIP"
        printf '[SKIP]  %-24s not installed — run scripts/setup-toolkit.sh to clone it.\n' "$name"
        return 0
    fi

    if [ ! -e "$target_dir/.git" ]; then
        record_status "$index" "FAIL"
        printf '[FAIL]  %-24s exists but is not a git working copy.\n' "$name"
        return 0
    fi

    if ! pending_changes="$(git -C "$target_dir" status --porcelain 2>/dev/null)"; then
        record_status "$index" "FAIL"
        printf '[FAIL]  %-24s git status failed inside the repository.\n' "$name"
        return 0
    fi

    if [ -n "$pending_changes" ]; then
        record_status "$index" "DIRTY"
        printf '[DIRTY] %-24s uncommitted changes — pull skipped (commit or stash first).\n' "$name"
        return 0
    fi

    printf '[PULL]  %-24s fast-forwarding to origin...\n' "$name"
    if git -C "$target_dir" pull --ff-only; then
        record_status "$index" "OK"
    else
        record_status "$index" "FAIL"
        printf '[FAIL]  %-24s fast-forward pull failed — diverged history or unreachable remote.\n' "$name"
    fi
}

process_toolkits() {
    local i

    for ((i = 0; i < ${#TOOLKIT_NAMES[@]}; i++)); do
        sync_repo "$i"
    done
}

print_summary() {
    local i
    local name
    local status

    printf '\n'
    printf 'Sync summary — %s\n' "$TOOLKIT_DIR"
    printf -- '--------------------------------------------------------------\n'
    for ((i = 0; i < ${#TOOLKIT_NAMES[@]}; i++)); do
        name="${TOOLKIT_NAMES[$i]}"
        status="${RESULT_STATUS[$i]}"
        printf '%2d. %-24s %s\n' "$((i + 1))" "$name" "$status"
    done
    printf -- '--------------------------------------------------------------\n'
    printf 'Total: %d   OK: %d   FAIL: %d   SKIP: %d   DIRTY: %d\n' \
        "${#TOOLKIT_NAMES[@]}" "$OK_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$DIRTY_COUNT"
}

print_followup_hint() {
    if [ "$SKIP_COUNT" -gt 0 ]; then
        printf '\nMissing toolkits detected. Install them with:\n'
        printf '  ./scripts/setup-toolkit.sh\n'
    fi
    if [ "$DIRTY_COUNT" -gt 0 ]; then
        printf '\nDirty working trees detected. Commit or stash local changes, then re-run:\n'
        printf '  ./scripts/%s\n' "$SCRIPT_NAME"
    fi
}

main() {
    parse_args "$@"
    require_git

    if [ ! -d "$TOOLKIT_DIR" ]; then
        log_info "Toolkit directory does not exist yet (nothing to sync): $TOOLKIT_DIR"
    else
        log_info "Toolkit directory: $TOOLKIT_DIR"
    fi

    process_toolkits
    print_summary
    print_followup_hint

    if [ "$OK_COUNT" -eq 0 ] && [ "$FAIL_COUNT" -gt 0 ]; then
        log_error "No toolkit was synced successfully."
        exit 1
    fi

    exit 0
}

main "$@"
