# Universal Agentic Engineering OS

*A Production-Grade, Multi-Domain Autonomous Development & AI Agent Orchestration Framework.*

Universal Agentic Engineering OS turns a raw mission statement into a verified, documented, production-ready outcome. It pairs a tripartite operating model — **Leader**, **Guide**, **Implementer** — with a four-phase lifecycle, a canonical 16-file project scaffold, and six bundled skills. Autonomy is bounded by hard safety machinery: a 3-strike circuit breaker, three independent second-pass guards, specification-before-code planning, tests-as-contract implementation in isolated git worktrees, and disciplined, changelog-driven releases.

[🌍 Read this in Arabic](README.ar.md)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Skills](https://img.shields.io/badge/skills-6-blue.svg)
![Docs](https://img.shields.io/badge/docs-7-blue.svg)
![Shells](https://img.shields.io/badge/shells-bash%20%7C%20zsh-black.svg)

---

## Why

- **Multi-domain by construction.** One operating model covers all four archetypes — Software Engineering, AI/ML, Business Automation, Deep Research — so your team and your agents learn one discipline instead of four.
- **Safety-gated autonomy.** Agents move fast inside rails: no code without an approved spec, no merge without green tests, no release without the guards, and never a blind fourth fix attempt.
- **Centralized toolkit economy.** Six upstream toolkits install once into `CLAUDE_TOOLKIT_DIR` and are injected per phase and pruned after, so context spend tracks the work actually being done.

## Architecture

Orca ADE (ORchestrated Cooperative Agents) is the runtime layer of this OS. It owns session bootstrap, dynamic tool and skill injection and pruning per lifecycle phase, and the git-worktree pool used by parallel Implementers. The tripartite operating model runs on top of it:

```
                        +-----------------------+
                        |        LEADER         |
                        | decomposes mission,   |
                        | routes tasks, owns    |
                        | sequencing + outcome  |
                        +-----------+-----------+
                                    |
              tasks + constraints   |    status + results
                +-------------------+-------------------+
                v                                       v
    +-----------------------+               +-----------------------+
    |         GUIDE         |               |     IMPLEMENTERS      |
    | specification         | ------------->| [worktree: feat-a]    |
    | architecture review   |  spec + gates | red -> green ->       |
    | guardrails + gates    | <-------------| refactor cycle        |
    | phase-exit sign-off   |  escalation + | [worktree: bugfix-b]  |
    +-----------------------+  strikes +DIR |                       |
                                            +-----------+-----------+
                                       reviewed merges  |
                                                        v
                                            +-----------------------+
                                            | main: guarded, tagged |
                                            | released via phase 4  |
                                            +-----------------------+
```

The Leader routes every task; the Guide specifies it and sets the gates; Implementers execute red-green-refactor cycles in isolated worktrees, one concern per worktree, merging back through reviewed, signed-off integrations.

| Role | Owns | Decision rights | Explicitly not theirs |
| --- | --- | --- | --- |
| **Leader** | Mission decomposition, task routing, sequencing, final accountability | Task order, scope boundaries, routing, abort authority | Signing off quality — that belongs to the Guide |
| **Guide** | Specification, architecture review, guardrails, quality gates; signs off every phase exit | Spec acceptance, phase-exit approval, changed-hypothesis approval, circuit-breaker invocation | Re-routing tasks — that belongs to the Leader |
| **Implementer** | TDD micro-cycles (red, green, refactor) inside isolated git worktrees, one concern per worktree | Technical approach within the spec, commit granularity, test structure | Widening scope or redefining acceptance criteria |

## The Four-Phase Lifecycle

| Phase | Lead role | Key activities | Exit criteria | Primary skills |
| --- | --- | --- | --- | --- |
| 1. Discover & Launch | Leader | Socratic discovery, mandatory deployment-path check, scaffold the 16 canonical files | Scaffold committed on `main`; deployment path fixed; discovery brief recorded in the vision, architecture, and decisions docs | `agentic-project-launcher`, `preflight-system-doctor`, `session-context-primer` |
| 2. Architect & Guide | Guide | Specifications, plan, dynamic toolkit and skill injection for the incoming phase | Approved specification; prioritized backlog; correct phase context set injected | `claude-stage-orchestrator` |
| 3. Implement & Verify | Implementer | TDD micro-cycles (red, green, refactor) in parallel isolated worktrees | Full suite green; concerns merged through reviewed integrations; changelog entries per merged concern | `circuit-breaker-guard` |
| 4. Harden & Release | Guide | Quality gates, second-pass guards, packaging, release | Clean Code Guard, Test Guard, and Docs Guard passed; CI green; tagged release published | `circuit-breaker-guard`, `github-release-packager` |

## Quick Start

```sh
# 1. Clone this repository
git clone https://github.com/madaar-team/universal-agentic-os.git
cd universal-agentic-os

# 2. Provision the centralized toolkit (installs the 6 upstream toolkits)
bash scripts/setup-toolkit.sh

# 3. Point the OS at the toolkit directory
export CLAUDE_TOOLKIT_DIR="$HOME/ai-agent-toolkit"

# 4. Open Claude Code and invoke the launcher skill with your mission statement
claude
# then: invoke the agentic-project-launcher skill
```

Keep the toolkit current with `bash scripts/sync-toolkit.sh`.

Starting a brand-new project? [docs/05-INITIAL-PROMPT.md](docs/05-INITIAL-PROMPT.md) is the standalone prompt for new projects — paste it into any fresh Claude Code session to run Discover & Launch with the same rigor, no local setup required.

## Bundled Skills

Six core skills ship with the OS. They are the executable form of its rules.

| Skill | What it does | Lifecycle phase |
| --- | --- | --- |
| [`agentic-project-launcher`](skills/agentic-project-launcher.md) | Runs Socratic discovery, completes the deployment-path check, and materializes the canonical 16-file scaffold | 1. Discover & Launch |
| [`claude-stage-orchestrator`](skills/claude-stage-orchestrator.md) | Injects exactly the skills, toolkit assets, and documents a phase needs — and prunes the rest — through Orca ADE | Phase transitions across all four phases |
| [`session-context-primer`](skills/session-context-primer.md) | Rebuilds essential working context in roughly ten seconds at session start and emits a CONTEXT ANCHOR block | Session bootstrap, every phase |
| [`circuit-breaker-guard`](skills/circuit-breaker-guard.md) | Tracks failed fix attempts per defect and forces a hard halt with a Diagnostic Incident Report at 3 strikes | 3. Implement & Verify, armed through 4 |
| [`preflight-system-doctor`](skills/preflight-system-doctor.md) | Validates environment, runtimes, configuration, and workspace health; blocks execution on critical failures | Preflight before any phase, starting with 1 |
| [`github-release-packager`](skills/github-release-packager.md) | Generates tiered bilingual READMEs and governs releases from changelog-derived notes through post-release verification | 4. Harden & Release |

## Documentation

Seven guides document the framework end to end:

| File | What it covers |
| --- | --- |
| [`docs/00-ARCHITECTURE-GUIDE.md`](docs/00-ARCHITECTURE-GUIDE.md) | The tripartite operating model, the 16-file canonical scaffold, precedence rules between artifacts, and how this repository obeys its own model |
| [`docs/01-MULTI-DOMAIN-ARCHETYPES.md`](docs/01-MULTI-DOMAIN-ARCHETYPES.md) | The four multi-domain archetypes and how each shapes discovery, stack defaults, and release criteria |
| [`docs/02-TOOLKIT-AND-ORCA-GUIDE.md`](docs/02-TOOLKIT-AND-ORCA-GUIDE.md) | The centralized toolkit under `CLAUDE_TOOLKIT_DIR`, the 6 upstream toolkits, and the Orca ADE runtime layer |
| [`docs/03-ORCA-WORKTREES-AND-PARALLEL-AGENTS.md`](docs/03-ORCA-WORKTREES-AND-PARALLEL-AGENTS.md) | The git-worktree pool: isolation rules, one concern per worktree, and reviewed merges from parallel Implementers |
| [`docs/04-QUALITY-GATES-AND-SAFETY.md`](docs/04-QUALITY-GATES-AND-SAFETY.md) | Quality gates and safety: the second-pass guards, circuit-breaker policy, secret handling, and the security baseline |
| [`docs/05-INITIAL-PROMPT.md`](docs/05-INITIAL-PROMPT.md) | The standalone initial prompt for launching a new project with the OS |
| [`docs/06-ENGINEERING-PILLARS.md`](docs/06-ENGINEERING-PILLARS.md) | The 10 engineering pillars and how every role, phase, skill, and guard operationalizes them |

## Multi-Domain

Four archetypes share one operating model — see [docs/01-MULTI-DOMAIN-ARCHETYPES.md](docs/01-MULTI-DOMAIN-ARCHETYPES.md):

- **Software Engineering** — spec-first delivery of production applications and services, with TDD micro-cycles fanned out across worktrees.
- **AI/ML** — data pipelines, training and evaluation harnesses, and model-backed features governed by the same gates as any other code.
- **Business Automation** — process workflows and integrations delivered as documented, testable, auditable changes.
- **Deep Research** — structured investigation with evidence logs, reproducible methods, and deliverable documentation.

## Safety

Autonomy without brakes is a liability. This OS ships three of them as standard equipment:

- **3-Strike Circuit Breaker.** If the same defect survives 3 consecutive failed fix attempts, all execution HALTs immediately — never a blind fourth fix — and a Diagnostic Incident Report is emitted: symptom, hypothesis log with evidence per strike, ranked root causes, and recommended unblock actions. Strikes reset only when the Guide approves a changed hypothesis.
- **Three Second-Pass Guards.** Every change passes independent post-implementation review in phase 4: Clean Code Guard, Test Guard, and Docs Guard. Author confidence is never the final check.
- **Bounded blast radius.** The preflight-system-doctor skill verifies the machine before any run, parallel work stays isolated one concern per worktree, and secrets live only in `.env` — referenced by name, never by value.

## Acknowledgments

This framework stands on six upstream toolkits, installed once into `CLAUDE_TOOLKIT_DIR` by `scripts/setup-toolkit.sh` and refreshed by `scripts/sync-toolkit.sh`:

- [everything-claude-code](https://github.com/worldflowai/everything-claude-code) — broad Claude Code configs, commands, and workflows
- [mattpocock-skills](https://github.com/mattpocock/skills) — TypeScript and DX-oriented skills
- [ponytail](https://github.com/dietrichgebert/ponytail) — radical minimalism: the smallest abstraction, no speculative features
- [guard-skills](https://github.com/amElnagdy/guard-skills) — defensive quality gates and review guards
- [cybersecurity-skills](https://github.com/mukul975/Anthropic-Cybersecurity-Skills) — security review and hardening skills
- [agency-agents](https://github.com/msitarzewski/agency-agents) — specialized agent personas for agency workflows

## Roadmap

- Domain starter kits that pre-seed the 16-file scaffold with archetype-specific Makefile targets and CI jobs.
- A pluggable catalog of additional second-pass guards alongside Clean Code Guard, Test Guard, and Docs Guard.
- Archetype-aware toolkit profiles that preselect bundles from the 6 upstream toolkits at inject time.
- More language mirrors alongside the English primary and the full Arabic README.

## License

Released under the MIT License. Copyright (c) 2026 Madaar Team. See [LICENSE](LICENSE).

Contributions are welcome — start with [CONTRIBUTING.md](CONTRIBUTING.md) and the [Engineering Pillars](docs/06-ENGINEERING-PILLARS.md).
