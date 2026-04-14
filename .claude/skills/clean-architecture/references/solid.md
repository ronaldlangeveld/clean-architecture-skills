# SOLID Principles in Clean Architecture

## Table of Contents
1. Why SOLID Matters Here
2. Single Responsibility Principle (SRP)
3. Open-Closed Principle (OCP)
4. Liskov Substitution Principle (LSP)
5. Interface Segregation Principle (ISP)
6. Dependency Inversion Principle (DIP)
7. SOLID Applied Across the Layers

---

## 1. Why SOLID Matters Here

Clean Architecture is SOLID at the architectural scale. The Dependency Rule is DIP applied to layers. Use cases are SRP applied to application operations. Port interfaces are ISP applied to boundaries. Understanding SOLID at the class and module level makes the architectural decisions intuitive rather than mechanical.

These principles aren't rules to follow blindly — they're tools for managing change. Each one answers a specific question about where to put code so that future changes cause the least damage.

## 2. Single Responsibility Principle (SRP)

**"A module should have one, and only one, reason to change."**

SRP is commonly misunderstood as "a class should do one thing." That's not quite it. The principle is about *who* causes changes — each module should be responsible to a single actor (a person or group of people who might request changes).

### How SRP Shapes Clean Architecture

**Entities** change when business rules change. If your `Order` entity also handles formatting for display, it has two reasons to change: business rule changes and presentation changes. Those are different actors (domain experts vs. UI designers).

**Use cases** change when a specific application operation changes. `CreateOrder` changes when the order creation workflow changes. If `CreateOrder` also handles order retrieval, it has two responsibilities — split them.

**Controllers** change when the input format changes. A controller that also contains business validation has two reasons to change: the API contract and the business rules.

### Practical Signals

You're violating SRP when:
- A class name includes "And" or "Manager" or "Handler" that handles multiple unrelated operations
- A change to how orders are displayed requires modifying the `Order` entity
- A change to the database schema requires modifying a use case
- Two different teams would need to edit the same file for unrelated reasons

### Example

```
// Violates SRP — two reasons to change
Class OrderProcessor:
  createOrder(data):
    // business logic for creating an order
    ...
  formatOrderForEmail(order):
    // presentation logic for email notifications
    ...
```

The order creation rules and email formatting will change for different reasons, driven by different people. Separate them:

```
// Each has one reason to change
Class CreateOrder:
  execute(request):
    // business logic only

Class EmailOrderPresenter:
  format(order):
    // presentation logic only
```

## 3. Open-Closed Principle (OCP)

**"Software entities should be open for extension but closed for modification."**

You should be able to add new behaviour to a system without modifying existing code. This is achieved through abstractions — interfaces and polymorphism.

### How OCP Shapes Clean Architecture

The entire architecture is an expression of OCP. When you add a new delivery mechanism (say, a CLI alongside your existing REST API), you don't modify use cases. You write a new controller that calls the same use case. The use case is *closed* for modification but *open* for extension through new adapters.

Similarly, switching from PostgreSQL to MongoDB means writing a new repository implementation. The port interface, the use cases, and the entities don't change. The persistence layer is open for extension (new implementations) while the inner layers are closed for modification.

### Practical Signals

You're achieving OCP when:
- Adding a new feature means adding new files, not editing existing ones
- Swapping an infrastructure component requires changes only in the infrastructure layer
- A new input channel (webhook, CLI, message queue) means a new controller, not changes to use cases

You're violating OCP when:
- Adding a new order type requires editing `CreateOrder` with another `if` branch
- Supporting a new database means modifying use case code
- Adding a new notification channel requires changing every use case that sends notifications

### Strategy: Polymorphism Through Ports

When you see a growing `if/else` or `switch` chain based on type, extract an interface:

```
// Violates OCP — every new notification channel requires modifying this
notify(order, channel):
  if channel == "email": sendEmail(order)
  if channel == "sms": sendSms(order)
  if channel == "push": sendPush(order)

// Follows OCP — new channels implement the interface
Interface NotificationChannel:
  send(order: Order): void

// Adding Slack notifications = adding a file, not editing one
Class SlackNotificationChannel implements NotificationChannel:
  send(order): ...
```

## 4. Liskov Substitution Principle (LSP)

**"Subtypes must be substitutable for their base types."**

If code works with an interface, it must work correctly with any implementation of that interface, without knowing which implementation it's using.

### How LSP Shapes Clean Architecture

LSP is what makes the port/implementation pattern trustworthy. A use case depends on `OrderRepository` (the port). It must work correctly whether the actual implementation is `PostgresOrderRepository`, `MongoOrderRepository`, or `InMemoryOrderRepository`.

This means every implementation must honour the port's contract completely:
- If `save` is documented as an upsert, every implementation must upsert
- If `findById` returns null for missing entities, no implementation should throw an exception instead
- If the port specifies that results are ordered by creation date, every implementation must maintain that ordering

### Practical Signals

You're violating LSP when:
- A test passes with the in-memory fake but fails with the real database implementation (or vice versa)
- Code checks which implementation it received before deciding how to use it
- An implementation throws `NotSupportedException` for a method on the interface
- Swapping one implementation for another changes application behaviour

### Contract Tests Enforce LSP

