# The Repository Pattern

## Table of Contents
1. What a Repository Is
2. Designing the Port Interface
3. Standard Methods
4. Querying Without Leaking Infrastructure
5. Pagination and Filtering
6. The In-Memory Fake
7. The Infrastructure Implementation
8. Aggregate Persistence
9. Common Mistakes

---

## 1. What a Repository Is

A repository is an abstraction over data access. It presents a collection-like interface to the application layer — "give me this entity," "save this entity," "find entities matching these criteria" — without revealing how or where the data is stored.

In Clean Architecture, the repository has two halves:

- **The port** (interface) — defined in `application/interfaces/`. This is what use cases depend on. It speaks in domain types: entities, value objects, and IDs.
- **The implementation** — lives in `infrastructure/persistence/`. This is where the database, ORM, file system, or API client actually does the work.

The port knows nothing about SQL, document schemas, or table names. The implementation knows nothing about business rules. Each changes for different reasons, and that separation is the entire point.

## 2. Designing the Port Interface

A repository port should read like a description of what the application needs from persistence, not what the database can do.

### Naming

Name the interface after the aggregate root it manages:

- `OrderRepository` — manages `Order` aggregates
- `CustomerRepository` — manages `Customer` aggregates
- `ProductRepository` — manages `Product` aggregates

One repository per aggregate root. If `LineItem` is part of the `Order` aggregate, it's persisted through `OrderRepository`, not through its own repository.

### Type Signatures

Every method on the port uses domain types. Parameters are entity IDs, value objects, or domain primitives. Return types are entities, lists of entities, or domain-specific result types.

```
Interface OrderRepository:
  save(order: Order): void
  findById(id: OrderId): Order or null
  findByCustomerId(id: CustomerId): List<Order>
  existsById(id: OrderId): boolean
  delete(id: OrderId): void
```

Never expose infrastructure types through the port — no SQL result sets, no ORM query builders, no cursor objects, no JSON documents.

## 3. Standard Methods

Most repositories share a common set of operations. Start with these and add domain-specific queries as use cases demand them.

### Write Operations

```
save(entity: T): void
```

Use a single `save` method that handles both creation and updates (upsert semantics). The implementation decides whether to insert or update based on whether the entity already exists. This keeps the use case simple — it constructs or modifies an entity and calls `save`. It doesn't need to know whether the entity is new.

```
delete(id: EntityId): void
```

Delete by identity. In many domains, you'll want soft deletion (a status flag) rather than hard deletion — but that's a domain decision expressed in the entity, not a repository concern. If your domain uses soft deletion, the entity might have an `archive()` method that sets a status, and the use case calls `save` after archiving. The repository doesn't need a special `softDelete` method.

### Read Operations

```
findById(id: EntityId): Entity or null
```

The most fundamental query. Returns the full aggregate or null if not found. Use cases that require the entity to exist should throw a domain error when null is returned — that's a use case responsibility, not a repository one.

```
findByIds(ids: List<EntityId>): List<Entity>
```

Batch retrieval. Useful when a use case needs several entities at once. The returned list may be shorter than the input if some IDs don't exist — the use case decides whether that's an error.

```
existsById(id: EntityId): boolean
```

A lightweight existence check when you don't need the full entity. Useful for validation in use cases ("does this customer exist?") without the overhead of hydrating the entire aggregate.

## 4. Querying Without Leaking Infrastructure

This is where repository design gets tricky. Use cases need to query data by various criteria, but exposing flexible query capabilities risks turning the repository into a thin wrapper around SQL.

### The Right Approach: Domain-Specific Query Methods

Add query methods that describe what the application needs in domain terms:

```
Interface OrderRepository:
  findByCustomerId(customerId: CustomerId): List<Order>
  findPendingOlderThan(cutoff: Timestamp): List<Order>
  findByStatus(status: OrderStatus): List<Order>
  countByCustomerIdAndStatus(customerId: CustomerId, status: OrderStatus): number
```

Each method is a named concept that a use case needs. The implementation translates it to whatever query the database requires.

### When to Add a New Query Method

Add a method when a use case needs data that existing methods can't provide efficiently. The process:

1. The use case identifies what data it needs
2. Check if an existing repository method provides it
3. If not, add a new method to the port interface
4. Implement it in the infrastructure layer

Don't add query methods speculatively. Every method on the port is a commitment — it must be implemented by every implementation, including test fakes.

### The Wrong Approach: Generic Query Methods

Avoid these patterns — they leak infrastructure concerns through the port:

```
// Bad: exposes query language
findWhere(conditions: Map<string, any>): List<Order>

// Bad: passes raw filter strings
query(filter: string): List<Order>

// Bad: accepts a specification that maps to SQL
findBySpecification(spec: Specification<Order>): List<Order>
```

