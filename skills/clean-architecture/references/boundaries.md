# Boundaries and the Humble Object Pattern

## Table of Contents
1. What Boundaries Are
2. The Anatomy of a Boundary Crossing
3. Control Flow vs. Dependency Direction
4. The Humble Object Pattern
5. Boundary Types in Practice
6. Partial Boundaries
7. Common Mistakes

---

## 1. What Boundaries Are

A boundary is a line drawn between things that change for different reasons. In Clean Architecture, the major boundaries separate domain from application, application from adapters, and adapters from infrastructure. But boundaries exist at every level — between components, modules, and even classes.

The purpose of a boundary is isolation. When something on one side changes, nothing on the other side needs to change. This is what makes systems maintainable at scale — changes stay local instead of rippling through the entire codebase.

Every boundary has a cost: indirection, additional types (interfaces, DTOs), and mapping code. The skill is knowing where boundaries earn their keep and where they'd just be overhead.

## 2. The Anatomy of a Boundary Crossing

When data crosses a boundary, three things must be true:

1. **The inner layer defines the data format.** The use case defines its request and response DTOs. The entity defines its own types. Outer layers conform to what inner layers expect, never the reverse.

2. **Data structures are simple.** Data crosses boundaries as plain structures — DTOs, primitives, or collections of these. Not entities (they have behaviour that shouldn't leak outward), not framework objects (they'd create an inward dependency), not database models (they're infrastructure details).

3. **The dependency direction is inward.** The outer layer calls the inner layer. The outer layer knows about the inner layer's types. The inner layer knows nothing about the outer layer.

### Example: HTTP Request to Use Case

```
HTTP request arrives
  ↓
Controller (adapter layer):
  1. Parses JSON body into primitives
  2. Constructs CreateOrderRequest DTO (defined by application layer)
  3. Calls createOrder.execute(request)
  ↓
Use Case (application layer):
  1. Receives request DTO (its own type)
  2. Constructs/modifies entities
  3. Calls orderRepository.save(order) — through a port
  4. Returns CreateOrderResponse DTO (its own type)
  ↓
Controller:
  1. Receives response DTO
  2. Maps to HTTP response (JSON, status code, headers)
  ↓
HTTP response sent
```

At every boundary crossing, data is translated from one format to another. The controller translates HTTP to DTO. The repository translates entity to database model. Each translation happens at the boundary, in the outer layer.

## 3. Control Flow vs. Dependency Direction

This is the subtlest and most important concept in Clean Architecture. Control flow and dependency direction are not the same thing, and they often point in opposite directions.

### The Problem

When a use case needs to save data, the natural control flow goes outward:

```
Use Case → Repository Implementation → Database
```

But if the use case depends directly on the repository implementation, the dependency also points outward — violating the Dependency Rule.

### The Solution: Dependency Inversion at the Boundary

Insert an interface (port) owned by the inner layer:

```
Control flow:    Use Case  →  PostgresOrderRepository  →  Database
Dependencies:    Use Case  →  OrderRepository (interface)
                              ↑
                 PostgresOrderRepository implements OrderRepository
```

Control flow still goes outward (the use case calls the repository, which calls the database). But the dependency direction is inverted — the use case depends on an abstraction it owns, and the infrastructure depends on that same abstraction. Both point inward.

This is the Dependency Inversion Principle applied at the architectural boundary. It's what allows inner layers to call outer layers without depending on them.

### Visualising It

```
Application layer          Infrastructure layer
┌──────────────┐          ┌──────────────────────┐
│              │          │                      │
│  Use Case ───────────────→ Repository Impl     │
│       │      │          │       │              │
│       ▼      │          │       ▼              │
│  [Port] ◄──────────────── implements Port      │
│              │          │                      │
└──────────────┘          └──────────────────────┘

───→ = control flow (runtime calls)
◄─── = dependency direction (source code reference)
```

The use case calls the implementation at runtime. But in the source code, the implementation references (depends on) the port, not the other way around.

## 4. The Humble Object Pattern

The Humble Object pattern is a testing technique that naturally emerges at architectural boundaries. The idea: split code at a boundary into two parts — one that's hard to test and one that's easy to test. Make the hard-to-test part so simple (humble) that it barely needs testing, and put all the interesting logic in the easy-to-test part.

### The Pattern

```
[Hard-to-test thing]  ←→  [Humble Object]  ←→  [Easy-to-test thing]
      (framework,                                   (pure logic,
       database,                                     no dependencies,
       UI, network)                                  fully testable)
```

The humble object sits at the boundary. It does the minimum work needed to translate between the hard-to-test external world and the easy-to-test internal logic.

### Presenters as Humble Objects

The classic example. The view (HTML rendering, UI framework) is hard to test. The business logic that decides *what* to display is easy to test. The presenter sits between them:

```
Use Case → Presenter (humble) → View

The Presenter:
  - Receives the use case response DTO
  - Formats data into a ViewModel (strings, booleans, display-ready values)
  - The ViewModel is so simple the View barely needs logic

The View (humble):
  - Takes the ViewModel
  - Renders it mechanically (plug values into a template)
  - Contains zero decision-making logic
```

The presenter is testable: give it a response DTO, assert it produces the right ViewModel. The view is so humble it doesn't need unit tests — if the ViewModel is correct, the rendering is a mechanical step.

### Controllers as Humble Objects

Controllers also follow this pattern:

```
HTTP framework → Controller (humble) → Use Case

The Controller:
  - Extracts data from the HTTP request
  - Maps it to a request DTO
  - Calls the use case
  - Maps the response DTO to an HTTP response

The Controller is humble because it contains no decisions, no business logic, no data transformation beyond simple mapping.
```

If a controller is making decisions about what to do based on business state, that logic should move to the use case.

### Repository Implementations as Humble Objects

The database is hard to test (slow, stateful, requires setup). The repository implementation sits at the boundary:

```
Use Case → [Port] → Repository Impl (humble) → Database

The Repository Implementation:
  - Maps domain entities to persistence models
  - Executes queries
  - Maps results back to domain entities
  - Contains no business logic
```

The mapping and querying are mechanical. The real logic lives in entities (business rules) and use cases (orchestration), both of which are tested without a database.

### Why "Humble"?

The word "humble" means the object is deliberately kept simple and dumb. It doesn't make decisions. It doesn't contain logic worth testing in isolation. Its job is to translate between the testable world and the untestable world, and to do so with as little cleverness as possible.

If your controller, presenter, or repository implementation is getting complex enough to need extensive unit tests, logic is leaking into the wrong place.

## 5. Boundary Types in Practice

### Full Boundaries

A full boundary uses interfaces, separate data structures, and dependency inversion. This is what Clean Architecture prescribes between the four main layers:

```
application/interfaces/OrderRepository    (port)
infrastructure/persistence/PostgresOrderRepository  (implementation)
```

Full boundaries are expensive (more files, more mapping code) but provide maximum isolation. Use them when the things on either side change independently and frequently, or when you need to swap implementations.

### Partial Boundaries

Not every boundary needs the full treatment. When you suspect a boundary will be needed eventually but the cost isn't justified today, there are lighter-weight options.

**Strategy pattern:** Define an interface and one implementation. No separate package, no elaborate structure. Just an interface and a class that implements it, living near each other. If you need a second implementation later, the interface is already in place.

```
// Interface and single implementation — easy to extend later
Interface PricingStrategy:
  calculatePrice(product, quantity): Money

Class StandardPricingStrategy implements PricingStrategy:
  calculatePrice(product, quantity):
    return product.price * quantity
```

**Facade pattern:** Put a simple class in front of a complex subsystem. External code talks to the facade; the facade coordinates the subsystem. This creates a boundary without full dependency inversion:

```
Class NotificationFacade:
  sendOrderConfirmation(orderId, email):
    // Coordinates email template, SMTP client, and logging
    // Callers don't know about the internals
```

### When to Upgrade a Boundary

Start partial, upgrade to full when you see:
- A second implementation is needed (testing counts)
- The boundary is crossed by multiple use cases
- Changes on one side are causing changes on the other
- The partial boundary's simplicity is becoming a limitation

## 6. Boundaries at Different Scales

### Between layers (architectural boundaries)

These are the primary boundaries in Clean Architecture. Full boundaries with interfaces, DTOs, and dependency inversion. They separate concerns that change for fundamentally different reasons.

### Between features (module boundaries)

Within a layer, features should have clear boundaries too. The `Order` aggregate and the `Customer` aggregate communicate through IDs, not direct references. Use cases for orders don't reach into customer repositories — they go through their own ports.

### Between services (deployment boundaries)

If your system is distributed across multiple services, each service should follow Clean Architecture internally. The boundary between services is just another infrastructure concern — an HTTP client or message queue consumer that implements a port.

Clean Architecture applies *within* each service. A microservice that's a ball of mud on the inside hasn't gained anything from being small. The boundary discipline applies at every scale.

## 7. Common Mistakes

**Boundaries without purpose.** Creating interfaces for everything "just in case." If a class has exactly one implementation and no realistic prospect of a second, the interface is ceremony without benefit. Start concrete, extract an interface when you have a reason.

**Leaking across boundaries.** Passing framework types through a boundary (an HTTP request object reaching a use case, an ORM model reaching an entity). Every boundary crossing should involve translating to the inner layer's types.

**Business logic in humble objects.** A controller that decides what to do based on order status, or a presenter that calculates discounts. Humble objects should be mechanical translators. If there's a conditional that depends on business state, it belongs in a use case or entity.

**Skipping boundaries for convenience.** A controller that calls the database directly "because it's just a simple read." This bypasses the use case layer, scatters data access across the codebase, and means you can't add business rules to that operation later without refactoring the controller.

**Too many boundaries too early.** Over-engineering a small application with full boundaries between every conceivable concern. Start with the main architectural boundaries (domain, application, adapters, infrastructure). Add finer-grained boundaries as the codebase grows and you discover where change is actually happening.

**Confusing control flow with dependency.** Assuming that because the use case calls the repository at runtime, the use case must depend on the repository implementation. The port interface breaks this assumption — the use case depends on the abstraction, not the implementation.
