#!/usr/bin/env bash
#
# setup-git-hooks.sh — activate this repository's git hooks.
#
# One line of work (git config core.hooksPath .githooks) plus a sanity
# check, so clones enforce secret scanning and zero AI attribution from
# the first commit. Idempotent.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

main() {
    if ! command -v git > /dev/null 2>&1; then
        printf 'ERROR: git is required but was not found on PATH.\n' >&2
        exit 1
    fi
    if [ ! -d "${REPO_ROOT}/.git" ]; then
        printf 'ERROR: %s is not a git repository.\n' "$REPO_ROOT" >&2
        exit 1
    fi

    git -C "$REPO_ROOT" config core.hooksPath .githooks
    printf '[git-hooks] hooksPath set to .githooks\n'

    if git -C "$REPO_ROOT" config core.hooksPath | grep -qx '.githooks'; then
        printf '[git-hooks] active: pre-commit (secrets + AI attribution), commit-msg (attribution).\n'
        exit 0
    fi
    printf 'ERROR: failed to activate .githooks.\n' >&2
    exit 1
}

main "$@"
