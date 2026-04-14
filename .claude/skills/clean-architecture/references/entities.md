# Entities & Value Objects

## Table of Contents
1. What Entities Are (and Aren't)
2. Designing Entities
3. Value Objects
4. Validation and Invariants
5. Entity Relationships
6. Common Mistakes

---

## 1. What Entities Are (and Aren't)

Entities represent the core business concepts of your application. They contain **enterprise-wide business rules** — the rules that would exist even if there were no software system at all.

An entity encapsulates the most general and high-level business rules. If you're building an e-commerce system, `Order`, `Product`, and `Customer` are entities. They'd exist in a manual paper-based business too.

**Entities are NOT:**
- Database models or ORM objects
- API response shapes
- UI view models
- Anything tied to a specific framework or persistence mechanism

An entity knows nothing about how it's stored, displayed, or transmitted. It knows only its own business rules.

## 2. Designing Entities

### Identity

Entities have identity — two entities are the same if they have the same identity, even if their attributes differ. An `Order` with ID `123` is the same order whether it has 3 items or 5. This is what distinguishes entities from value objects.

Generate identity at construction time. The entity itself doesn't care whether the ID comes from a database sequence, a UUID generator, or any other source — that's an infrastructure detail passed in from outside.

### Structure

Every entity should:

1. **Accept all required data through its constructor.** An entity should never exist in an invalid state. If an `Order` requires a `customerId` and at least one line item, the constructor enforces that.

2. **Expose behavior, not just data.** Instead of a public `status` field that any code can change, provide `ship()`, `cancel()`, `refund()` methods that enforce the business rules around status transitions.

3. **Protect its invariants.** If an `Order` can't have a negative total, that rule lives inside the `Order` entity, not in a controller or service somewhere.

### Example Pattern (pseudocode)

```
Entity Order:
  Properties:
    id: OrderId
    customerId: CustomerId
    lineItems: List<LineItem>    (at least one required)
    status: OrderStatus          (starts as DRAFT)
    createdAt: Timestamp

  Constructor(id, customerId, lineItems):
    if lineItems is empty:
      throw "Order must have at least one line item"
    set all properties
    status = DRAFT

  addLineItem(item):
    if status is not DRAFT:
      throw "Cannot modify a submitted order"
    add item to lineItems

  submit():
    if status is not DRAFT:
      throw "Order already submitted"
    if total() <= 0:
      throw "Order total must be positive"
    status = SUBMITTED

  total():
    return sum of lineItem.price * lineItem.quantity for each item
```

Notice: no database calls, no HTTP references, no framework annotations. This is pure business logic.

## 3. Value Objects

Value objects represent concepts that are defined entirely by their attributes, not by an identity. Two `Money` objects with the same amount and currency are the same `Money` — there's no "Money ID."

Common value objects: `Email`, `Money`, `Address`, `DateRange`, `PhoneNumber`, `Coordinates`, `Quantity`.

### Characteristics

- **Immutable.** Once created, a value object never changes. Any operation that modifies it returns a new instance.
- **Equality by value.** Two value objects are equal if all their attributes are equal.
- **Self-validating.** An `Email` value object validates the email format at construction. If you have an `Email` instance, you know it's a valid email.

### Example Pattern (pseudocode)

```
ValueObject Email:
  Properties:
    address: String (immutable)

  Constructor(address):
    if not valid email format:
      throw "Invalid email address"
    set address to lowercased, trimmed value

  equals(other):
    return this.address == other.address
```

### When to Use Value Objects

Extract a value object whenever you see:
- A primitive with validation rules (email, phone, zip code)
- A group of fields that always travel together (money = amount + currency)
- A concept with its own behavior (a `DateRange` knows if a date falls within it)
- The same validation logic repeated in multiple places

Value objects prevent **primitive obsession** — the habit of using raw strings and numbers for domain concepts, scattering validation logic across the codebase.

## 4. Validation and Invariants

There are two kinds of validation in Clean Architecture:

**Domain validation** (enforced by entities and value objects): Business rules that are always true. An `Order` must have line items. An `Email` must be well-formed. These live in the domain layer and throw domain-specific errors.

**Input validation** (enforced at the boundary): Is this string parseable as a number? Is this required field present in the request? This lives in the adapter or use case layer, before the data reaches an entity.

The key distinction: domain validation is about **business rules**. Input validation is about **data format**. Don't pollute entities with input-format concerns, and don't scatter business rules across adapters.

### Invariant Enforcement Pattern

Entities enforce invariants at two points:
1. **At construction** — An entity should never be created in an invalid state
2. **At mutation** — Every method that changes state checks that the change is legal

If an invariant is violated, throw a domain-specific error, not a generic exception. `OrderAlreadySubmittedError`, not `RuntimeError("bad state")`.

## 5. Entity Relationships

Entities reference each other by identity, not by direct object reference. An `Order` holds a `customerId`, not a `Customer` object. This is important because:

- It prevents the domain layer from needing to fetch related data (that's a use case concern)
- It keeps entities focused on their own rules
- It avoids circular dependency tangles

When a business rule requires data from multiple entities (e.g., "a customer's total outstanding orders can't exceed their credit limit"), that rule belongs in a **use case**, not inside either entity. The use case fetches both pieces of data and enforces the cross-entity rule.

### Aggregates

When multiple entities are so tightly coupled that they must be consistent together, group them into an **aggregate**. The aggregate has a root entity that controls all access.

`Order` and `LineItem` form a natural aggregate — you never modify a line item independently of its order. `Order` is the aggregate root. External code accesses line items only through the `Order` entity.

Rules for aggregates:
- Only the root entity is referenced from outside the aggregate
- The root ensures the consistency of the entire aggregate
- Other entities within the aggregate are accessed through the root
- Cross-aggregate references use IDs, not object references

## 6. Common Mistakes

**Anemic entities.** Entities that are just bags of data with getters and setters, with all business logic living in "service" classes. This defeats the purpose — the entity should embody the business rules, not be a passive data holder.

**Framework contamination.** Adding ORM annotations, serialization attributes, or framework-specific decorators to entities. The entity is in the innermost circle — it should have zero dependencies on external libraries. Create separate persistence models in the infrastructure layer and map between them.

**God entities.** An entity that tries to do too much. If your `User` entity handles authentication, profile management, notification preferences, billing, and permissions, it needs to be broken into separate entities or value objects.

**Leaking identity generation.** Entities that call a database or UUID library directly to generate their own IDs. Identity is provided from outside — the use case or a factory handles generation and passes the ID into the constructor.
