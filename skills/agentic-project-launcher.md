---
name: agentic-project-launcher
description: Bootstraps a greenfield project through Socratic discovery and the canonical 16-file scaffold, and should be used at the start of the Discover & Launch phase of any new project.
---

# Agentic Project Launcher

## Purpose

Turns an unstructured mission statement into a validated specification baseline and materializes the 16-file canonical scaffold. It enforces the pillar Specification Before Code: nothing is implemented until discovery answers are captured and the deployment path is fixed.

## When to Use

- At the start of phase 1 (Discover & Launch) for any new project under one of the four archetypes: Software Engineering, AI/ML, Business Automation, or Deep Research.
- When an existing repository is missing parts of the 16-file scaffold and must be completed without overwriting anything.
- Not for day-to-day implementation work; hand off to phase 2 (Architect & Guide) once the scaffold exists.

## Inputs

- A mission statement from the user (one or two sentences suffice).
- A target directory for the new project.
- Optional: archetype preference, known technology stack, known deployment path.

## Procedure

1. **Frame the engagement.** Confirm the target directory, detect whether it already contains a git repository, and propose the closest archetype (Software Engineering, AI/ML, Business Automation, Deep Research). State up front that every answer is written into docs/00-VISION.md, docs/01-ARCHITECTURE.md, or docs/03-DECISIONS.md.

2. **Run Socratic discovery.** Ask the six questions below ONE at a time. Never batch them. After each answer, restate it in one line, then move on.

   1. **What problem does this project solve, for whom?**
      - Why it matters: it names the customer and the pain; every later decision is judged against it.
      - A good answer unlocks: the mission one-liner in docs/00-VISION.md and the rejection filter for backlog items.
   2. **What does success look like in 90 days (measurable)?**
      - Why it matters: it converts intent into a falsifiable target the Guide can gate releases against.
      - A good answer unlocks: the success-metrics section of docs/00-VISION.md and the release criteria used in Harden & Release.
   3. **What are the hard constraints (deadline, budget, compliance, team skills)?**
      - Why it matters: constraints eliminate entire architectures before any design effort is spent.
      - A good answer unlocks: non-negotiable invariants in CLAUDE.md and the first entries in docs/03-DECISIONS.md.
   4. **What is the technology stack and what must NOT change?**
      - Why it matters: it separates replaceable choices from frozen ones; frozen choices become architecture boundaries.
      - A good answer unlocks: the stack table in docs/01-ARCHITECTURE.md and the toolchain defaults for the Makefile.
   5. **Who are the users and what is the primary user journey?**
      - Why it matters: the journey is the backbone of the initial backlog and of the end-to-end test plan.
      - A good answer unlocks: seeded items in docs/02-BACKLOG.md and scenarios in docs/05-TEST-PLAN.md.
   6. **What is the maintenance model after launch?**
      - Why it matters: it sets documentation depth, observability requirements, and handover expectations.
      - A good answer unlocks: the outline of docs/04-RUNBOOK.md and the support section of README.md.

3. **Complete the mandatory deployment-path check.** Ask where this will run (serverless, containers, VM/on-prem, edge) and what CI/CD target exists (GitHub Actions, GitLab CI, none, other). This MUST be answered before scaffolding: the answer decides the Makefile targets and the jobs generated in .github/workflows/ci.yml.

4. **Confirm the brief.** Present a one-screen summary (problem, success metric, constraints, stack, users, journey, maintenance, deployment path) and scaffold only after explicit confirmation.

5. **Create the repository and the 16-file scaffold.** Initialize a new git repository on branch `main`, then create exactly the 16 canonical files, in this order, each with purposeful starter content:

   | # | File | Starter content |
   |---|------|-----------------|
   | 01 | `CLAUDE.md` | Project invariants, the Leader/Guide/Implementer role split, and session rules. |
   | 02 | `README.md` | Project name, tagline, quickstart commands, and license note. |
   | 03 | `.gitignore` | Stack-appropriate ignores plus `.env`, build output, and OS artifacts. |
   | 04 | `.env.example` | Every required variable with obvious placeholder values, never real secrets. |
   | 05 | `LICENSE` | MIT text with the project copyright line. |
   | 06 | `CONTRIBUTING.md` | Branching, commit style, test expectations, and pull-request checklist. |
   | 07 | `CHANGELOG.md` | Keep-a-Changelog structure with an Unreleased section. |
   | 08 | `docs/00-VISION.md` | Problem, audience, mission one-liner, and the 90-day success metric. |
   | 09 | `docs/01-ARCHITECTURE.md` | Components, data flow, and the stack table from discovery. |
   | 10 | `docs/02-BACKLOG.md` | Prioritized initial items derived from the primary user journey. |
   | 11 | `docs/03-DECISIONS.md` | Decision log opened with the stack and deployment-path choices. |
   | 12 | `docs/04-RUNBOOK.md` | Local setup, build, test, run, and deploy commands for the chosen path. |
   | 13 | `docs/05-TEST-PLAN.md` | Test strategy honoring Tests Are the Contract, mapped to the user journey. |
   | 14 | `SECURITY.md` | Vulnerability reporting contact and supported versions. |
   | 15 | `Makefile` | Targets matched to the deployment path: build, test, lint, run or deploy. |
   | 16 | `.github/workflows/ci.yml` | CI jobs matched to the declared CI/CD target. |

6. **Commit the scaffold** so the baseline is reproducible:

   ```bash
   git init -b main
   git add .
   git commit -m "chore: scaffold the 16 canonical project files"
   ```

7. **Mirror for stakeholders (Business Automation only).** For the Business Automation archetype, optionally mirror the scaffold to a Google Drive folder for stakeholder visibility. Skip this for the other three archetypes unless explicitly requested.

8. **Hand off.** Report what was created and pass control to phase 2 (Architect & Guide), where the Guide reviews the specification and Orca ADE injects the toolkit and skills the phase needs (CLAUDE_TOOLKIT_DIR).

## Outputs

- A git repository on `main` containing exactly the 16 canonical scaffold files (or, in an existing repository, only the previously missing ones).
- A recorded discovery brief spread across docs/00-VISION.md, docs/01-ARCHITECTURE.md, and docs/03-DECISIONS.md.
- Deployment-path-driven defaults baked into the Makefile and .github/workflows/ci.yml.
- A handoff summary naming the confirmed archetype and the entry point for Architect & Guide.

## Failure Modes

- User answers vaguely: re-ask the same question with forced-choice options (offer three or four concrete candidate answers); never silently invent an answer on the user's behalf.
- Deployment path unknown: default to containers plus a minimal CI stub job (lint and test), record the assumption in docs/03-DECISIONS.md, and flag it prominently in the handoff summary.
- Existing repository detected: scaffold only the missing files, never overwrite existing content, and report created versus skipped files.
- Discovery stalls on the 90-day metric: record the open question in docs/02-BACKLOG.md and continue with the remaining questions instead of blocking the launch.
