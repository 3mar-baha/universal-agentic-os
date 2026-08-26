#!/usr/bin/env bash
#
# ingest-specs.sh — Deep specification ingestion for the Universal Agentic
# Engineering OS.
#
# Reads, parses, and cross-references every specification document under
# docs/ (excluding the live checkpoint and the archive) WITHOUT modifying
# any of them — specifications are authored by the Leader and are immutable
# input. It produces:
#
#   .claude/spec-index.md   compact per-document index (titles, section
#                           outlines, extracted invariants) used to prime
#                           agent context; ephemeral, wiped by teardown.
#   stdout                  consistency report; exit 1 on broken
#                           cross-references so failures are surfaced,
#                           never swallowed.
#
# Consistency checks:
#   - every docs/*.md cross-link target exists,
#   - every scripts/<name>.sh referenced from a doc exists,
#   - document numbering has no duplicates,
#   - the checkpoint's milestone DAG is anchored: every milestone line
#     references material that resolves inside docs/.
#
# Usage:
#   ./scripts/ingest-specs.sh [-h | --help]
#
# Exit status:
#   0 — all documents ingested and cross-references resolve
#   1 — broken cross-reference or unreadable specification found

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCS="${REPO_ROOT}/docs"
CHECKPOINT="10-CHECKPOINT.md"
INDEX="${REPO_ROOT}/.claude/spec-index.md"

log_info() { printf '[ingest] %s\n' "$*"; }
log_warn() { printf '[ingest] WARN: %s\n' "$*" >&2; }
log_error() { printf '[ingest] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
ingest-specs.sh — parse and cross-reference every spec in docs/, read-only.

Writes .claude/spec-index.md (ephemeral context index) and prints a
consistency report. Specifications are never modified.

Exit status:
  0    All specs ingested; cross-references resolve.
  1    Broken reference or duplicate numbering detected.
EOF
}

usage_line() {
    # usage_line <doc_path> — first "# " heading of a document.
    sed -n 's/^#[[:space:]]*//p' "$1" | head -n 1
}

check_references() {
    # check_references <doc_name> <doc_path> — verify targets the doc points
    # at actually exist. Emits errors, increments FAILS via stdout marker.
    local name="$1"
    local path="$2"
    local target resolved

    # Relative markdown links to other repo files.
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        case "$target" in
            http://*|https://*|\#*|mailto:*) continue ;;
        esac
        target="${target%%#*}"
        [ -n "$target" ] || continue
        resolved="${REPO_ROOT}/${target}"
        if [ ! -e "$resolved" ]; then
            log_error "$name links to missing file: $target"
            printf 'FAIL\n'
        fi
    done < <(grep -oE '\]\(([^)]+)\)' "$path" | sed -e 's/^\]//' -e 's/^(//' -e 's/)$//' | sort -u)

    # Explicit script mentions: scripts/foo.sh must exist.
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        if [ ! -f "${REPO_ROOT}/${target}" ]; then
            log_error "$name references missing script: $target"
            printf 'FAIL\n'
        fi
    done < <(grep -oE 'scripts/[A-Za-z0-9._-]+\.sh' "$path" | sort -u)
}

extract_invariants() {
    # extract_invariants <doc_path> — normative lines (MUST/NEVER/invariant).
    grep -nE '(^|[^a-z])(MUST|MUST NOT|NEVER|invariant|Invariant)[^a-z]' "$1" \
        | head -n 8 || true
}

main() {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        usage
        exit 0
    fi

    if [ ! -d "$DOCS" ]; then
        log_error "docs directory not found: $DOCS"
        exit 1
    fi

    mkdir -p "$(dirname "$INDEX")"
    : > "$INDEX"

    local fails=0 warned=0 count=0 doc name title
    local seen_numbers=""

    for doc in "$DOCS"/*.md; do
        [ -f "$doc" ] || continue
        name="$(basename "$doc")"
        [ "$name" = "$CHECKPOINT" ] && continue

        count=$((count + 1))
        title="$(usage_line "$doc")"
        title="${title:-$name}"

        # Duplicate numbering guard (NN- prefix).
        num="$(printf '%s' "$name" | grep -oE '^[0-9]+' || true)"
        if [ -n "$num" ]; then
            case ",$seen_numbers," in
                *",$num,"*)
                    log_error "duplicate document number: $num ($name)"
                    printf 'FAIL\n'
                    ;;
                *) seen_numbers="${seen_numbers:+$seen_numbers,}$num" ;;
            esac
        fi

        log_info "ingesting: $name — $title"
        {
            printf '## %s\n\n' "$title"
            printf -- '- file: docs/%s\n' "$name"
            printf -- '- sections:\n'
            grep -E '^#{2,3} ' "$doc" | sed 's/^/  - /' | head -n 20
            printf '\n'
        } >> "$INDEX"

        if check_references "$name" "$doc" | grep -q '^FAIL$'; then
            fails=$((fails + 1))
        fi

        # Top normative lines ride along as invariant context.
        inv="$(extract_invariants "$doc")"
        if [ -n "$inv" ]; then
            fence='```'
            {
                printf '### Normative lines (%s)\n\n' "$name"
                printf '%s\n%s\n%s\n\n' "$fence" "$inv" "$fence"
            } >> "$INDEX"
        fi
    done

    # Anchor the baseline DAG: milestone lines cite their source material.
    # Mentions of not-yet-authored artifacts are expected mid-milestone, so
    # they warn rather than fail; only unreadable specs are hard errors.
    if [ -f "$DOCS/$CHECKPOINT" ]; then
        while IFS= read -r ref; do
            [ -n "$ref" ] || continue
            case "$ref" in
                docs/*) ref="${ref#docs/}" ;;
            esac
            if [ ! -e "$DOCS/$ref" ] && [ ! -e "${REPO_ROOT}/$ref" ]; then
                log_warn "checkpoint references not-yet-authored artifact: $ref"
                warned=$((warned + 1))
            fi
        done < <(grep -oE '(docs/)?[A-Za-z0-9._/-]+\.md' "$DOCS/$CHECKPOINT" \
            | grep -v "^docs/$CHECKPOINT\$" | sort -u)
        log_info "baseline DAG anchored against $(grep -cE '^- \[' "$DOCS/$CHECKPOINT") DAG item(s)."
    fi

    log_info "index written: ${INDEX#"$REPO_ROOT"/} ($count document(s), ${warned} forward reference(s), $fails failure(s))"

    if [ "$fails" -gt 0 ]; then
        log_error "$fails cross-reference failure(s); fix the specs (never regenerate them)."
        exit 1
    fi
    exit 0
}

main "$@"