Write tests against the port interface, then run them with every implementation:

```
Shared "OrderRepository contract":
  Test "save then findById returns the entity":
    ...
  Test "findById returns null for unknown ID":
    ...
  Test "save existing entity updates it":
    ...

Run with: InMemoryOrderRepository    ✓
Run with: PostgresOrderRepository    ✓
Run with: MongoOrderRepository       ✓
```

If any implementation fails a contract test, it violates LSP. See `references/repositories.md` for the full contract testing pattern.

## 5. Interface Segregation Principle (ISP)

**"Clients should not be forced to depend on interfaces they do not use."**

Don't create fat interfaces that force implementors to provide methods they don't need and force consumers to see methods they don't use.

### How ISP Shapes Clean Architecture

**Port interfaces should be focused.** If a use case only needs to read orders, it shouldn't depend on a port that also includes write operations:

```
// Fat interface — violates ISP
Interface OrderRepository:
  save(order): void
  delete(id): void
  findById(id): Order
  findByCustomerId(id): List<Order>
  findPendingOlderThan(cutoff): List<Order>
  generateReport(): Report
  exportToCsv(): string

// Segregated — each consumer depends only on what it needs
Interface OrderReader:
  findById(id): Order
  findByCustomerId(id): List<Order>

Interface OrderWriter:
  save(order): void
  delete(id): void

Interface OrderQueryService:
  findPendingOlderThan(cutoff): List<Order>
```

A use case that only reads orders depends on `OrderReader`. A use case that creates orders depends on `OrderWriter` and `OrderReader`. Neither is forced to see `exportToCsv`.

### When to Segregate

Don't split every interface preemptively — that's over-engineering. Start with a single, cohesive interface. Split when:

- Different use cases need obviously different subsets of the interface
- An implementation would need to throw `NotSupportedException` for methods it can't support
- The interface is growing beyond 5–7 methods and the methods cluster into natural groups
- You're writing a new implementation and half the methods don't apply

### Practical Application to Gateways

External service ports benefit from ISP particularly well:

```
// Don't create a single PaymentGateway with everything
Interface PaymentGateway:
  charge(amount, token): Result
  refund(chargeId, amount): Result
  createSubscription(plan, customer): Subscription
  cancelSubscription(subId): void
  listTransactions(filter): List<Transaction>

// Instead, separate by capability
Interface PaymentCharger:
  charge(amount, token): Result

Interface PaymentRefunder:
  refund(chargeId, amount): Result

Interface SubscriptionManager:
  create(plan, customer): Subscription
  cancel(subId): void
```

## 6. Dependency Inversion Principle (DIP)

**"High-level modules should not depend on low-level modules. Both should depend on abstractions."**

This is the principle that the Dependency Rule enforces at the architectural level. It's the most structurally important SOLID principle in Clean Architecture.

### How DIP Shapes Clean Architecture

Without DIP, the natural dependency chain flows outward:

```
Entity → Use Case → Controller → Web Framework
Entity → Use Case → Repository → Database
```

This means changing your database changes your repository, which changes your use case, which might change your entity. Everything is coupled to the outermost, most volatile layer.

DIP inverts this. The use case defines an interface (abstraction). The repository implements it. The dependency points inward:

```
Use Case → [OrderRepository interface]
                    ↑
PostgresOrderRepository implements OrderRepository
```

The use case depends on the abstraction. The infrastructure depends on the abstraction. Neither depends on the other. The abstraction lives in the inner layer (application), owned by the high-level policy.

### The Critical Detail: Who Owns the Interface?

DIP says both high-level and low-level modules depend on abstractions, but the **abstraction must be owned by the higher-level module**. In Clean Architecture, this means:

- Port interfaces live in `application/interfaces/`, not in `infrastructure/`
- The application layer defines what it needs; the infrastructure layer provides it
- If the infrastructure team changes a database, they change the implementation — the port (and therefore the use case) stays untouched

If the interface lived in the infrastructure layer, the application would depend on infrastructure — the dependency would point outward, violating the Dependency Rule.

## 7. SOLID Applied Across the Layers

| Principle | Domain Layer | Application Layer | Adapter Layer | Infrastructure Layer |
|-----------|-------------|-------------------|---------------|---------------------|
| SRP | Each entity owns one business concept | Each use case handles one operation | Each controller handles one input path | Each implementation wraps one external system |
| OCP | New entity types extend behaviour via polymorphism | New use cases add capabilities without modifying existing ones | New controllers add delivery channels without touching use cases | New implementations swap infrastructure without touching ports |
| LSP | Entity subtypes honour parent contracts | — | — | Every port implementation is fully substitutable |
| ISP | Entities expose focused interfaces to use cases | Ports are narrow and purpose-specific | Controllers consume only the use cases they need | Implementations fulfil only the ports they claim to |
| DIP | Entities depend on nothing | Use cases depend on port abstractions, not implementations | Adapters depend on use cases and ports | Implementations depend on port abstractions owned by the application layer |

The principles reinforce each other. SRP tells you *where* to split. OCP tells you *how* to structure for extension. LSP tells you *what contract* implementations must honour. ISP tells you *how wide* an interface should be. DIP tells you *which direction* dependencies flow. Together, they produce the layered, boundary-driven architecture.
