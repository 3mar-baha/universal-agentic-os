---
name: session-context-primer
description: Rebuilds essential working context at session start in about ten seconds by loading invariants, the docs index, git state, and circuit-breaker status, and should be used whenever a session begins or context is lost.
---

# Session Context Primer

## Purpose

Operationalizes Prime Context Before Action at startup. Within a strict ~10-second budget it loads the minimum state every role needs (mission, lifecycle phase, worktree pool, next backlog item, guard status) and emits a single CONTEXT ANCHOR block that anchors the rest of the session.

## When to Use

- As the first action of any session in a project scaffolded by this framework.
- Immediately after a context reset, conversation compaction, or `/clear`.
- Before resuming work in an existing git worktree.

## Inputs

- The project root, expected to contain CLAUDE.md and the docs set from the 16-file scaffold.
- Read access to git metadata (status, branch, recent commits).

## Procedure

Read in strict order. The timebox rule in step 6 overrides everything else.

1. **Read CLAUDE.md invariants.** Load the invariants section only: role boundaries, non-negotiable rules, and any frozen stack decisions.

2. **Read the docs index.** Load docs/00-VISION.md (mission), skim docs/01-ARCHITECTURE.md (system shape), and read the top items of docs/02-BACKLOG.md (what comes next).

3. **Read git state.** Current branch, short status, and the last five commits:

   ```bash
   git status --short --branch
   git log --oneline -5
   ```

4. **Read circuit-breaker state, if any.** If the circuit-breaker-guard skill has recorded strikes or emitted a Diagnostic Incident Report (DIR), load its current state: strike count, halted phase, and the hypothesis the Guide approved. Otherwise record zero strikes.

5. **Emit the CONTEXT ANCHOR.** Output exactly one fenced block and nothing else:

   ```text
   CONTEXT ANCHOR
   ----------------------------------------------------------
   Mission  : <one-liner from docs/00-VISION.md>
   Phase    : <current phase of the 4-phase lifecycle>
   Branch   : <branch> (<clean|N files changed>)
   Worktrees: <active Implementer worktrees, or "none">
   Next     : <top backlog item id and title>
   Guards   : Clean Code Guard <pending|passed> | Test Guard <pending|passed> | Docs Guard <pending|passed>
   Circuit  : <n> strike(s) <or "DIR open">
   ----------------------------------------------------------
   ```

   A filled anchor looks like this:

   ```text
   CONTEXT ANCHOR
   ----------------------------------------------------------
   Mission  : Invoice extraction API for the finance team
   Phase    : 3. Implement & Verify
   Branch   : feat/pdf-ingestion (clean)
   Worktrees: wt-invoice-parse (active), wt-pdf-export (idle)
   Next     : B-014 Add retry with backoff on provider timeout
   Guards   : Clean Code Guard pending | Test Guard pending | Docs Guard pending
   Circuit  : 0 strikes
   ----------------------------------------------------------
   ```

6. **Respect the hard rule.** If priming exceeds roughly 10 seconds worth of reads (very large files, slow storage, many worktrees), stop reading immediately and emit the anchor from whatever is loaded, marking unloaded slots as `unknown`. An approximate anchor now beats a perfect anchor late.

## Outputs

- Exactly one CONTEXT ANCHOR block in the session transcript (about nine lines).
- Nothing written to disk; the primer is strictly read-only.

## Failure Modes

- Missing docs: anchor from git state alone (branch, recent commits, dirty files) and flag the gap explicitly, for example `Docs unavailable - anchored from git state`.
- Oversized CLAUDE.md: read only the invariants section (locate it by heading) instead of streaming the whole file into context.
- Timebox exceeded: stop mid-sequence, emit the partial anchor, and mark unread slots `unknown` rather than finishing the read sequence.
- No git repository: anchor from CLAUDE.md and the docs index only, and flag the missing VCS state.
- Dirty tree or detached HEAD: surface the condition verbatim in the anchor instead of resolving it silently; resolution belongs to the Leader.
