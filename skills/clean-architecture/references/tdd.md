# TDD in Clean Architecture

## Table of Contents
1. Why Clean Architecture Makes TDD Natural
2. The Red-Green-Refactor Cycle
3. Testing Each Layer
4. Test Doubles and Ports
5. The Testing Workflow for a New Feature
6. Test Organization
7. Common Mistakes

---

## 1. Why Clean Architecture Makes TDD Natural

Clean Architecture and TDD are designed to work together. The dependency rule and port-based boundaries create natural seams for testing:

- **Entities** are pure business logic with no dependencies — test them directly with no setup.
- **Use cases** depend only on port interfaces — swap in test doubles and test the orchestration in isolation.
- **Adapters** bridge boundaries — test them with focused integration tests.
- **Infrastructure** wraps external systems — test with integration tests or contract tests.

The architecture eliminates the most common TDD obstacle: "I can't test this because it depends on the database/API/framework." Ports make everything testable by design.

## 2. The Red-Green-Refactor Cycle

Every piece of code is written through this cycle:

**Red:** Write a test that describes what the code should do. Run it. It fails because the code doesn't exist yet. This failure is important — it proves the test is actually checking something.

**Green:** Write the simplest code that makes the test pass. Don't optimize, don't handle edge cases you haven't written tests for, don't refactor. Just make the red test turn green.

**Refactor:** With the safety net of passing tests, improve the code's structure. Remove duplication, clarify names, extract methods. Run the tests after each change to ensure nothing breaks.

### Cycle Discipline

- **Don't write production code without a failing test.** If you're about to write a method, first write the test that calls it.
- **Don't write more test than is sufficient to fail.** A compilation error counts as a failure. Once you have a failing test, stop writing test code and switch to production code.
- **Don't write more production code than is sufficient to pass.** Once the test passes, stop. Write the next test.

This cadence keeps you moving in small, verifiable steps. Each step is safe because the previous step's tests still pass.

## 3. Testing Each Layer

### Entity Tests

Entity tests are the simplest. No mocks, no setup, no test doubles. Just construct the entity and verify its behavior.

```
Test "Order requires at least one line item":
  expect error when:
    new Order(id, customerId, emptyList)

Test "Order calculates total from line items":
  lineItems = [
    LineItem(productId: "A", price: Money(10, "USD"), quantity: 2),
    LineItem(productId: "B", price: Money(5, "USD"), quantity: 3)
  ]
  order = new Order(id, customerId, lineItems)
  assert order.total() == Money(35, "USD")

Test "Order cannot be submitted twice":
  order = createValidOrder()
  order.submit()
  expect error when:
    order.submit()

Test "Draft order can add line items":
  order = createValidOrder()
  order.addLineItem(newLineItem)
  assert order.lineItems.length == originalLength + 1

Test "Submitted order cannot add line items":
  order = createValidOrder()
  order.submit()
  expect error when:
    order.addLineItem(newLineItem)
```

**Value object tests** follow the same pattern — test construction validation and equality:

```
Test "Email rejects invalid format":
  expect error when:
    new Email("not-an-email")

Test "Email normalizes to lowercase":
  email = new Email("User@Example.COM")
  assert email.address == "user@example.com"

Test "Equal emails are equal":
  a = new Email("test@example.com")
  b = new Email("test@example.com")
  assert a.equals(b)
```

### Use Case Tests

Use case tests verify orchestration logic. They use test doubles (fakes, stubs, spies) for ports.

```
Test "CreateOrder saves order and sends confirmation":
  // Arrange — set up test doubles
  orderRepo = new InMemoryOrderRepository()
  productCatalog = new StubProductCatalog([
    Product(id: "P1", price: Money(10, "USD")),
    Product(id: "P2", price: Money(20, "USD"))
  ])
  notificationSpy = new NotificationSpy()
  idGenerator = new FixedIdGenerator("order-123")

  useCase = new CreateOrder(orderRepo, productCatalog, notificationSpy, idGenerator)

  // Act
  request = CreateOrderRequest(
    customerId: "C1",
    items: [{productId: "P1", quantity: 2}, {productId: "P2", quantity: 1}],
    customerEmail: "customer@test.com"
  )
  response = useCase.execute(request)

  // Assert
  assert response.orderId == "order-123"
  assert response.total == 40
  assert orderRepo.savedOrders.length == 1
  assert notificationSpy.sentNotifications.length == 1
  assert notificationSpy.sentNotifications[0].email == "customer@test.com"

Test "CreateOrder fails when product not found":
  productCatalog = new StubProductCatalog([])  // empty catalog
  useCase = new CreateOrder(orderRepo, productCatalog, ...)

  request = CreateOrderRequest(items: [{productId: "NONEXISTENT", quantity: 1}])
  expect ProductNotFoundError when:
    useCase.execute(request)
```

### Adapter Tests

Controller tests verify that input is correctly parsed and mapped to use case calls:

```
Test "CreateOrderController maps HTTP body to request DTO":
  useCaseSpy = new CreateOrderSpy()
  controller = new CreateOrderController(useCaseSpy)

  httpBody = {
    "customer_id": "C1",
    "items": [{"product_id": "P1", "quantity": 2}],
    "email": "test@example.com"
  }
  controller.handle(httpBody)

  assert useCaseSpy.lastRequest.customerId == "C1"
  assert useCaseSpy.lastRequest.items[0].productId == "P1"
```

### Infrastructure / Integration Tests

These test that the infrastructure actually works with real external systems. Run them against a real database (not mocks) and real APIs (or sandboxes).

