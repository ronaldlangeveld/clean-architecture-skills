# Clean Architecture Skills

Agent Skills for AI-assisted software development using **Clean Architecture** principles by Robert C. Martin (Uncle Bob).

These skills teach Claude Code (and any compliant AI agent) to build software where the business rules are front and centre, the infrastructure is a swappable detail, and any developer can understand what the system does by glancing at the folder structure.

## Why this exists

When you ask an AI agent to build an app, it needs architectural guidance — otherwise you get framework-coupled spaghetti where business logic hides inside controllers, entities double as ORM models, and testing requires spinning up a database.

These skills solve that. They give the agent a prescriptive, opinionated playbook so every project it helps you build follows the same principled structure — regardless of language, framework, or database.

## Skills

| Skill | Version | Summary |
|-------|---------|---------|
| [clean-architecture](skills/clean-architecture/SKILL.md) | 1.0.0 | Dependency rule, layered folder structure, entities, use cases, adapters, infrastructure, and TDD workflow. |

See [`VERSIONS.md`](VERSIONS.md) for the full version history.

## Install

### Claude Code (as a plugin)

Clone this repo, then reference it from your Claude Code config as a local marketplace:

```bash
git clone https://github.com/ronaldlangeveld/clean-arch-skills.git
```

Then in Claude Code, add the local plugin pointing at this repo. The `.claude-plugin/marketplace.json` manifest registers every skill under `skills/`.

### Any Claude Code project (drop-in)

Copy the skills directory into your project:

```bash
cp -r clean-arch-skills/skills/clean-architecture /path/to/your/project/.claude/skills/
```

### Other AI agents

The skills conform to the [Agent Skills specification](https://agentskills.io/specification.md). Install under `.agents/skills/` (cross-agent) or the agent-specific skills directory.

## Manual trigger

If the agent doesn't pick up the skill automatically, reference it directly:

> "Follow the clean-architecture skill to scaffold this project."
>
> "Use the clean architecture patterns from the skill when adding this feature."

## The dependency rule

This is the one rule everything else follows:

**Source code dependencies must point inward only.** Nothing in an inner circle can know anything about something in an outer circle.

```
┌───────────────────────────────────────────────┐
│  Infrastructure (DB, Web, External APIs)      │
│  ┌─────────────────────────────────────────┐  │
│  │  Adapters (Controllers, Gateways)       │  │
│  │  ┌─────────────────────────────────┐    │  │
│  │  │  Application (Use Cases)        │    │  │
│  │  │  ┌─────────────────────────┐    │    │  │
│  │  │  │  Domain (Entities)      │    │    │  │
│  │  │  └─────────────────────────┘    │    │  │
│  │  └─────────────────────────────────┘    │  │
│  └─────────────────────────────────────────┘  │
└───────────────────────────────────────────────┘

Dependencies point INWARD →
```

Entities know nothing about use cases. Use cases know nothing about controllers. Controllers know nothing about which database you're using. The database, the web framework, and the UI are plugins.

## The folder structure it prescribes

```
src/
├── domain/
│   ├── entities/              # Enterprise business rules
│   └── value-objects/         # Immutable domain primitives (Email, Money, etc.)
│
├── application/
│   ├── use-cases/             # One file per use case, named by intent
│   ├── interfaces/            # Port definitions (repository, gateway contracts)
│   └── dto/                   # Data Transfer Objects crossing boundaries
│
├── adapters/
│   ├── controllers/           # Inbound: HTTP/CLI → use case
│   ├── presenters/            # Outbound: use case → formatted response
│   └── gateways/              # Outbound: implements repository/service interfaces
│
├── infrastructure/
│   ├── persistence/           # Database implementations
│   ├── web/                   # HTTP server, routing, middleware
│   ├── external/              # Third-party API clients
│   └── config/                # Environment, DI container, app bootstrap
│
└── main.*                     # Composition root — wires everything together
```

Someone looking at `application/use-cases/` should immediately know every operation the system supports. Someone looking at `domain/entities/` should see the core business concepts. The architecture screams what the application *does*, not what framework it uses.

## What each reference doc covers

| Doc | When to read it |
|-----|-----------------|
| [`entities.md`](skills/clean-architecture/references/entities.md) | Creating or modifying domain models |
| [`use-cases.md`](skills/clean-architecture/references/use-cases.md) | Adding a business operation |
| [`repositories.md`](skills/clean-architecture/references/repositories.md) | Working with data access and persistence ports |
| [`adapters.md`](skills/clean-architecture/references/adapters.md) | Connecting use cases to the outside world |
| [`infrastructure.md`](skills/clean-architecture/references/infrastructure.md) | Setting up DB, web server, or external APIs |
| [`tdd.md`](skills/clean-architecture/references/tdd.md) | Writing or structuring tests |
| [`adding-features.md`](skills/clean-architecture/references/adding-features.md) | Extending an existing codebase |
| [`solid.md`](skills/clean-architecture/references/solid.md) | Making design decisions about structure |
| [`boundaries.md`](skills/clean-architecture/references/boundaries.md) | Reasoning about boundary crossings |
| [`component-principles.md`](skills/clean-architecture/references/component-principles.md) | Organising code as the codebase grows |

## Design principles

- **Language agnostic.** Examples use pseudocode. Works with TypeScript, Python, Go, Java, Rust, C#.
- **Framework agnostic.** No opinions on Express vs. Flask vs. Spring. The framework is a detail.
- **Database agnostic.** PostgreSQL, MongoDB, SQLite — the database is a plugin behind a repository interface.
- **TDD built in.** Every feature starts with a failing test. Entity tests need no mocks; use case tests use in-memory fakes; integration tests hit real infrastructure.
- **Prescriptive.** Exact folder structure, naming conventions, and file organisation. No ambiguity.

## Validation

Validate the repository locally:

```bash
./validate-skills.sh
```

CI runs the same script on every PR that touches a `SKILL.md`.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The bar for changes: does this make it easier for a developer (working with an AI agent) to build well-structured software? If yes, it belongs.

## Licence

[MIT](LICENSE)

## Acknowledgements

Based on the work of Robert C. Martin (Uncle Bob), particularly *Clean Architecture: A Craftsman's Guide to Software Structure and Design* (2017). These skills distil those principles into an actionable, agent-friendly format.
