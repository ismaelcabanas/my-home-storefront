# SPDD Analysis: Inventory Item State Transitions API

## Original Business Requirement

# [STORY-001-002] Inventory Item State Transitions API Development

## Background

El sistema de inventario doméstico permite a los usuarios actualizar el estado de sus productos mediante acciones semánticas directas ("reponer", "marcar como bajo", "agotar") en lugar de modificar cantidades numéricas. Esto reduce la fricción y permite una actualización rápida con un solo clic.

Esta historia implementa los tres endpoints dedicados para transicionar el estado de un producto, gestionando automáticamente el indicador de lista de la compra según el nuevo estado.

## Business Value

- Permite al usuario actualizar el estado de su despensa con un solo clic mediante acciones semánticas
- Automatiza la gestión de la lista de la compra: productos en estado crítico se marcan automáticamente como "pendientes de compra"
- Reduce errores al usar endpoints dedicados con semántica clara en lugar de un endpoint genérico de actualización
- Identifica instantáneamente qué productos necesitan reposición

## Dependencies and Assumptions

- **Prerequisites**: [STORY-001-001] Create Inventory Item — debe existir la capacidad de crear productos
- **Data assumptions**: Los productos a transicionar ya existen en el sistema con un ID válido
- **Integration points**: Ninguno en esta historia
- **Business constraints**: Las transiciones de estado actualizan automáticamente el indicador `requires_purchase`

## Scope In

- Implementar `POST /api/inventory/items/{id}/replenish` para cambiar estado a "Available"
- Implementar `POST /api/inventory/items/{id}/mark-low` para cambiar estado a "Low"
- Implementar `POST /api/inventory/items/{id}/deplete` para cambiar estado a "Depleted"
- Al reponer: establecer `requires_purchase: false`
- Al marcar como bajo o agotar: establecer `requires_purchase: true`
- Validar que el producto exista antes de transicionar

## Scope Out

- Creación de productos (historia anterior)
- Listado de productos
- Listado de productos pendientes de compra (futura historia)
- Historial de transiciones de estado
- Notificaciones al usuario
- Validación de transiciones permitidas (cualquier estado puede transicionar a cualquier otro)

## Acceptance Criteria

### AC1: Reponer producto agotado

**Given** un producto "Leche" en estado "Depleted" con `requires_purchase: true`
**When** el usuario compra el producto y el sistema invoca `POST /api/inventory/items/{id}/replenish`
**Then** el sistema devuelve HTTP 200 con:
  - Estado actualizado a "Available"
  - Indicador de compra: `requires_purchase: false`
  - El producto deja de aparecer como pendiente de compra

### AC2: Reponer producto con stock bajo

**Given** un producto "Aceite" en estado "Low" con `requires_purchase: true`
**When** el usuario repone el producto y el sistema invoca `POST /api/inventory/items/{id}/replenish`
**Then** el sistema devuelve HTTP 200 con:
  - Estado actualizado a "Available"
  - Indicador de compra: `requires_purchase: false`

### AC3: Marcar producto como bajo

**Given** un producto "Arroz" en estado "Available" con `requires_purchase: false`
**When** el usuario observa que queda poco arroz y el sistema invoca `POST /api/inventory/items/{id}/mark-low`
**Then** el sistema devuelve HTTP 200 con:
  - Estado actualizado a "Low"
  - Indicador de compra: `requires_purchase: true` (se añade automáticamente a la lista de compra)

### AC4: Agotar producto desde estado suficiente

**Given** un producto "Café" en estado "Available" con `requires_purchase: false`
**When** el usuario consume todo el café y el sistema invoca `POST /api/inventory/items/{id}/deplete`
**Then** el sistema devuelve HTTP 200 con:
  - Estado actualizado a "Depleted"
  - Indicador de compra: `requires_purchase: true` (se añade automáticamente a la lista de compra)

### AC5: Agotar producto desde estado bajo

**Given** un producto "Pasta" en estado "Low" con `requires_purchase: true`
**When** el usuario consume toda la pasta y el sistema invoca `POST /api/inventory/items/{id}/deplete`
**Then** el sistema devuelve HTTP 200 con:
  - Estado actualizado a "Depleted"
  - Indicador de compra: `requires_purchase: true` (permanece en la lista de compra)

### AC6: Transición idempotente - reponer producto ya suficiente

