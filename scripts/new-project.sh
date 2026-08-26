#!/usr/bin/env bash
#
# new-project.sh — Scaffold a brand-new governed project under the
# Universal Agentic Engineering OS.
#
# Creates <PARENT>/<name> with the canonical 16-file scaffold (real seed
# content, no filler essays), seeds the live checkpoint, vendors the OS
# runtime (scripts, native Claude Code hooks and settings, git hooks, the
# Universal Meta-Skill, MCP baseline, lint config), then initializes git
# with a clean first commit. The result is immediately ready for the master
# initial prompt (docs/05-INITIAL-PROMPT.md in the OS repository).
#
# Usage:
#   ./scripts/new-project.sh <PROJECT_NAME> [PARENT_DIR] [-h | --help]
#
#   PROJECT_NAME   lowercase kebab-case identifier.
#   PARENT_DIR     where to create it (default: current directory).
#
# Exit status:
#   0 — scaffolded, vendored, committed
#   1 — refused (bad name, target exists, git unavailable) or commit failed

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info() { printf '[new] %s\n' "$*"; }
log_error() { printf '[new] ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<EOF
new-project.sh — scaffold a governed project under the OS.

Usage:
  ./scripts/new-project.sh <PROJECT_NAME> [PARENT_DIR]

Creates the canonical 16-file scaffold plus the OS runtime layer
(checkpoint, hooks, scripts, meta-skill, .mcp.json) and an initial commit,
ready for the master initial prompt.

Exit status:
  0    Project ready.
  1    Refused (bad name, existing target) or git commit failed.
EOF
}

write_file() {
    # write_file <abs_path> — reads seed content from stdin.
    mkdir -p "$(dirname "$1")"
    cat > "$1"
}

