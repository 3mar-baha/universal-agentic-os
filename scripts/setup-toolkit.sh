#!/usr/bin/env bash
#
# setup-toolkit.sh — One-click clone-or-update of the 6 canonical upstream
# toolkits of the Universal Agentic Engineering OS.
#
# What it does:
#   - Resolves the centralized toolkit directory from CLAUDE_TOOLKIT_DIR
#     (default: "$HOME/ai-agent-toolkit"), overridable via the environment
#     or the --dir flag.
#   - Creates the toolkit directory if it does not exist.
#   - For each canonical toolkit below: updates it in place with
#     "git pull --quiet" when it is already cloned, otherwise performs a
#     shallow "git clone --depth 1".
#   - With --verify: performs no network operation at all; instead checks
#     that every canonical toolkit is present (a git working copy with a
#     resolvable HEAD) and unmutated (clean working tree), and fails if
#     any of the 6 is missing or dirty.
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
#   - network access to github.com (except for --verify)
#
# Usage:
#   ./scripts/setup-toolkit.sh [--dir PATH] [--verify] [-h | --help]
#
# Exit status:
#   0 — at least one toolkit was cloned or updated successfully,
#       or (--verify) all 6 toolkits are present and unmutated
#   1 — all toolkits failed, the toolkit directory could not be created,
#       git is missing, the command line was invalid, or (--verify) at
#       least one toolkit is missing or mutated
#
# After setup, point agents at the toolkit via your shell profile:
#   export CLAUDE_TOOLKIT_DIR="$HOME/ai-agent-toolkit"

set -u

SCRIPT_NAME="setup-toolkit.sh"
# shellcheck disable=SC2016  # literal "$HOME" is intentional: the hint is printed verbatim
DEFAULT_PROFILE_HINT='export CLAUDE_TOOLKIT_DIR="$HOME/ai-agent-toolkit"'

if [ -z "${HOME:-}" ]; then
    printf 'ERROR: HOME is not set; cannot resolve the default toolkit directory.\n' >&2
    exit 1
fi

TOOLKIT_DIR="${CLAUDE_TOOLKIT_DIR:-${HOME}/ai-agent-toolkit}"
VERIFY=0

readonly -a TOOLKIT_URLS=(
    "https://github.com/worldflowai/everything-claude-code.git"
    "https://github.com/mattpocock/skills.git"
    "https://github.com/dietrichgebert/ponytail.git"
    "https://github.com/amElnagdy/guard-skills.git"
    "https://github.com/mukul975/Anthropic-Cybersecurity-Skills.git"
    "https://github.com/msitarzewski/agency-agents.git"
)

readonly -a TOOLKIT_NAMES=(
    "everything-claude-code"
    "mattpocock-skills"
    "ponytail"
    "guard-skills"
    "cybersecurity-skills"
    "agency-agents"
)

# Per-toolkit result, indexed like TOOLKIT_NAMES ("OK" or "FAIL").
RESULT_STATUS=()
OK_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<EOF
${SCRIPT_NAME} — clone or update the 6 canonical toolkits of the
Universal Agentic Engineering OS into CLAUDE_TOOLKIT_DIR.

Usage:
  ./${SCRIPT_NAME} [options]

Options:
  --dir PATH    Target toolkit directory.
                Default: \$CLAUDE_TOOLKIT_DIR or \$HOME/ai-agent-toolkit
  --dir=PATH    Same as --dir PATH.
  --verify      Offline integrity check: every canonical toolkit must be a
                git working copy with a resolvable HEAD and a clean tree.
                No clone, no pull, no network.
  -h, --help    Show this help and exit.

Environment:
  CLAUDE_TOOLKIT_DIR   Base directory for the toolkits (overridden by --dir).

Exit status:
  0    At least one toolkit was cloned or updated successfully, or
       (--verify) all 6 toolkits are present and unmutated.
  1    All toolkits failed, the toolkit directory could not be created,
       git is missing, the command line was invalid, or (--verify) at
       least one toolkit is missing or mutated.
EOF
}

log_info() {
    printf '[setup] %s\n' "$*"
}

log_error() {
    printf '[setup] ERROR: %s\n' "$*" >&2
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
            --verify)
                VERIFY=1
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

ensure_base_dir() {
    if [ ! -d "$TOOLKIT_DIR" ]; then
        log_info "Creating toolkit directory: $TOOLKIT_DIR"
        if ! mkdir -p "$TOOLKIT_DIR"; then
            log_error "Could not create toolkit directory: $TOOLKIT_DIR"
            return 1
        fi
    elif [ ! -w "$TOOLKIT_DIR" ]; then
        log_error "Toolkit directory is not writable: $TOOLKIT_DIR"
        return 1
    fi
    return 0
}

