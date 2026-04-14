# Adding Features to an Existing Clean Architecture Codebase

## Table of Contents
1. The Feature Addition Workflow
2. Step-by-Step Process
3. Modifying Existing Entities
4. Adding a New Entity
5. Keeping Things Clean During Changes
6. Refactoring Toward Clean Architecture

---

## 1. The Feature Addition Workflow

Adding a feature in Clean Architecture follows a predictable path. You work from the inside out — start with the domain, move to the use case, then work outward to adapters and infrastructure. This ensures that business logic drives the design, not framework or database concerns.

The workflow:

1. Identify the use case (what the user/system needs to do)
2. Identify entity changes (if any new business rules are needed)
3. Write entity tests and entity code (TDD, inside-out)
4. Define or update port interfaces (if new external dependencies are needed)
5. Write use case tests and use case code
6. Create request/response DTOs
7. Implement adapters (controllers, presenters)
8. Implement infrastructure (new repository methods, new API clients)
9. Wire everything in the composition root

## 2. Step-by-Step Process

### Step 1: Name the Use Case

Before writing any code, name what you're building. The name should be a verb phrase that describes the user's intent:

- "Cancel an order" → `CancelOrder`
- "Get a customer's order history" → `GetCustomerOrderHistory`
- "Apply a discount code" → `ApplyDiscountCode`

If you can't name it clearly, you don't understand the requirement well enough yet. Discuss it further before coding.

### Step 2: Identify Domain Changes

Ask: does this feature introduce new business rules? If yes, those rules belong in entities or value objects.

- "A canceled order can't be shipped" → Entity rule on `Order`
- "Discount codes must be alphanumeric and 8 characters" → Value object `DiscountCode`
- "A discount can't exceed 50% of the order total" → Entity rule on `Order` or a domain service

If the feature is purely orchestration (e.g., "fetch this data and return it formatted"), you may not need any entity changes.

### Step 3: Write Entity Tests First

If you identified domain changes in Step 2, write the tests before the code:

```
Test "Order can be canceled when status is SUBMITTED":
  order = createSubmittedOrder()
  order.cancel()
  assert order.status == CANCELED

Test "Order cannot be canceled when already shipped":
  order = createShippedOrder()
  expect OrderAlreadyShippedError when:
    order.cancel()

Test "Canceled order cannot be modified":
  order = createCanceledOrder()
  expect error when:
    order.addLineItem(someItem)
```

Implement the entity behavior to make the tests pass.

### Step 4: Define Ports (If Needed)

If the use case needs a new external capability, define the port interface in `application/interfaces/`:

```
Interface RefundGateway:
  processRefund(orderId: OrderId, amount: Money): RefundResult
```

Don't implement it yet — just define the contract.

If the feature only needs existing ports (e.g., it reads from `OrderRepository` which already exists), skip this step.

### Step 5: Write the Use Case Test

Now test the orchestration:

```
Test "CancelOrder cancels and initiates refund":
  orderRepo = InMemoryOrderRepository(with: [submittedOrder])
  refundGateway = RefundSpy()
  notificationService = NotificationSpy()

  useCase = new CancelOrder(orderRepo, refundGateway, notificationService)
  useCase.execute(CancelOrderRequest(orderId: "order-123", reason: "changed mind"))

  savedOrder = orderRepo.findById("order-123")
  assert savedOrder.status == CANCELED
  assert refundGateway.processedRefunds.length == 1
  assert notificationService.sentNotifications[0].type == "order_canceled"
```

Implement the use case to make the test pass.

### Step 6: Create DTOs

Define the request and response structures:

```
CancelOrderRequest:
  orderId: string
  reason: string

CancelOrderResponse:
  orderId: string
  status: string
  refundAmount: number
  refundStatus: string
```

### Step 7: Build the Adapter

Create the controller:

```
Controller CancelOrderController:
  Dependencies:
    cancelOrder: CancelOrder

  Handle(rawInput):
    request = CancelOrderRequest(
      orderId: rawInput.params.orderId,
      reason: rawInput.body.reason
    )
    response = cancelOrder.execute(request)
    return formatResponse(response)
```

### Step 8: Implement Infrastructure

Now implement the port you defined in Step 4:

```
Class StripeRefundGateway implements RefundGateway:
  processRefund(orderId, amount):
    stripeResult = stripeClient.refunds.create(...)
    return mapToRefundResult(stripeResult)
```

