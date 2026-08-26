#!/usr/bin/env bash
#
# orchestrate-stage.sh — Deterministic stage orchestration for the Universal
# Agentic Engineering OS.
#
# Given a phase number (1-4), it:
#   1. Purges all ephemeral context (.claude/skills/*, .claude/agents/*,
#      ephemeral stage hooks) so no stale kit from another phase survives.
#   2. Injects exactly the skills and agents that phase needs, copied from
#      the centralized toolkit directory (CLAUDE_TOOLKIT_DIR, default
#      "$HOME/ai-agent-toolkit") or from this repository's own bundled
#      skills/ directory.
#
# Phase injection table (sources verified against the 6 upstream toolkits):
#   Phase 1 — Inception & Specs:
#       agency-agents        testing/testing-reality-checker.md -> agents/reality-checker.md
#       agency-agents        product/product-manager.md         -> agents/product-manager.md
#       mattpocock-skills    productivity/grill-me              -> skills/grill-me
#       mattpocock-skills    engineering/to-spec                -> skills/to-spec
#   Phase 2 — Core Build & TDD:
#       ponytail             skills/* (all 6)                   -> skills/<name>
#       mattpocock-skills    engineering/tdd                    -> skills/tdd
#       mattpocock-skills    engineering/diagnosing-bugs        -> skills/diagnosing-bugs
#       everything-claude-code agents/tdd-guide.md               -> agents/tdd-guide.md
#       everything-claude-code language specialist (detected)    -> agents/
#       everything-claude-code rules/testing.md                  -> skills/reference-ecc-testing-rules.md
#   Phase 3 — Quality Gates & Security:
#       guard-skills         clean-code-guard                   -> skills/clean-code-guard
#       guard-skills         test-guard                         -> skills/test-guard
#       cybersecurity-skills github-advanced-security scanning  -> skills/security-review
#       everything-claude-code agents/security-reviewer.md      -> agents/security-reviewer.md
#       everything-claude-code rules/security.md                 -> skills/reference-ecc-security-rules.md
#   Phase 4 — Docs Verification & Release:
#       guard-skills         docs-guard                         -> skills/docs-guard
#       mattpocock-skills    misc/git-guardrails-claude-code    -> skills/git-guardrails
#       this repository      skills/github-release-packager.md  -> skills/github-release-packager.md
#
# A missing toolkit asset is a warning, not a fatal error: upstream toolkits
# evolve. A missing TOOLKIT_DIR is fatal. The script never edits project code.
#
# Usage:
#   ./scripts/orchestrate-stage.sh <PHASE_NUM> [-h | --help]
#
# Exit status:
#   0 — phase orchestrated (individual missing assets are warnings)
#   1 — invalid arguments, or the toolkit directory does not exist, or
#       every injection of the phase failed

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -z "${HOME:-}" ]; then
    printf 'ERROR: HOME is not set; cannot resolve the default toolkit directory.\n' >&2
    exit 1
fi

TOOLKIT_DIR="${CLAUDE_TOOLKIT_DIR:-${HOME}/ai-agent-toolkit}"

SKILLS_DEST="${REPO_ROOT}/.claude/skills"
AGENTS_DEST="${REPO_ROOT}/.claude/agents"

INJECTED=0
WARNED=0
FAILED=0

usage() {
    cat <<EOF
orchestrate-stage.sh — purge ephemeral context, then inject exactly the
skills and agents one lifecycle phase needs.

Usage:
  ./scripts/orchestrate-stage.sh <PHASE_NUM>

Phases:
  1    Inception & Specs            (reality-check, product management, grilling, to-spec)
  2    Core Build & TDD             (ponytail set, tdd, diagnosing-bugs, ECC implementers)
  3    Quality Gates & Security     (clean-code/test guards, security review, ECC auditor)
  4    Docs Verification & Release  (docs-guard, git guardrails, release packager)

Environment:
  CLAUDE_TOOLKIT_DIR   Base directory of the 6 canonical toolkits.
                       Default: \$HOME/ai-agent-toolkit

Exit status:
  0    Phase orchestrated; individual missing assets are reported as warnings.
  1    Invalid arguments, missing toolkit directory, or every injection failed.
EOF
}

log_info() {
    printf '[orchestrate] %s\n' "$*"
}

log_warn() {
    printf '[orchestrate] WARN: %s\n' "$*" >&2
}

log_error() {
    printf '[orchestrate] ERROR: %s\n' "$*" >&2
}

# inject_dir <source_path> <destination_name>
# Copy a skill directory (or file) from the toolkit into .claude/skills/.
inject_dir() {
    local src="$1"
    local dest_name="$2"

    if [ ! -e "$src" ]; then
        log_warn "missing toolkit asset, skipped: $src"
        WARNED=$((WARNED + 1))
        return 0
    fi
    if ! cp -R "$src" "${SKILLS_DEST}/${dest_name}"; then
        log_error "copy failed: $src -> ${SKILLS_DEST}/${dest_name}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    INJECTED=$((INJECTED + 1))
    printf '[orchestrate] + skill  %s\n' "$dest_name"
}

