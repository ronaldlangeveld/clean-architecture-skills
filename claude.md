# Clean Architecture Skills

This project contains Claude skills that guide building software using Clean Architecture principles by Robert C. Martin (Uncle Bob).

## How to use

When building any application in this project, follow the Clean Architecture skill located at `.claude/skills/clean-architecture/SKILL.md`. Read it before scaffolding a new project or adding features to an existing one.

## Key rules

- All source code dependencies point inward. Inner layers never depend on outer layers.
- The prescribed folder structure under `src/` must be followed: `domain/`, `application/`, `adapters/`, `infrastructure/`.
- Use cases are named by intent (e.g., `CreateOrder`, not `OrderService`).
- Entities are pure business logic with no framework or database dependencies.
- The database, web framework, and UI are details — implemented in the infrastructure layer behind port interfaces.
- Follow TDD: write a failing test first, make it pass, then refactor. Entity tests need no mocks. Use case tests use fakes for ports.

## When to read reference docs

The main skill points to reference docs in `.claude/skills/clean-architecture/references/`. Read the relevant one based on what you're doing:

- Creating or modifying domain models → `entities.md`
- Adding a business operation → `use-cases.md`
- Designing repository ports or implementing data access → `repositories.md`
- Connecting use cases to HTTP, CLI, or other inputs → `adapters.md`
- Implementing persistence, external APIs, or framework setup → `infrastructure.md`
- Writing or structuring tests → `tdd.md`
- Adding a feature to an existing codebase → `adding-features.md`
- Making design decisions about structure and dependencies → `solid.md`
- Understanding boundary crossings and testability → `boundaries.md`
- Organising code into components as the codebase grows → `component-principles.md`

## Principles

- Language agnostic, framework agnostic, database agnostic.
- The codebase should scream what it does, not what tools it uses.
- Entities and use cases are the heart of the system. Everything else is a plugin.
