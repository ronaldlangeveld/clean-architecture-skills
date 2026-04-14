---
name: clean-architecture
description: "Guides building software using Clean Architecture principles (Robert C. Martin). Use this skill whenever the developer is starting a new project, adding a feature, creating entities or use cases, setting up project structure, writing business logic, or discussing architectural boundaries. Trigger on any mention of: clean architecture, use cases, entities, domain layer, dependency rule, ports and adapters, hexagonal, onion architecture, separation of concerns, or when the developer wants code that is testable, framework-independent, and easy to understand at a glance. Also use when the developer asks about folder structure for a new app, how to organize business logic, or how to keep their codebase from becoming spaghetti."
---

# Clean Architecture

This skill guides you in building software that follows Clean Architecture principles. The goal is simple: **make the software's intent obvious, its business rules protected, and its infrastructure swappable.**

Every decision flows from one rule.

## The Dependency Rule

Source code dependencies must point **inward only**. Nothing in an inner circle can know anything about something in an outer circle. This means names, functions, classes, data formats — nothing declared in an outer circle can be mentioned by code in an inner circle.

The layers, from innermost to outermost:

1. **Entities** — Enterprise-wide business rules and data structures
2. **Use Cases** — Application-specific business rules (orchestrate entities)
3. **Interface Adapters** — Convert data between use cases and external formats
4. **Infrastructure** — Frameworks, databases, web servers, UI, external services

Data crosses boundaries through simple structures (plain objects, DTOs). The inner layers define interfaces that outer layers implement.

## Prescribed Folder Structure

Every project following this skill uses this structure at its source root:

```
src/
├── domain/
│   ├── entities/          # Enterprise business rules and data structures
│   └── value-objects/     # Immutable domain primitives (Email, Money, etc.)
│
├── application/
│   ├── use-cases/         # One file per use case, named by intent
│   ├── interfaces/        # Port definitions (repository, service, gateway contracts)
│   └── dto/               # Data Transfer Objects crossing boundaries
│
├── adapters/
│   ├── controllers/       # Inbound adapters (handle input, call use cases)
│   ├── presenters/        # Outbound formatting (shape use case output for delivery)
│   └── gateways/          # Outbound adapters (implement repository/service interfaces)
│
├── infrastructure/
│   ├── persistence/       # Database implementations (repos, ORM config, migrations)
│   ├── web/               # HTTP server setup, routing, middleware
│   ├── external/          # Third-party API clients
│   └── config/            # Environment, DI container, app bootstrap
│
└── main.*                 # Composition root — wires everything together
```

### Naming Conventions

Use case files are named by what they do, not what they are. The name should read like a sentence describing the user's intent:

- `CreateOrder` not `OrderCreator` or `OrderService`
- `AuthenticateUser` not `AuthService` or `LoginHandler`  
- `GetInvoiceById` not `InvoiceFetcher`

Entity files are named after the business concept they represent: `Order`, `User`, `Invoice`, `Product`.

Interface (port) files describe the capability: `OrderRepository`, `PaymentGateway`, `NotificationService`.

## How to Use This Skill

**Starting a new project:** Set up the folder structure above. Start by identifying the core entities and the first use case you need. Write the domain layer first, then the use case, then work outward. Read `references/entities.md` and `references/use-cases.md` first.

**Adding a feature to an existing codebase:** Read `references/adding-features.md` for the step-by-step workflow. The short version: identify the use case, define the entity changes, write the use case, then implement the adapters.

**Writing tests:** This architecture is designed for testability. Read `references/tdd.md` for the TDD workflow that pairs with Clean Architecture. Tests for use cases mock the ports (interfaces), not the implementations. Tests for entities need no mocks at all.

## Core Principles at a Glance

**The Screaming Architecture test:** Someone looking at your top-level folder structure should immediately know what the application *does*, not what framework it uses. If your folders say `controllers/`, `models/`, `views/` — that screams "MVC framework." If they say `domain/entities/Order`, `application/use-cases/CreateOrder` — that screams "this is an ordering system."

**Entities are not ORM models.** Your domain entity `Order` is not the same as a database row. The persistence layer maps between the two. The entity doesn't know what a database is.

**Use cases are the application's story.** Reading the `application/use-cases/` folder should tell you everything the system can do. Each use case is a single, focused operation. If you can't name it clearly, it's doing too much.

**The database is a detail.** So is the web framework. So is the UI. So is the message queue. These are all plugins that the inner layers don't know about. You should be able to swap PostgreSQL for MongoDB, or REST for GraphQL, without touching a single line in `domain/` or `application/`.

**Boundaries are enforced by interfaces (ports).** The application layer defines what it needs via interfaces. The infrastructure layer provides implementations. This inversion of control is what makes the dependency rule possible.

## Reference Docs

Read these as needed — each goes deep on its layer:

- `references/entities.md` — How to design entities and value objects. Read when creating or modifying domain models.
- `references/use-cases.md` — How to write use cases that tell the application's story. Read when adding business operations.
- `references/repositories.md` — How to design repository ports, write in-memory fakes, and implement persistence without leaking infrastructure. Read when working with data access.
- `references/adapters.md` — How controllers, presenters, and gateways bridge the gap. Read when connecting use cases to the outside world.
- `references/infrastructure.md` — How to implement persistence, web, and external services as swappable plugins. Read when setting up databases, APIs, or frameworks.
- `references/tdd.md` — The TDD workflow tailored for Clean Architecture. Read when writing or structuring tests.
- `references/adding-features.md` — Step-by-step guide for adding features to an existing Clean Architecture codebase. Read when extending functionality.
- `references/solid.md` — SOLID principles applied to architectural decisions. Read when making design choices about where code belongs and how to structure dependencies.
- `references/boundaries.md` — How boundaries work, control flow vs. dependency direction, and the Humble Object pattern. Read when reasoning about boundary crossings or testability at boundaries.
- `references/component-principles.md` — Cohesion and coupling rules for organising code into components. Read when deciding how to group modules or when the codebase is growing and needs restructuring.