```
Test "PostgresOrderRepository saves and retrieves an order":
  repo = new PostgresOrderRepository(testDbConnection)
  order = createValidOrder()

  repo.save(order)
  retrieved = repo.findById(order.id)

  assert retrieved is not null
  assert retrieved.id == order.id
  assert retrieved.lineItems.length == order.lineItems.length
  assert retrieved.total() == order.total()
```

Integration tests are slower and harder to maintain, so keep their count focused. Test the mapping and query logic, not the business rules — those are already covered by entity and use case tests.

## 4. Test Doubles and Ports

Clean Architecture's port interfaces make test doubles straightforward. You implement the port interface with a test-friendly version.

### Types of Test Doubles

**Fakes** — Working implementations with shortcuts. An `InMemoryOrderRepository` that stores orders in a list instead of a database. Fakes are the most useful test double for repository ports because they actually work — you can save and retrieve, which makes tests more realistic.

```
Class InMemoryOrderRepository implements OrderRepository:
  storage = []

  save(order):
    storage.removeIf(o => o.id == order.id)
    storage.add(order)

  findById(id):
    return storage.find(o => o.id == id) or null
```

**Stubs** — Return predetermined responses. A `StubProductCatalog` that always returns the same products regardless of what you ask for. Use stubs when the test doesn't care about the interaction, just the data.

**Spies** — Record what happened. A `NotificationSpy` that records every notification sent so you can assert on it. Use spies when you need to verify a side effect occurred.

### Prefer Fakes Over Mocks

Mocking frameworks create brittle tests that break when implementation details change. If your use case calls `repository.save(order)` and your test mocks `repository.save` to return a specific value, you've coupled the test to the exact call sequence.

Fakes are more resilient. An `InMemoryOrderRepository` will work correctly regardless of whether the use case calls `save` once or twice, in which order, or with what exact parameters — as long as the end state is correct. Test the outcome, not the implementation.

## 5. The Testing Workflow for a New Feature

When adding a new feature using TDD in Clean Architecture, follow this order:

### Step 1: Start with the Entity (if the feature needs new domain logic)

Write failing tests for the new entity behavior, then implement it.

```
Test "Order can be partially shipped":
  order = createSubmittedOrder(3 line items)
  order.shipPartially([item1, item2])
  assert order.status == PARTIALLY_SHIPPED
  assert order.shippedItems.length == 2
  assert order.unshippedItems.length == 1
```

### Step 2: Write the Use Case

With the entity behavior working, write a failing test for the use case that orchestrates it. Use fakes/stubs for ports.

```
Test "ShipOrder partially ships and notifies warehouse":
  // ... setup fakes
  response = shipOrder.execute(ShipOrderRequest(orderId, [item1Id, item2Id]))
  assert orderRepo.find(orderId).status == PARTIALLY_SHIPPED
  assert warehouseSpy.receivedShipments.length == 1
```

### Step 3: Implement the Adapter (if needed)

If there's a new controller or a new gateway needed, write focused tests for the adapter's mapping and integration logic.

### Step 4: Wire it Up

Update the composition root to instantiate and wire the new components. The integration test suite should now pass end-to-end.

### Working on Existing Codebases

For an existing codebase where you're modifying behavior, start by writing a test that describes the desired behavior and watching it fail. Then modify the code to make it pass. The existing test suite ensures you haven't broken anything else.

## 6. Test Organization

### Folder Structure

Mirror the source structure in your test directory:

```
tests/
├── domain/
│   ├── entities/
│   │   └── OrderTest
│   └── value-objects/
│       └── EmailTest
│       └── MoneyTest
├── application/
│   └── use-cases/
│       └── CreateOrderTest
│       └── ShipOrderTest
├── adapters/
│   └── controllers/
│       └── CreateOrderControllerTest
├── infrastructure/
│   └── persistence/
│       └── PostgresOrderRepositoryTest   (integration test)
└── helpers/
    ├── fakes/
    │   └── InMemoryOrderRepository
    │   └── StubProductCatalog
    └── builders/
        └── OrderBuilder                  (test data builder)
```

### Test Data Builders

For entities with complex construction, use builder patterns in tests:

```
Class OrderBuilder:
  defaults:
    id: new OrderId("test-order-1")
    customerId: new CustomerId("test-customer-1")
    lineItems: [defaultLineItem()]
    status: DRAFT

  withId(id): set id, return self
  withCustomerId(id): set customerId, return self
  withLineItems(items): set lineItems, return self
  submitted(): set status to SUBMITTED, return self
  build(): return new Order(id, customerId, lineItems) and apply status transitions
```

Usage: `order = OrderBuilder().submitted().withLineItems(threeItems).build()`

Builders keep tests readable by highlighting only what's relevant to each test case while providing sensible defaults for everything else.

## 7. Common Mistakes

**Testing implementation instead of behavior.** A test that verifies `repository.save` was called exactly once with specific parameters is testing implementation. A test that verifies "after creating an order, I can retrieve it by ID" is testing behavior. Behavior tests survive refactoring; implementation tests break.

**Mocking entities.** Entities have no dependencies — there's nothing to mock. Test them directly. If you feel the need to mock an entity, the entity probably depends on something it shouldn't.

**Integration tests for business logic.** Spinning up a database to test that an order can't be submitted twice is wasteful. That's an entity rule — test it with a fast, isolated entity test. Save integration tests for verifying that the persistence layer correctly maps data.

**No test doubles for ports.** Writing use case tests that hit a real database "because mocks are bad." This isn't about mocks vs. real — it's about testing the right thing. Use case tests verify orchestration logic using fakes. Integration tests verify infrastructure using real systems. Both are needed.

**Skipping the red step.** Writing the test and the code at the same time, or writing the code first. If you never saw the test fail, you don't know it works. A test that has never failed might be testing nothing.
