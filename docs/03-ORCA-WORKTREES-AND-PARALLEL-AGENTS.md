# Orca Worktrees & Parallel Agents

Orca — ORchestrated Cooperative Agents — is the runtime layer of the Universal Agentic Engineering OS. It owns session bootstrap, dynamic tool and skill injection per lifecycle phase, and the git-worktree pool in which parallel Implementers execute. This guide specifies why that pool exists, the protocol every agent follows inside it, the rules for contested files, the sanctioned fan-out patterns, and the full lifecycle of a worktree.

Audience: Leaders routing tasks, Guides arbitrating merges, Implementers working inside the pool. Companion reading: docs/02-TOOLKIT-AND-ORCA-GUIDE.md covers injection and pruning; docs/06-ENGINEERING-PILLARS.md lists the principles cited here.

## Why Isolation

Parallel Implementers mutating one working tree destroy each other's progress: interleaved half-finished edits, races over lockfiles, builds that mix incompatible changes, and diffs nobody can attribute. Isolation removes this entire class of failure. Each Implementer receives an independent checkout backed by its own branch, while git shares the underlying object database across worktrees — so parallelism costs almost nothing in disk space or setup time.

Operating principle — pillar 4, Isolate to Parallelize: if two tasks cannot proceed without touching the same files, they are not parallel tasks. Split them or serialize them.

```text
                          integration (main)
                                 ^
          merges land in completion order; Guide arbitrates conflicts
                                 |
     +------------------+--------+--------+------------------+
     |                  |                 |                  |
 orca/add-auth    orca/fix-ratelimit  orca/gen-clients  orca/bench-io
  worktree A         worktree B         worktree C        worktree D
 (Implementer 1)   (Implementer 2)    (Implementer 3)   (Implementer 4)
```

## Per-Agent Worktree Protocol

Orca creates and tears down worktrees. Agents never improvise their own topology. Five rules govern conduct inside the pool:

1. **Create from the integration branch with a fresh base.** Fork at the current tip of the integration branch so the diff under review stays minimal and the eventual merge is a clean candidate.
2. **Name the branch `orca/<task-slug>`.** The slug is kebab-case, derived from the Leader's task identifier. One glance at the branch name tells you which task lives in the tree.

   ```text
   orca/user-token-refresh        correct: one task, kebab-case slug
   orca/fixes-and-doc-updates     wrong: multiple concerns, vague slug
   ```

3. **One concern per worktree.** A worktree exists to answer exactly one routed task. Adjacent defects discovered along the way become new tasks for the Leader to route — never side quests inside someone else's tree. This restates the tripartite contract: the Implementer executes one TDD concern; the Leader owns decomposition and routing.
4. **Commit early and often.** Small commits at every green test. Uncommitted work is unprotected work; the rebase and merge steps assume a clean, granular history.
5. **Merge order equals completion order.** The first worktree whose concern verifies merges first; later worktrees rebase onto the result. When two completed concerns conflict, the Guide arbitrates. Agents never resolve disputes by force-pushing over one another.

## Collision Rules

Some files attract concurrent edits no matter how cleanly tasks are partitioned. They are single-owner files: exactly one designated editor, the Integrator, may modify them; every other agent consumes them read-only and routes required changes through the Leader.

| Contested file | Why it collides | Rule |
| --- | --- | --- |
| `package.json` | Every dependency-adjacent task appends entries; concurrent edits guarantee textual conflict | Single-owner file. Other agents declare required dependencies in their task notes; the Integrator applies them during merge. |
| Lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `uv.lock`, `poetry.lock`) | Machine-generated from the manifest; two agents regenerating produce irreconcilable histories | Single-owner file. Never hand-edit. The Integrator regenerates once after the final manifest merge; everyone else consumes. |
| `CHANGELOG.md` | Every task prepends its entry at the top; simultaneous edits conflict constantly | Single-owner file. Agents submit entries with their merge; the Integrator orders them for the release. |
| Generated code (OpenAPI clients, protobuf outputs, migration artifacts, build output) | Hand edits are overwritten on the next generation and hide the true source of truth | Never edit generated output in any worktree. Change the generator input, then regenerate after merge. |

