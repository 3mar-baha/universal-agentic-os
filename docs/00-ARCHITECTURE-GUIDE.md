# Architecture Guide

This guide defines the structural contract of the Universal Agentic Engineering OS: the tripartite operating model, the canonical 16-file project scaffold and its precedence rules, and how this repository itself obeys the same model. Read it before any other guide.

## 1. Purpose and Position in the Repository

This is guide 00 of the seven documentation guides shipped with the OS:

| # | Guide |
|---|-------|
| 00 | `00-ARCHITECTURE-GUIDE.md` — Architecture Guide (this document) |
| 01 | `01-MULTI-DOMAIN-ARCHETYPES.md` — Multi-Domain Archetypes |
| 02 | `02-TOOLKIT-AND-ORCA-GUIDE.md` — Toolkit and Orca Guide |
| 03 | `03-ORCA-WORKTREES-AND-PARALLEL-AGENTS.md` — Orca Worktrees and Parallel Agents |
| 04 | `04-QUALITY-GATES-AND-SAFETY.md` — Quality Gates and Safety |
| 05 | `05-INITIAL-PROMPT.md` — Initial Prompt |
| 06 | `06-ENGINEERING-PILLARS.md` — Engineering Pillars |

It serves three audiences: agents starting a session who need the operating rules; humans evaluating the framework who need its shape in one document; and maintainers who need to know which artifact governs when documents disagree. Where this guide states an invariant, the invariant binds every project launched by the OS.

## 2. The Tripartite Operating Model

Every mission runs through exactly three roles. They are roles, not people: one operator or agent instance may hold several, but responsibilities, decision rights, and escalation paths never merge.

The Orca ADE runtime provides the machinery the roles operate through: session bootstrap, per-phase tool and skill injection and pruning, and the git-worktree pool used by parallel Implementers. See `02-TOOLKIT-AND-ORCA-GUIDE.md`.

### 2.1 Leader

The Leader decomposes the mission into tasks, routes each task, owns sequencing across tasks, and carries final accountability for the outcome.

Responsibilities:

- Decompose the mission into routable tasks.
- Sequence tasks and resolve cross-task conflicts.
- Decide re-plan versus abort when the circuit breaker fires.
- Report status and own the final result.

Decision rights: task order, task scope boundaries, routing, and abort authority. The Leader does not sign off quality — that right belongs to the Guide.

### 2.2 Guide

The Guide owns specification, architecture review, guardrails, and quality gates, and signs off every phase exit.

Responsibilities:

- Write and maintain specifications.
- Review architectural decisions.
- Define guardrails and gate criteria.
- Approve changed hypotheses under the circuit breaker.
- Sign off phase exits.

Decision rights: acceptance of specifications, approval of phase exits, approval of changed hypotheses, and invocation of the 3-Strike Circuit Breaker. The Guide does not re-route tasks — that right belongs to the Leader.

### 2.3 Implementer

The Implementer executes TDD implementation cycles (red, green, refactor) inside isolated git worktrees, one concern per worktree.

Responsibilities:

- Turn a specification into a red-green-refactor cycle.
- Keep the worktree single-concern.
- Log evidence for every failed fix hypothesis.
- Deliver green tests and a small diff for review.

Decision rights: technical approach inside the specification, commit granularity, and test structure within `docs/05-TEST-PLAN.md`. The Implementer does not widen scope or redefine acceptance criteria.

### 2.4 Escalation Flow and the 3-Strike Circuit Breaker

Escalation follows a fixed ladder:

1. Strike 1 — a fix hypothesis fails. The Implementer logs the hypothesis with its evidence and attempts a second hypothesis.
2. Strike 2 — a second hypothesis fails. The Implementer must escalate to the Guide; further unilateral attempts are prohibited.
3. The Guide either approves a changed hypothesis (which resets the strike counter) or endorses one narrowly scoped third attempt.
4. Strike 3 — a third consecutive failure. The Guide invokes the 3-Strike Circuit Breaker: halt all execution immediately. Never attempt a blind fourth fix.
5. The Guide emits a Diagnostic Incident Report (DIR) containing: the symptom; a hypothesis log with one entry per strike, each with evidence; ranked root causes; and recommended unblock actions.
6. The Leader reads the DIR and decides to re-plan (new decomposition or routing) or abort. Strikes reset only when the Guide approves a changed hypothesis; a Leader re-plan alone does not reset them.

### 2.5 One Task Through the Three Roles

```
   Leader                     Guide                     Implementer
     |                          |                           |
     | route task T1 ---------->|                           |
     | (scope, priority,        |> specification ---------->|
     |  constraints)            |> quality gates ---------->|
     |                          |<- clarifying questions ---|
     |                          |> resolved answers ------->|
     |                          |                           |
     |                          |   [isolated worktree]     |
     |                          | [red -> green -> refactor]|
     |                          |                           |
     |                          |<- BLOCKED: hypothesis 1 <-|
     |                          |> revised guidance ------->|
     |                          |<- BLOCKED: hypothesis 2 <-|
     |                          |   (escalate after 2)      |
     |                          |> changed hypothesis ------>|
     |                          |   (strikes reset)         |
     |                          |<- STRIKE 3: still broken -|
     |                          |                           |
     |<= CIRCUIT BREAKER =======|                           |
     | halt; DIR emitted        |                           |
     | re-plan or abort ------->|                           |
     |------------------------->|------------------------->>|
     |                          |                           |
     |<- phase exit sign-off ---|<- green tests + patch ----|
     |                          |                           |
```

Happy path: route, specify, implement, sign off, merge. Failure path: the blocked-and-strike ladder in section 2.4, terminating in the breaker.

