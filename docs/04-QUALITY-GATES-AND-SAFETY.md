# Quality Gates & Safety

Quality is enforced by gates, not by goodwill. Two mechanisms carry most of the load: the 3-strike circuit breaker, which stops runaway debugging before it burns the schedule, and the three second-pass guards, which review finished work before release. This guide defines both precisely, wires them to the lifecycle, and states the safety invariants every agent obeys.

## The 3-Strike Circuit Breaker

Principle — pillar 6, Fail Fast, Halt at Three Strikes. A defect that survives three consecutive failed fix attempts is not understood well enough to fix blindly. Stop, diagnose, and report.

Definitions:

- **Defect fingerprint.** The stable identity of a defect: failing test name(s), error type plus stack location, or a named observable symptom. The same fingerprint is the same defect.
- **Strike.** One failed fix attempt against the same fingerprint. Failed means the defect's verification — its tests or reproduction script — did not turn green after the attempt.
- **Consecutive.** Strikes accumulate while attempts target the same fingerprint. Intervening unrelated work does not reset the count. Only a Guide-approved changed hypothesis resets it.

Algorithm:

```text
strikes := 0
loop:
  state a hypothesis for the CURRENT fingerprint (before writing any fix)
  apply the fix
  run the defect's verification (tests, reproduction script)

  if verification passes:
      record the fix
      strikes := 0
      continue with the next work item
  else:
      strikes += 1
      append to the hypothesis log: hypothesis, change made, evidence of failure

      if strikes == 3:
          HALT all execution for this task — never attempt a blind 4th fix
          emit a Diagnostic Incident Report (DIR) to the Guide and the Leader
          STOP
```

Reset rule: strikes reset only when the Guide approves a changed hypothesis — a materially different causal explanation, not a rewording of the old one. On approval, the count returns to zero and implementation resumes under the new hypothesis.

At strike 3:

1. HALT all execution for the task immediately. Dependent tasks are frozen by the Leader.
2. Emit the DIR using the template below, with the complete hypothesis log.
3. Resume only when the Guide signs off a changed hypothesis (strikes reset) or the Leader re-scopes or cancels the task.

The circuit-breaker-guard skill enforces strike counting and halt behavior; agents never track strikes informally.

### Diagnostic Incident Report (DIR) Template

```text
# Diagnostic Incident Report (DIR)

Incident ID:        DIR-<YYYYMMDD>-<NN>
Date opened:        <YYYY-MM-DD>
Project:            <project name>
Lifecycle phase:    <Discover & Launch | Architect & Guide | Implement & Verify | Harden & Release>
Reporting agent:    <Implementer name or id>
Task reference:     <task id and title>
Defect fingerprint: <failing test name(s) / error signature / symptom id>

## Symptom
<What is observably wrong: exact error output, failing test names,
reproduction command, expected versus actual behavior.>

## Hypothesis Log (one entry per strike)

### Strike 1
Hypothesis:  <causal explanation tested>
Fix applied: <exact change attempted>
Evidence:    <verification command and observed result proving failure>

### Strike 2
Hypothesis:  <causal explanation tested>
Fix applied: <exact change attempted>
Evidence:    <verification command and observed result proving failure>

### Strike 3
Hypothesis:  <causal explanation tested>
Fix applied: <exact change attempted>
Evidence:    <verification command and observed result proving failure>

## Ranked Root Causes
1. <root cause>  — confidence: <high|medium|low>  — evidence: <pointer>
2. <root cause>  — confidence: <high|medium|low>  — evidence: <pointer>
3. <root cause>  — confidence: <high|medium|low>  — evidence: <pointer>

## Recommended Unblock Actions
1. <action> — owner: <role> — expected effect: <outcome>
2. <action> — owner: <role> — expected effect: <outcome>

## Sign-off
Guide:         ____________________  Date: ____________
Decision:      <approve changed hypothesis | re-scope | cancel>
Strikes reset: <yes — new hypothesis recorded | no — task remains halted>
```

## The Second-Pass Guards

In phase 4 (Harden & Release), finished work passes three independent review passes. Each produces pass or fail with concrete findings. A failed guard returns the work to an Implementer worktree — never to ad hoc patches on the integration branch. Principle — pillar 7, Every Change Passes the Guards.