**Given** un producto "Huevos" ya en estado "Available" con `requires_purchase: false`
**When** el sistema invoca `POST /api/inventory/items/{id}/replenish`
**Then** el sistema devuelve HTTP 200 con:
  - Estado: "Available" (sin cambio)
  - Indicador de compra: `requires_purchase: false` (sin cambio)

### AC7: Producto no encontrado al reponer

**Given** un ID de producto que no existe en el sistema (por ejemplo, UUID "550e8400-e29b-41d4-a716-446655440000")
**When** el sistema invoca `POST /api/inventory/items/550e8400-e29b-41d4-a716-446655440000/replenish`
**Then** el sistema devuelve HTTP 404 indicando que el producto no fue encontrado

### AC8: Producto no encontrado al marcar como bajo

**Given** un ID de producto que no existe en el sistema
**When** el sistema invoca `POST /api/inventory/items/{id}/mark-low`
**Then** el sistema devuelve HTTP 404 indicando que el producto no fue encontrado

### AC9: Producto no encontrado al agotar

**Given** un ID de producto que no existe en el sistema
**When** el sistema invoca `POST /api/inventory/items/{id}/deplete`
**Then** el sistema devuelve HTTP 404 indicando que el producto no fue encontrado

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **InventoryItem**: Aggregate representing a product in the pantry — owns id, name, state, requires_purchase flag, and createdAt; extends AggregateRoot; provides factory method `create()` and static method `fromPrimitives()`
- **InventoryItemState**: Value object for qualitative stock state — constrained to "Available", "Low", "Depleted"; provides static factory methods (Available(), Low(), Depleted()); includes business logic method `derivesRequiresPurchase()` that returns false only for "Available" state
- **InventoryItemRepository**: Domain interface for persistence — currently only defines `save(item)` method; follows repository pattern with single abstraction
- **InventoryItemCreator**: Application service for creating inventory items — orchestrates ID generation, aggregate creation, and persistence; serves as reference pattern for use case naming
- **PostgresInventoryItemRepository**: Infrastructure implementation — extends PostgresRepository base class; implements save() with INSERT statement; provides toAggregate() for reconstruction from database rows
- **HttpNextResponse**: Utility for standardized HTTP responses — includes ok(), notFound(), badRequest(), created() methods; returns NextResponse with appropriate status codes and error structure
- **PostgresRepository**: Generic base class for PostgreSQL repositories — provides execute(), searchOne(), searchMany() template methods; handles SQL execution and row-to-aggregate mapping
- **diod.config.ts**: DI container configuration — uses @Service() decorators; registers repositories as implementations of domain interfaces; registers application services
- **Database schema**: `inventory.inventory_items` table exists with columns (id UUID, name VARCHAR, state VARCHAR, requires_purchase BOOLEAN, created_at TIMESTAMPTZ)

### New Concepts Required

- **InventoryItemReplenisher**: Application service (use case) for transitioning item to "Available" state — orchestrates item retrieval, state update, and persistence
- **InventoryItemLowMarker**: Application service (use case) for transitioning item to "Low" state — orchestrates item retrieval, state update, and persistence
- **InventoryItemDepleter**: Application service (use case) for transitioning item to "Depleted" state — orchestrates item retrieval, state update, and persistence
- **InventoryItemNotFoundError**: Domain error for not-found scenarios — extends existing error pattern (like InvalidInventoryItemNameError)
- **Repository read method**: `searchById()` or similar — needed to retrieve existing item by ID before state transition; currently only save() exists
- **API route handlers**: Three Next.js route handlers at `/api/inventory/items/[id]/replenish/route.ts`, `/api/inventory/items/[id]/mark-low/route.ts`, `/api/inventory/items/[id]/deplete/route.ts` — follow existing POST route pattern

### Key Business Rules

- **State-to-purchase-flag derivation**: When state is "Available", requires_purchase must be false; when state is "Low" or "Depleted", requires_purchase must be true — enforced by domain logic, not independent state
- **State transition unrestricted**: Any state can transition to any other state (no state machine validation) — simplifies UX, reduces validation complexity
- **Idempotent transitions**: Transitioning to the same state is allowed and succeeds without error — AC6 demonstrates "replenish" on already "Available" item returns success
- **Existence validation**: All three operations must verify the item exists before attempting state transition — AC7, AC8, AC9 specify 404 for non-existent IDs
- **Automatic shopping list management**: Setting state to "Low" or "Depleted" automatically adds item to shopping list via requires_purchase: true; conversely, "Available" removes it from shopping list