## 3. The 16-File Canonical Project Hierarchy

### 3.1 The Scaffold

Every project launched by the OS receives exactly these 16 files, in this order:

| # | File | Purpose |
|----|------|---------|
| 01 | `CLAUDE.md` | Agent-facing operating contract: invariants, conventions, and commands every session must honor. |
| 02 | `README.md` | Human-facing overview: what the project is, how to install, run, and use it. |
| 03 | `.gitignore` | Excludes generated and local artifacts from version control. |
| 04 | `.env.example` | Template of required environment variables with obvious placeholder values only; never secrets. |
| 05 | `LICENSE` | Legal terms for use and redistribution (MIT by default). |
| 06 | `CONTRIBUTING.md` | Contribution process: branching, commits, tests, and review expectations. |
| 07 | `CHANGELOG.md` | Reverse-chronological record of notable changes per release. |
| 08 | `docs/00-VISION.md` | Mission, non-goals, and success criteria that anchor later decisions. |
| 09 | `docs/01-ARCHITECTURE.md` | System components, boundaries, data flow, and key design choices. |
| 10 | `docs/02-BACKLOG.md` | Prioritized, testable work items the Leader routes from. |
| 11 | `docs/03-DECISIONS.md` | Decision log: context, options considered, outcome, and consequences. |
| 12 | `docs/04-RUNBOOK.md` | Operational procedures: run, debug, deploy, and recover. |
| 13 | `docs/05-TEST-PLAN.md` | Test strategy, coverage expectations, and gate criteria. |
| 14 | `SECURITY.md` | Vulnerability reporting policy and the project security baseline. |
| 15 | `Makefile` | Canonical task entrypoints so agents and humans execute identical commands. |
| 16 | `.github/workflows/ci.yml` | CI pipeline enforcing build, test, and lint on every push. |

### 3.2 Hierarchy Rules

#### Reading Order for a New Agent Session

1. `CLAUDE.md` — load the invariants before anything else.
2. `docs/00-VISION.md` — why the project exists.
3. `docs/01-ARCHITECTURE.md` — how it is built.
4. `docs/02-BACKLOG.md` — what work exists and in what priority.
5. Task-scoped documents — load `docs/03-DECISIONS.md`, `docs/04-RUNBOOK.md`, and `docs/05-TEST-PLAN.md` only as the routed task requires.

The session-context-primer skill enforces this order at session bootstrap.

#### Precedence When Documents Conflict

When two artifacts disagree, the higher one wins:

```
CLAUDE.md invariants  >  docs guides  >  skills  >  code comments
```

A lower artifact never overrides a higher one; it yields, and the discrepancy is raised as a proposal to amend the higher artifact.

#### Update Discipline by Lifecycle Phase

| Lifecycle Phase | Files Updated |
|-----------------|---------------|
| 1. Discover & Launch | The agentic-project-launcher skill creates all 16 files; `CLAUDE.md`, `README.md`, and `docs/00-VISION.md` receive their initial substantive content. |
| 2. Architect & Guide | `docs/01-ARCHITECTURE.md` authored; `docs/02-BACKLOG.md` populated and prioritized; `docs/03-DECISIONS.md` opened; `CLAUDE.md` amended only when an invariant genuinely changes. |
| 3. Implement & Verify | `docs/02-BACKLOG.md` item statuses maintained; `docs/05-TEST-PLAN.md` evolved as strategy matures; `CHANGELOG.md` accumulates an entry per merged concern. |
| 4. Harden & Release | `docs/04-RUNBOOK.md` completed; `SECURITY.md` reviewed; `Makefile` targets finalized; `.github/workflows/ci.yml` verified green; release entry added to `CHANGELOG.md`; `README.md` finalized. |

#### Single Source of Scaffolding

Only the agentic-project-launcher skill creates the scaffold — the same 16 files in the same order — so every project started under this OS is uniform. Any role or skill may edit scaffold files afterward, but none may generate a replacement scaffold or omit files. Uniform scaffolds are what let any agent enter any project and know exactly where everything lives.

## 4. How This Repository Maps onto the Same Model

The OS is built with its own rules:

```
universal-agentic-os/
├── CLAUDE.md                     <- operating contract
├── README.md / README.ar.md     <- English primary, full Arabic translation
├── LICENSE                       <- MIT, (c) 2026 Madaar Team
├── CONTRIBUTING.md, CHANGELOG.md
├── .gitignore, .gitattributes, .env.example
├── docs/                         <- the 7 guides (this file is 00)
├── skills/                       <- the 6 core skills
├── scripts/
│   ├── setup-toolkit.sh          <- provisions CLAUDE_TOOLKIT_DIR
│   └── sync-toolkit.sh           <- updates it
└── .github/workflows/ci.yml      <- quality gate on every change
```

- The repository evolves through the same four phases: Discover & Launch produced this layout; Architect & Guide specified the 7 guides; changes are implemented and verified in isolated worktrees; releases pass the guards and ship through the github-release-packager skill.
- Role separation holds here too: routing and sequencing decisions live in the roadmap and backlog, specification and gate ownership sit with the reviewing side, and implementation lands as small diffs gated by `.github/workflows/ci.yml`.
- The 6 core skills — `agentic-project-launcher`, `claude-stage-orchestrator`, `session-context-primer`, `circuit-breaker-guard`, `preflight-system-doctor`, `github-release-packager` — are the executable form of the rules in this guide.
- Upstream toolkits stay centralized under `CLAUDE_TOOLKIT_DIR` (default `~/ai-agent-toolkit`) and are managed exclusively by `scripts/setup-toolkit.sh` and `scripts/sync-toolkit.sh`.
