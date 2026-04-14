# Use Cases (Application Business Rules)

## Table of Contents
1. What Use Cases Are
2. Anatomy of a Use Case
3. Ports (Interfaces)
4. DTOs and Boundary Crossing
5. Use Case Patterns
6. Error Handling
7. Common Mistakes

---

## 1. What Use Cases Are

A use case is a single, specific thing the application can do. It orchestrates the flow of data to and from entities, calling on them to apply their business rules.

The `application/use-cases/` folder is your application's table of contents. Someone reading it should immediately understand every operation the system supports without reading any implementation code.

Use cases contain **application-specific** business rules — rules that exist because of the software system itself. "An order must have line items" is an entity rule (true even without software). "Send a confirmation email after order placement" is a use case rule (specific to this application).

## 2. Anatomy of a Use Case

Every use case follows this shape:

```
UseCase CreateOrder:
  Dependencies (injected via constructor):
    orderRepository: OrderRepository      (port)
    productCatalog: ProductCatalog        (port)
    notificationService: NotificationService (port)
    idGenerator: IdGenerator              (port)

  Execute(request: CreateOrderRequest) -> CreateOrderResponse:
    1. Validate the request (input validation)
    2. Fetch any data needed from ports
    3. Construct or modify entities
    4. Let entities enforce their business rules
    5. Persist results through ports
    6. Return a response DTO

    Concretely:
      products = productCatalog.getByIds(request.productIds)
      if any products not found:
        throw ProductNotFoundError

      lineItems = build line items from products and request quantities
      orderId = idGenerator.generate()
      order = new Order(orderId, request.customerId, lineItems)
      order.submit()

      orderRepository.save(order)
      notificationService.sendOrderConfirmation(order.id, request.customerEmail)

      return CreateOrderResponse(order.id, order.total(), order.status)
```

### Key principles

**One use case, one operation.** `CreateOrder` creates an order. It doesn't also list orders or update shipping. If you find yourself passing a "mode" or "action type" parameter, split it into separate use cases.

**Dependencies are injected, never constructed.** The use case declares what it needs via ports (interfaces). The composition root wires in the implementations. This is what makes use cases testable — you swap real implementations for test doubles.

**Use cases don't know about delivery mechanisms.** A use case doesn't know whether it was called from an HTTP controller, a CLI command, a message queue consumer, or a test. It accepts a request DTO and returns a response DTO.

## 3. Ports (Interfaces)

Ports are the contracts that the application layer defines for what it needs from the outside world. They live in `application/interfaces/`.

There are two kinds:

**Driven ports (outbound):** Things the application needs to call — repositories, external service gateways, notification senders. The application defines the interface; the infrastructure provides the implementation.

```
Interface OrderRepository:
  save(order: Order): void
  findById(id: OrderId): Order or null
  findByCustomerId(customerId: CustomerId): List<Order>
```

**Driver ports (inbound):** The use cases themselves act as inbound ports. A controller calls a use case — the use case *is* the port that the outside world drives.

### Port Design Guidelines

- Name ports by capability, not implementation: `OrderRepository`, not `PostgresOrderStore`
- Keep ports focused. Don't create a single `DatabasePort` that handles everything — separate by domain concept
- Port methods should use domain types (entities, value objects, IDs), not infrastructure types (SQL rows, JSON objects)
- Avoid exposing query language through ports. `findByCustomerIdAndStatus(id, status)` is fine. `query(sqlString)` violates the boundary.

## 4. DTOs and Boundary Crossing

Data crosses the use case boundary through **Data Transfer Objects** — simple structures with no behavior.

**Request DTOs** carry input into the use case:
```
CreateOrderRequest:
  customerId: string
  items: List<{productId: string, quantity: number}>
  customerEmail: string
```

**Response DTOs** carry output from the use case:
```
CreateOrderResponse:
  orderId: string
  total: number
  status: string
```

### Why DTOs, not entities?

Returning entities from use cases would let the outer layers depend on entity structure. If you change an entity, every controller and presenter that touches it breaks. DTOs create a stable boundary — you can reshape entity internals without affecting anything outside the application layer.

DTOs are flat, simple structures. They use primitive types or other DTOs. They have no business logic, no methods, no validation beyond basic type constraints. They exist solely to carry data across a boundary.

## 5. Use Case Patterns

### Query vs. Command

Use cases naturally split into two categories:

**Commands** change state: `CreateOrder`, `CancelSubscription`, `UpdateUserProfile`. They may or may not return data.

**Queries** read state: `GetOrderById`, `ListUserOrders`, `SearchProducts`. They never modify anything.

Separating these makes the codebase easier to reason about. Looking at a use case name, you know whether it changes the system.

### Use Case Interactor Pattern

When a use case needs to present results in a specific format (e.g., the same order data formatted differently for an API vs. a report), use a presenter port:

```
UseCase GetOrderDetails:
  Dependencies:
    orderRepository: OrderRepository
    presenter: OrderDetailsPresenter   (port)

  Execute(request):
    order = orderRepository.findById(request.orderId)
    if not found: throw OrderNotFoundError
    presenter.present(order)
```

The presenter is an interface defined in the application layer, implemented in the adapter layer. Different implementations format the data differently.

### Composing Use Cases

When a higher-level operation needs to do several things (e.g., "checkout" creates an order, processes payment, and sends a confirmation), create a new use case that calls the relevant ports directly. Don't call use cases from other use cases — this creates hidden coupling. Extract shared logic into domain services or entities instead.

## 6. Error Handling

Use cases should throw **domain-specific errors** that describe what went wrong in business terms:

- `OrderNotFoundError` — not `404` or `RecordNotFound`
- `InsufficientStockError` — not `ValidationError("stock too low")`
- `CustomerCreditLimitExceededError` — not `BusinessRuleViolation`

The adapter layer (controllers, presenters) translates these into appropriate delivery-mechanism responses (HTTP status codes, CLI exit codes, error messages in a UI).

### Error Categories

**Domain errors** (thrown by entities): Invariant violations. "Order already submitted," "Invalid email format." These indicate the operation is not allowed by business rules.

**Application errors** (thrown by use cases): The operation can't proceed. "Order not found," "Product discontinued." These indicate a precondition isn't met.

**Infrastructure errors** (thrown by implementations): Database timeout, external API failure. Use cases should not catch or handle these directly — let them propagate and be handled by the infrastructure layer's error handling middleware.

## 7. Common Mistakes

**The "Service" antipattern.** Creating a `OrderService` that contains `createOrder()`, `getOrder()`, `updateOrder()`, `deleteOrder()`, `listOrders()`. This is a disguised God class. Each of those is a separate use case with different dependencies and different business rules. Separate them.

**Use cases that know about HTTP.** If your use case accepts an `HttpRequest` or returns a `HttpResponse`, the boundary is broken. Use cases work with DTOs, not transport-layer objects.

**Skipping the use case layer.** Controllers that talk directly to repositories, bypassing use cases. This scatters business logic across controllers, making it impossible to reuse across different delivery mechanisms and hard to test.

**Fat use cases.** A use case that contains complex business logic that should live in an entity. The use case orchestrates — it calls `order.submit()`, it doesn't inline the submission rules. If a use case is getting long, look for entity behavior trying to escape.

**Use cases calling other use cases.** This creates hidden coupling and makes the dependency graph unpredictable. If two use cases share behavior, extract it into a domain service or entity method that both can call independently.
