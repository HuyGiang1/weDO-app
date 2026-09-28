# weDO Agent Operating & Handoff Protocol

This repository is shared across multiple coding agents (such as Codex and Antigravity). The repository itself is the shared source of context so any agent starting with zero prior chat history can safely inspect and continue the active milestone.

## 1. Mandatory Startup Reading Order

Before planning, running build/deploy actions, or editing any file, every agent **MUST** read in this exact order:

1. `.agents/skills/wedo-milestone-delivery/SKILL.md` — Standard delivery workflow, verification ladder, and safety gates.
2. `docs/AGENT_PROJECT_CONTEXT.md` — **STATIC** long-lived architecture, stack, domain rules, conventions, and M0–M19 roadmap.
3. `docs/AGENT_CURRENT_HANDOFF.md` — **DYNAMIC** snapshot of the active branch, unfinished worktree state, test status, and exact next actions.
4. `docs/AGENT_DECISION_LOG.md` — **APPEND-ONLY / STABLE DECISIONS** log of architectural and product rulings across milestones.

## 2. Mandatory Pre-Edit Git Inspection

Immediately after reading the handoff files and before editing anything, inspect the live worktree:

```powershell
git branch --show-current
git status --short
git diff --stat
git stash list
```

*(Optional read-only helper: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent-handoff.ps1`)*

## 3. Authority & Drift Prevention Rules

- **Unfinished Work Authority**: The **current git worktree** (`git status`, `git diff`, and untracked milestone directories) is authoritative for unfinished in-progress work. If `docs/AGENT_CURRENT_HANDOFF.md` lags behind actual code or runtime state, the actual repository/runtime state wins.
- **Product / API / DB Authority**: The canonical documents (`docs/BA_CONSOLIDATED_SPECIFICATION_v1.0.md`, `docs/API_CONTRACT_BACKEND_IMPLEMENTATION_BLUEPRINT_v1.0.md`, `docs/ERD_DATABASE_DESIGN_v1.0.md`, `docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md`, `docs/architecture/CLASS_DIAGRAM.puml`, and `docs/LOCAL_DEVELOPMENT.md`) plus Flyway migrations (`V1`..`V12`+) are authoritative for product behavior, API contracts, and database schema. Do not duplicate whole canonical docs into agent handoff files.
- **Document Separation**:
  - `docs/AGENT_PROJECT_CONTEXT.md` = **STATIC** (long-lived architecture and rules; no volatile task notes or test counts).
  - `docs/AGENT_CURRENT_HANDOFF.md` = **DYNAMIC** (current branch, uncommitted changes, verification status, and immediate next steps).
  - `docs/AGENT_DECISION_LOG.md` = **APPEND-ONLY / STABLE DECISIONS** (locked product/technical rulings with ID, milestone, reason, and consequences).

## 4. Strict Git, Local-File & Approval Guardrails

- **No Destructive Git Commands**: Never run `git reset`, `git clean`, `git restore`, `git checkout -- <file>`, `git stash drop`, `git stash pop`, or `git commit --amend` unless explicitly authorized by the user for that exact target.
- **Preserve Protected Stash & Local Files**: Keep `stash@{0}` (`On dev: codex-m7-foundation-pre-m6-sync`), `docs/LEARNING_HANDBOOK_M0_M2.md`, `docs/M8_STITCH_FIDELITY_INVENTORY.md`, `.stitch/`, `.dev-runtime/`, and `.dev-logs/` completely untouched and out of commits.
- **Commit Requires Explicit User Approval**: Never stage or commit changes without explicit user authorization.
- **Push Requires Separate Explicit User Approval**: Approval to commit is **never** approval to push. Always wait for separate explicit push authorization.
- **Mandatory Handoff Update**: Before ending a session or handing work to another agent, update `docs/AGENT_CURRENT_HANDOFF.md` so the next agent inherits an accurate, verified worktree summary.
