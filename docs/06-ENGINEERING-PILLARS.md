# Engineering Pillars

The ten pillars below are the invariants of the Universal Agentic Engineering OS. Every role, lifecycle phase, skill, and guard operationalizes at least one of them. When no specific document resolves a situation, decide by these pillars.

Index:

1. Specification Before Code
2. Tests Are the Contract
3. Prime Context Before Action
4. Isolate to Parallelize
5. Inject Only What the Phase Needs
6. Fail Fast, Halt at Three Strikes
7. Every Change Passes the Guards
8. Documentation Is a Deliverable
9. Reproducibility by Preflight
10. Ship With Discipline

## 1. Specification Before Code

**Principle.** No implementation begins until a written specification defines behavior, boundaries, and acceptance criteria. The Guide signs off that specification before any Implementer opens a worktree.

**Rationale.** Ambiguity discovered during implementation costs far more than ambiguity resolved during design. A written specification turns disagreement into an edit instead of a rewrite.

**Practice.** Specifications are produced in phase 2 (Architect & Guide) and recorded in `docs/01-ARCHITECTURE.md`, with acceptance criteria tracked in `docs/02-BACKLOG.md`. The claude-stage-orchestrator skill blocks progression to Implement & Verify until a signed specification exists.

**Anti-pattern.** An Implementer opens a worktree and codes against a verbal description, then negotiates scope retroactively through review comments.

## 2. Tests Are the Contract

**Principle.** Tests define correct behavior before and independently of the implementation. A feature is done when its tests pass, not when its author believes it works.

**Rationale.** Executable checks survive refactors, handoffs between agents, and context loss between sessions. Prose claims cannot be run in CI.

**Practice.** Implementers run strict red-green-refactor micro-cycles in phase 3 (Implement & Verify); strategy lives in `docs/05-TEST-PLAN.md`; the Test Guard re-verifies coverage claims in phase 4 (Harden & Release).

**Anti-pattern.** Writing tests after the code until they pass, deleting failing tests to unblock a merge, or mocking so heavily that the test verifies nothing.

## 3. Prime Context Before Action

**Principle.** Load relevant context before acting; never begin a task from a cold start. Each session reconstructs mission state deliberately rather than inferring it from file names.

**Rationale.** Agents act on what they hold in context. Stale or missing context produces output that is confident and wrong.

**Practice.** The session-context-primer skill bootstraps every session, and the reading order defined in the Architecture Guide governs what loads: `CLAUDE.md` first, then `docs/00-VISION.md`, `docs/01-ARCHITECTURE.md`, `docs/02-BACKLOG.md`, then task-scoped documents.

**Anti-pattern.** Editing after a single search hit, or violating `CLAUDE.md` invariants because they were never read.

## 4. Isolate to Parallelize

**Principle.** Concurrent work happens in isolated git worktrees, one concern per worktree. Isolation is what makes parallelism safe and failure cheap.

**Rationale.** A shared working tree forces serialization or produces conflicts. Isolated worktrees let multiple Implementers proceed independently and let a failed experiment be discarded whole.

**Practice.** Orca ADE manages the git-worktree pool used by parallel Implementers; each worktree carries exactly one concern. See `docs/03-ORCA-WORKTREES-AND-PARALLEL-AGENTS.md`.

**Anti-pattern.** Two Implementers editing one checkout, or a single worktree mixing an unrelated refactor with a bug fix so that neither can be merged alone.

## 5. Inject Only What the Phase Needs

**Principle.** Tools and skills are injected per lifecycle phase and pruned when the phase ends. The context budget is spent on capability the current phase actually uses.

**Rationale.** Irrelevant tools distract models and consume context. Minimal, phase-appropriate surfaces improve decision quality and reduce cost.