### Clean Code Guard

- **Dead code.** Unreachable functions, commented-out blocks, unused exports, and unused dependencies are removed.
- **Duplication.** Copy-pasted logic collapses into a single definition.
- **Naming.** Names state intent, follow one vocabulary drawn from the specification, and require no decoder ring.
- **Complexity.** Functions stay short, branching depth stays shallow, and no function accumulates unconditional complexity.
- **Abstraction fit.** Judged against ponytail radical minimalism: the smallest abstraction that works, no speculative features, no layers justified by someday. A construct that earns its place only hypothetically is cut.

### Test Guard

- **New behavior covered.** Every specification requirement maps to at least one test, and the red-green-refactor history shows tests were written first. Principle — pillar 2, Tests Are the Contract.
- **Assertions meaningful.** Tests assert observable outcomes, not implementation internals. Assertion-free smoke tests do not count as coverage.
- **No flaky tests.** Tests are deterministic: fixed clocks, seeded randomness, no network or wall-time dependence. A test that fails intermittently fails the gate.
- **Tests read as specification.** Names describe behavior, structure follows arrange-act-assert, and a reader can reconstruct the requirements from the suite alone.

### Docs Guard

- **Docs match behavior.** README, docs/, and inline references describe what the code does now — pillar 8, Documentation Is a Deliverable.
- **Cross-links resolve.** Every relative link and referenced file path exists in the repository.
- **Changelog updated.** Every user-visible change has an entry in CHANGELOG.md.
- **README quick start still true.** The documented install, run, and test commands execute verbatim on a clean checkout.

## Gate Wiring

Each lifecycle phase exits only through its gates. Specification Before Code makes phase 2 approval a gate, not a formality. The Guide signs off every phase exit; the Leader holds final accountability for the release decision.

| Phase | Gates | Sign-off |
| --- | --- | --- |
| 1. Discover & Launch | Preflight system-doctor check of environment and deployment path; 16-file canonical scaffold present and complete | Guide |
| 2. Architect & Guide | Specification and architecture review approved; plan approved; injected toolkit and skill set validated against the phase | Guide |
| 3. Implement & Verify | TDD micro-cycle evidence per concern (red, green, refactor); worktree isolation intact; circuit breaker clean — no open strikes | Guide |
| 4. Harden & Release | Clean Code Guard, Test Guard, and Docs Guard passed; secret scan clean; release package verified | Guide (Leader accountable for the release decision) |

A gate that cannot be evaluated is a failed gate, not a skipped one.

## Safety Invariants

Three invariants hold in every phase, in every archetype — Software Engineering, AI/ML, Business Automation, Deep Research — and in every project.

### Zero Secret Leaks

- Secrets live in environment variables or a secret manager, never in the repository. `.env.example` carries placeholder keys only.
- Secret scanning runs during phase 4 hardening through the `preflight-system-doctor` skill's credential scan of tracked files. A dirty scan fails its gate and blocks the release.
- A leaked credential is treated as compromised regardless of exposure duration: revoke or rotate first, then remove it from history. Deleting the text without rotating the credential is not remediation.

### Destructive-Command Policy

Agents run destructive commands only when all three conditions hold:

- **Scoped.** The target is the agent's own worktree or an explicitly named path inside the project. Never the shared integration checkout, never anything outside the project root.
- **Reversible-first.** Prefer operations git can undo. Force pushes, history rewrites, recursive deletions, and schema or data drops require Guide approval recorded before execution.
- **Non-production.** Destructive actions never touch deployed environments or shared infrastructure from an agent session.

### Escalation Ladder

Problems travel up exactly one level at a time; resolutions travel back down carrying authority.

```text
Implementer ---> Guide : ambiguity, guard disputes, hypothesis-change requests
Guide ---------> Leader: scope, sequencing, resources, circuit-breaker HALTs
```

- **Implementer to Guide:** specification ambiguity, architecture questions, disputed guard findings, and requests to change a hypothesis under the circuit breaker.
- **Guide to Leader:** scope or sequencing decisions, cross-task conflicts the Guide cannot arbitrate within the plan, resource and tooling gaps, and every circuit-breaker HALT — the DIR is delivered to both.
- Skipping a level hides information. Escalations carry evidence, not blame.
