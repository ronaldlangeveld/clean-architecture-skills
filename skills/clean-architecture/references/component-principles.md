# Component Principles

## Table of Contents
1. What Components Are
2. Component Cohesion: What Belongs Together
3. Component Coupling: How Components Relate
4. Applying Component Principles to Clean Architecture
5. Practical Decision Framework
6. Common Mistakes

---

## 1. What Components Are

A component is a unit of deployment — the smallest thing that can be independently developed and versioned. Depending on your language and ecosystem, this might be a package, a module, a library, a namespace, or a directory with a clear public interface.

In Clean Architecture, the natural components are the layers and the features within them. `domain/entities/`, `application/use-cases/`, `infrastructure/persistence/` — each is a component with its own responsibilities and dependency rules.

Component principles help answer two questions:
- **Cohesion:** Which classes and modules belong together in the same component?
- **Coupling:** How should components depend on each other?

Getting these right determines whether your codebase scales gracefully or collapses under its own weight.

## 2. Component Cohesion: What Belongs Together

Three principles govern what should be grouped into the same component.

### The Reuse/Release Equivalence Principle (REP)

**"The granule of reuse is the granule of release."**

Classes that are reused together should be released together. If someone depends on your component, every class in it should be relevant to them. A component shouldn't force a consumer to depend on things they don't need.

**In Clean Architecture:** The `domain/entities/` component contains entities that are used together by use cases. If `Order` and `LineItem` are always used together (they form an aggregate), they belong in the same component. If `Order` and `UserPreferences` are never used together, they probably shouldn't be in the same component.

### The Common Closure Principle (CCP)

**"Classes that change together belong together."**

Group classes that are likely to change for the same reason at the same time. When a change request arrives, you want it to affect as few components as possible — ideally one.

CCP is the Single Responsibility Principle applied to components. Just as a class should have one reason to change, a component should have one reason to change.

