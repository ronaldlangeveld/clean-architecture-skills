# Interface Adapters

## Table of Contents
1. The Role of Adapters
2. Controllers (Inbound Adapters)
3. Presenters (Outbound Formatting)
4. Gateways (Outbound Adapters)
5. Mapping Between Layers
6. Common Mistakes

---

## 1. The Role of Adapters

Adapters are the translators between the application's use cases and the outside world. They sit in the third ring of the Clean Architecture diagram — they know about use cases and entities, but the inner layers know nothing about them.

Adapters handle two directions:

**Inbound (controllers):** Take input from the outside world (HTTP request, CLI args, message queue event), translate it into a use case request DTO, call the use case, and take the response DTO to a presenter.

**Outbound (gateways):** Implement the port interfaces defined by the application layer. A `OrderRepository` interface defined in `application/interfaces/` gets a `PostgresOrderRepository` implementation in the adapter or infrastructure layer.

The adapter layer is where framework-specific code begins to appear — but it stays contained here. Adapters depend on use cases, never the reverse.

## 2. Controllers (Inbound Adapters)

A controller's job is narrow and mechanical:

1. Receive input from the delivery mechanism (HTTP body, CLI args, event payload)
2. Parse and validate the input format (not business rules — just "is this valid JSON?", "is this field present?")
3. Map the input into a use case request DTO
4. Call the use case
5. Pass the use case response to a presenter or return it directly

### Structure

```
Controller CreateOrderController:
  Dependencies:
    createOrder: CreateOrder (use case)

  Handle(rawInput):
    // 1. Parse and validate input format
    request = parseAndValidate(rawInput)

    // 2. Call the use case
    response = createOrder.execute(request)

    // 3. Return or present the response
    return response
```

### Guidelines

**Controllers are thin.** If a controller has business logic, that logic should move to a use case or entity. A controller that checks "does this customer have enough credit?" is overstepping — that check belongs in the `CreateOrder` use case or the `Customer` entity.

**One controller per use case (or per closely related group).** Don't create a `OrderController` with 15 methods. Create `CreateOrderController`, `GetOrderController`, `CancelOrderController`. This keeps each controller focused and easy to find.

**Error translation happens here.** When a use case throws `OrderNotFoundError`, the controller (or an error-handling middleware in the web layer) translates it to the appropriate delivery response — HTTP 404, CLI error message, etc.

## 3. Presenters (Outbound Formatting)

Presenters take use case output and format it for a specific delivery mechanism. They implement a presenter interface defined in the application layer.

### When to Use Presenters

Presenters are most valuable when the same data needs to look different depending on the delivery mechanism. An `OrderDetails` response might become:

- A JSON object for an API
- An HTML page for a web interface
- A formatted string for a CLI
- A simplified structure for a mobile client

If your application has a single delivery mechanism and the response DTO maps cleanly to the output format, you can skip explicit presenter classes and let the controller handle it directly. Don't add abstraction for abstraction's sake.

### Example Pattern

```
Interface OrderDetailsPresenter:
  present(response: GetOrderResponse): FormattedOutput

Class ApiOrderDetailsPresenter implements OrderDetailsPresenter:
  present(response):
    return {
      "order_id": response.orderId,
      "total": formatCurrency(response.total),
      "status": response.status.toLowerCase(),
      "items": response.items.map(formatLineItem)
    }

Class CliOrderDetailsPresenter implements OrderDetailsPresenter:
  present(response):
    return """
    Order #{response.orderId}
    Status: {response.status}
    Total: {formatCurrency(response.total)}
    Items:
      {formatItemsList(response.items)}
    """
```

## 4. Gateways (Outbound Adapters)

Gateways implement the port interfaces that use cases depend on. They handle the actual communication with external systems — databases, APIs, file systems, message queues.

### Repository Gateways

The most common gateway. Implements a repository port defined in the application layer:

```
// Port (defined in application/interfaces/)
Interface OrderRepository:
  save(order: Order): void
  findById(id: OrderId): Order or null

// Gateway (implemented in adapters/gateways/ or infrastructure/persistence/)
Class PostgresOrderRepository implements OrderRepository:
  Dependencies:
    dbConnection: DatabaseConnection

  save(order):
    row = mapToRow(order)         // Entity -> DB row
    dbConnection.upsert("orders", row)
    for lineItem in order.lineItems:
      itemRow = mapLineItemToRow(lineItem, order.id)
      dbConnection.upsert("order_line_items", itemRow)

  findById(id):
    row = dbConnection.findOne("orders", {id: id.value})
    if not row: return null
    itemRows = dbConnection.findMany("order_line_items", {orderId: id.value})
    return mapToEntity(row, itemRows)  // DB rows -> Entity
```

### External Service Gateways

Wrap third-party API calls behind a port interface:

```
// Port
Interface PaymentGateway:
  charge(amount: Money, token: PaymentToken): PaymentResult

// Gateway
Class StripePaymentGateway implements PaymentGateway:
  charge(amount, token):
    stripeResponse = stripeClient.charges.create({
      amount: amount.cents(),
      currency: amount.currency,
      source: token.value
    })
    return mapToPaymentResult(stripeResponse)
```

The use case says "charge this amount." The gateway knows it's Stripe. If you switch to a different payment provider, you write a new gateway — the use case doesn't change.

## 5. Mapping Between Layers

Every boundary crossing involves mapping data from one representation to another. This is intentional — it prevents inner layers from depending on outer layer structures.

### Mapping Points

1. **Input → Request DTO**: Controller parses raw input into a use case request
2. **Entity → Persistence Model**: Gateway converts entities to/from database representations
3. **Response DTO → Output Format**: Presenter formats the use case response for delivery
4. **External API Response → Domain Types**: Gateway converts third-party responses into domain objects

### Mapping Guidelines

**Keep mappers simple and boring.** A mapper is just field-by-field assignment. If mapping logic gets complex, it's a sign that the data structures on one side need refactoring.

**Mappers live at the boundary they serve.** The controller contains (or calls) the input→DTO mapper. The gateway contains the entity→persistence mapper. Don't create a shared "mapper utils" module that everything depends on.

**Don't try to eliminate "duplication" across layers.** It's tempting to look at a request DTO, an entity, and a database model that all have similar fields and merge them into one class. Resist this — they change for different reasons. The entity changes when business rules change. The DTO changes when the API contract changes. The database model changes when the schema evolves. Keeping them separate protects each layer from changes in the others.

## 6. Common Mistakes

**Fat controllers.** Controllers that contain business logic, validation rules, or orchestration that belongs in use cases. If your controller is more than ~20–30 lines, business logic is likely leaking in.

**Adapters that depend on each other.** A controller that imports a gateway directly, bypassing the use case layer. If a controller needs data, it calls a use case, which calls a repository through a port.

**Persistence models leaking into the domain.** Using ORM-generated classes as entities, or having entities depend on database-specific annotations. The domain must be persistence-ignorant.

**Over-engineering presenters.** Creating presenter interfaces and multiple implementations for an API that only serves JSON. Presenters earn their keep when you actually have multiple output formats. Otherwise, the controller can format the response directly.

**Mapping in the wrong direction.** Infrastructure types flowing inward. If your use case accepts a `SqlRow` or returns a `HttpResponse`, the boundary is violated. Data always flows through DTOs or domain types at the boundary.