**Practice.** The claude-stage-orchestrator skill drives dynamic injection and pruning per phase. The 6 upstream toolkits are centralized under `CLAUDE_TOOLKIT_DIR` (default `~/ai-agent-toolkit`) and curated by `scripts/setup-toolkit.sh` and `scripts/sync-toolkit.sh`. See `docs/02-TOOLKIT-AND-ORCA-GUIDE.md`.

**Anti-pattern.** Loading every available skill into every session, or leaving security-hardening skills attached during routine documentation edits.

## 6. Fail Fast, Halt at Three Strikes

**Principle.** Surface failures immediately and stop systematic retries once a defect proves resistant. If the same defect survives 3 consecutive failed fix attempts, halt all execution and emit a Diagnostic Incident Report (DIR).

**Rationale.** A blind fourth attempt burns effort and often deepens the damage. Halting converts wasted cycles into structured evidence for a changed hypothesis or a human decision.

**Practice.** The circuit-breaker-guard skill enforces the halt and structures the DIR: symptom, hypothesis log with one entry per strike and its evidence, ranked root causes, and recommended unblock actions. Strikes reset only when the Guide approves a changed hypothesis.

**Anti-pattern.** A loop applying escalating random fixes to a failing test, or quietly weakening an assertion to force a pass.

## 7. Every Change Passes the Guards

**Principle.** No change reaches release without independent post-implementation review. Review is separated from authorship so the author's confidence is never the final check.

**Rationale.** Authors, human or agent, are structurally blind to their own assumptions. Independent passes catch drift that self-review cannot.

**Practice.** Phase 4 (Harden & Release) runs three second-pass guards: Clean Code Guard, Test Guard, and Docs Guard. Their policies are documented in `docs/04-QUALITY-GATES-AND-SAFETY.md`, and defensive gate patterns from the guard-skills toolkit inform them.

**Anti-pattern.** Merging because the Implementer already checked it, or treating a guard finding as optional feedback.

## 8. Documentation Is a Deliverable

**Principle.** Documentation ships with the change it describes, not after it. A release whose documentation lags its code is incomplete and does not exit phase 4.

**Rationale.** Undocumented systems become unmaintainable the moment their authors' context expires — and for agents, that is immediate.

**Practice.** The Docs Guard reviews documentation in phase 4; the 16-file canonical scaffold created by the agentic-project-launcher skill guarantees every project starts with a complete documentation set; `CHANGELOG.md` records every notable change.

**Anti-pattern.** Merging a feature against a stale README, or reconstructing the changelog weeks later from memory.

## 9. Reproducibility by Preflight

**Principle.** Verify the environment before relying on it. Every workflow begins with explicit checks that dependencies, versions, and configuration are present and correct.

**Rationale.** Most agent failures are environmental, not logical. Catching a missing dependency up front costs seconds; discovering it mid-implementation costs a corrupted worktree.

**Practice.** The preflight-system-doctor skill runs environment checks, and Discover & Launch performs the deployment-path check. `.env.example` documents required variables, while the `Makefile` and `.github/workflows/ci.yml` pin identical commands for agents, humans, and CI.

**Anti-pattern.** Assuming a global tool is installed, hardcoding machine-specific paths, or committing real credentials because no example file existed.

## 10. Ship With Discipline

**Principle.** Releases are deliberate acts executed by procedure, not side effects of accumulated merges. Quality gates, packaging, and release notes complete in a fixed order.

**Rationale.** Ad hoc releases leak unreviewed work, undocumented breaking changes, and unverifiable builds into production.

**Practice.** The github-release-packager skill packages tagged releases in phase 4 (Harden & Release), after the Clean Code Guard, Test Guard, and Docs Guard pass and `.github/workflows/ci.yml` is green. Release content is drawn from `CHANGELOG.md`.

**Anti-pattern.** Tagging the default branch directly under stakeholder pressure, or skipping the guards for a supposedly small fix.

Violations of any pillar are defects. Route them through the normal escalation flow in the Architecture Guide rather than working around them.
