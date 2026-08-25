# Contributing to Universal Agentic Engineering OS

## Welcome

Thank you for helping improve the Universal Agentic Engineering OS. This repository holds its own toolchain to the same standard it imposes on downstream projects: specification before code, tests as the contract, documentation as a deliverable. Read `CLAUDE.md` and `docs/06-ENGINEERING-PILLARS.md` before opening your first pull request.

## Code of Conduct

Be excellent to each other. Keep discussions technical, assume good intent, critique code rather than people, and help newcomers land their first contribution. Report unacceptable behavior privately to the maintainers.

## Setup

```bash
# 1. Fork the repository on GitHub, then clone your fork
git clone git@github.com:<your-username>/universal-agentic-os.git
cd universal-agentic-os

# 2. Install the 6 upstream toolkits
bash scripts/setup-toolkit.sh

# 3. Point the framework at the toolkit directory
export CLAUDE_TOOLKIT_DIR="$HOME/ai-agent-toolkit"

# 4. Activate the git hooks (secret scanning + zero AI attribution)
bash scripts/setup-git-hooks.sh

# 5. Put the uos CLI on your PATH (optional but recommended)
bash scripts/uos.sh install
```

The `uos` CLI wraps every lifecycle script: `uos doctor` verifies this setup end to end, `uos plan` shows the milestone DAG, `uos dispatch <stream>` / `uos merge <stream>` run parallel work in isolated worktrees, and `uos ship` runs all local quality gates before a release. See the [README](README.md#the-uos-cli) for the full command table.

`scripts/setup-toolkit.sh` clones the six upstream toolkits into `CLAUDE_TOOLKIT_DIR` (default `~/ai-agent-toolkit`): everything-claude-code, mattpocock-skills, ponytail, guard-skills, cybersecurity-skills, agency-agents. Run `scripts/sync-toolkit.sh` later to refresh them, and `scripts/setup-toolkit.sh --verify` for an offline integrity check.

## Commit Messages

Conventional Commits is mandatory. Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

The `.githooks/pre-commit` and `.githooks/commit-msg` hooks (activated in setup step 4) reject commits containing API keys or AI attribution — this repository ships zero AI attribution in its history. Never bypass them with `--no-verify`.

```text
feat(worktrees): recover orphaned worktrees during pool teardown
fix(guards): stop Docs Guard flagging frontmatter-only skill files
docs(readme): expand the Arabic quick-start section
```

Scope is optional. Write the subject in imperative mood with no trailing period; add a body when the why is not obvious from the what.

## Skills Compliance (Agent Skills Standard)

Any new automation MUST ship as a skill file under `skills/`. Ad-hoc scripts, prose runbooks, and chat-paste procedures are rejected in review. Each skill file must have:

1. YAML frontmatter whose `name` matches the filename slug and whose `description` is a one-line summary.
2. A body following the Agent Skills standard structure: Purpose, When to use, Inputs, Procedure, Outputs, Failure modes.

```markdown
---
name: my-new-skill
description: One-line description of what this skill does.
---

# My New Skill

## Purpose
## When to use
## Inputs
## Procedure
## Outputs
## Failure modes
```

Use the 6 core skills under `skills/` as the reference implementation of this structure.

## Test-Driven Development

Code changes follow red, green, refactor. Write the failing test first, then implement until green, then refactor while the suite stays green. A pull request containing implementation without failing-test-first history is returned unreviewed. Keep the full suite green locally before pushing.

## Documentation

Update documentation in the same pull request as the change it describes — never as follow-up work. Architecture changes touch `docs/00-ARCHITECTURE-GUIDE.md`; workflow or toolkit changes touch the relevant guide; user-facing changes touch both READMEs. Documentation is a deliverable (Engineering Pillar 8), not an afterthought.

## Quality Gates

The three second-pass guards must pass before you request review:

1. Clean Code Guard
2. Test Guard
3. Docs Guard

Run them yourself before opening the PR; `.github/workflows/ci.yml` verifies again on every push. A red guard blocks review regardless of how good the code looks.

## Pull Request Checklist

- [ ] Branch created from the latest default branch; one concern per branch.
- [ ] Commits follow Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`).
- [ ] Specification note or issue linked in the description.
- [ ] Tests written first (red, green, refactor); full suite green locally.
- [ ] Clean Code Guard passed.
- [ ] Test Guard passed.
- [ ] Docs Guard passed.
- [ ] Documentation updated in the same PR.
- [ ] `CHANGELOG.md` entry added.
- [ ] New automation (if any) ships as a compliant skill under `skills/`.
- [ ] No secrets, tokens, or credentials anywhere in the diff, logs, or fixtures.
- [ ] All local quality gates pass — run `uos ship` (or `bash scripts/uos.sh ship`) before opening the PR.

## Secrets

Never commit real API keys, tokens, passwords, or connection strings — not even in tests or fixtures. Reference secrets by environment-variable name only, and document any new variable in `.env.example` with an obvious placeholder. If you believe a secret was exposed, rotate it immediately and notify the maintainers in the PR.

## License

By contributing, you agree that your contributions are licensed under the MIT License covering this repository (copyright (c) 2026 Madaar Team).