# Clone "$repo_url" into "$target_dir", or update it in place when it already
# exists as a git working copy.
clone_or_update() {
    local target_dir="$1"
    local repo_url="$2"

    if [ -e "$target_dir/.git" ]; then
        printf 'Updating %s...\n' "$target_dir"
        git -C "$target_dir" pull --quiet
    else
        printf 'Cloning %s from %s...\n' "$target_dir" "$repo_url"
        git clone --depth 1 "$repo_url" "$target_dir"
    fi
}

process_toolkits() {
    local i
    local name
    local repo_url
    local target_dir

    for ((i = 0; i < ${#TOOLKIT_NAMES[@]}; i++)); do
        name="${TOOLKIT_NAMES[$i]}"
        repo_url="${TOOLKIT_URLS[$i]}"
        target_dir="${TOOLKIT_DIR}/${name}"
        if clone_or_update "$target_dir" "$repo_url"; then
            RESULT_STATUS[i]="OK"
            OK_COUNT=$((OK_COUNT + 1))
        else
            RESULT_STATUS[i]="FAIL"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            log_error "Failed to set up $name."
        fi
    done
}

# Offline integrity gate for one toolkit directory: it must be a git working
# copy with a resolvable HEAD (complete enough to pin) and a clean tree
# (unmutated — no local edits, no untracked debris). Sets RESULT_STATUS.
verify_toolkit() {
    local name="$1"
    local target_dir="${TOOLKIT_DIR}/${name}"
    local head_commit

    if [ ! -e "${target_dir}/.git" ]; then
        log_error "verify: $name is missing or not a git working copy ($target_dir)."
        return 1
    fi
    if ! head_commit="$(git -C "$target_dir" rev-parse --verify HEAD 2>/dev/null)"; then
        log_error "verify: $name has no resolvable HEAD (incomplete clone?)."
        return 1
    fi
    if [ -n "$(git -C "$target_dir" status --porcelain)" ]; then
        log_error "verify: $name has a dirty working tree (mutated after clone)."
        return 1
    fi
    printf '[setup] verify: %-24s OK @ %.7s\n' "$name" "$head_commit"
    return 0
}

verify_toolkits() {
    local i
    local name

    for ((i = 0; i < ${#TOOLKIT_NAMES[@]}; i++)); do
        name="${TOOLKIT_NAMES[$i]}"
        if verify_toolkit "$name"; then
            RESULT_STATUS[i]="OK"
            OK_COUNT=$((OK_COUNT + 1))
        else
            RESULT_STATUS[i]="FAIL"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    done
}

print_summary() {
    local i
    local name
    local status

    printf '\n'
    printf 'Setup summary — %s\n' "$TOOLKIT_DIR"
    printf -- '--------------------------------------------------------------\n'
    for ((i = 0; i < ${#TOOLKIT_NAMES[@]}; i++)); do
        name="${TOOLKIT_NAMES[$i]}"
        status="${RESULT_STATUS[$i]}"
        printf '%2d. %-24s %s\n' "$((i + 1))" "$name" "$status"
    done
    printf -- '--------------------------------------------------------------\n'
    printf 'Total: %d   OK: %d   FAIL: %d\n' \
        "${#TOOLKIT_NAMES[@]}" "$OK_COUNT" "$FAIL_COUNT"
}

print_profile_hint() {
    printf '\nPoint agents at the toolkit by adding this to your shell profile:\n'
    if [ "$TOOLKIT_DIR" = "${HOME}/ai-agent-toolkit" ]; then
        printf '  %s\n' "$DEFAULT_PROFILE_HINT"
    else
        printf '  export CLAUDE_TOOLKIT_DIR="%s"\n' "$TOOLKIT_DIR"
    fi
}

main() {
    parse_args "$@"
    require_git

    log_info "Toolkit directory: $TOOLKIT_DIR"

    if [ "$VERIFY" -eq 1 ]; then
        verify_toolkits
        print_summary
        if [ "$FAIL_COUNT" -gt 0 ]; then
            log_error "Verification failed for $FAIL_COUNT toolkit(s); run without --verify to (re)install them."
            exit 1
        fi
        printf '[setup] verify: all %d canonical toolkits are present and unmutated.\n' "${#TOOLKIT_NAMES[@]}"
        exit 0
    fi

    if ! ensure_base_dir; then
        exit 1
    fi

    process_toolkits
    print_summary

    if [ "$OK_COUNT" -eq 0 ]; then
        log_error "No toolkit was set up successfully."
        exit 1
    fi

    print_profile_hint
    exit 0
}

main "$@"
