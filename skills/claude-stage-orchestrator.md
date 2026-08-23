---
name: claude-stage-orchestrator
description: Orchestrates dynamic skill and toolkit injection and pruning at every transition between the four canonical lifecycle phases to protect the agent context window.
---

# Claude Stage Orchestrator

## Purpose

Maintains the phase registry for the Universal Agentic Engineering OS and executes it inside
the Orca ADE runtime (Orca = ORchestrated Cooperative Agents), which owns session bootstrap,
dynamic tool and skill injection and pruning per lifecycle phase, and the git-worktree pool
used by parallel Implementers. On every phase transition this skill injects exactly the
skills, toolkit assets and documents the incoming phase requires, and prunes everything the
incoming phase does not need. It operationalizes Engineering Pillar 5, "Inject Only What the
Phase Needs".

## When to Use

- At session bootstrap, to load the first phase's context set.
- Whenever the Guide declares a lifecycle phase transition.
- After any mid-phase interruption or context compaction, to re-anchor and re-verify the active phase.
- Whenever it is unclear which phase the session is actually in.

## Inputs

- Current context manifest: the set of skills, toolkit assets and documents currently loaded.
- Phase signals: phase markers in `docs/02-BACKLOG.md`, active branch and worktree names in
  the Orca worktree pool, scaffold completeness (the 16 canonical files), and the presence of
  an open Diagnostic Incident Report (DIR).
- Optional explicit phase override issued by the Guide.
- Toolkit root: `CLAUDE_TOOLKIT_DIR` (default `~/ai-agent-toolkit`), populated by
  `scripts/setup-toolkit.sh` and refreshed by `scripts/sync-toolkit.sh`.

## Procedure

1. Detect the current phase from signals, in priority order: (a) an open Diagnostic Incident
   Report means execution is HALTED — run no transition until the Guide approves a changed
   hypothesis; (b) phase markers in `docs/02-BACKLOG.md`; (c) active branch and worktree
   naming in the Orca worktree pool; (d) scaffold completeness — all 16 canonical files
   present means Discover & Launch has exited.
2. If signals conflict, stop and ask the Guide to adjudicate. Never guess a phase.
3. Read the registry row for the detected phase (table below).
4. Compute the diff between the current context manifest and the registry row: `INJECT` =
   required by the new phase but absent; `PRUNE` = currently loaded but not required by it.
5. Apply the diff through Orca ADE: load each item in `INJECT`; unload or ignore each item in
   `PRUNE`. `session-context-primer` is exempt from pruning because interruptions at any
   phase require re-anchoring.
6. Emit exactly one transition log line (format below).
7. Re-run from step 1 after any interruption, ambiguity, or Guide instruction. Transitions
   are idempotent: applying the same phase twice must yield an empty diff.

### Phase Registry: Inject and Prune Map

| Phase | Inject | Prune |
| --- | --- | --- |
| 1. Discover & Launch | Skills: `agentic-project-launcher`, `session-context-primer`, `preflight-system-doctor`. Toolkit: `everything-claude-code`. Docs: `docs/05-INITIAL-PROMPT.md` | `github-release-packager`, TDD micro-cycle tooling, Second-Pass Guards, worktree protocol |
| 2. Architect & Guide | Skills: `claude-stage-orchestrator` (this registry), `circuit-breaker-guard` (armed). Toolkit: `ponytail`, `agency-agents`. Docs: `docs/01-MULTI-DOMAIN-ARCHETYPES.md` plus archetype-matched toolkit assets selected from the 4 multi-domain archetypes | Discovery-era capabilities (`agentic-project-launcher` once the scaffold is complete), implementation-heavy tooling (TDD runners, worktree-pool operations), release packaging |
| 3. Implement & Verify | Skills: `claude-stage-orchestrator`, `circuit-breaker-guard` (active). Workflow: TDD micro-cycles (red, green, refactor). Docs: `docs/03-ORCA-WORKTREES-AND-PARALLEL-AGENTS.md` (worktree protocol). Toolkit: `mattpocock-skills` (TypeScript/DX repos), `everything-claude-code` (workflow subset) | Design-only kits (`ponytail`, `agency-agents`), research skills and deep-research workflows, discovery prompts, release packaging |
| 4. Harden & Release | Skills: `circuit-breaker-guard` (active), `preflight-system-doctor`, `github-release-packager`. Guards: Clean Code Guard, Test Guard, Docs Guard. Docs: `docs/04-QUALITY-GATES-AND-SAFETY.md`. Toolkit: `guard-skills`, `cybersecurity-skills` | Scaffolding skills (`agentic-project-launcher`), implementation kits (`mattpocock-skills`, `everything-claude-code` workflow subset), research skills, TDD micro-cycle runners |

The baseline payload above mirrors the master injection table in docs/02-TOOLKIT-AND-ORCA-GUIDE.md
(How Orca Decides What to Inject); where the two ever differ, docs/02 governs and this registry is
corrected to match. Archetype defaults in docs/01-MULTI-DOMAIN-ARCHETYPES.md are declared variance:
they add or swap toolkits for a domain but never remove a baseline core skill.

### Transition Log Line Format

```
[STAGE] from="<previous phase>" to="<new phase>" inject=[<items>] prune=[<items>] evidence="<deciding signal>"
```

Example:

```
[STAGE] from="Discover & Launch" to="Architect & Guide" inject=[claude-stage-orchestrator, circuit-breaker-guard, ponytail, agency-agents, docs/01-MULTI-DOMAIN-ARCHETYPES.md] prune=[agentic-project-launcher, preflight-system-doctor] evidence="backlog phase marker"
```

## Outputs

- One transition log line per phase change.
- An updated context manifest listing the authoritative set of loaded skills, toolkit assets
  and documents for the current phase.
- An inject/prune diff report surfaced to the Leader (sequencing) and the Guide (sign-off).

## Failure Modes

- **Conflicting phase signals** (for example the branch indicates Implement & Verify while
  `docs/02-BACKLOG.md` indicates Architect & Guide): halt the transition, ask the Guide to
  adjudicate, and apply nothing until resolved.
- **Skill or toolkit asset missing from `CLAUDE_TOOLKIT_DIR`**: degrade gracefully — proceed
  with the remaining set, append the gap to the transition log line, notify the Leader, and
  repair with `scripts/setup-toolkit.sh` or `scripts/sync-toolkit.sh`.
- **Mid-phase interruption or context compaction**: re-anchor with `session-context-primer`,
  then re-run phase detection from step 1 before taking any further action.
- **Repeated transition failures**: count consecutive failures of the same transition against
  the 3-Strike Circuit Breaker; at three strikes emit a Diagnostic Incident Report and HALT
  all execution.
