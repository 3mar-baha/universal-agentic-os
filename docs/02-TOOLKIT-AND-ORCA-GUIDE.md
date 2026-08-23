# Toolkit & Orca Guide

The Universal Agentic Engineering OS keeps its agent-facing capabilities outside project
repositories. Six upstream toolkits live in one shared directory, and Orca ADE — the orchestration
runtime layer — decides what enters and leaves the session context at every lifecycle phase. This
guide covers the centralized toolkit model, the six toolkits, Orca's responsibilities and setup.

## The Centralized Toolkit Model

All toolkits are cloned into a single directory named by the `CLAUDE_TOOLKIT_DIR` environment
variable. The default path is `~/ai-agent-toolkit`. Projects reference skills and commands by
absolute path under this directory; they never vendor copies.

```bash
# Default
export CLAUDE_TOOLKIT_DIR="$HOME/ai-agent-toolkit"

# Custom location
export CLAUDE_TOOLKIT_DIR="/opt/ai-agent-toolkit"
```

Resulting layout:

```text
~/ai-agent-toolkit/
+-- everything-claude-code/
+-- mattpocock-skills/
+-- ponytail/
+-- guard-skills/
+-- cybersecurity-skills/
+-- agency-agents/
```

Why centralization beats per-project copies:

- **One update, every project benefits.** scripts/sync-toolkit.sh refreshes the single copy, and
  every project on the machine picks it up at its next session. There are no per-project upgrade
  chores and no version drift between teams.
- **Skills are referenced by absolute path.** Sessions resolve skills as
  `$CLAUDE_TOOLKIT_DIR/<toolkit>/<path>`, so references survive project renames and relocation and
  never depend on repo-relative guesses.
- **Lean repositories.** No vendored toolkit blobs inflate diffs, license files or review surface.
- **One place to audit.** Reviewing what capabilities agents can invoke means reading one
  directory.

## The Six Toolkits

| Name | Upstream | Focus | Typical injection phase |
| --- | --- | --- | --- |
| everything-claude-code | github.com/worldflowai/everything-claude-code | Broad Claude Code configurations, commands and workflows | Phase 1 — Discover & Launch |
| mattpocock-skills | github.com/mattpocock/skills | TypeScript and DX-oriented skills | Phase 3 — Implement & Verify |
| ponytail | github.com/dietrichgebert/ponytail | Radical minimalism: smallest abstraction, no speculative features | Phase 2 — Architect & Guide |
| guard-skills | github.com/amElnagdy/guard-skills | Defensive quality gates and review guards | Phase 4 — Harden & Release |
| cybersecurity-skills | github.com/mukul975/Anthropic-Cybersecurity-Skills | Security review and hardening skills | Phase 4 — Harden & Release |
| agency-agents | github.com/msitarzewski/agency-agents | Specialized agent personas for agency workflows | Phase 2 — Architect & Guide |

Notes:

- everything-claude-code is the only toolkit injected in every engagement; it is the baseline.
- guard-skills backs the quality gates and the three second-pass guards (Clean Code Guard, Test
  Guard, Docs Guard) but is not itself one of them.
- Injection is conditional on archetype and repository signals. Per-archetype defaults are in
  docs/01-MULTI-DOMAIN-ARCHETYPES.md.
- These upstream toolkits are capability libraries. They are distinct from the framework's own six
  core skills, which ship in this repository under skills/.

## Orca ADE

Orca ADE is the orchestration runtime layer of this OS. The name expands as ORchestrated
Cooperative Agents (Orca); ADE stands for Agent Development Environment. Orca sits beneath the
4-phase lifecycle and turns the lifecycle's decisions into session state: what context is primed,
which tools and skills are loaded, and where parallel Implementers work.

```text
Session
   |
   v
Orca ADE (orchestration runtime layer)
   |-- 1. session bootstrap ..... prime context, health preflight, archetype select
   |-- 2. inject / prune ........ phase-scoped upstream toolkits and core skills
   |-- 3. worktree pool ......... one concern per lease, reaped on merge
   |
   |-- pulls skills from CLAUDE_TOOLKIT_DIR (6 upstream toolkits)
   +-- leases isolated git worktrees to parallel Implementers
```

### Responsibility 1: Session Bootstrap

At session start, Orca primes context (Prime Context Before Action): loads the project CLAUDE.md,
resolves `CLAUDE_TOOLKIT_DIR`, runs the preflight-system-doctor skill to confirm environment
health, records the selected archetype, and arms the circuit-breaker-guard so strike counting
begins before any implementation. Bootstrap fails closed: if the toolkit directory cannot be
resolved, Orca halts with a diagnostic instead of continuing with missing capabilities.

