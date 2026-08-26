# Universal Agentic Engineering OS

*A Production-Grade, Multi-Domain Autonomous Development & AI Agent Orchestration Framework.*

Universal Agentic Engineering OS turns a raw mission statement into a verified, documented, production-ready outcome. It pairs a tripartite operating model — **Leader**, **Guide**, **Implementer** — with a four-phase lifecycle, a canonical 16-file project scaffold, and six bundled skills. Autonomy is bounded by hard safety machinery: a 3-strike circuit breaker, three independent second-pass guards, specification-before-code planning, tests-as-contract implementation in isolated git worktrees, and disciplined, changelog-driven releases.

[🌍 Read this in Arabic](README.ar.md)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.4.5.3-blue.svg)
![Skills](https://img.shields.io/badge/skills-7-blue.svg)
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

# 2. One-command bootstrap: toolkits + git hooks + CLI on PATH + doctor report
bash scripts/uos.sh init

# 3a. Start a brand-new governed project (canonical scaffold + OS runtime)
uos new my-project ~/Projects

# 3b. ...or work inside an existing repository: open your agent there and
#     paste docs/05-INITIAL-PROMPT.md — agents other than Claude Code start
#     from AGENTS.md automatically.
```

Keep the toolkit current with `bash scripts/sync-toolkit.sh`.

### Vantrilex launcher (Windows)

[`vantrilex.ps1`](vantrilex.ps1) is the interactive coding-agent orchestrator — one launcher for **Claude Code, OpenCode, and Codex**, and a full session bootstrap, not just an environment setter:

1. **Prompt type first**: no prompt; **new project from full docs** (injects the Master Initial Project Prompt, extracted live from `docs/05-INITIAL-PROMPT.md` — ingests your documentation read-only and starts Phase 2 TDD); **new project from an idea** (grill-me style Socratic interview → authors the complete canonical documentation suite → follows the governed workflow); or **continue a project** (primes context from the checkpoint, honors the BLOCKED circuit-breaker path, resumes the first open milestone with strict TDD).
2. **Provider**: DeepSeek direct, OrcaRouter free gateway, Ox Alpha via OpenRouter (1M context), or any custom endpoint.
3. **Agent**: Claude Code (Anthropic env wiring), OpenCode (standard provider keys + `-m provider/model`), or Codex (`-c model_provider` overrides over an OpenAI-compatible endpoint). Provider→tool translation is automatic; unsupported combinations warn instead of failing silently.
4. **Effort level** up to Ultracode (applied where the agent supports it), then the project path.
5. **Session preparation**: provisions the 6 toolkits if missing, vendors the OS runtime into the project when absent (native hooks + settings, lifecycle scripts, the Universal Meta-Skill, pinned `.mcp.json`, lint config) so MCP servers, skills, and hooks load directly into the session.
6. **Launches the chosen agent** with the chosen prompt as its first message.

No keys are stored in the script: environment → gitignored `.env.vantrilex` sidecar (opt-in save) → interactive paste, masked to the last 6 characters.

**Verified, not assumed.** The provider→tool translation lives in one pure function exercised by an offline self-test matrix covering every agent × provider combination:

```powershell
powershell -ExecutionPolicy Bypass -File vantrilex.ps1 -SelfTest
```

CI additionally runs that matrix on every push plus a launch smoke that executes each agent CLI's `--version` for real (`@anthropic-ai/claude-code`, `opencode-ai`, `@openai/codex`).

```powershell
powershell -ExecutionPolicy Bypass -File vantrilex.ps1
```

### Security & key rotation

- This repository ships **zero secrets** — pre-commit scanning rejects known API-key formats, bearer headers, and credential-shaped assignments on every commit.
- Launcher keys resolve from your process environment or a gitignored `.env.vantrilex`; never commit that file, never paste keys into issues or chats.
- **Rotate immediately** any key that appeared in plaintext anywhere (chat, screenshot, repo history): DeepSeek → Platform dashboard → API keys → delete + create; OpenRouter → Settings → Keys → create new, revoke old; Orca → provider console. Update the value in your environment or `.env.vantrilex` afterwards — nothing else references it.
- If a secret ever reaches git history, rotation is the fix; history rewriting does not un-leak it.

Sessions run with a pinned MCP baseline — [`.mcp.json`](.mcp.json) enforces five core servers (`fetch`, `brave-search`, `sequential-thinking`, `filesystem`, `git`; credentials by environment variable name only) — and [.devcontainer/](.devcontainer/) gives one-command environment parity for local and cloud sandboxes, preloading all 6 toolkits via `postCreateCommand`.

Starting from a repository already seeded with the OS scaffold? [docs/05-INITIAL-PROMPT.md](docs/05-INITIAL-PROMPT.md) is the turnkey master initial project prompt — paste it into any fresh agent session to verify the 6-toolkit centralized toolkit, ingest and validate the existing specs, wire the hooks and the `uos` CLI, generate the project-tailored `CLAUDE.md`, anchor the checkpoint, and begin Phase 2 TDD immediately.

## The `uos` CLI

One entry point over everything above. Install it with `bash scripts/uos.sh install` (links onto `~/.local/bin`), or call it directly:

| Command | What it does |
| --- | --- |
| `uos init` | One-command machine bootstrap: provisions and verifies the 6 toolkits, activates git hooks, installs the CLI onto PATH, ends with a `doctor` report |
| `uos new <NAME> [DIR]` | Scaffolds a brand-new governed project: canonical 16-file hierarchy with real seed content, live checkpoint, vendored OS runtime (hooks, scripts, meta-skill, MCP baseline), initial commit |
| `uos ingest` | Parses and cross-references every spec in `docs/`, read-only; writes `.claude/spec-index.md` for context priming and fails on broken references |
| `uos plan` | Prints the checkpoint milestone DAG as dispatchable workstreams |
| `uos dispatch <stream> [phase]` | Provisions an isolated git worktree at `.worktrees/<stream>` on `feature/<stream>`, pre-injected with the phase context kit |
| `uos merge <stream> [--keep]` | Gates the stream's diff (`bash -n`, shellcheck, markdownlint), merges `--no-ff`, prunes the worktree, stamps the checkpoint |
| `uos graph [--check]` | Syncs the repo tree into a marker-bounded Mermaid graph in the architecture doc; `--check` fails CI on stale graphs |
| `uos decide <TITLE>` | Appends an auditable ADR to the decision log (`docs/09-DECISIONS.md` or `docs/03-DECISIONS.md`) |
| `uos doctor` | Sub-second diagnostics: runtimes, hook wiring, API-key presence, toolkit integrity |
| `uos ship [--release]` | Runs all local quality gates (now including version consistency across changelog/badges/CLI and architecture-graph currency) and prints the release checklist; `--release` additionally opens a draft GitHub release via `gh` for you to publish |
| `uos release <X.Y.Z>` | One-command publish: extracts the version's CHANGELOG section as release notes, tags, pushes, and creates the GitHub release (`--draft` to review first); a tag-push workflow attaches the source tarball to the release |
| `uos status` | Compact 3-line card: active phase, active milestone, test status |

## Bundled Skills

Seven core skills ship with the OS. They are the executable form of its rules — six operational skills plus the Universal Meta-Skill that gives any AI agent complete comprehension of all of them.

| Skill | What it does | Lifecycle phase |
| --- | --- | --- |
| [`universal-agentic-workflow`](skills/universal-agentic-workflow.md) | The Universal Meta-Skill: complete operating manual for the OS — tripartite model, 4-phase lifecycle, 6-toolkit rotation, Orca worktrees, every invariant and safety gate | Load once at session start, every phase |
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
| [`docs/05-INITIAL-PROMPT.md`](docs/05-INITIAL-PROMPT.md) | The turnkey master initial project prompt: toolkit verification, spec ingestion, machinery wiring, tailored `CLAUDE.md` generation, checkpoint anchoring, and immediate Phase 2 TDD |
| [`docs/06-ENGINEERING-PILLARS.md`](docs/06-ENGINEERING-PILLARS.md) | The 10 engineering pillars and how every role, phase, skill, and guard operationalizes them |
| [`docs/10-CHECKPOINT.md`](docs/10-CHECKPOINT.md) | Live session state: `ACTIVE_PHASE`, `status`, and the milestone DAG; completed milestones archive to `docs/archive/` |

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