**In Clean Architecture:** All the code related to order processing — the `Order` entity, `CreateOrder` use case, `OrderRepository` port, and `CreateOrderRequest` DTO — changes when order requirements change. While they live in different layers (and that's correct), within each layer, order-related code should be grouped.

This is why feature-based organisation within layers is powerful:

```
application/
  use-cases/
    order/
      CreateOrder
      CancelOrder
      GetOrderById
      OrderRepository (port)
    customer/
      RegisterCustomer
      UpdateCustomerProfile
      CustomerRepository (port)
```

When order requirements change, the `order/` directory changes. The `customer/` directory is untouched.

### The Common Reuse Principle (CRP)

**"Don't force users of a component to depend on things they don't need."**

If you depend on a component, you depend on all of it. So don't put classes together if some consumers need only a subset. The flip side: classes that aren't reused together shouldn't be in the same component.

CRP is the Interface Segregation Principle applied to components.

**In Clean Architecture:** If your `application/interfaces/` directory contains `OrderRepository`, `CustomerRepository`, `PaymentGateway`, and `NotificationService`, a use case that only needs `OrderRepository` is forced to depend on a component that also contains `PaymentGateway`. When the payment gateway interface changes, the order use case's component dependency has technically changed — even though it doesn't use payments at all.

Solution: organise interfaces alongside the use cases that need them, or split into focused sub-packages.

### The Tension Between the Three

These principles pull in different directions:

- **REP and CCP** want to make components larger (group for reuse, group for common change)
- **CRP** wants to make components smaller (don't include things consumers don't need)

Early in a project, lean toward CCP — group by common change to keep modifications localised. As the codebase matures and is reused more broadly, lean toward CRP — split components so consumers aren't burdened by irrelevant dependencies.

## 3. Component Coupling: How Components Relate

Three principles govern how components should depend on each other.

### The Acyclic Dependencies Principle (ADP)

**"There must be no cycles in the component dependency graph."**

If component A depends on B, and B depends on C, and C depends on A — you have a cycle. Cycles mean you can't build, test, or understand any component in isolation. A change anywhere in the cycle can affect everything in the cycle.

**Detecting Cycles:**

Map out which components import from which. If you can follow the imports and arrive back where you started, there's a cycle.

```
// Cycle:
Order use cases → Customer use cases → Order use cases

// No cycle:
Order use cases → OrderRepository port
Customer use cases → CustomerRepository port
Both ports → domain entities (no cycle — both point inward)
```

**Breaking Cycles:**

Two strategies:

1. **Apply DIP.** If A depends on B and B depends on A, create an interface in A that B implements. B now depends on A's interface. The cycle is broken.

2. **Extract a new component.** Move the shared code that both A and B need into a new component C. Both A and B depend on C. No cycle.

### The Stable Dependencies Principle (SDP)

**"Depend in the direction of stability."**

A component should only depend on components that are more stable than itself. Stability here means "hard to change" — a component that many other components depend on is stable because changing it would have wide-reaching effects.

**Measuring Stability:**

A component's instability (I) can be estimated:

```
I = outgoing dependencies / (incoming dependencies + outgoing dependencies)
```

- I = 0: maximally stable (many things depend on it, it depends on nothing) — hard to change
- I = 1: maximally unstable (nothing depends on it, it depends on many things) — easy to change

**In Clean Architecture:** The Dependency Rule naturally enforces SDP. Domain entities are the most stable (everything depends on them, they depend on nothing). Infrastructure is the least stable (nothing depends on it, it depends on everything). Dependencies point from unstable to stable — from infrastructure toward domain.

```
Infrastructure (I ≈ 1, unstable) → Adapters → Application → Domain (I ≈ 0, stable)
```

### The Stable Abstractions Principle (SAP)

**"A component should be as abstract as it is stable."**

Stable components (hard to change) should be abstract so they can be extended without modification. Unstable components (easy to change) should be concrete — they contain the implementations that change frequently.

**In Clean Architecture:**

- **Domain entities** are stable and relatively abstract — they define business concepts and rules that rarely change
- **Application interfaces (ports)** are stable and fully abstract — they define contracts without implementations
- **Infrastructure implementations** are unstable and fully concrete — they provide the specific database, framework, and API code that changes frequently

This is exactly the pattern: stable inner layers are abstract (entities, interfaces), unstable outer layers are concrete (controllers, repository implementations, framework configurations).

## 4. Applying Component Principles to Clean Architecture

### Layer-First vs. Feature-First Organisation

**Layer-first** (prescribed in this skill):
```
src/
  domain/entities/
  application/use-cases/
  adapters/controllers/
  infrastructure/persistence/
```

Optimises for CCP across architectural concerns. All entities are together, all use cases are together. Good for enforcing the Dependency Rule and making boundaries visible.

**Feature-first:**
```
src/
  order/
    Order (entity)
    CreateOrder (use case)
    OrderController (adapter)
    PostgresOrderRepository (infrastructure)
  customer/
    Customer (entity)
    RegisterCustomer (use case)
    ...
```

Optimises for CCP within features. All order code is together. Good for keeping changes localised to a feature.

**Hybrid (recommended as a codebase grows):**
```
src/
  domain/
    order/Order, LineItem, OrderId
    customer/Customer, CustomerId
  application/
    order/CreateOrder, CancelOrder, OrderRepository
    customer/RegisterCustomer, CustomerRepository
  adapters/
    order/CreateOrderController
    customer/RegisterCustomerController
  infrastructure/
    persistence/order/PostgresOrderRepository
    persistence/customer/PostgresCustomerRepository
```

This maintains the layer boundaries (enforcing the Dependency Rule) while grouping by feature within each layer (optimising for CCP). Changes to order requirements affect `*/order/` directories. Changes to the web framework affect only `adapters/` and `infrastructure/`. Best of both approaches.

### The Main Component

The `main` file (composition root) is the most unstable component in the system — it depends on everything and nothing depends on it. Its instability (I = 1) is appropriate because it's the most concrete component: it knows every class, constructs every object, and wires every dependency.

This is by design. All the "dirty" knowledge of which specific implementations to use lives in one place. The rest of the system works with abstractions.

## 5. Practical Decision Framework

When deciding where code belongs, ask these questions in order:

**"What changes would cause this code to change?"** Group it with code that changes for the same reason (CCP).

**"Who uses this code?"** Don't force consumers to depend on things they don't need (CRP).

**"Does this dependency point toward stability?"** Depend on things that change less frequently than you do (SDP).

**"Does adding this dependency create a cycle?"** If yes, invert the dependency or extract a shared component (ADP).

**"Is this stable component abstract enough to extend?"** If many things depend on it, it should be an interface or abstraction, not a concrete implementation (SAP).

## 6. Common Mistakes

**Circular dependencies between features.** Order use cases importing from customer use cases and vice versa. Break the cycle by having both depend on shared domain types or by defining ports.

**Unstable components at the centre.** Putting frequently-changing code in a component that many other components depend on. This makes every change ripple outward. Stable components should be abstract; concrete, volatile code should be at the edges.

**Mega-components.** A single `services/` or `utils/` package containing unrelated code. This violates CRP — consumers depend on the whole package even if they need one function. Split by purpose.

**Premature splitting.** Creating ten tiny components for a small application where three would do. Component boundaries have a maintenance cost (interfaces, mapping, indirection). Start coarser, split as the codebase and team grow.

**Ignoring the dependency graph.** Never visualising or checking which components depend on which. In a well-structured system, the dependency graph is a directed acyclic graph (DAG) flowing inward. If you can't draw it clearly, the architecture is likely tangled.

**Coupling through shared mutable state.** Two components that don't directly import each other but both write to the same database table, global variable, or shared file. This is invisible coupling — harder to detect than import-based coupling but equally damaging. Each aggregate's persistence should be owned by a single repository.
