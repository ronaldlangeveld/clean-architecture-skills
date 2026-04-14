# New skill

## Summary

<!-- What does this skill do? When should an agent trigger it? -->

## Checklist

- [ ] `skills/<name>/SKILL.md` exists with valid frontmatter (`name`, `description`, `metadata.version`).
- [ ] `name` matches the directory name and follows naming rules (lowercase, hyphens only).
- [ ] `description` includes explicit trigger phrases and scope boundaries.
- [ ] `SKILL.md` body is under 500 lines. Long-form material is in `references/`.
- [ ] Examples are pseudocode or language-agnostic.
- [ ] `evals/evals.json` exists with at least 5 realistic prompts and assertion arrays.
- [ ] Entry added to `VERSIONS.md`.
- [ ] Entry added to `.claude-plugin/marketplace.json`.
- [ ] `validate-skills.sh` passes locally.
