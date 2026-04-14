# Infrastructure (Frameworks & Drivers)

## Table of Contents
1. What Infrastructure Is
2. Persistence
3. Web / Delivery Mechanism
4. External Services
5. The Composition Root
6. Configuration
7. Common Mistakes

---

## 1. What Infrastructure Is

The infrastructure layer is the outermost ring. It contains everything that is a "detail" — frameworks, databases, web servers, file systems, third-party services, UI. These are the things Robert C. Martin calls "details that should be deferred as long as possible."

The infrastructure layer depends on everything inside it. Nothing inside depends on it. The application layer defines port interfaces; the infrastructure layer provides implementations. This is the Dependency Inversion Principle in action.

The infrastructure layer is where your chosen tools live, but the architecture doesn't care about those choices. PostgreSQL, MongoDB, MySQL — all valid. Express, Flask, Spring — all valid. REST, GraphQL, gRPC — all valid. The inner layers are identical regardless.

## 2. Persistence

Persistence implementations live in `infrastructure/persistence/`. They implement the repository ports defined in `application/interfaces/`.

### Structure

```
infrastructure/
  persistence/
    repositories/           # Port implementations
      PostgresOrderRepository
      PostgresCustomerRepository
    models/                 # Database-specific representations
      OrderModel            # ORM model or schema definition
      CustomerModel
    migrations/             # Schema changes
    connection.*            # Database connection management
```

### Key Principles

**Persistence models are NOT entities.** Your database model `OrderModel` maps to/from the domain entity `Order`, but they are separate structures. The entity has behavior and business rules. The persistence model has database annotations, column mappings, and storage concerns.

**Repositories encapsulate all database access.** No SQL, no ORM queries, no database-specific code exists outside the persistence directory. If a use case needs data, it asks a repository through a port interface.

**Transactions belong here.** The infrastructure layer manages database transactions. A common pattern is a Unit of Work that wraps a use case execution in a transaction. The use case itself doesn't know transactions exist.

### Data Mapping

Map between persistence models and domain entities at the repository boundary:

```
Class PostgresOrderRepository implements OrderRepository:
  save(order: Order):
    model = toPersistenceModel(order)
    database.save(model)

  findById(id: OrderId): Order
    model = database.findById(id)
    return toDomainEntity(model)

  Private toPersistenceModel(order):
    return new OrderModel(
      id: order.id.value,
      customer_id: order.customerId.value,
      status: order.status.toString(),
      total_cents: order.total().cents,
      created_at: order.createdAt
    )

  Private toDomainEntity(model):
    return new Order(
      id: new OrderId(model.id),
      customerId: new CustomerId(model.customer_id),
      lineItems: mapLineItems(model.line_items),
      status: OrderStatus.from(model.status),
      createdAt: model.created_at
    )
```

## 3. Web / Delivery Mechanism

The web layer lives in `infrastructure/web/`. It sets up the HTTP server, routing, middleware, and wires routes to controllers.

### Structure

```
infrastructure/
  web/
    server.*               # HTTP server setup and startup
    routes.*               # Route definitions mapping URLs to controllers
    middleware/            # Auth, logging, error handling, CORS
    error-handler.*       # Translates domain errors to HTTP responses
```

### Guidelines

**Routes are just wiring.** A route maps an HTTP method + path to a controller. No business logic in route definitions.

```
Routes:
  POST /orders        → CreateOrderController.handle
  GET  /orders/:id    → GetOrderController.handle
  POST /orders/:id/cancel → CancelOrderController.handle
```

**Middleware handles cross-cutting concerns.** Authentication, request logging, rate limiting, CORS — these are infrastructure concerns. They run before the controller and after the response, but they don't contain business logic.

**Error handling middleware translates domain errors.** A centralized error handler catches domain exceptions and maps them to HTTP responses:

```
ErrorHandler:
  handle(error):
    if error is OrderNotFoundError: return 404
    if error is InsufficientStockError: return 409
    if error is InvalidInputError: return 400
    // Unexpected errors
    log(error)
    return 500
```

This keeps error translation in one place instead of scattered across every controller.

## 4. External Services

Third-party API integrations live in `infrastructure/external/`. They implement gateway ports defined in the application layer.

### Structure

