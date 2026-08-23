---
name: preflight-system-doctor
description: Validates environment, runtimes, configuration and workspace health before any execution runs, printing a PASS/FAIL/SKIPPED table with remediation commands and blocking on critical failures.
---

# Preflight System Doctor

## Purpose

Make every run reproducible by verifying the machine before acting on it. This skill
implements Engineering Pillar 9, "Reproducibility by Preflight": no lifecycle phase,
toolkit injection, or Orca session bootstrap starts until the doctor issues a PASS
verdict on all critical checks. It inspects four areas in order — environment,
runtimes, configuration, and workspace — and produces one actionable report. Run it
before session-context-primer so the primer operates on verified ground truth.

## When to Use

- At session bootstrap, before Orca injects tools and skills for phase 1,
  Discover & Launch.
- Before running scripts/setup-toolkit.sh or scripts/sync-toolkit.sh.
- Before phase 3 fans out into parallel git worktrees, where git hygiene and disk
  capacity matter most.
- Before phase 4, Harden & Release, where gh CLI authentication is mandatory.
- Whenever an agent is about to run long-lived or mutating operations in a new shell,
  container, or checkout.

## Inputs

- Target repository root (defaults to the current working directory).
- `CLAUDE_TOOLKIT_DIR` (optional; falls back to the default `~/ai-agent-toolkit`).
- Minimum version policy: git >= 2.30, gh >= 2.40.0, jq >= 1.6, node >= 20,
  python >= 3.10.
- Optional explicit override for a dirty workspace, supplied by the operator and
  recorded in the run log.

## Procedure

1. **Declare scope.** Record the repo root, the resolved `CLAUDE_TOOLKIT_DIR`, and the
   run timestamp. Later rows cite these values.
2. **Check the environment.** Detect OS and default shell; probe network egress to
   github.com with `git ls-remote https://github.com/worldflowai/everything-claude-code HEAD`.
3. **Check the runtimes.** For git, gh, jq, node, and python: confirm presence and
   compare the reported version against the minimums above. For gh, additionally run
   `gh auth status` as its own check.
4. **Check the configuration.** Confirm `CLAUDE_TOOLKIT_DIR` is set (or accept the
   default) and contains all 6 canonical toolkits: everything-claude-code,
   mattpocock-skills, ponytail, guard-skills, cybersecurity-skills, agency-agents.
   Confirm `.env` exists and defines every variable named in `.env.example`. Scan
   tracked files for real-looking credentials (AWS access-key ids, `ghp_`/`sk-`/`xox`
   token shapes, long high-entropy literals) so no secret is about to be leaked.
5. **Check the workspace.** Require `git status --porcelain` to be empty, or accept an
   explicit operator override recorded in the run log. Verify free disk space on the
   repo volume and on the Orca worktree-pool volume; require at least 5 GB free on each.

   Canonical probes:

   ```sh
   git --version                                                     # >= 2.30
   gh --version                                                      # >= 2.40.0
   gh auth status                                                    # authenticated account required
   jq --version                                                      # >= 1.6
   node --version                                                    # >= 20
   python --version                                                  # >= 3.10
   git ls-remote https://github.com/worldflowai/everything-claude-code HEAD   # egress probe
   git status --porcelain                                            # must be empty, or override logged
   ```

6. **Assign severities before reading results.** Each row is CRITICAL or WARN:
   - CRITICAL: git present and version ok; gh authenticated when the run touches
     GitHub; `.env`/`.env.example` in sync; secret scan clean; clean workspace or
     logged override; disk space.
   - WARN: OS/shell identity; jq/node/python when the current phase does not invoke
     them; toolkit population when operating entirely outside toolkit-injected phases.
7. **Print the report.** Emit one table with the columns check, status, detail, and
   remediation command, followed by the overall verdict. Statuses are PASS, FAIL, or
   SKIPPED.
8. **Enforce the verdict.** The verdict is PASS only when no CRITICAL row is FAIL.
   FAIL on any critical check blocks execution immediately — print the report and
   stop. SKIPPED rows (for example, network checks while offline) do not fail the run;
   however, a CRITICAL check that lands on SKIPPED requires explicit operator
   confirmation before execution proceeds.

## Outputs

One report block per run, in this shape:

| Check | Status | Detail | Remediation |
| --- | --- | --- | --- |
| OS / shell | PASS | Windows 11, PowerShell 7 | n/a |
| Network egress to github.com | SKIPPED | Offline; degraded to cached checks | Restore connectivity |
| git >= 2.30 | PASS | 2.45.0 | n/a |
| gh >= 2.40.0 | PASS | 2.57.0 | n/a |
| gh auth status | FAIL | Not authenticated | `gh auth login` |
| jq >= 1.6 | PASS | 1.7.1 | n/a |
| node >= 20 | PASS | 20.11.0 | n/a |
| python >= 3.10 | WARN | 3.9.7 found | Install Python 3.10+ |
| CLAUDE_TOOLKIT_DIR populated with 6 toolkits | FAIL | 4 of 6 present; missing ponytail, agency-agents | `bash scripts/setup-toolkit.sh` |
| .env present and .env.example in sync | PASS | 12 of 12 variables covered | n/a |
| Secret scan of tracked files | PASS | No credential-shaped strings found | n/a |
| Clean git status (or logged override) | FAIL | 3 modified files | Commit, stash, or log an explicit override |
| Disk space (repo + worktree pool) | PASS | 84 GB and 120 GB free | n/a |

Verdict lines:

```text
PREFLIGHT VERDICT: FAIL — 3 critical check(s) failed. Execution blocked.
PREFLIGHT VERDICT: PASS — all critical checks green. Execution may proceed.
```

Remediation commands are copy-pasteable and reference project scripts where they exist:
`bash scripts/setup-toolkit.sh` repairs a partial toolkit installation, and
`bash scripts/sync-toolkit.sh` refreshes stale toolkit contents.

## Failure Modes

- **gh not authenticated.** Print the exact login command — `gh auth login` — in the
  remediation column and in the verdict summary, and note that the device-flow login is
  interactive, so the operator must run it personally.
- **Partial toolkit installation.** Fewer than 6 canonical toolkits present: list the
  missing names explicitly and offer `bash scripts/setup-toolkit.sh`; when the
  directories exist but are stale, offer `bash scripts/sync-toolkit.sh` instead.
- **Offline machine.** Degrade gracefully: reuse cached toolkit metadata and
  last-known versions, mark every network-dependent check SKIPPED rather than FAIL,
  and state plainly which follow-on steps (cloning, syncing, releasing) cannot run
  until connectivity returns.