If you need new repository methods (e.g., `findByStatus`), add them to the port interface and implement them in the existing repository class.

### Step 9: Wire It Up

Update the composition root:

```
// New infrastructure
refundGateway = new StripeRefundGateway(stripeClient)

// New use case
cancelOrder = new CancelOrder(orderRepository, refundGateway, notificationService)

// New controller
cancelOrderController = new CancelOrderController(cancelOrder)

// New route
router.post("/orders/:id/cancel", cancelOrderController)
```

## 3. Modifying Existing Entities

When a feature requires changing an existing entity, follow this checklist:

1. **Write tests for the new behavior first.** Describe what the entity should do after the change.
2. **Check that existing tests still describe desired behavior.** If the change should alter existing behavior, update those tests first.
3. **Make the change.** Run all entity tests — new ones should pass, existing ones should still pass (unless intentionally changed).
4. **Check use case tests.** If the entity change affects how use cases interact with the entity, some use case tests may need updating.
5. **Persistence mapping.** If you added or changed fields, update the persistence model and mapping in the repository implementation. Add a database migration if needed.

The key insight: entity changes ripple outward, not inward. Changing an entity might require adapter and infrastructure updates, but it should never require changes to another entity (unless that entity depends on the changed one through the use case layer).

## 4. Adding a New Entity

When a feature introduces a completely new business concept:

1. **Create the entity in `domain/entities/`** with its business rules and tests
2. **Create any value objects** it needs in `domain/value-objects/`
3. **Define a repository port** in `application/interfaces/` if it needs persistence
4. **Create the persistence model** and repository implementation in `infrastructure/persistence/`
5. **Create database migration** for the new table/collection
6. **Build use cases** that work with the new entity
7. **Wire everything** in the composition root

Don't create an entity preemptively. An entity earns its place by having business rules. If it's just a data container with no behavior, it might be a DTO or a value object instead.

## 5. Keeping Things Clean During Changes

### The Strangler Fig Pattern

When working in a codebase that doesn't fully follow Clean Architecture, don't try to rewrite everything at once. Instead, apply the **strangler fig** approach:

1. Build the new feature following Clean Architecture
2. Have the new code coexist with the old code
3. Gradually route traffic/calls from old paths to new ones
4. Remove old code when it's no longer called

### Dependency Checks

After adding a feature, verify the dependency rule isn't violated:

- `domain/` imports nothing from `application/`, `adapters/`, or `infrastructure/`
- `application/` imports from `domain/` only (and defines its own interfaces)
- `adapters/` imports from `application/` and `domain/`
- `infrastructure/` can import from all inner layers

If any import points in the wrong direction, something is off. The most common violation is an entity importing a repository or an external service — this always means a responsibility is in the wrong layer.

### Feature Folders vs. Layer Folders

The prescribed structure in this skill uses layer folders (`domain/`, `application/`, `adapters/`, `infrastructure/`). Some teams prefer feature folders (`order/`, `customer/`, `payment/`), with layers nested inside each feature.

Either works, but be consistent. The layer-first approach (used in this skill) makes the architectural boundaries explicit and highly visible. The feature-first approach groups related code together, which can be easier to navigate as the codebase grows.

If you switch to feature folders, maintain the same layer separation within each feature — the dependency rule still applies.

## 6. Refactoring Toward Clean Architecture

When bringing Clean Architecture to an existing codebase that doesn't follow it:

### Priority 1: Extract the Domain

Identify business rules that are scattered in controllers, services, or database models. Move them into entity classes. This is the highest-value refactoring because it makes the business rules explicit, testable, and centralized.

### Priority 2: Define Ports

Create interfaces for external dependencies that use cases currently access directly. This doesn't require changing the implementations — just introduce the interface and have the existing implementation fulfill it.

### Priority 3: Isolate Use Cases

Extract orchestration logic from controllers into dedicated use case classes. Each use case gets its own file, named by intent.

### Priority 4: Clean Up Infrastructure

Move framework-specific code to the infrastructure layer. Separate persistence models from domain entities. This is the most labor-intensive step and can be done incrementally.

Each step makes the codebase incrementally cleaner. You don't need to finish all four to see benefits — even just extracting the domain layer into proper entities dramatically improves testability and clarity.
