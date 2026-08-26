#!/usr/bin/env bash
#
# release.sh — One-command release publishing for the Universal Agentic
# Engineering OS.
#
# Given a version, it performs the full ship sequence:
#   1. Validates the version and locates its CHANGELOG section.
#   2. Extracts that section as the release notes (nothing invented).
#   3. Refuses on a dirty work tree or an existing v<version> tag.
#   4. Creates the annotated tag, pushes the branch and the tag.
#   5. Creates the GitHub release with the extracted notes via gh.
#
# Usage:
#   ./scripts/release.sh <VERSION> [--draft] [-h | --help]
#
#   VERSION     X.Y.Z (a leading "v" is accepted and stripped).
#   --draft     create the GitHub release as a draft for review.
#
# Exit status:
#   0 — tagged, pushed, and released
#   1 — refused (bad version, missing CHANGELOG section, dirty tree,
#       existing tag) or publish failed

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

log_info() { printf '[release] %s\n' "$*"; }
log_error() { printf '[release] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
release.sh — tag, push, and publish a release from CHANGELOG notes.

Usage:
  ./scripts/release.sh <VERSION> [--draft]

  VERSION    X.Y.Z matching a '## [<VERSION>]' section in CHANGELOG.md.

Exit status:
  0    Tagged, pushed, and released.
  1    Refused or publish failed; nothing partial is left behind except
       an already-pushed tag (reported explicitly).
EOF
}

extract_notes() {
    # extract_notes <version> — print this version's CHANGELOG section:
    # printing turns on at our heading and off at the next version heading.
    awk -v "ver=$1" '
        /^## \[[0-9]/ { on = (index($0, "## [" ver "]") == 1) }
        on { print }
    ' "$CHANGELOG"
}

main() {
    local version="" draft=""
    local notes branch tag repo_slug

    while [ $# -gt 0 ]; do
        case "$1" in
            -h | --help) usage; exit 0 ;;
            --draft) draft=1; shift ;;
            *)
                if [ -z "$version" ]; then
                    version="$1"
                else
                    log_error "unexpected argument: $1"
                    usage >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    case "$version" in
        [vV][0-9]*) version="${version#[vV]}" ;;
    esac
    if ! printf '%s' "$version" | grep -qE '^[0-9]+(\.[0-9]+){2,3}$'; then
        log_error "VERSION must be X.Y.Z or X.Y.Z.W (got: '${version}')."
        usage >&2
        exit 1
    fi

    if [ ! -f "$CHANGELOG" ]; then
        log_error "no changelog at ${CHANGELOG#"$REPO_ROOT"/}."
        exit 1
    fi

    notes="$(mktemp)"
    trap 'rm -f "$notes"' EXIT
    extract_notes "$version" > "$notes"
    if ! grep -q '^## \[' "$notes"; then
        log_error "CHANGELOG has no '## [$version]' section."
        exit 1
    fi

    if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
        log_error 'work tree is dirty; commit everything before releasing.'
        exit 1
    fi

    branch="$(git -C "$REPO_ROOT" branch --show-current)"
    if [ -z "$branch" ]; then
        log_error 'detached HEAD; run from a branch.'
        exit 1
    fi

    tag="v${version}"
    if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/${tag}" > /dev/null; then
        log_error "tag ${tag} already exists locally."
        exit 1
    fi

    log_info "releasing ${tag} from branch ${branch} ($(wc -l < "$notes" | tr -d ' ') note lines)"

    if ! git -C "$REPO_ROOT" tag -a "$tag" -m "${tag}"; then
        log_error 'git tag failed.'
        exit 1
    fi
    if ! git -C "$REPO_ROOT" push origin "$branch" "$tag"; then
        log_error "push failed; the local tag ${tag} was NOT removed — delete it manually if re-running: git tag -d ${tag}"
        exit 1
    fi

    local create_args=(--title "${tag}" --notes-file "$notes")
    [ -n "$draft" ] && create_args+=(--draft)
    if command -v gh > /dev/null 2>&1; then
        gh release create "$tag" "${create_args[@]}"
    else
        log_error 'gh is not installed; tag is pushed but no release was created.'
        exit 1
    fi

    repo_slug="$(git -C "$REPO_ROOT" remote get-url origin | sed -E 's#.*github\.com[/:]##; s#\.git$##')"
    log_info "released ${tag}: https://github.com/${repo_slug}/releases/tag/${tag}"
    exit 0
}

main "$@"