### Responsibility 2: Dynamic Injection and Pruning

Per phase, Orca injects only the toolkits and skills that phase needs (Inject Only What the Phase
Needs) and prunes them at phase exit. Pruning keeps the context window lean and keeps
phase-inappropriate capabilities — release-packaging skills during discovery, for example — out
of reach. Injection and pruning happen at phase boundaries: the Guide signs off the phase exit,
then Orca swaps the payload.

### Responsibility 3: Worktree Pool Management

Orca owns the git-worktree pool used by parallel Implementers (Isolate to Parallelize). It creates
one worktree per concern, leases worktrees to Implementers, refuses a second concern in a leased
worktree, reaps worktrees whose branches have merged or gone stale, and reports pool state to the
Leader for merge sequencing.

### How Orca Decides What to Inject

| Lifecycle phase | Framework core skills active | Toolkits injected | Pruned at exit |
| --- | --- | --- | --- |
| 1. Discover & Launch | session-context-primer, preflight-system-doctor, agentic-project-launcher | everything-claude-code | Launcher and primer skills once the scaffold exists |
| 2. Architect & Guide | claude-stage-orchestrator, circuit-breaker-guard (armed) | ponytail, agency-agents | Discovery-era skills |
| 3. Implement & Verify | claude-stage-orchestrator, circuit-breaker-guard (active) | mattpocock-skills (TypeScript/DX repos), everything-claude-code (workflow subset) | Design-only kits |
| 4. Harden & Release | circuit-breaker-guard (active), preflight-system-doctor, github-release-packager | guard-skills, cybersecurity-skills | Implementation kits, before packaging |

The six framework core skills above are the framework's complete skill set; nothing else ships in
skills/.

Three inputs drive every injection decision:

1. **Phase** — the lifecycle stage sets the base payload per the table above.
2. **Archetype** — the declared archetype adds its domain defaults (docs/01-MULTI-DOMAIN-ARCHETYPES.md).
3. **Repository signals** — detected facts refine the payload: a `tsconfig.json` pulls
   mattpocock-skills; a specification flagging payment flows pulls cybersecurity-skills early.

Anything not justified by these three inputs stays out of context.

## Setup

### First Run

```bash
bash scripts/setup-toolkit.sh
```

The script creates `CLAUDE_TOOLKIT_DIR` (default `~/ai-agent-toolkit`) if it is missing, clones
the six toolkits from their upstream URLs, verifies that each clone is populated, and prints a
per-toolkit summary. Re-running is safe: toolkits already present are checked and reported rather
than duplicated.

Success looks like:

```text
$ ls "$CLAUDE_TOOLKIT_DIR"
agency-agents  cybersecurity-skills  everything-claude-code
guard-skills   mattpocock-skills     ponytail
```

and a probe resolving an absolute skill path:

```bash
test -d "$CLAUDE_TOOLKIT_DIR/guard-skills" && echo "toolkit ready"
```

### Updates

```bash
bash scripts/sync-toolkit.sh
```

Sync fetches and fast-forwards each toolkit from upstream and reports which kits moved, were
skipped or stayed dirty. Exit status follows scripts/sync-toolkit.sh: zero when at least one
toolkit updated or nothing actually failed, nonzero when every present toolkit failed to update.
Run it periodically and before starting a major engagement so that every project sees current skills.

### Troubleshooting

**Missing CLAUDE_TOOLKIT_DIR**

- Symptom: session bootstrap fails the context-prime check; skills referenced by absolute path do
  not resolve.
- Fix: export `CLAUDE_TOOLKIT_DIR` or accept the default `~/ai-agent-toolkit`, confirm with
  `echo "$CLAUDE_TOOLKIT_DIR"`, then run scripts/setup-toolkit.sh if the directory is absent.

**Partial clone failure**

- Symptom: after a network interruption a toolkit directory exists but is empty or missing its
  skills.
- Fix: delete the affected toolkit directory and re-run scripts/setup-toolkit.sh. Never point a
  session at a half-cloned kit; Orca treats an empty kit as a hard bootstrap error.

**Auth failures on private forks**

- Symptom: clone or sync stops on a credential prompt, a 403, or permission denied for a private
  fork.
- Fix: configure a credential helper or SSH key for that host and retry; prefer read-only access.
  Never embed tokens in scripts, committed environment files or shell history. If a fork must
  remain inaccessible, drop it from the local toolkit set and record the capability gap in the
  affected project's docs/03-DECISIONS.md.