```
infrastructure/
  external/
    stripe/
      StripePaymentGateway     # Implements PaymentGateway port
      StripeClient             # HTTP client configuration
    sendgrid/
      SendgridNotificationService  # Implements NotificationService port
    twilio/
      TwilioSmsGateway         # Implements SmsGateway port
```

### Guidelines

**Wrap every external dependency.** Never let a third-party SDK's types leak into the application layer. The gateway translates between the SDK's types and your domain types. This means if the SDK changes its API, only the gateway changes.

**Handle failures at the infrastructure level.** Retries, circuit breakers, timeouts, and fallback logic for external services belong here. The use case doesn't know or care about network reliability — it calls the port and expects a result or a meaningful error.

**External services should be replaceable.** If you switch from Stripe to a different payment processor, you write a new gateway. The port interface stays the same, the use case stays the same.

## 5. The Composition Root

The composition root is where the entire application is wired together. It lives in `main.*` (or `infrastructure/config/`). This is the only place in the codebase that knows about all layers simultaneously.

### Responsibilities

1. Create infrastructure instances (database connections, HTTP clients)
2. Create gateway/repository instances (passing infrastructure dependencies)
3. Create use case instances (passing port implementations)
4. Create controller instances (passing use cases)
5. Wire routes to controllers
6. Start the application

### Example Pattern

```
Main:
  // Infrastructure
  dbConnection = new DatabaseConnection(config.databaseUrl)
  stripeClient = new StripeClient(config.stripeApiKey)

  // Gateways (implement ports)
  orderRepository = new PostgresOrderRepository(dbConnection)
  paymentGateway = new StripePaymentGateway(stripeClient)
  notificationService = new SendgridNotificationService(config.sendgridKey)

  // Use Cases
  createOrder = new CreateOrder(orderRepository, paymentGateway, notificationService)
  getOrder = new GetOrderById(orderRepository)
  cancelOrder = new CancelOrder(orderRepository, notificationService)

  // Controllers
  createOrderController = new CreateOrderController(createOrder)
  getOrderController = new GetOrderController(getOrder)
  cancelOrderController = new CancelOrderController(cancelOrder)

  // Wire and start
  router = new Router()
  router.post("/orders", createOrderController)
  router.get("/orders/:id", getOrderController)
  router.post("/orders/:id/cancel", cancelOrderController)

  server = new HttpServer(router, errorHandler)
  server.start(config.port)
```

### Dependency Injection

The composition root handles all dependency injection manually or through a DI container. The key principle: **only the composition root resolves dependencies.** No other part of the codebase creates its own dependencies.

If using a DI container/framework, configure it in the composition root. Don't scatter container references throughout the codebase — that turns the DI container into a Service Locator antipattern.

## 6. Configuration

Application configuration lives in `infrastructure/config/`. It reads environment variables, config files, or secret managers and provides typed configuration to the rest of the infrastructure.

### Guidelines

**Configuration is read at startup.** The composition root reads configuration once and injects values where needed. Components don't read environment variables directly — they receive configuration through their constructors.

**Secrets never touch domain or application layers.** API keys, database passwords, and tokens live in configuration and are injected into infrastructure components only.

**Separate configuration by concern.** Database config, API keys, feature flags, server settings — keep these in logical groups rather than one monolithic config object.

## 7. Common Mistakes

**Framework lock-in.** Letting framework-specific types pervade the entire codebase. Express middleware, Spring annotations, Django model classes — these should be confined to the infrastructure layer. If removing the framework requires rewriting your entities and use cases, the boundaries were violated.

**The "everything is infrastructure" trap.** Putting business logic in middleware, database triggers, or framework hooks. If it's a business rule, it belongs in an entity or use case, regardless of how convenient the framework makes it to put it elsewhere.

**Shared database models.** Using the same model class for domain logic and persistence. This tightly couples your business rules to your database schema. When the schema changes (add a column, split a table), your domain logic breaks.

**Over-configured DI containers.** DI containers that auto-scan, auto-wire, and use so much magic that nobody can trace how dependencies are resolved. Prefer explicit wiring — it's boring but readable. You should be able to follow the dependency chain by reading the composition root.

**Infrastructure in the wrong folder.** Putting a database repository in `adapters/gateways/` or a controller in `infrastructure/web/`. Follow the prescribed folder structure — controllers are adapters (they adapt HTTP to use cases), and database implementations are infrastructure (they implement persistence as a detail).
