#!/usr/bin/env bash
#
# teardown-stage.sh — Ephemeral teardown for the Universal Agentic
# Engineering OS.
#
# Removes everything a stage session accumulated that must not leak into the
# next one:
#   - .claude/skills/*  (injected toolkit context)
#   - .claude/agents/*  (injected specialist agents)
#   .claude/hooks/stage-*.sh (ephemeral stage hooks)
#   - .claude/.strike_tracker (circuit-breaker strike state)
#   - .claude/hooks/ecc/ (vendored upstream ECC lifecycle hooks)
#   - .claude/spec-index.md (spec ingestion index)
#   - empty .worktrees/ directory left by stream dispatching
#
# It never touches project code, docs/, or the repository's own bundled
# skills/ directory. Safe to run repeatedly and from any directory.
#
# Usage:
#   ./scripts/teardown-stage.sh [-h | --help]
#
# Exit status:
#   0 — teardown completed (nothing to remove counts as success)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
    cat <<'EOF'
teardown-stage.sh — clean all temporary skills, agents, ephemeral stage
hooks, and circuit-breaker state before session exit.

Usage:
  ./scripts/teardown-stage.sh

Exit status:
  0    Teardown completed (or there was nothing to clean).
EOF
}

log_info() {
    printf '[teardown] %s\n' "$*"
}

main() {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        usage
        exit 0
    fi

    local removed=0

    for target in \
        "${REPO_ROOT}/.claude/skills" \
        "${REPO_ROOT}/.claude/agents" \
        "${REPO_ROOT}/.claude/hooks/ecc"; do
        if [ -d "$target" ]; then
            rm -rf "$target"
            removed=$((removed + 1))
            log_info "removed $(basename "$target")/"
        fi
    done

    if compgen -G "${REPO_ROOT}/.claude/hooks/stage-*.sh" > /dev/null; then
        rm -f "${REPO_ROOT}/.claude/hooks/stage-"*.sh
        removed=$((removed + 1))
        log_info 'removed ephemeral stage hooks'
    fi

    if [ -f "${REPO_ROOT}/.claude/.strike_tracker" ]; then
        rm -f "${REPO_ROOT}/.claude/.strike_tracker"
        log_info 'reset circuit-breaker strike tracker'
    fi

    if [ -f "${REPO_ROOT}/.claude/spec-index.md" ]; then
        rm -f "${REPO_ROOT}/.claude/spec-index.md"
        log_info 'removed spec ingestion index'
    fi

    if [ -d "${REPO_ROOT}/.worktrees" ] && [ -z "$(ls -A "${REPO_ROOT}/.worktrees")" ]; then
        rmdir "${REPO_ROOT}/.worktrees"
        log_info 'removed empty .worktrees/ directory'
    fi

    # Recreate the empty scaffolding so hooks never hit missing directories.
    mkdir -p "${REPO_ROOT}/.claude/skills" "${REPO_ROOT}/.claude/agents" "${REPO_ROOT}/.claude/hooks"

    log_info "teardown complete (${removed} target(s) removed). Context is phase-neutral."
    exit 0
}

main "$@"
