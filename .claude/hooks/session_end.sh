#!/usr/bin/env bash
#
# session_end.sh — Native Claude Code SessionEnd hook.
#
# Runs the ephemeral teardown (injected skills/agents, stage hooks, strike
# state) before the session exits, so no phase's context leaks into the next.
#
# This hook must never block session exit: it exits 0 on every path.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

main() {
    printf '[session-end] running ephemeral teardown...\n'
    if bash "${REPO_ROOT}/scripts/teardown-stage.sh"; then
        printf '[session-end] teardown complete; context is phase-neutral.\n'
    else
        # Never trap the user in a session that cannot end.
        printf '[session-end] WARN: teardown returned non-zero; leaving state as-is.\n' >&2
    fi
    exit 0
}

main "$@"