# inject_agent <source_path> <destination_name>
# Copy an agent definition file into .claude/agents/.
inject_agent() {
    local src="$1"
    local dest_name="$2"

    if [ ! -e "$src" ]; then
        log_warn "missing toolkit asset, skipped: $src"
        WARNED=$((WARNED + 1))
        return 0
    fi
    if ! cp -R "$src" "${AGENTS_DEST}/${dest_name}"; then
        log_error "copy failed: $src -> ${AGENTS_DEST}/${dest_name}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    INJECTED=$((INJECTED + 1))
    printf '[orchestrate] + agent  %s\n' "$dest_name"
}

purge_ephemeral_context() {
    rm -rf "$SKILLS_DEST" "$AGENTS_DEST"
    mkdir -p "$SKILLS_DEST" "$AGENTS_DEST"
    # Ephemeral stage hooks and vendored ECC hooks follow the same lifecycle
    # as injected context.
    rm -f "${REPO_ROOT}/.claude/hooks/stage-"*.sh 2>/dev/null
    rm -rf "${REPO_ROOT}/.claude/hooks/ecc"
    log_info 'purged .claude/skills/*, .claude/agents/*, ephemeral stage hooks, and ECC hook vendoring'
}

# inject_ecc_lifecycle_hooks
# Vendor the upstream everything-claude-code lifecycle hooks (the
# dependency-free bash variants) into the ephemeral .claude/hooks/ecc
# directory. The native session_start/session_end hooks invoke them when
# present, so upstream context persistence rides the OS's own lifecycle
# events without touching tracked settings.
inject_ecc_lifecycle_hooks() {
    local src_base="${TOOLKIT_DIR}/everything-claude-code/hooks"
    local pair src dest_name

    mkdir -p "${REPO_ROOT}/.claude/hooks/ecc"
    for pair in \
        "memory-persistence/session-start.sh:session-start.sh" \
        "memory-persistence/session-end.sh:session-end.sh" \
        "memory-persistence/pre-compact.sh:pre-compact.sh" \
        "strategic-compact/suggest-compact.sh:suggest-compact.sh"; do
        src="${src_base}/${pair%%:*}"
        dest_name="${pair##*:}"
        if [ ! -e "$src" ]; then
            log_warn "missing ECC hook asset, skipped: $src"
            WARNED=$((WARNED + 1))
            continue
        fi
        if ! cp "$src" "${REPO_ROOT}/.claude/hooks/ecc/${dest_name}"; then
            log_error "copy failed: $src -> ${REPO_ROOT}/.claude/hooks/ecc/${dest_name}"
            FAILED=$((FAILED + 1))
            continue
        fi
        INJECTED=$((INJECTED + 1))
        printf '[orchestrate] + ecc-hook %s\n' "$dest_name"
    done
}

# select_language_specialist
# Inspects the project's specification documents to detect the implementation
# language, then prints the path of the matching specialist agent definition.
# ponytail: keyword mapping over the spec text; swap in per-language agents
# when ECC ships them.
select_language_specialist() {
    local spec_file=""
    local candidate
    local lang

    # Canonical name first (docs/03-TECHNICAL-SPECIFICATION.md), then the
    # scaffold's own architecture/decision files as fallbacks.
    for candidate in \
        "${REPO_ROOT}/docs/03-TECHNICAL-SPECIFICATION.md" \
        "${REPO_ROOT}/docs/01-ARCHITECTURE.md" \
        "${REPO_ROOT}/docs/03-DECISIONS.md"; do
        if [ -f "$candidate" ]; then
            spec_file="$candidate"
            break
        fi
    done

    if [ -z "$spec_file" ]; then
        printf '%s' ""
        return 0
    fi

    lang="$(grep -ioE 'typescript|javascript|python|rust|golang|kotlin|swift|php|ruby|c\+\+|c#' \
        "$spec_file" | head -n 1 | tr '[:upper:]' '[:lower:]')"

    case "${lang:-}" in
        rust)
            printf '%s' "${TOOLKIT_DIR}/agency-agents/engineering/engineering-rust-refactoring-specialist.md"
            ;;
        typescript|javascript|python|golang|kotlin|swift|php|ruby|c++|c#)
            # No dedicated per-language agent upstream yet; the ECC architect
            # carries stack-level guidance for every mainstream language.
            printf '%s' "${TOOLKIT_DIR}/everything-claude-code/agents/architect.md"
            ;;
        *)
            printf '%s' ""
            ;;
    esac
}

