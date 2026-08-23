# Multi-Domain Archetypes

The Universal Agentic Engineering OS runs every mission through the same tripartite operating
model (Leader, Guide, Implementer) and the same 4-phase lifecycle. What changes between missions
is the domain. This guide defines the four canonical archetypes, how each tunes the lifecycle,
which toolkits Orca injects by default, and which second-pass guard carries the most weight. The
Leader selects the archetype during Phase 1 (Discover & Launch); the selection drives toolkit
injection, guard emphasis and worktree topology for the entire engagement.

## Selecting an Archetype

Match the mission shape to the archetype before scaffolding:

| Mission shape | Archetype |
| --- | --- |
| Build, change or operate a software system where specifications and tests define done | Software Engineering |
| Produce, evaluate or harden a model whose quality is defined by measurable evaluation | AI/ML |
| Automate a repeatable business process across systems of record, with human approval on critical steps | Business Automation |
| Answer an open question from many sources and produce a verifiable, cited synthesis | Deep Research |

Mixed missions take the archetype of the dominant deliverable. The Leader may borrow individual
lifecycle tweaks from a secondary archetype, but toolkit injection and guard emphasis always
follow the primary.

---

## Software Engineering

### Profile

Typical mission: design, build, modernize or operate a software system — a web service, library,
CLI or application — where correctness is fixed by specification and proven by automated tests and
continuous integration.

### Lifecycle Tweaks

- **Phase 1 — Discover & Launch:** the deployment-path check pins the target platform, runtime
  versions and CI availability before anything is scaffolded. The 16-file canonical scaffold is
  created unchanged.
- **Phase 2 — Architect & Guide:** the Guide specifies interfaces and data models before any
  implementation (Specification Before Code). The plan decomposes into service- or module-scoped
  tasks, each sized for one concern per worktree.
- **Phase 3 — Implement & Verify:** Implementers run TDD micro-cycles (red, green, refactor) in
  parallel worktrees. Merge order follows the Leader's sequence.
- **Phase 4 — Harden & Release:** full quality gates, the three second-pass guards, packaging and
  release. CI must be green on the release candidate before the Leader signs off.

### Toolkit Mapping

| Toolkit | Why it is injected |
| --- | --- |
| everything-claude-code | Baseline Claude Code configurations, commands and workflows for everyday engineering sessions. Injected from Phase 1. |
| ponytail | Radical minimalism applied at design time; keeps speculative features and oversized abstractions out of the plan. Phase 2. |
| mattpocock-skills | TypeScript and DX-oriented skills; injected in Phase 3 when the stack is TypeScript or developer-experience tooling. |
| guard-skills | Defensive review guards backing the quality gates and the second-pass guards. Phase 4. |

Conditional: cybersecurity-skills is added in Phase 4 when the specification flags exposed attack
surface; agency-agents is added when the engagement needs agency-style persona routing.

### Guard Emphasis

Primary guard: **Test Guard**. Tests Are the Contract, so Test Guard decides release readiness.
It checks that every behavior change lands with a failing test written first, that no assertions
were skipped, muted or weakened relative to the base branch, that changed paths do not lose
coverage, and that every defect fix carries a regression test. Clean Code Guard and Docs Guard
still run; in this domain they rarely block alone.

### Example Stack

```text
Service:    HTTP API (TypeScript) with PostgreSQL persistence, containerized delivery
Tests:      unit, contract and integration suites driving the TDD micro-cycles
CI:         GitHub Actions - lint, typecheck, test and build on every pull request
Release:    tagged images, CHANGELOG.md entries, ci.yml green on the release branch
```

---

## AI/ML

### Profile

Typical mission: train, fine-tune, evaluate or integrate a model whose quality is defined by
measurable evaluation against held-out data and whose reported results must be reproducible.

### Lifecycle Tweaks

- **Phase 1 — Discover & Launch:** discovery additionally establishes data availability, compute
  budget and the primary success metric. The metric and its acceptance thresholds are written into
  docs/00-VISION.md at launch, never after training.
- **Phase 2 — Architect & Guide:** the specification defines the dataset schema, baseline model,
  evaluation protocol and thresholds. The plan splits into three tracks — data pipeline, modeling,
  evaluation — each eligible for its own worktree.
- **Phase 3 — Implement & Verify:** a failing evaluation counts as red and a threshold met counts
  as green. Every experiment run logs parameters, data version and metrics to the experiment
  tracker; untracked runs are not accepted as evidence.
- **Phase 4 — Harden & Release:** the preflight re-runs the evaluation from a clean checkout and
  must reproduce the reported metrics (Reproducibility by Preflight). The model card and
  evaluation report ship with the artifact.

### Toolkit Mapping

| Toolkit | Why it is injected |
| --- | --- |
| everything-claude-code | Baseline session workflows and commands for long, iterative experimentation. Phase 1 onward. |
| agency-agents | Reviewer personas for data and modeling critique during specification and plan review. Phase 2. |
| guard-skills | Defensive gates over evaluation evidence before release. Phase 4. |
| cybersecurity-skills | Hardening review when the model consumes untrusted input: prompt-injection and data-exfiltration checks. Phase 4. |

Conditional: mattpocock-skills joins in Phase 3 when the serving layer is TypeScript; ponytail is
available when the team wants enforced minimalism in pipeline code but is not part of the default
set.

### Guard Emphasis

Primary guard: **Clean Code Guard**. The dominant defect class in this domain is experiment
scaffolding bleeding into production paths: notebook logic pasted into the pipeline, hidden global
state, unpinned seeds and versions, and speculative wrapper abstractions. Clean Code Guard checks
that experiment code is separated from serving code, that production transforms are deterministic
and tested, that seeds and dependency versions are pinned, and that no abstraction exists that the
specification does not call for. Test Guard still enforces the evaluation suite; it passes only
when the thresholds hold.

