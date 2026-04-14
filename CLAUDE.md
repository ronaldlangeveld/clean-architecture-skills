# CLAUDE.md

Instructions for Claude Code and any other AI agent working in this repository. `AGENTS.md` is a mirror of this file — keep them in sync.

## Repository overview

This repo publishes a set of Agent Skills for AI-assisted software development using **Clean Architecture** principles by Robert C. Martin (Uncle Bob). Each skill is self-contained under `skills/<name>/` and conforms to the [Agent Skills specification](https://agentskills.io/specification.md).

```
clean-arch-skills/
├── .claude-plugin/
│   └── marketplace.json          # Claude Code plugin manifest
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── PULL_REQUEST_TEMPLATE/
│   └── workflows/
│       └── validate-skill.yml    # CI validation for skills
├── skills/
│   └── clean-architecture/
│       ├── SKILL.md              # Entry point — dependency rule + structure
│       ├── evals/
│       │   └── evals.json        # Behavioural tests for this skill
│       └── references/           # Deep-dive reference docs (loaded on demand)
├── AGENTS.md                     # Mirror of CLAUDE.md
├── CLAUDE.md                     # This file
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── VERSIONS.md                   # Version table for all skills
└── validate-skills.sh            # Local validation script
```

## How to use the skills

When an agent is working on a software project:

1. Match the user's intent to a skill under `skills/<name>/SKILL.md` (currently only `clean-architecture`).
2. Read the `SKILL.md` first. It always contains the core rule, structure, and links to the reference docs.
3. Load reference docs from `references/` *on demand* — do not preload them all. Each reference doc is self-contained for its topic.

For Clean Architecture specifically, the dependency rule is the single non-negotiable principle: **source code dependencies point inward only**. Everything else in the skill serves this rule.

## Agent Skills specification (summary)

- Each skill lives in its own directory under `skills/`.
- The directory name must match the `name` field in `SKILL.md`'s frontmatter.
- `SKILL.md` frontmatter is YAML with required fields `name` and `description`, and an optional `metadata.version`.
- `name`: lowercase letters, digits, and hyphens only. 1–64 chars. No leading/trailing/consecutive hyphens.
- `description`: 1–1024 chars. Must contain explicit trigger phrases ("Trigger when...", "Use when the user says...") and scope boundaries to related skills.
- `SKILL.md` body should stay under 500 lines. Long-form material belongs in `references/`.
- Optional directories: `references/` (markdown reference docs), `evals/` (behavioural tests as `evals.json`), `scripts/`, `assets/`.

## Writing style guidelines

- **Prescriptive.** Tell the agent what to do, not what it *could* do.
- **Structured.** Headings, lists, code blocks. The reader (human or AI) should scan and land.
- **Concrete.** Show the pattern, then explain why it works.
- **Pseudocode, not code.** Examples must be language- and framework-agnostic unless the skill is explicitly language-scoped.
- **Name what things are, not what they do.** `CreateOrder` not `OrderService`. `OrderRepository` not `OrderDB`.
- Short sentences. No filler. British or American English — pick one per doc and stay consistent.

## Version management

- Every change to a skill's content requires bumping `metadata.version` in its `SKILL.md` frontmatter and updating `VERSIONS.md`.
- Versioning follows semver:
  - **Major** — breaking changes to folder structure or naming conventions.
  - **Minor** — new reference docs or expanded guidance.
  - **Patch** — wording, typos, example tweaks.
- Agents can compare `VERSIONS.md` in this repo against the user's local copy to prompt for updates.

## Validation

Run `./validate-skills.sh` locally before committing. The script verifies:

- `SKILL.md` exists for every directory under `skills/`.
- Frontmatter has required fields (`name`, `description`) and `metadata.version`.
- `name` matches the directory and follows naming rules.
- `description` length is within 1–1024 chars.
- `SKILL.md` body is under 500 lines.

CI runs the same script via `.github/workflows/validate-skill.yml` on any PR that touches a `SKILL.md`.

## Git workflow

- Branch naming: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
- Commit messages describe *why*, not just *what*. One concern per commit.
- Never force-push to `main`. Never skip hooks.
- Every PR uses one of the templates under `.github/PULL_REQUEST_TEMPLATE/` (new skill, skill update, documentation).

## Plugin distribution

This repo is installable as a Claude Code plugin via `.claude-plugin/marketplace.json`. When adding a new skill, add its path (e.g. `./skills/<new-skill>`) to the `plugins[0].skills` array in that file.