orchestrate_phase_1() {
    inject_agent "${TOOLKIT_DIR}/agency-agents/testing/testing-reality-checker.md" "reality-checker.md"
    inject_agent "${TOOLKIT_DIR}/agency-agents/product/product-manager.md" "product-manager.md"
    inject_dir "${TOOLKIT_DIR}/mattpocock-skills/skills/productivity/grill-me" "grill-me"
    inject_dir "${TOOLKIT_DIR}/mattpocock-skills/skills/engineering/to-spec" "to-spec"
}

orchestrate_phase_2() {
    local ponytail_skill
    local specialist

    for ponytail_skill in "${TOOLKIT_DIR}/ponytail/skills/"*; do
        [ -e "$ponytail_skill" ] || continue
        inject_dir "$ponytail_skill" "$(basename "$ponytail_skill")"
    done
    inject_dir "${TOOLKIT_DIR}/mattpocock-skills/skills/engineering/tdd" "tdd"
    inject_dir "${TOOLKIT_DIR}/mattpocock-skills/skills/engineering/diagnosing-bugs" "diagnosing-bugs"

    inject_agent "${TOOLKIT_DIR}/everything-claude-code/agents/tdd-guide.md" "tdd-guide.md"
    specialist="$(select_language_specialist)"
    if [ -n "$specialist" ]; then
        inject_agent "$specialist" "$(basename "$specialist")"
        log_info "language specialist selected from spec: $(basename "$specialist")"
    else
        log_info 'no specification document found; defaulting to ECC architect as language specialist'
        inject_agent "${TOOLKIT_DIR}/everything-claude-code/agents/architect.md" "architect.md"
    fi

    # The ECC testing discipline rides along as reference context.
    inject_dir "${TOOLKIT_DIR}/everything-claude-code/rules/testing.md" "reference-ecc-testing-rules.md"
}

orchestrate_phase_3() {
    inject_dir "${TOOLKIT_DIR}/guard-skills/skills/clean-code-guard" "clean-code-guard"
    inject_dir "${TOOLKIT_DIR}/guard-skills/skills/test-guard" "test-guard"
    inject_dir \
        "${TOOLKIT_DIR}/cybersecurity-skills/skills/implementing-github-advanced-security-for-code-scanning" \
        "security-review"
    inject_agent "${TOOLKIT_DIR}/everything-claude-code/agents/security-reviewer.md" "security-reviewer.md"
    inject_dir "${TOOLKIT_DIR}/everything-claude-code/rules/security.md" "reference-ecc-security-rules.md"
}

orchestrate_phase_4() {
    inject_dir "${TOOLKIT_DIR}/guard-skills/skills/docs-guard" "docs-guard"
    inject_dir "${TOOLKIT_DIR}/mattpocock-skills/skills/misc/git-guardrails-claude-code" "git-guardrails"
    # Release packaging is bundled with this repository itself.
    inject_dir "${REPO_ROOT}/skills/github-release-packager.md" "github-release-packager.md"
}

print_inventory() {
    local dir
    local count

    for dir in "$SKILLS_DEST" "$AGENTS_DEST"; do
        count="$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
        printf '[orchestrate] inventory %-16s %s item(s)\n' "$(basename "$dir"):" "$count"
    done
}

main() {
    local phase="${1:-}"

    if [ "${2:-}" = "-h" ] || [ "${2:-}" = "--help" ] || [ "$phase" = "-h" ] || [ "$phase" = "--help" ]; then
        usage
        exit 0
    fi

    case "$phase" in
        1|2|3|4) ;;
        *)
            log_error "PHASE_NUM must be 1, 2, 3, or 4 (got: '${phase}')."
            usage >&2
            exit 1
            ;;
    esac

    if [ ! -d "$TOOLKIT_DIR" ]; then
        log_error "toolkit directory not found: $TOOLKIT_DIR"
        log_error "run scripts/setup-toolkit.sh first."
        exit 1
    fi

    log_info "orchestrating phase $phase against $REPO_ROOT"

    mkdir -p "${REPO_ROOT}/.claude/hooks"
    purge_ephemeral_context

    case "$phase" in
        1) orchestrate_phase_1 ;;
        2) orchestrate_phase_2 ;;
        3) orchestrate_phase_3 ;;
        4) orchestrate_phase_4 ;;
    esac

    # Lifecycle-wide: ECC context persistence rides every phase, not one.
    inject_ecc_lifecycle_hooks

    print_inventory

    if [ "$FAILED" -gt 0 ]; then
        log_error "$FAILED injection(s) failed; see errors above."
        exit 1
    fi
    if [ "$INJECTED" -eq 0 ]; then
        log_error "every injection of phase $phase was skipped (toolkit layout changed?)."
        log_error "verify toolkits: bash scripts/setup-toolkit.sh --verify"
        exit 1
    fi

    log_info "phase $phase ready: ${INJECTED} injected, ${WARNED} skipped."
    exit 0
}

main "$@"
