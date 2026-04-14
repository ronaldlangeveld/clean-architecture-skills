# Contributing

Contributions are welcome. The goal of this repo is to give AI agents a prescriptive, opinionated playbook for Clean Architecture. Every change should make it easier for a developer working with Claude (or any agent) to build well-structured software.

## Before you start

- Read [`skills/clean-architecture/SKILL.md`](skills/clean-architecture/SKILL.md) and the relevant reference doc.
- Skim [`CLAUDE.md`](CLAUDE.md) for the Agent Skills spec, naming rules, and writing style guidelines.
- Check open issues to see if your idea is already being discussed.

## Ways to contribute

1. **Improve a reference doc.** Clarify wording, add missing patterns, fix mistakes, or strengthen examples.
2. **Add a reference doc.** If there's a concept under-served by the current docs (e.g. event-driven boundaries, CQRS within Clean Architecture), propose a new file under `skills/clean-architecture/references/`.
3. **Add a new skill.** New skills must live under `skills/<name>/` and follow the Agent Skills spec. Include a `SKILL.md`, optional `references/`, and an `evals/evals.json`.
4. **Strengthen the evals.** Real-world prompts that exercise edge cases are welcome in `skills/clean-architecture/evals/evals.json`.
5. **Tooling.** Validation scripts, workflow improvements, marketplace metadata fixes.

## Skill authoring rules

- `SKILL.md` frontmatter must include `name` (lowercase, hyphens only, matches the directory) and a `description` that includes explicit trigger phrases and scope boundaries.
- `SKILL.md` body should stay under 500 lines. Long-form material belongs in `references/`.
- Examples should be pseudocode or language-agnostic. Don't lock the skill to a single framework or language.
- Every claim about structure must align with the Dependency Rule: inner layers never import outer layers.

## Pull request checklist

- [ ] `SKILL.md` frontmatter is valid and version is bumped in both the skill file and `VERSIONS.md` if content changed meaningfully.
- [ ] New or changed reference docs are linked from `SKILL.md`.
- [ ] Examples are pseudocode, not framework-specific.
- [ ] `validate-skills.sh` passes locally.
- [ ] Commit messages describe *why*, not just *what*.

## Style

- British English is fine. American English is also fine. Pick one per doc and stay consistent.
- Short sentences. Concrete examples. No filler.
- Show the pattern, then explain why it works — not the other way round.
