---
name: github-release-packager
description: Generates tiered bilingual project READMEs and governs GitHub releases from changelog-derived release notes through post-release verification.
---

# GitHub Release Packager

## Purpose

Executes the release-facing duties of phase 4, Harden & Release. It generates and upgrades
project READMEs to a defined information tier, optionally mirrored in Arabic, and governs the
GitHub release path end to end: release notes, semantic version checks, tagging, publication
and post-release verification. It enforces Engineering Pillar 8, "Documentation Is a
Deliverable", and Engineering Pillar 10, "Ship With Discipline".

## When to Use

- Creating the README for a project freshly scaffolded by `agentic-project-launcher`.
- Upgrading an existing README to a higher tier before release.
- Producing the Arabic mirror `README.ar.md`.
- Preparing and publishing a tagged GitHub release from a guarded, passing codebase.
- Verifying a release after publication.

## Inputs

- Existing `README.md` (if any) and the target tier: S, M or L.
- `CHANGELOG.md`, which must contain an entry for the pending version in the same change.
- Conventional commits since the last `vX.Y.Z` tag.
- Project facts: tripartite operating model, 4-phase lifecycle, 16-file canonical scaffold,
  6 core skills, 4 multi-domain archetypes, MIT License copyright (c) 2026 Madaar Team.
- Authenticated `gh` CLI and a clean git worktree.

## Procedure

### Part 1 — Multi-Tier README Generation

1. Confirm the target tier with the user or the Guide, then inventory the existing README's
   sections and measure its line count.
2. Generate or upgrade cumulatively: every tier contains the previous tier verbatim plus the
   additions listed in the tier table, in the stated order.
3. Validate the budget constraint for the target tier before finishing.
4. If the bilingual option was requested, produce `README.ar.md` mirroring the English
   structure exactly: identical section order, heading levels and table shapes, with Arabic
   prose. `README.md` remains the primary document.
5. Emoji are permitted only in README files and closing banner sections; render all diagrams
   as fenced ASCII art.

| Tier | Budget | Sections |
| --- | --- | --- |
| S | 60 lines maximum | Badge-lite header, what the project is, quick start, license |
| M | Tier S plus | Architecture diagram (fenced ASCII), 4-phase lifecycle table, docs index linking the 7 documentation guides |
| L | Full | Full badge set, tripartite operating-model diagram, archetype matrix over the 4 multi-domain archetypes, skills table for the 6 core skills, roadmap, acknowledgments |

### Part 2 — Release Governance

6. Check the mandatory preconditions and refuse to proceed if either fails:

   ```
   git status --porcelain                     # must print nothing
   grep -n "<pending-version>" CHANGELOG.md   # must match
   ```

7. Derive release notes by merging the `CHANGELOG.md` entry for the pending version with the
   conventional commits since the last tag:

   ```
   git log "$(git describe --tags --abbrev=0)..HEAD" --pretty=format:"- %s"
   ```

8. Run the semver check: a breaking change (`feat!` or a `BREAKING CHANGE` footer) requires a
   MAJOR bump, new features require MINOR, fixes and chores require PATCH. Compare the result
   against the latest `vX.Y.Z` tag and block on any mismatch.
9. Publish using this checklist:

   ```
   gh auth status                                                # must show a logged-in account
   git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z       # annotated tag, pushed
   gh release create vX.Y.Z --title "vX.Y.Z" --notes-file RELEASE_NOTES.md
   ```

   Attach build artifacts when the project produces them.
10. Post-release verification: confirm badge URLs resolve against live endpoints; run the
    clone-from-scratch test — fresh clone, install per Quick Start, execute the documented
    command; confirm the release page renders the notes.

## Outputs

- `README.md` at the target tier, and `README.ar.md` when the bilingual option is chosen.
- Drafted release notes derived from `CHANGELOG.md` plus conventional commits.
- Annotated tag `vX.Y.Z` pushed to origin, with a published GitHub release and attached
  artifacts.
- Post-release verification report covering badge URLs, fresh-clone behavior and the rendered
  release page.

## Failure Modes

- **Dirty worktree**: refuse to release; instruct the operator to commit or stash and re-run
  from step 6.
- **Unauthenticated `gh` CLI**: emit the exact remediation command `gh auth login`, then
  re-run `gh auth status` before continuing.
- **Missing changelog entry**: block the release and offer to draft the missing entry from
  conventional commits since the last tag, subject to Guide approval before proceeding.
- **Semver mismatch**: a breaking change paired with a non-major bump blocks the release;
  require the correct major bump and an updated `CHANGELOG.md` in the same change.