One rule sits above the table: **never share mutable state outside git.** No shared scratch directories, no coordination through running services, no side-channel file copies between worktrees. Git is the only transport between agents.

## Fan-Out Patterns

Three patterns are sanctioned. Any other fan-out shape requires Guide approval before launch.

### Map-Reduce Review

N reviewers examine the change independently and each produces findings; one synthesizer deduplicates, ranks, and emits a single report. Use it for review-shaped work: guard preparation, security review, and specification conformance checks.

Reviewers do not communicate during the map stage. The synthesizer merges and ranks findings; disagreements that survive the evidence escalate to the Guide.

```text
                 change under review
                         |
      +-----------+------+------+-----------+
      v           v             v           v
  reviewer 1  reviewer 2  ...  reviewer N      map: independent passes
      |           |             |           |
      +-----------+------+------+-----------+
                         v
                   synthesizer                  reduce: one ranked report
```

### Domain-Partition Implementation

The default fan-out for phase 3 (Implement & Verify). The Leader partitions the mission along existing architectural seams — modules, packages, bounded contexts — and assigns exactly one partition per Implementer worktree. Interfaces shared between partitions are specified first, in phase 2 (Architect & Guide), so the partitions compose without negotiation at merge time.

### Pipeline Pattern

For work that is sequential between stages but parallelizable inside each stage:

```text
stage 1  schema migration        [Implementer x1]  -> merge
stage 2  consumer updates        [Implementer x3]  -> rebase, merge
stage 3  documentation, release  [Implementer x1]
```

Stage k+1 consumes stage k's merged output. Parallelism lives within a stage; ordering between stages is enforced by the Leader's sequencing.

### When Not to Parallelize

Do not fan out when independence cannot be established:

- **Shared-schema migrations.** A migration touches definitions consumed everywhere. Run it as a single serialized concern ahead of its dependents.
- **Sequential refactors.** Step n+1 depends on the exact result of step n — staged renames, incremental type tightening, layered extraction. Parallel attempts manufacture conflicts, not speed.

Rule of thumb: if you cannot name the interface that keeps two tasks independent, they are one task.

## Lifecycle of a Worktree

Five states: create, work, rebase, merge, remove.

The create → merge → remove cycle is automated by the OS itself: `uos dispatch <stream>` provisions a worktree at `.worktrees/<stream>` with the phase context kit pre-injected, and `uos merge <stream>` gates the stream's diff before a `--no-ff` integration and prunes the tree afterwards (see `scripts/dispatch-worktrees.sh`, `scripts/merge-worktrees.sh`). The manual sequence below documents what those scripts perform.

```bash
# 1. CREATE — fork from the tip of the integration branch
git fetch origin
git worktree add -b orca/user-token-refresh ../proj-orca-token origin/integration

# 2. WORK — implement the single concern; commit early and often
cd ../proj-orca-token
#    red -> green -> refactor, repeated until the concern verifies
git add -A && git commit -m "feat(auth): rotate refresh tokens on reuse"

# 3. REBASE — replay onto the moved integration branch before merging
git fetch origin
git rebase origin/integration

# 4. MERGE — completion order; the Guide arbitrates any conflict
cd /path/to/integration-checkout
git merge --no-ff orca/user-token-refresh

# 5. REMOVE — retire the worktree once merged and signed off
git worktree remove ../proj-orca-token
git branch -d orca/user-token-refresh
git worktree prune
```

Run `git worktree list` at any moment to see the state of the pool.

### Cleanup Policy

- **Remove on acceptance.** A worktree is removed immediately after its branch merges and the Guide signs off the phase exit.
- **Nothing unsaved.** Before removal, all work is committed and merged, or explicitly abandoned by the Leader. Never delete a worktree carrying uncommitted changes.
- **Daily prune.** Orca prunes stale administrative entries and deletes branches whose worktrees are gone.
- **Escalate stragglers.** A worktree idle past its phase window, or parked mid-circuit-breaker, is reported to the Leader — never silently kept and never silently killed.
