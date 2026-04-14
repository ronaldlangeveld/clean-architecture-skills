# Clean Architecture Skills for Claude

A set of [Claude skills](https://docs.claude.com) that guide AI-assisted software development using **Clean Architecture** principles by Robert C. Martin (Uncle Bob).

These skills teach Claude to build software where the business rules are front and centre, the infrastructure is a swappable detail, and any developer can understand what the system does by glancing at the folder structure.

## Why this exists

When you ask Claude to build an app, it needs architectural guidance — otherwise you get framework-coupled spaghetti where business logic hides inside controllers, entities double as ORM models, and testing requires spinning up a database.

These skills solve that. They give Claude a prescriptive, opinionated playbook for Clean Architecture so that every project it helps you build follows the same principled structure — regardless of language, framework, or database.

## What's inside

```
.claude/
  skills/
    clean-architecture/
      SKILL.md                        # Main entry point — the dependency rule,
                                      # folder structure, and core principles
      references/
        entities.md                   # Domain layer: entities, value objects,
                                      # invariants, aggregates
        use-cases.md                  # Application layer: use case design, ports,
                                      # DTOs, error handling
        repositories.md               # Repository pattern: port design, fakes,
                                      # pagination, contract tests
        adapters.md                   # Interface adapters: controllers, presenters,
                                      # gateways, mapping
        infrastructure.md             # Frameworks & drivers: persistence, web,
                                      # external services, composition root
        tdd.md                        # TDD workflow tailored for Clean Architecture
        adding-features.md            # Step-by-step guide for extending existing
                                      # codebases
        solid.md                      # SOLID principles applied at every layer
        boundaries.md                 # Boundary crossing, control flow vs.
                                      # dependency, Humble Object pattern
        component-principles.md       # Cohesion, coupling, and organising code
                                      # into components
```

## Design principles

**Language agnostic.** All examples use pseudocode. Works with TypeScript, Python, Go, Java, Rust, C# — anything.

**Framework agnostic.** No opinions on Express vs. Flask vs. Spring. The framework is a detail that lives in the outermost layer.

**Database agnostic.** PostgreSQL, MongoDB, SQLite — doesn't matter. The database is a plugin behind a repository interface.

**TDD built in.** Every feature starts with a failing test. Entity tests need no mocks. Use case tests use in-memory fakes. Integration tests hit real infrastructure.

**Highly prescriptive.** Exact folder structure, naming conventions, and file organisation. No ambiguity about where code goes.

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
│   └── config/               # Environment, DI container, app bootstrap
│
└── main.*                     # Composition root — wires everything together
```

The test is simple: someone looking at `application/use-cases/` should immediately know every operation the system supports. Someone looking at `domain/entities/` should see the core business concepts. The architecture screams what the application *does*, not what framework it uses.

## How to use

### With Claude Code

Clone this repo (or copy the `.claude/` directory into your project), then use Claude Code as usual. The skill triggers automatically when you're building apps, adding features, creating entities, writing use cases, or discussing architecture.

```bash
# Copy into your project
cp -r .claude/ /path/to/your/project/.claude/

# Or clone and start a new project here
claude
```

### With Cowork

Select the folder containing these skills when starting a Cowork session. The skill will be available automatically.

### Manual trigger

If Claude doesn't pick up the skill automatically, you can reference it directly:

> "Follow the clean-architecture skill to scaffold this project"

> "Use the clean architecture patterns from the skill when adding this feature"

## The dependency rule

This is the one rule everything else follows:

**Source code dependencies must point inward only.**

Nothing in an inner circle can know anything about something in an outer circle.

```
┌─────────────────────────────────────────────┐
│  Infrastructure (DB, Web, External APIs)     │
│  ┌─────────────────────────────────────┐     │
│  │  Adapters (Controllers, Gateways)   │     │
│  │  ┌─────────────────────────────┐    │     │
│  │  │  Application (Use Cases)    │    │     │
│  │  │  ┌─────────────────────┐    │    │     │
│  │  │  │  Domain (Entities)  │    │    │     │
│  │  │  └─────────────────────┘    │    │     │
│  │  └─────────────────────────────┘    │     │
│  └─────────────────────────────────────┘     │
└─────────────────────────────────────────────┘

Dependencies point INWARD →
```

Entities know nothing about use cases. Use cases know nothing about controllers. Controllers know nothing about which database you're using. The database, the web framework, and the UI are all plugins.

## What each reference doc covers

| Doc | When to read it | What you'll learn |
|-----|----------------|-------------------|
| `entities.md` | Creating or modifying domain models | Entity design, value objects, invariants, aggregates, identity |
| `use-cases.md` | Adding a business operation | Use case anatomy, ports/interfaces, DTOs, error handling |
| `repositories.md` | Working with data access and persistence ports | Port design, query methods, pagination, in-memory fakes, contract tests |
| `adapters.md` | Connecting use cases to the outside world | Controllers, presenters, gateways, data mapping |
| `infrastructure.md` | Setting up DB, web server, or external APIs | Persistence, composition root, configuration, DI |
| `tdd.md` | Writing or structuring tests | Test strategy per layer, fakes vs. mocks, test data builders |
| `adding-features.md` | Extending an existing codebase | Inside-out workflow, refactoring patterns, strangler fig |
| `solid.md` | Making design decisions about structure | SRP, OCP, LSP, ISP, DIP applied to each architectural layer |
| `boundaries.md` | Reasoning about boundary crossings | Control flow vs. dependency direction, Humble Object pattern, partial boundaries |
| `component-principles.md` | Organising code as the codebase grows | Cohesion (REP, CCP, CRP), coupling (ADP, SDP, SAP), feature vs. layer grouping |

## Contributing

Contributions welcome. If you find a principle that's unclear, a pattern that's missing, or an example that could be better — open an issue or PR.

The bar for changes: does this make it easier for a developer (working with Claude) to build well-structured software? If yes, it belongs.

## Licence

MIT

## Acknowledgements

Based on the work of Robert C. Martin (Uncle Bob), particularly *Clean Architecture: A Craftsman's Guide to Software Structure and Design* (2017). These skills distill those principles into an actionable, AI-friendly format.