---

## Strategic Approach

### Solution Direction

Extend the existing `inventory` bounded context with three state transition use cases following the established hexagonal architecture pattern. The flow for each endpoint will be:

1. Next.js API route receives POST request at `/api/inventory/items/{id}/{action}`
2. Route extracts ID from URL path, delegates to application service
3. Application service orchestrates: retrieve item by ID, create new aggregate with updated state, persist updated item
4. Repository updates the corresponding row in `inventory.inventory_items` table
5. Return updated item primitives with HTTP 200 (or 404 if not found)

This mirrors the existing `InventoryItemCreator` pattern but introduces a read-then-write flow (retrieve existing item, modify state, persist) versus the write-only flow of creation.

### Key Design Decisions

- **Repository method for retrieval**: Add searchById() to domain interface vs. create separate read-side — Recommendation: Add searchById() to InventoryItemRepository interface. Maintains single repository abstraction, follows existing pattern where repositories handle both read and write. The PostgresRepository base class already provides searchOne() template method.

- **Aggregate state mutation**: Modify existing aggregate instance vs. create new instance with new state — Recommendation: Create new aggregate instance with updated state (immutable approach). InventoryItem already has readonly state field and fromPrimitives() factory; creating new instance maintains immutability and aligns with DDD aggregate patterns.

- **Persistence strategy**: UPDATE vs. DELETE+INSERT vs. upsert — Recommendation: Use UPDATE statement to modify existing row. The table already exists with data; UPDATE is semantically correct and more efficient than delete+insert. Follows typical ORM/repository update patterns.

- **Three separate application services vs. generic state transition service**: Create InventoryItemReplenisher, InventoryItemLowMarker, InventoryItemDepleter vs. single StateTransitioner(action) — Recommendation: Three separate services. Provides explicit domain language (replenish, mark-low, deplete), each service is single-purpose (SRP), and mirrors the three distinct API endpoints specified in requirements.

- **Error handling for not-found**: Domain-specific error vs. generic not-found response — Recommendation: Create InventoryItemNotFoundError domain error class. Follows existing pattern (InvalidInventoryItemNameError), allows domain-level error semantics, and can be caught in API route for appropriate HTTP 404 response.

### Alternatives Considered

- **Generic state endpoint**: Rejected — Requirement specifies three dedicated endpoints with semantic URLs (`/replenish`, `/mark-low`, `/deplete`). Generic endpoint like `POST /api/inventory/items/{id}` with `{state}` body parameter would be less expressive and harder to validate.

- **State transition validation**: Rejected — Scope explicitly excludes "validación de transiciones permitidas" (any state can transition to any other). Adding a state machine would be over-engineering given current business requirements.

- **PUT vs. POST**: Rejected — While these operations could be modeled as PUT (update existing resource), the requirement uses POST semantics for "actions" on resources (transition to state). POST is more appropriate for state transition operations that are not simple CRUD updates.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **Response JSON structure**: ACs specify return values (state, requires_purchase) but not the complete JSON structure. Assumed: Return full updated item primitives (id, name, state, requiresPurchase, createdAt) matching the create endpoint response structure for consistency.

- **Error response format**: 404 response format not specified beyond "indicating que el producto no fue encontrado". Assumed: Use existing HttpNextResponse.notFound() which returns `{error: {type, description, params}}` structure.

- **UUID format in URL**: Not specified whether UUID validation should occur beyond database lookup. Assumed: Database non-existence is sufficient validation; premature UUID format validation not required.

- **Idempotent transition behavior for all states**: AC6 only specifies idempotent behavior for replenish (Available → Available). Assumed: Mark-low on already Low and deplete on already Depleted should also succeed idempotently (same-state transition is allowed).

- **Concurrent state updates**: Not specified what happens if two users simultaneously update the same item's state. Assumed: Last write wins; no optimistic concurrency control required for this use case.

### Edge Cases

- **Invalid UUID format**: What if client sends malformed UUID (e.g., "not-a-uuid")? Assumed: Database query will return no results (PostgreSQL UUID type validates), leading to 404 response. No need for explicit pre-validation.

- **Immediately deleted item**: What if item exists when read but is deleted before write? Assumed: Extremely rare edge case; database UPDATE will affect 0 rows, can be treated as not-found (404) or no-op (200 with unchanged state). 404 is more consistent.