seed_scaffold() {
    local root="$1" name="$2"

    write_file "${root}/CLAUDE.md" <<EOF
# CLAUDE.md — ${name}

## Operating Contract

You operate inside the Universal Agentic Engineering OS. Read, in order:
skills/universal-agentic-workflow.md (complete operating manual),
docs/10-CHECKPOINT.md (live state), then this project's docs/.

## Autonomous Session Protocol

Sessions are zero-prompt by contract. On start, read docs/10-CHECKPOINT.md;
if status is ACTIVE, resume the active milestone immediately with strict
TDD — prompting for permission on in-scope work violates this protocol.
If status is BLOCKED, read the recorded DIR, change hypothesis, wait for
Guide approval.

## Non-Negotiable Invariants

Specification before code. TDD always (red-green-refactor). Ponytail
minimalism. Three-strike circuit breaker with DIR logging; never a blind
fourth fix. Zero secret leaks (secrets referenced by name only). Context
hygiene. One concern per worktree. No error swallowing. Zero AI
attribution — no attribution trailers or footers anywhere, ever.

## Quality Gates Before Every Push

Lint, full test suite green, build passing, documentation updated in the
same change, CHANGELOG entry added.
EOF

    write_file "${root}/README.md" <<EOF
# ${name}

(Fill during Phase 1 Socratic discovery: one-sentence mission.)

## Install

(To be defined.)

## Usage

(To be defined.)
EOF

    write_file "${root}/.gitignore" <<'EOF'
# Dependencies
node_modules/
.venv/
__pycache__/

# Secrets
.env

# Build output
dist/
build/
coverage/

# OS / editor noise
.DS_Store
Thumbs.db
*.log

# OS runtime ephemera (managed by orchestrate-stage.sh / teardown-stage.sh)
.claude/skills/
.claude/agents/
.claude/hooks/ecc/
.claude/.strike_tracker
.claude/spec-index.md
.claude/settings.local.json
.claude/STREAM.md
.worktrees/
EOF

    write_file "${root}/.env.example" <<EOF
# ${name} - example environment file.
# Copy to .env and replace every placeholder; reference variables by name
# only, never by value. Never commit .env.
EOF

    write_file "${root}/LICENSE" <<EOF
MIT License

Copyright (c) 2026 <copyright holder>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    write_file "${root}/CONTRIBUTING.md" <<EOF
# Contributing to ${name}

- Branch from main; one concern per branch (or OS worktree stream).
- Conventional commits; tests written first (red-green-refactor).
- Every push passes lint, tests, and build locally.
- Zero AI attribution in commits, files, and messages.
EOF

    write_file "${root}/CHANGELOG.md" <<'EOF'
# Changelog

All notable changes are documented here. Format follows Keep a Changelog;
versions follow Semantic Versioning.

## [Unreleased]
EOF

    write_file "${root}/docs/00-VISION.md" <<EOF
# Vision

## Mission

(Restated from Socratic discovery - three sentences maximum.)

## Non-Goals

(What this project deliberately does not do.)

## Success Criteria

(Measurable outcomes agreed with the Leader.)
EOF

    write_file "${root}/docs/01-ARCHITECTURE.md" <<EOF
# Architecture

## Components and Boundaries

(Filled during Architect & Guide; deployment path constrains every choice.)

## Data Flow

(Primary flows end to end.)

## Design Choices

(Key decisions cross-referenced to docs/03-DECISIONS.md.)
EOF

    write_file "${root}/docs/02-BACKLOG.md" <<EOF
# Backlog

Prioritized, testable items. The Leader routes from here.

| # | Item | Priority | Status |
| --- | --- | --- | --- |
| 1 | Complete Phase 1 discovery and fill vision/architecture | high | open |
EOF

    write_file "${root}/docs/03-DECISIONS.md" <<'EOF'
# Decision Log

Architecture Decision Records (ADRs): context, options considered, outcome,
and consequences. Appended by the uos decide command; append-only.
EOF

    write_file "${root}/docs/04-RUNBOOK.md" <<EOF
# Runbook

## Run / Debug / Deploy / Recover

(Procedures filled as the deployment path is fixed in Phase 2.)
EOF

    write_file "${root}/docs/05-TEST-PLAN.md" <<EOF
# Test Plan

Strategy, coverage expectations, and gate criteria. Tests are the contract:
no production code without a failing test first.
EOF

    write_file "${root}/SECURITY.md" <<EOF
# Security Policy

- Report vulnerabilities privately to <security contact>.
- Secrets live only in gitignored .env, referenced by name, never by value.
- Pre-commit scanning rejects credential-shaped staged content.
EOF

    # Real tabs are required inside a Makefile.
    write_file "${root}/Makefile" <<'EOF'
.PHONY: help lint test build
help:
	@echo "Targets: lint | test | build (replace with stack-specific commands in Phase 2)"
lint:
	@echo "(define lint command for this stack)"
test:
	@echo "(define test command for this stack)"
build:
	@echo "(define build command for this stack)"
EOF

    write_file "${root}/.github/workflows/ci.yml" <<'EOF'
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint markdown
        run: npx --yes markdownlint-cli "**/*.md" --ignore node_modules
      - name: Lint shell
        run: |
          shellcheck scripts/*.sh || echo "add shellcheck via apt-get when scripts exist"
      - name: Test
        run: echo "(replace with the stack's test command in Phase 2)"
EOF

    local today
    today="$(date +%Y-%m-%d)"
    write_file "${root}/docs/10-CHECKPOINT.md" <<EOF
# 10-CHECKPOINT.md — Live Session State (single source of truth)

status: ACTIVE
ACTIVE_PHASE: 1
updated: ${today}

## Mission In Effect

To be defined in Phase 1 Socratic discovery. First session: paste the master
initial prompt (OS repository, docs/05-INITIAL-PROMPT.md) as your message.

## Milestone DAG

- [ ] M1 — Complete discovery; fill vision, architecture, backlog; Guide sign-off

## Standing Rules

- Keep this file under 50 lines; archive completed milestones to docs/archive/.
- Resume the active milestone immediately each session — strict TDD, no prompts.
- status: BLOCKED means the circuit breaker tripped; read the DIR, await approval.
EOF
}

vendor_runtime() {
    # vendor_runtime <target_root> — copy the OS's own machinery into the
    # new project so it is self-governed from commit one.
    local dst="$1"
    mkdir -p "${dst}/scripts" "${dst}/skills"
    cp "${REPO_ROOT}"/scripts/*.sh "${dst}/scripts/"
    mkdir -p "${dst}/.claude/hooks" "${dst}/.githooks" "${dst}/.github/workflows"
    cp "${REPO_ROOT}"/.claude/hooks/*.sh "${dst}/.claude/hooks/"
    cp "${REPO_ROOT}/.claude/settings.json" "${dst}/.claude/settings.json"
    cp "${REPO_ROOT}"/.githooks/* "${dst}/.githooks/"
    cp "${REPO_ROOT}/skills/universal-agentic-workflow.md" "${dst}/skills/"
    cp "${REPO_ROOT}/.mcp.json" "${dst}/.mcp.json"
    cp "${REPO_ROOT}/.editorconfig" "${dst}/.editorconfig" 2> /dev/null || true
    cp "${REPO_ROOT}/.markdownlint.jsonc" "${dst}/.markdownlint.jsonc" 2> /dev/null || true
    cp "${REPO_ROOT}/AGENTS.md" "${dst}/AGENTS.md" 2> /dev/null || true
}

main() {
    local name="${1:-}" parent="${2:-.}"

    [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

    case "$name" in
        '' | *[!a-z0-9-]* | -* | *-)
            log_error "project name must be lowercase kebab-case: '${name}'."
            exit 1
            ;;
    esac

    if ! command -v git > /dev/null 2>&1; then
        log_error 'git is not available.'
        exit 1
    fi

    local target="${parent%/}/${name}"
    if [ -e "$target" ] && [ -n "$(ls -A "$target" 2> /dev/null)" ]; then
        log_error "target exists and is not empty: $target"
        exit 1
    fi

    mkdir -p "$target"
    log_info "scaffolding canonical 16-file hierarchy in ${target}"
    seed_scaffold "$target" "$name"

    log_info 'vendoring OS runtime (scripts, hooks, meta-skill, mcp baseline)...'
    vendor_runtime "$target"

    log_info 'initializing git...'
    git -C "$target" init -q -b main
    git -C "$target" add -A
    # Fresh machines and CI runners may carry no git identity; supply a
    # local-only one for the scaffold commit when none is configured.
    ident_args=()
    if [ -z "$(git -C "$target" config user.email 2> /dev/null || true)" ]; then
        ident_args=(-c user.name="Universal Agentic OS" -c user.email="uos@scaffold.local")
    fi
    if ! git -C "$target" commit "${ident_args[@]}" -qm "chore: scaffold ${name} under universal agentic engineering os"; then
        log_error 'initial commit failed (is git user.name/user.email configured globally?).'
        log_error "the scaffold remains intact at ${target}; configure identity and commit manually."
        exit 1
    fi

    log_info "ready: ${target}"
    printf '       next steps:\n'
    printf '         1. cd %s && bash scripts/init.sh\n' "$target"
    printf '         2. open your agent there; paste the master initial prompt\n'
    printf '            (OS repo docs/05-INITIAL-PROMPT.md) as the first message.\n'
    exit 0
}

main "$@"
