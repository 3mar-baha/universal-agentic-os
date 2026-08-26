#!/usr/bin/env bash
#
# generate-graph.sh — Live architecture-graph sync for the Universal Agentic
# Engineering OS.
#
# Scans the repository's top-level structure (directories with file counts,
# root files) and synchronizes it into a deterministic Mermaid diagram
# embedded in the architecture document between marker lines:
#
#   <!-- uos:graph:start -->
#   ```mermaid
#   ...
#   ```
#   <!-- uos:graph:end -->
#
# The target document is auto-detected: docs/04-ARCHITECTURE.md (16-doc spec
# suite layout), then docs/01-ARCHITECTURE.md (canonical scaffold), then
# docs/00-ARCHITECTURE-GUIDE.md (this repository). When no markers exist the
# block is appended under an "Architecture Graph" heading.
#
# Regeneration is idempotent: identical structure produces byte-identical
# output, so re-running is always safe.
#
# Usage:
#   ./scripts/generate-graph.sh [--check]
#
#   --check   do not write; exit 1 when the committed graph is stale.
#
# Exit status:
#   0 — graph synchronized (or already current with --check)
#   1 — no architecture document found, malformed markers, or (--check)
#       the committed graph does not match the current structure

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

START_MARK='uos:graph:start'
END_MARK='uos:graph:end'

# Top-level entries that never belong in an architecture overview.
SKIPPED='.git node_modules .worktrees dist build coverage'

log_info() { printf '[graph] %s\n' "$*"; }
log_error() { printf '[graph] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
generate-graph.sh — synchronize the repo tree into a Mermaid diagram
embedded in the architecture document (marker-bounded, idempotent).

Usage:
  ./scripts/generate-graph.sh [--check]

  --check    verify the committed graph matches the current tree;
             exit 1 when stale, writing nothing.

Exit status:
  0    Graph synchronized (or already current).
  1    No architecture doc, malformed markers, or stale graph (--check).
EOF
}

detect_target_doc() {
    # Auto-detect the architecture document; first existing wins.
    local candidate
    for candidate in \
        "${REPO_ROOT}/docs/04-ARCHITECTURE.md" \
        "${REPO_ROOT}/docs/01-ARCHITECTURE.md" \
        "${REPO_ROOT}/docs/00-ARCHITECTURE-GUIDE.md"; do
        if [ -f "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

emit_graph_block() {
    # emit_graph_block <output_file> — marker-bounded deterministic block.
    local out="$1"
    local entry count i=0

    {
        printf '<!-- %s -->\n' "$START_MARK"
        printf '```mermaid\n'
        printf 'graph TD\n'
        printf '    ROOT["%s"]\n' "$(basename "$REPO_ROOT")"
        while IFS= read -r entry; do
            [ -n "$entry" ] || continue
            case " $SKIPPED " in *" ${entry} "*) continue ;; esac
            i=$((i + 1))
            if [ -d "${REPO_ROOT}/${entry}" ]; then
                # Tracked files only: ephemeral content must never make the
                # graph stale between sessions.
                count="$(git -C "$REPO_ROOT" ls-files -- "$entry" 2> /dev/null | wc -l | tr -d ' ')"
                printf '    ROOT --> n%s["%s/ (%s files)"]\n' "$i" "$entry" "$count"
            else
                printf '    ROOT --> n%s["%s"]\n' "$i" "$entry"
            fi
        done < <(cd "$REPO_ROOT" && find . -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)
        printf '```\n'
        printf '<!-- %s -->\n' "$END_MARK"
    } > "$out"
}

main() {
    local check=0 arg="${1:-}"
    local target tmp_block tmp_doc
    local starts ends

    case "$arg" in
        -h | --help) usage; exit 0 ;;
        --check) check=1 ;;
        '') ;;
        *)
            log_error "unknown option: $arg"
            usage >&2
            exit 1
            ;;
    esac

    target="$(detect_target_doc)" || {
        log_error 'no architecture document found (expected docs/04-ARCHITECTURE.md, docs/01-ARCHITECTURE.md, or docs/00-ARCHITECTURE-GUIDE.md).'
        exit 1
    }

    tmp_block="$(mktemp)"
    tmp_doc="$(mktemp)"
    trap 'rm -f "$tmp_block" "$tmp_doc"' EXIT

    emit_graph_block "$tmp_block"

    starts="$(grep -cxF "<!-- ${START_MARK} -->" "$target" || true)"
    ends="$(grep -cxF "<!-- ${END_MARK} -->" "$target" || true)"
    if [ "$starts" -gt 1 ] || [ "$ends" -gt 1 ]; then
        log_error 'duplicate graph markers; keep exactly one start/end pair.'
        exit 1
    fi

    if [ "$starts" -eq 1 ] && [ "$ends" -eq 1 ]; then
        # Replace mode: swap the marker-bounded block in place.
        awk -v blk="$tmp_block" -v s="$START_MARK" -v e="$END_MARK" '
            BEGIN { n = 0; while ((getline line < blk) > 0) lines[n++] = line; close(blk) }
            index($0, "<!-- " s " -->") { inblk = 1; for (i = 0; i < n; i++) print lines[i]; next }
            index($0, "<!-- " e " -->") { inblk = 0; next }
            !inblk { print }
        ' "$target" > "$tmp_doc"
    elif [ "$starts" -eq 0 ] && [ "$ends" -eq 0 ]; then
        if [ "$check" -eq 1 ]; then
            log_error 'no graph embedded yet; run scripts/generate-graph.sh once.'
            exit 1
        fi
        # Append mode: new section at the end of the document.
        {
            cat "$target"
            # Guard against a missing trailing newline merging the heading.
            [ -s "$target" ] && [ -n "$(tail -c 1 "$target")" ] && printf '\n'
            printf '\n## Architecture Graph\n\n'
            cat "$tmp_block"
        } > "$tmp_doc"
    else
        log_error 'malformed graph markers (start/end pair incomplete); fix them manually.'
        exit 1
    fi

    if [ "$check" -eq 1 ]; then
        if cmp -s "$target" "$tmp_doc"; then
            log_info 'graph is current.'
            exit 0
        fi
        log_error "committed graph is stale; regenerate: bash scripts/generate-graph.sh (${target#"$REPO_ROOT"/})"
        exit 1
    fi

    cat "$tmp_doc" > "$target"
    log_info "graph synchronized into ${target#"$REPO_ROOT"/}"
    exit 0
}

main "$@"