- **Whitespace in UUID parameter**: URL path parameter with whitespace (e.g., `/items/ uuid /replenish`). Assumed: Next.js route matching or UUID parsing will handle; unlikely to reach application layer.

- **Very rapid successive calls**: Client calls replenish then immediately deplete same item. Assumed: Each request is independent; last one wins. No rate limiting or debouncing required.

### Technical Risks

- **New repository method**: Adding searchById() to InventoryItemRepository requires interface change and implementation in PostgresInventoryItemRepository — Low risk, straightforward extension following existing PostgresRepository.searchOne() pattern.

- **UPDATE vs. INSERT migration**: Current PostgresInventoryItemRepository only implements save() with INSERT. Need to implement UPDATE logic for state transitions — Medium risk, need to decide between separate update() method vs. smart save() that detects insert vs. update. Could use INSERT ... ON CONFLICT or separate UPDATE statement.

- **DI container registration**: Three new application services must be registered in diod.config.ts — Low risk, follows existing registration pattern for InventoryItemCreator.

- **API route structure**: Next.js dynamic routes with `[id]` segment and action-specific subdirectories — Low risk, follows standard Next.js App Router pattern. Need to verify directory structure matches requirement (`/api/inventory/items/[id]/replenish/route.ts`).

- **Aggregate reconstruction from database**: Current toAggregate() in PostgresInventoryItemRepository uses fromPrimitives() which expects state to be valid string. Database state values should match enum values — Low risk, schema and domain are aligned (Available, Low, Depleted).

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| AC1 | Replenish depleted item → Available with requires_purchase: false | Yes | Requires UPDATE query to modify state and requires_purchase columns |
| AC2 | Replenish low item → Available with requires_purchase: false | Yes | Same flow as AC1, different starting state |
| AC3 | Mark as low → Low with requires_purchase: true | Yes | Requires Low state transition and purchase flag calculation |
| AC4 | Deplete from available → Depleted with requires_purchase: true | Yes | Requires Depleted state transition and purchase flag calculation |
| AC5 | Deplete from low → Depleted with requires_purchase: true | Yes | Same flow as AC4, different starting state |
| AC6 | Idempotent replenish (already Available) | Yes | Business logic already supports same-state transition; should return 200 |
| AC7 | Not found on replenish | Yes | Requires searchById() returning null → 404 response |
| AC8 | Not found on mark-low | Yes | Same as AC7, different endpoint |
| AC9 | Not found on deplete | Yes | Same as AC7, different endpoint |

**Coverage Summary**: All 9 ACs are addressable with the proposed approach. No gaps identified in the strategic direction.

---

## Implementation Guidance for REASONS Canvas Phase

When generating the REASONS Canvas structured prompt, consider the following strategic constraints that should inform detailed design:

1. **Repository enhancement**: The PostgresInventoryItemRepository needs an update mechanism. Consider whether to:
   - Add a separate `update(item: InventoryItem)` method alongside `save(item)`
   - Make `save(item)` smart (detect insert vs. update based on existence)
   - Use PostgreSQL `INSERT ... ON CONFLICT DO UPDATE` for upsert semantics

2. **API route directory structure**: Next.js App Router requires specific file structure:
   - `/api/inventory/items/[id]/replenish/route.ts`
   - `/api/inventory/items/[id]/mark-low/route.ts`
   - `/api/inventory/items/[id]/deplete/route.ts`
   Each file exports a named POST handler.

3. **Domain events consideration**: While InventoryItem extends AggregateRoot (has domain event support), this requirement doesn't specify events. Consider whether state transitions should emit domain events (e.g., `InventoryItemDepleted`, `InventoryItemReplenished`) for future extensibility (shopping list notifications, analytics).

4. **Testing strategy**: Follow established patterns:
   - Unit tests for each application service using mock repository
   - Object mother for creating test InventoryItem instances (InventoryItemMother)
   - API integration tests using next-test-api-route-handler (already in dependencies)

5. **Transaction boundaries**: Each state transition is a single UPDATE operation — no multi-step transactions required. However, consider the read-then-write pattern for race conditions (item deleted between read and write).

6. **Error response consistency**: Ensure all three endpoints return identical 404 response format using HttpNextResponse.notFound(). Consider whether 404 should include the invalid ID in response for debugging.