The Specification pattern deserves a nuance: it's acceptable when the specification is defined in domain terms and the repository implementation translates it. But in practice, specifications tend to evolve into thinly disguised query builders. Prefer explicit named methods until you have a genuine need for composable queries across many combinations of criteria.

## 5. Pagination and Filtering

Real applications need pagination. The challenge is expressing it through the port without coupling to a specific database's pagination mechanism.

### Domain-Level Pagination

Define pagination types in the application layer:

```
PageRequest:
  page: number        (1-based)
  pageSize: number    (e.g., 20)

PageResult<T>:
  items: List<T>
  totalItems: number
  totalPages: number
  currentPage: number
  pageSize: number
```

Repository methods that return potentially large result sets accept a `PageRequest`:

```
Interface OrderRepository:
  findByCustomerId(customerId: CustomerId, page: PageRequest): PageResult<Order>
  findByStatus(status: OrderStatus, page: PageRequest): PageResult<Order>
```

### Cursor-Based Pagination

For high-volume or real-time data, cursor-based pagination is often more appropriate. Define it similarly:

```
CursorRequest:
  cursor: string or null    (null = start from beginning)
  limit: number

CursorResult<T>:
  items: List<T>
  nextCursor: string or null   (null = no more results)
  hasMore: boolean
```

The cursor is opaque to the use case — it's a string that the repository implementation knows how to interpret. This lets the implementation use whatever cursor strategy suits the database (offset-based, keyset-based, token-based) without the use case caring.

### Sorting

When sorting is needed, express it in domain terms:

```
OrderSortField:
  CREATED_AT
  TOTAL
  STATUS

SortDirection:
  ASCENDING
  DESCENDING

Interface OrderRepository:
  findByCustomerId(
    customerId: CustomerId,
    sortBy: OrderSortField,
    direction: SortDirection,
    page: PageRequest
  ): PageResult<Order>
```

The sort fields are an enum of domain concepts, not database column names. The implementation maps `OrderSortField.TOTAL` to whatever column or expression the database uses.

## 6. The In-Memory Fake

Every repository port should have an in-memory fake implementation for testing. This is one of the biggest payoffs of the repository pattern — fast, deterministic tests that don't need a database.

```
Class InMemoryOrderRepository implements OrderRepository:
  storage: Map<string, Order> = empty map

  save(order):
    storage.set(order.id.value, order)

  findById(id):
    return storage.get(id.value) or null

  findByCustomerId(customerId):
    return storage.values()
      .filter(order => order.customerId.equals(customerId))

  findPendingOlderThan(cutoff):
    return storage.values()
      .filter(order => order.status == PENDING and order.createdAt < cutoff)

  findByStatus(status):
    return storage.values()
      .filter(order => order.status == status)

  existsById(id):
    return storage.has(id.value)

  delete(id):
    storage.remove(id.value)

  // Test helper — not part of the port interface
  count(): number
    return storage.size
```

### Fake Design Guidelines

**The fake must honour the same contract as the real implementation.** If `save` is an upsert, the fake must upsert. If `findByCustomerId` returns results ordered by creation date, the fake must do the same. Contract tests (see below) help enforce this.

**Add test helper methods that aren't part of the port.** Methods like `count()`, `clear()`, `getAll()` are useful in tests but don't belong on the port interface. Add them directly to the fake class.

**Keep fakes simple.** An in-memory list or map is almost always sufficient. Don't build an in-memory query engine — if your fake is getting complex, your port interface might be too broad.

## 7. The Infrastructure Implementation

The real implementation lives in `infrastructure/persistence/` and does the actual database work.

### Structure

```
infrastructure/
  persistence/
    repositories/
      PostgresOrderRepository     # Implements OrderRepository port
    models/
      OrderModel                  # Database-specific representation
      OrderLineItemModel
    mappers/
      OrderMapper                 # Maps between entity and model
    migrations/
      001_create_orders_table
      002_add_status_column
```

### Mapping Between Entity and Persistence Model

The repository is responsible for translating between domain entities and database representations. This mapping happens in both directions:

**Entity → Persistence Model** (for saving):
```
Private toModel(order: Order): OrderModel
  return OrderModel(
    id: order.id.value,
    customer_id: order.customerId.value,
    status: order.status.toString(),
    total_cents: order.total().toCents(),
    created_at: order.createdAt,
    updated_at: now()
  )
```

**Persistence Model → Entity** (for retrieval):
```
Private toEntity(model: OrderModel, itemModels: List<OrderLineItemModel>): Order
  return Order.reconstitute(
    id: new OrderId(model.id),
    customerId: new CustomerId(model.customer_id),
    lineItems: itemModels.map(toLineItemEntity),
    status: OrderStatus.from(model.status),
    createdAt: model.created_at
  )
```

