#!/usr/bin/env bash
#
# init.sh — One-command machine bootstrap for the Universal Agentic
# Engineering OS.
#
# Collapses first-time setup into a single step:
#   1. Provisions the 6-toolkit directory (CLAUDE_TOOLKIT_DIR, default
#      ~/ai-agent-toolkit) if missing, then verifies integrity offline.
#   2. Activates this repository's git hooks (secret scanning + zero AI
#      attribution).
#   3. Installs the uos CLI onto PATH (~/.local/bin).
#   4. Prints the CLAUDE_TOOLKIT_DIR export line when the variable is not
#      set (never edits a shell profile silently).
#   5. Finishes with `uos doctor` so the machine's verdict is explicit.
#
# Idempotent: safe to re-run at any time.
#
# Usage:
#   ./scripts/init.sh [-h | --help]
#
# Exit status:
#   0 — environment healthy (doctor passed)
#   1 — a required step failed (toolkit or hooks); doctor details below

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { printf '[init] %s\n' "$*"; }
log_error() { printf '[init] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
init.sh — one-command machine bootstrap for the OS.

Provisions and verifies the 6 toolkits, activates git hooks, installs the
uos CLI, and finishes with a doctor report. Idempotent.

Usage:
  ./scripts/init.sh

Exit status:
  0    Environment healthy.
  1    A required step (toolkit, hooks) failed; see output above.
EOF
}

main() {
    [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

    log_info '1/4 toolkit...'
    if bash "${SCRIPT_DIR}/setup-toolkit.sh"; then
        if bash "${SCRIPT_DIR}/setup-toolkit.sh" --verify > /dev/null 2>&1; then
            log_info 'toolkit verified: 6/6 canonical toolkits intact.'
        else
            log_error 'toolkit verification failed; see setup-toolkit.sh output above.'
            exit 1
        fi
    else
        log_error 'toolkit provisioning failed.'
        exit 1
    fi

    log_info '2/4 git hooks...'
    if ! bash "${SCRIPT_DIR}/setup-git-hooks.sh"; then
        log_error 'git hook activation failed.'
        exit 1
    fi

    log_info '3/4 uos CLI...'
    bash "${SCRIPT_DIR}/uos.sh" install || log_error 'CLI install reported a problem; continuing.'

    if [ -z "${CLAUDE_TOOLKIT_DIR:-}" ]; then
        log_info 'CLAUDE_TOOLKIT_DIR is unset (sessions fall back to ~/ai-agent-toolkit).'
        log_info 'to pin it explicitly, add to your shell profile:'
        # The literal $HOME is the point: users paste this line verbatim.
        # shellcheck disable=SC2016
        printf '       export CLAUDE_TOOLKIT_DIR="%s"\n' '$HOME/ai-agent-toolkit'
    fi

    log_info '4/4 doctor...'
    bash "${SCRIPT_DIR}/uos.sh" doctor
}

main "$@"
