# Skill Versions

Track the current published version of each skill. Agents compare this table against their local copies to decide whether to prompt for updates.

| Skill | Version | Last Updated | Summary |
|-------|---------|--------------|---------|
| [clean-architecture](skills/clean-architecture/SKILL.md) | 1.0.0 | 2026-04-15 | Clean Architecture by Robert C. Martin — dependency rule, layered structure, entities, use cases, adapters, infrastructure, TDD. |

## Versioning rules

- **Major** — breaking changes to folder structure, naming conventions, or required files that existing projects would need to migrate.
- **Minor** — new reference docs, new guidance sections, or expanded coverage that doesn't conflict with prior usage.
- **Patch** — clarifications, typo fixes, example tweaks, and wording improvements.

When updating a skill, bump the version in both the skill's `SKILL.md` frontmatter (`metadata.version`) and this table.