Note the use of `Order.reconstitute` (or a similar factory method) for rebuilding an entity from stored data. This is distinct from the constructor used to create a new entity — reconstitution skips validation that only applies at creation time (e.g., "new orders must have status DRAFT") because the stored data represents an entity that has already passed those checks.

### Contract Tests

Write contract tests that verify both the real implementation and the fake behave identically:

```
Shared contract "OrderRepository contract":
  repositoryUnderTest: OrderRepository   (injected — either real or fake)

  Test "save and retrieve by ID":
    order = createValidOrder()
    repositoryUnderTest.save(order)
    retrieved = repositoryUnderTest.findById(order.id)
    assert retrieved is not null
    assert retrieved.id == order.id
    assert retrieved.total() == order.total()

  Test "findById returns null for unknown ID":
    result = repositoryUnderTest.findById(unknownId)
    assert result is null

  Test "save overwrites existing entity":
    order = createValidOrder()
    repositoryUnderTest.save(order)
    order.addLineItem(newItem)
    repositoryUnderTest.save(order)
    retrieved = repositoryUnderTest.findById(order.id)
    assert retrieved.lineItems.length == order.lineItems.length

Run contract with InMemoryOrderRepository    (fast, in unit tests)
Run contract with PostgresOrderRepository    (slower, in integration tests)
```

This ensures the fake faithfully mirrors the real implementation, which in turn ensures your use case tests are trustworthy.

## 8. Aggregate Persistence

When an aggregate contains multiple entities (e.g., `Order` with `LineItem`s), the repository saves and loads the entire aggregate as a unit.

### Save the Whole Aggregate

```
Class PostgresOrderRepository implements OrderRepository:
  save(order):
    transaction:
      upsertOrderRow(order)
      deleteLineItemsForOrder(order.id)
      for each lineItem in order.lineItems:
        insertLineItemRow(lineItem, order.id)
```

The repository handles the transactional boundary. The use case doesn't know about transactions — it calls `save(order)` and trusts that the aggregate is persisted atomically.

### Load the Whole Aggregate

```
  findById(id):
    orderRow = selectOrder(id)
    if not orderRow: return null
    lineItemRows = selectLineItemsForOrder(id)
    return toEntity(orderRow, lineItemRows)
```

Always load the full aggregate. If you find yourself wanting to load an order without its line items for performance, that's a signal either that the aggregate boundary is wrong (maybe line items should be their own aggregate) or that you need a separate read model for that query.

### Cross-Aggregate References

Aggregates reference each other by ID, not by direct object reference. The `Order` holds a `customerId`, and if the use case needs the `Customer` entity, it fetches it from `CustomerRepository` separately:

```
UseCase GetOrderWithCustomerDetails:
  order = orderRepository.findById(orderId)
  customer = customerRepository.findById(order.customerId)
  // Combine as needed in the response DTO
```

Never have one repository reach into another repository's tables. Each repository owns its aggregate's persistence exclusively.

## 9. Common Mistakes

**Generic repositories.** A `Repository<T>` base class with `save`, `findById`, `findAll`, `delete` that every repository inherits from. This seems DRY but it pushes every entity toward the same persistence shape, hides domain-specific query methods, and makes the port interface meaningless. Each repository should be designed for its specific aggregate.

**Returning persistence models from the port.** The port returns domain entities, never database rows, ORM objects, or DTOs shaped for the database. If a use case receives an `OrderRow` instead of an `Order`, the boundary is broken.

**Query methods that accept raw SQL or filter maps.** This turns the repository into a pass-through to the database and defeats the purpose of the abstraction. Use case code should never contain anything that looks like a query language.

**Repositories for non-aggregate entities.** If `LineItem` is part of the `Order` aggregate, it doesn't get its own repository. Accessing line items independently bypasses the aggregate root's consistency rules.

**Lazy loading through the port.** A repository that returns an `Order` with lazily-loaded line items that trigger a database call when accessed. This hides I/O inside what looks like a property access, makes behaviour unpredictable, and couples the entity to the persistence mechanism. Load the full aggregate eagerly.

**Too many query methods.** If your repository port has 20 `findBy` methods, the interface is doing too much. Consider whether some queries belong to a separate read model (see CQRS) rather than the aggregate repository. The repository is optimised for writes and simple lookups — complex reporting queries may warrant their own path.

**Ignoring the fake.** Building the real PostgreSQL implementation first and skipping the in-memory fake. This forces every use case test to hit the database, making them slow and fragile. Write the fake first — it's simpler, it drives good port design, and it gives you fast tests immediately.
