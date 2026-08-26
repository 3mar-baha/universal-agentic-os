#!/usr/bin/env bash
#
# record-decision.sh — Automated ADR ledger for the Universal Agentic
# Engineering OS.
#
# Appends one Architecture Decision Record to the project's decision log so
# every autonomous trade-off stays auditable. The target document is
# auto-detected: docs/09-DECISIONS.md (16-doc spec suite layout), then
# docs/03-DECISIONS.md (canonical scaffold); when neither exists the
# canonical file is created with a standard header.
#
# Records are append-only: existing ADRs are never reordered or rewritten.
#
# Usage:
#   ./scripts/record-decision.sh <TITLE> [--status accepted|proposed|superseded]
#                                [--context TEXT] [--decision TEXT]
#                                [--consequences TEXT] [-h | --help]
#
# Exit status:
#   0 — ADR appended (or created with its header on first use)
#   1 — missing title, invalid status, or unwritable decision log

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() { printf '[decide] %s\n' "$*"; }
log_error() { printf '[decide] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
record-decision.sh — append one ADR to the decision log (auto-detected).

Usage:
  ./scripts/record-decision.sh <TITLE> [--status accepted|proposed|superseded]
                               [--context TEXT] [--decision TEXT]
                               [--consequences TEXT]

  TITLE          short imperative name of the decision (required).
  --status       record state; default: proposed.

Exit status:
  0    ADR appended.
  1    Missing title, invalid status, or unwritable decision log.
EOF
}

detect_decisions_doc() {
    # Auto-detect the decision log; create the canonical file on first use.
    if [ -f "${REPO_ROOT}/docs/09-DECISIONS.md" ]; then
        printf '%s' "${REPO_ROOT}/docs/09-DECISIONS.md"
    elif [ -f "${REPO_ROOT}/docs/03-DECISIONS.md" ]; then
        printf '%s' "${REPO_ROOT}/docs/03-DECISIONS.md"
    else
        mkdir -p "${REPO_ROOT}/docs" || return 1
        {
            printf '# Decision Log\n\n'
            printf 'Architecture Decision Records (ADRs): context, options considered, outcome, and consequences. Appended by the uos decide command; entries are append-only and never reordered.\n'
        } > "${REPO_ROOT}/docs/03-DECISIONS.md"
        printf '%s' "${REPO_ROOT}/docs/03-DECISIONS.md"
    fi
}

next_adr_number() {
    # next_adr_number <doc> — count existing records; numbering is append-only.
    local count
    count="$(grep -cE '^## ADR-[0-9]+' "$1" 2> /dev/null || true)"
    printf 'ADR-%03d' "$((count + 1))"
}

main() {
    local title="" status="proposed" context="" decision="" consequences=""
    local doc adr

    while [ $# -gt 0 ]; do
        case "$1" in
            -h | --help) usage; exit 0 ;;
            --status) status="${2:-}"; shift 2 ;;
            --context) context="${2:-}"; shift 2 ;;
            --decision) decision="${2:-}"; shift 2 ;;
            --consequences) consequences="${2:-}"; shift 2 ;;
            *)
                if [ -z "$title" ]; then
                    title="$1"
                else
                    log_error "unexpected argument: $1"
                    usage >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$title" ]; then
        log_error 'a decision TITLE is required.'
        usage >&2
        exit 1
    fi

    case "$status" in
        accepted | proposed | superseded) ;;
        *)
            log_error "invalid --status '$status' (accepted, proposed, superseded)."
            exit 1
            ;;
    esac

    doc="$(detect_decisions_doc)" || {
        log_error 'cannot create the decision log under docs/.'
        exit 1
    }
    adr="$(next_adr_number "$doc")"

    {
        printf '\n## %s: %s\n\n' "$adr" "$title"
        printf -- '- **Date:** %s\n' "$(date +%Y-%m-%d)"
        printf -- '- **Status:** %s\n\n' "$status"
        printf '### Context\n\n%s\n\n' "${context:-(fill in before sign-off)}"
        printf '### Decision\n\n%s\n\n' "${decision:-(fill in before sign-off)}"
        printf '### Consequences\n\n%s\n' "${consequences:-(fill in before sign-off)}"
    } >> "$doc"

    log_info "$adr recorded in ${doc#"$REPO_ROOT"/}: $title"
    exit 0
}

main "$@"
