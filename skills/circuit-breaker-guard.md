---
name: circuit-breaker-guard
description: Enforces the 3-strike circuit breaker by tracking consecutive failed fix attempts per defect and forcing a hard halt with a Diagnostic Incident Report instead of a blind fourth attempt.
---

# Circuit Breaker Guard

## Purpose

Protect the project from unbounded debugging loops. This skill implements Engineering
Pillar 6, "Fail Fast, Halt at Three Strikes": when the same defect survives 3
consecutive failed fix attempts, all execution halts immediately and the agent emits a
Diagnostic Incident Report (DIR) for human review.

A fix attempt counts as **failed** when the failing test or observed behavior is
unchanged after the attempt. The strike ledger is tracked per defect id, so unrelated
defects never consume each other's budget. The Guide owns this gate: strikes reset only
when the Guide approves a changed hypothesis, and nothing else — including user
pressure — reopens the loop.

## When to Use

- During phase 3, Implement & Verify, whenever an Implementer iterates on a failing
  test or defect inside its isolated worktree.
- Whenever a defect id has been assigned and a fix attempt is about to be applied.
- Whenever a second or third failed attempt on the same defect id is detected, to arm
  the halt.
- After a Guide-approved changed hypothesis, to reset and rebuild the ledger correctly.

Do not use for greenfield work with no failing contract, and do not share a counter
across defect ids: the ledger is always scoped to one root symptom.

## Inputs

- Defect id (`DEF-<NNN>`), assigned at first detection of the failure.
- The failing test or behavioral probe that proves the defect exists.
- Exactly one hypothesis per fix attempt, plus the evidence collected after running it.
- The strike ledger (session notes keyed by defect id).
- Git history of fix-attempt commits, used to rebuild a lost ledger.

## Procedure

1. **Open a ledger entry.** On first detection, assign the defect id and create its
   ledger entry: `{defect id, root symptom, strikes: 0}`. State the root symptom as an
   invariant description of the wrong behavior, not the stack trace of the moment.
2. **State the hypothesis before touching code.** Every attempt begins with one
   falsifiable hypothesis written into the ledger. No hypothesis, no attempt.
3. **Apply exactly one fix per attempt.** One attempt equals one coherent change
   addressing the stated hypothesis. Do not bundle speculative changes.
4. **Re-run the failing test or probe.** Compare the behavior to the previous attempt.
5. **Score the attempt.**
   - Behavior resolved: close the ledger entry; the defect is fixed.
   - Behavior unchanged: record one strike — append the hypothesis and its evidence
     (test output, diff, measurements) to the ledger for that defect id.
6. **Check the count after every strike.** Strikes 1 and 2: continue the loop at
   step 2. Strike 3: go to step 7 immediately.
7. **HALT.** Print the exact halt message below verbatim, then stop all execution —
   no edits, no tests, no worktree activity, no parallel agents. Never attempt a blind
   fourth fix.
8. **Emit the Diagnostic Incident Report.** Fill the DIR template in Outputs directly
   from the ledger: one hypothesis-log entry per strike, each backed by evidence.
9. **Reset only through the Guide.** Present the DIR to the Guide. If the Guide
   approves a changed hypothesis, record the approval, reset the strike count to zero,
   and resume at step 2 with the new hypothesis. Without that approval, remain halted.

### Exact Halt Message

Print verbatim, substituting the real defect id:

```text
[CIRCUIT BREAKER] HALT — defect DEF-<id> has survived 3 consecutive failed fix attempts.
All execution stops now. There will be no fourth attempt, blind or otherwise.
Strikes reset only when the Guide approves a changed hypothesis.
Emitting Diagnostic Incident Report for review.
```

## Outputs

- A maintained strike ledger entry for every active defect id.
- On strike 3: the exact halt message above, printed verbatim.
- On strike 3: a completed Diagnostic Incident Report in this exact form:

```text
=== DIAGNOSTIC INCIDENT REPORT ===
Defect ID:        DEF-<id>
Phase / Worktree: <lifecycle phase and worktree where the defect lives>
Symptom:          <root symptom, stated invariantly>

Hypothesis Log (one entry per strike):
  Strike 1:
    Hypothesis:  <what we believed caused the defect>
    Fix Applied: <the change made under this hypothesis>
    Evidence:    <test output / observation proving the behavior did not change>
  Strike 2:
    Hypothesis:  <what we believed caused the defect>
    Fix Applied: <the change made under this hypothesis>
    Evidence:    <test output / observation proving the behavior did not change>
  Strike 3:
    Hypothesis:  <what we believed caused the defect>
    Fix Applied: <the change made under this hypothesis>
    Evidence:    <test output / observation proving the behavior did not change>

Ranked Root Causes (most likely first, justified by the evidence above):
  1. <root cause candidate and the evidence that supports it>
  2. <root cause candidate and the evidence that supports it>
  3. <root cause candidate and the evidence that supports it>

Recommended Unblock Actions:
  1. <action that gathers missing information, e.g. reproduce outside the worktree,
     add tracing, profile the failing path>
  2. <proposed changed hypothesis for the Guide to evaluate>

Guide Sign-off (changed hypothesis approved): ______________________  Date: __________
Strikes reset ONLY on this sign-off.
```

## Failure Modes

- **Defect mutates slightly between attempts** — new stack trace, shifted line number,
  different error text. Treat it as the same defect and keep counting strikes whenever
  the root symptom is identical; only a genuinely different root symptom earns a new
  defect id and a fresh ledger.
- **User pressure to continue** ("just try once more"). Hold the halt. Offer the DIR as
  the fastest path forward and state that resumption requires a Guide-approved changed
  hypothesis; do not run a fourth attempt under any circumstances.
- **Ledger lost mid-session** (context compaction, crashed shell, fresh terminal).
  Rebuild it from the git history of fix-attempt commits on the defect's branch: each
  attempt commit paired with the test output it produced reconstructs one hypothesis-log
  entry. If any strike cannot be reconstructed with evidence, keep the higher count and
  flag the gap explicitly in the DIR.