### Example Stack

```text
Model:      PyTorch or scikit-learn training pipeline with pinned dependencies
Data:       versioned snapshots; deterministic, tested preprocessing
Evaluation: golden-dataset harness with thresholds fixed in the specification
Tracking:   experiment tracker capturing parameters, data version and metrics per run
Release:    model card + evaluation report + clean-checkout reproduction of metrics
```

---

## Business Automation

### Profile

Typical mission: automate a repeatable business process — order handling, onboarding, reporting,
notifications — across systems of record, where mistakes carry financial or compliance cost and
some steps require a human decision.

### Lifecycle Tweaks

- **Phase 1 — Discover & Launch:** discovery enumerates systems of record, triggers, side effects
  and who approves what. The deployment-path check covers scheduler and integration hosts and
  provisions sandbox credentials only.
- **Phase 2 — Architect & Guide:** every workflow is specified with its trigger, inputs, side
  effects, idempotency strategy, retry policy, audit events and human approval gates. Any
  irreversible step gets a gate.
- **Phase 3 — Implement & Verify:** TDD runs against simulated integrations. Replay tests prove
  idempotency, audit-event emission is asserted per step, and real credentials never enter a
  worktree.
- **Phase 4 — Harden & Release:** the release candidate runs in shadow or dry-run mode against
  production-shaped data, audit output is verified complete, and the operator runbook is finalized
  before enablement (Ship With Discipline).

### Toolkit Mapping

| Toolkit | Why it is injected |
| --- | --- |
| everything-claude-code | Baseline configurations and workflows for integration-heavy sessions. Phase 1 onward. |
| agency-agents | Personas mirroring operations, finance and compliance reviewers sharpen specifications and approval design. Phase 2. |
| ponytail | Automations accumulate steps by default; radical minimalism keeps each workflow to the steps the process actually needs. Phase 2. |
| guard-skills | Defensive gates over audit completeness and approval-gate enforcement. Phase 4. |

Conditional: cybersecurity-skills joins Phase 4 when the process moves money, personal data or
credentials. mattpocock-skills is injected only if a TypeScript integration surface exists.

### Guard Emphasis

Primary guard: **Docs Guard**. An automation nobody can read is an automation nobody can audit.
Docs Guard checks that every shipped workflow documents its trigger, side effects, idempotency
strategy, rollback procedure and approval gate in the runbook; that the audit-event catalog
matches the events the code actually emits; and that runbook updates land in the same changeset as
behavior changes (Documentation Is a Deliverable). Test Guard's idempotency replay results feed
exactly the documentation Docs Guard reviews.

### Example Stack

```text
Engine:      durable workflow executor - scheduled and event-driven triggers
Idempotency: dedupe keys persisted before any side effect; replay-safe handlers
Audit:       append-only audit log recording actor, action, timestamp and outcome
Approvals:   human gate before irreversible actions - payments, deletions, outbound sends
Operations:  alerting on failed runs; runbook covering recovery for each failure mode
```

---

## Deep Research

### Profile

Typical mission: answer an open question by gathering many sources, verifying them, and producing
a cited synthesis that a third party can audit claim by claim.

### Lifecycle Tweaks

- **Phase 1 — Discover & Launch:** discovery fixes the research questions, scope boundaries,
  acceptable source classes and the deliverable format before any retrieval starts.
- **Phase 2 — Architect & Guide:** the Guide plans the synthesis outline, defines the source-log
  schema and fixes one citation style. The plan splits into retrieval, verification and writing
  tracks.
- **Phase 3 — Implement & Verify:** each track runs in its own worktree. Every claim is committed
  together with its source-log entry, and refactoring may never detach a claim from its evidence.
- **Phase 4 — Harden & Release:** an independent synthesis-review pass re-verifies citations
  against the source log, unresolved contradictions are escalated to the Guide, and the report
  ships with its bibliography and archived source log.

### Toolkit Mapping

| Toolkit | Why it is injected |
| --- | --- |
| everything-claude-code | Session workflows and command conventions suited to long research sessions. Phase 1 onward. |
| agency-agents | Researcher, skeptic and editor personas give retrieval, adversarial verification and synthesis their own reviewers. Phase 2. |
| ponytail | Keeps the deliverable minimal - findings and evidence, not padding. Phases 2 and 3. |

Conditional: cybersecurity-skills when the research subject is security itself. Not injected by
default: mattpocock-skills and guard-skills, whose defensive code gates have little purchase on
prose deliverables; the synthesis review takes their place.

### Guard Emphasis

Primary guard: **Docs Guard**. Citation discipline is documentation discipline. Docs Guard checks
that the source log is append-only and complete (URL, publisher, capture date, access method),
that every claim in the synthesis maps to at least one source entry, that all citations resolve,
and that the synthesis-review trail records who verified what and which conflicts were found.

### Example Stack

```text
Source log:  append-only ledger - URL, publisher, date captured, access method
Extraction:  claim-evidence matrix binding each claim to source entries
Citations:   one enforced style; every claim resolvable to a logged source
Review:      independent synthesis pass re-verifies citations before delivery
Deliverable: report + bibliography + archived source log in the repository
```

---

## Cross-References

- Injection mechanics and Orca ADE: docs/02-TOOLKIT-AND-ORCA-GUIDE.md
- The pillars cited above: docs/06-ENGINEERING-PILLARS.md
- Parallel execution in worktrees: docs/03-ORCA-WORKTREES-AND-PARALLEL-AGENTS.md
