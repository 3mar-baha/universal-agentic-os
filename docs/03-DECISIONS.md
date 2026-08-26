# Decision Log

Architecture Decision Records (ADRs): context, options considered, outcome, and consequences. Appended by `uos decide`; entries are append-only and never reordered.

## ADR-001: Pin a five-server MCP protocol baseline

- **Date:** 2026-08-26
- **Status:** accepted

### Context

Agent sessions need bounded external capability (docs lookup, research, reasoning, scaffolding, VCS) without ad-hoc per-session tool negotiation.

### Decision

.mcp.json pins exactly five core servers - fetch, brave-search, sequential-thinking, filesystem, git - committed with placeholder config only; credentials are referenced by environment variable name, never value.

### Consequences

uvx or npx must be present for command-type servers; the server set evolves only by amending this record.

## ADR-002: Vendor upstream ECC lifecycle hooks as ephemeral context

- **Date:** 2026-08-26
- **Status:** accepted

### Context

everything-claude-code ships session persistence and compaction hooks written against its plugin root and static settings registration, which cannot be committed safely into consuming repositories.

### Decision

Stage orchestration vendors the dependency-free bash variants into ephemeral .claude/hooks/ecc each phase; the native session_start and session_end hooks invoke them when present, so no tracked settings change and worktree propagation stays automatic.

### Consequences

Upstream hook changes land via scripts/sync-toolkit.sh at next orchestration; PreToolUse-style ECC guards remain out of scope until a safe dynamic-registration path exists.

## ADR-003: Ship a devcontainer with preloaded toolkits

- **Date:** 2026-08-26
- **Status:** accepted

### Context

Fresh machines fail uos doctor on missing linters, and cloud sandboxes need identical environments.

### Decision

.devcontainer provides an Ubuntu 24.04 image with shellcheck and jq plus Node LTS and gh features; postCreateCommand provisions all 6 toolkits and activates git hooks.

### Consequences

One-command parity locally and in cloud sandboxes at the cost of an image build.
