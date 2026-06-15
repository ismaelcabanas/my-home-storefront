# SPDD Analysis: List Shopping List API

## Original Business Requirement

# List Shopping List

## Background

Cuando los usuarios marcan productos como "Low" (bajo) o "Depleted" (agotado), estos se añaden automáticamente a la lista de la compra mediante el indicador `requires_purchase: true`. Esta historia implementa el endpoint dedicado para recuperar únicamente los productos que necesitan ser comprados, proporcionando una vista filtrada y optimizada para la experiencia de compra.

## Business Value

- Permite al usuario acceder instantáneamente a su lista de la compra sin tener que filtrar manualmente
- Optimiza la experiencia de compra mostrando solo los productos relevantes
- Facilita el proceso de compra en supermercado mostrando qué productos adquirir
- Complementa las acciones semánticas (replenish, mark-low, deplete) cerrando el ciclo de gestión de inventario

## Dependencies and Assumptions

- **Prerequisites**: 
  - [STORY-001-001] Create Inventory Item — deben existir productos
  - [STORY-001-002] Inventory Item State Transitions — debe existir el indicador `requires_purchase`
  - **Data assumptions**: Existen productos con `requires_purchase: true` (estado Low o Depleted)
  - **Integration points**: Ninguno en esta historia
  - **Business constraints**: 
    - El listado devuelve SOLO productos con `requires_purchase: true`
    - No se requiere filtrado adicional por parte del usuario

## Scope In

- Implementar `GET /api/inventory/shopping-list` para listar productos pendientes de compra
- Implementar paginación mediante scroll infinito usando cursor basado en timestamp (interno)
- Parámetros de consulta:
  - `limit` (opcional, default 20): número de items a retornar
  - `cursor` (opcional): token opaco para obtener el siguiente lote de productos
- Filtrado automático: solo productos con `requires_purchase: true`
- Retornar para cada producto:
  - ID único
  - Nombre
  - Estado actual (Low/Depleted)
- Ordenamiento alfabético ascendente por nombre
- Retornar metadatos de paginación:
  - `items`: array de productos
  - `nextCursor`: token para siguiente página (null si no hay más)
  - `hasMore`: boolean indicando si existen más productos

## Scope Out

- Modificación de productos en la lista de compra (usar endpoints de transición de estado)
- Marcar productos como comprados (usar `POST /api/inventory/items/{id}/replenish`)
- Sugerencias de cantidades a comprar
- Organización por categorías o pasillos de supermercado
- Compartir lista de la compra con otros usuarios
- Historial de compras anteriores
- Exposición de `requires_purchase` en la respuesta (redundante, todos los items lo tienen a true)
- Exposición de timestamp de creación en la respuesta (usado internamente para cursor)

## Acceptance Criteria

### AC1: Listado exitoso de productos pendientes de compra

**Given** existen productos: "Leche" (Available, requires_purchase: false), "Aceite" (Low, requires_purchase: true), "Café" (Depleted, requires_purchase: true)
**When** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array solo con ["Aceite", "Café"] (excluye "Leche")
  - `nextCursor`: null si no hay más productos, o token si existen más
  - `hasMore`: false o true según corresponda
  - Cada producto incluye: ID, nombre, estado

### AC2: Lista de la compra vacía

**Given** todos los productos están en estado "Available" con `requires_purchase: false`
**When** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array vacío []
  - `nextCursor`: null
  - `hasMore`: false

### AC3: Scroll infinito con múltiples productos pendientes

**Given** existen 35 productos con `requires_purchase: true` mezclados con otros que no lo requieren
**When** el sistema invoca `GET /api/inventory/shopping-list?limit=15`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con exactamente 15 productos (todos con requires_purchase: true internamente)
  - `nextCursor`: token para obtener los siguientes productos pendientes
  - `hasMore`: true (quedan más productos pendientes)

### AC4: Respeta ordenamiento alfabético en lista de compra

**Given** existen productos pendientes: "Zanahoria" (Depleted), "Arroz" (Low), "Manzana" (Depleted), "Tomate" (Low)
**When** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con productos en orden: "Arroz", "Manzana", "Tomate", "Zanahoria" (alfabético A-Z)

### AC5: Solo incluye productos con requires_purchase true

**Given** existen productos:
  - "Pan" (Available, requires_purchase: false)
  - "Queso" (Available, requires_purchase: true)
  - "Yogur" (Low, requires_purchase: true)
  - "Miel" (Depleted, requires_purchase: true)
**When** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array solo con ["Queso", "Yogur", "Miel"]
  - NO incluye "Pan" que tiene requires_purchase: false

### AC6: Actualización de lista después de reponer producto

**Given** "Aceite" está en lista de compra (Low, requires_purchase: true) y aparece en `GET /api/inventory/shopping-list`
**When** el usuario repone "Aceite" invocando `POST /api/inventory/items/{id}/replenish`
**Then** el producto actualiza su estado a "Available" y `requires_purchase: false`
**And** una nueva invocación a `GET /api/inventory/shopping-list` NO incluye "Aceite"

### AC7: Cursor funciona independientemente de productos no pendientes

**Given** existen 50 productos totales, de los cuales 12 tienen `requires_purchase: true`
**When** el sistema navega mediante cursores con `limit=5`
**Then** los cursores omiten automáticamente los productos con `requires_purchase: false`
**And** se obtienen todos los 12 productos pendientes en 3 páginas (5 + 5 + 2)

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **InventoryItem**: Aggregate root representing an inventory product with id, name, state, and derived `requiresPurchase` property. The `requiresPurchase` flag is derived from state (Available → false, Low/Depleted → true) via `InventoryItemState.derivesRequiresPurchase()`. Located in `src/contexts/inventory/inventory-items/domain/InventoryItem.ts`.

- **InventoryItemState**: Value object encapsulating the three possible states — Available, Low, Depleted. Contains business logic `derivesRequiresPurchase()` which returns `!isAvailable()`. State transitions are managed through separate application services (InventoryItemLowMarker, InventoryItemDepleter, InventoryItemReplenisher). Located in `src/contexts/inventory/inventory-items/domain/InventoryItemState.ts`.

- **InventoryItemRepository**: Abstract repository interface with methods `save()`, `searchById()`, `findById()`, and `searchAll(limit, cursor)`. The `searchAll` method already implements cursor-based pagination returning `PaginatedInventoryItems`. Located in `src/contexts/inventory/inventory-items/domain/InventoryItemRepository.ts`.

- **PostgresInventoryItemRepository**: Concrete repository implementation using PostgreSQL with existing cursor-based pagination on the composite index `(name, created_at)`. The pagination logic fetches `limit + 1` items to determine if more pages exist, and encodes cursors as base64 JSON containing `{name, createdAt}`. Located in `src/contexts/inventory/inventory-items/infrastructure/PostgresInventoryItemRepository.ts`.

- **PaginatedInventoryItems**: Response interface with `items: InventoryItemPrimitives[]`, `nextCursor: string | null`, and `hasMore: boolean`. Includes factory functions `emptyPaginatedInventoryItems()` and `createPaginatedInventoryItems()` that ensure consistency (nextCursor is null when hasMore is false). Located in `src/contexts/inventory/inventory-items/domain/PaginatedInventoryItems.ts`.

- **Cursor**: Value object for pagination tokens, encoding `{name: string, createdAt: Date}` as base64 JSON. Used internally for pagination, not exposed in domain language. Provides `decode(token)` and `encode()` methods with validation. Located in `src/contexts/inventory/inventory-items/domain/Cursor.ts`.

- **InventoryItemLister**: Application service for listing all inventory items without filtering. Implements input validation for limit (1-100, default 20) and delegates to `repository.searchAll()`. Located in `src/contexts/inventory/inventory-items/application/list/InventoryItemLister.ts`.

- **HttpNextResponse**: Shared utility class for consistent HTTP responses with static methods `ok()`, `created()`, `badRequest()`, `notFound()`, `internalServerError()`. Located in `src/contexts/shared/infrastructure/http/HttpNextResponse.ts`.

### New Concepts Required

- **ShoppingList**: A specialized read view or application service that filters inventory items by `requires_purchase: true`. This could be implemented as:
  - A new application service `ShoppingItemLister` that calls a filtered repository method
  - A new repository method `searchByRequiresPurchase(limit, cursor)` that adds a WHERE clause
  - Or a parameterized `searchAll(filters)` approach
  
  The key distinction from existing `InventoryItemLister` is the automatic filtering to only items requiring purchase. This is not a new domain concept but a specialized use case of existing InventoryItem aggregate.

- **ShoppingListAPIRoute**: New API route at `GET /api/inventory/shopping-list` that follows existing Next.js 16 route patterns with `reflect-metadata` import, query parameter parsing, and HttpNextResponse for consistent responses.

### Key Business Rules

- **Filtering invariant**: Shopping list MUST only contain items where `requires_purchase: true` (derived from state being Low or Depleted, not Available). This is enforced at the data retrieval layer, not in the domain.

- **Pagination consistency**: Cursor pagination must work correctly across filtered results — when `requires_purchase: false` items exist between cursor position and the next `requires_purchase: true` item, the query should skip them transparently. This requires the WHERE clause to filter before cursor evaluation.

- **Alphabetical ordering**: Items must be ordered by `name ASC, created_at ASC` regardless of state filtering. This is already supported by the existing composite index.

- **State-requires_purchase relationship**: The `requires_purchase` flag is derived from state, not stored independently. Available → false, Low/Depleted → true. This logic lives in `InventoryItemState.derivesRequiresPurchase()` and is persisted to the database via `InventoryItem.toPrimitives()`.

---

## Strategic Approach

### Solution Direction

The overall approach follows the existing hexagonal architecture patterns already established in the codebase:

1. **Application Layer**: Create a new `ShoppingItemLister` application service (one-use-case-per-class pattern) that handles the shopping list use case. This service will:
   - Accept `limit` and `cursor` parameters with validation (1-100, default 20)
   - Delegate to a new repository method that filters by `requires_purchase: true`
   - Return `PaginatedInventoryItems` for API response serialization

2. **Domain/Repository Layer**: Extend `InventoryItemRepository` interface with a new method `searchByRequiresPurchase(limit, cursor)` that:
   - Adds a WHERE clause for `requires_purchase = true` in the SQL query
   - Reuses existing cursor pagination logic (name, created_at comparison)
   - Returns the same `PaginatedInventoryItems` interface

3. **Infrastructure/Postgres**: Implement `searchByRequiresPurchase()` in `PostgresInventoryItemRepository` with:
   - SQL query: `SELECT * FROM inventory.inventory_items WHERE requires_purchase = true AND (name > cursor.name OR (name = cursor.name AND created_at > cursor.createdAt)) ORDER BY name ASC, created_at ASC LIMIT fetchLimit`
   - The filter applies before cursor evaluation to ensure AC7 (cursor works independently of non-pending items)
   - Leverages existing composite index on `(name, created_at)` for performance

4. **API Layer**: Create new route at `src/app/api/inventory/shopping-list/route.ts` following existing patterns:
   - Import `"reflect-metadata"` at top
   - Parse `limit` and `cursor` query parameters
   - Inject `ShoppingItemLister` from DIOD container
   - Handle `InvalidCursorError` with 400 response
   - Return 200 with `HttpNextResponse.ok(paginatedItems)`
   - Error propagation to global handler

5. **Dependency Injection**: Register `ShoppingItemLister` in `diod.config.ts` with `@Service()` decorator and `builder.registerAndUse()` pattern.

### Key Design Decisions

- **Separate application service vs. parameterized existing service**: Create a new `ShoppingItemLister` rather than adding a `filter` parameter to `InventoryItemLister`. 
  - **Rationale**: Follows the established one-use-case-per-class pattern visible in the codebase (Creator, Lister, Replenisher, LowMarker, Depleter are all separate classes). This keeps each service focused and aligns with the hexagonal architecture principle of use case clarity.

- **New repository method vs. parameterized existing method**: Add `searchByRequiresPurchase()` to repository interface rather than parameterizing `searchAll()`.
  - **Trade-off**: New method requires interface modification but provides explicit intent and separation of concerns. Parameterizing would create ambiguity about what "all" means.
  - **Rationale**: The existing `searchAll()` method semantically means "all items" (as seen in STORY-001-003). Adding a filter would violate this semantic contract. A dedicated method makes the filtering intent explicit in the domain layer.

- **WHERE clause placement in SQL**: Apply `requires_purchase = true` filter before cursor comparison, not after.
  - **Trade-off**: This could theoretically skip cursor positions if the cursor item is filtered out, but ensures AC7 compliance.
  - **Rationale**: AC7 explicitly requires that "los cursores omiten automáticamente los productos con `requires_purchase: false`". The filter must apply first to ensure pagination works correctly over the filtered subset.

- **Reuse existing PaginatedInventoryItems vs. new DTO**: Reuse the existing `PaginatedInventoryItems` interface rather than create a shopping-list-specific response shape.
  - **Trade-off**: The response will include `requiresPurchase: true` for all items (technically redundant per Scope Out), but this maintains consistency with existing APIs.
  - **Rationale**: The Scope Out section says "Exposición de `requires_purchase` en la respuesta (redundante, todos los items lo tienen a true)" is out of scope, meaning we don't need to create a custom DTO. The existing interface already matches the AC requirements (ID, name, state, pagination metadata).

### Alternatives Considered

- **Alternative 1: Filter in application layer after fetching all items**: Fetch all items via `searchAll()` then filter in `ShoppingItemLister`.
  - **Rejected**: This would break cursor pagination (cursors would point to positions in the full list, not the filtered list). AC7 would fail. Database-level filtering is required for correct pagination behavior.

- **Alternative 2: Add a separate `shopping_list` table**: Create a dedicated table that syncs with inventory items when state changes.
  - **Rejected**: Introduces data synchronization complexity and eventual consistency issues. The `requires_purchase` flag is already derived from state, so a separate table would be redundant and create additional failure modes.

- **Alternative 3: Use `searchAll()` with a filter parameter**: Extend `InventoryItemLister` with an optional `filters` parameter.
  - **Rejected**: Would create a multi-purpose service that violates the one-use-case-per-class pattern established in the codebase. The existing architecture shows clear separation: Creator, Lister, Replenisher, LowMarker, Depleter are all separate services.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **Cursor behavior when last item in page is filtered**: If a cursor points to an item that becomes `requires_purchase: false` (e.g., user replenishes an item), the next page fetch should still work correctly.
  - **Clarification needed**: Should the cursor be validated against current state, or should we use "seek" logic (find first item after cursor position that matches the filter)?
  - **Resolution approach**: The SQL query `WHERE requires_purchase = true AND (name > cursor.name OR ...)` naturally handles this by finding the first matching item after the cursor position, regardless of whether the cursor item itself still matches.

- **Edge case with duplicate names at same timestamp**: The composite key is `(name, created_at)`, but if multiple items have the same name and timestamp (unlikely with UUID IDs but theoretically possible), pagination could skip items.
  - **Clarification needed**: Is this a realistic scenario given UUID-based IDs?
  - **Assumption**: The `created_at` column has sufficient granularity (TIMESTAMPTZ) to make duplicates extremely rare. The existing `searchAll()` implementation uses the same composite key and this hasn't been identified as an issue.

### Edge Cases

- **Empty shopping list**: AC2 covers this explicitly. The endpoint should return `{items: [], nextCursor: null, hasMore: false}` rather than a 404 or empty response body.
  - **Impact**: Low — covered by existing `emptyPaginatedInventoryItems()` factory function.

- **Single item in shopping list**: Pagination metadata should be `{items: [item], nextCursor: null, hasMore: false}`.
  - **Impact**: Low — existing pagination logic handles this by fetching `limit + 1` items and comparing counts.

- **Cursor from previous state becomes invalid**: User receives page 1, then some items are replenished, then user requests page 2 with stale cursor.
  - **Impact**: Medium — the cursor should still work by seeking to the next matching item after the cursor position. The SQL query structure handles this, but it should be tested explicitly.

- **Concurrent state changes during pagination**: User browses shopping list while another client replenishes items.
  - **Impact**: Low — eventual consistency is acceptable for this use case. The next refresh will show updated state.

### Technical Risks

- **Index usage with WHERE clause**: The existing composite index on `(name, created_at)` may not be optimally used when adding `WHERE requires_purchase = true`.
  - **Impact**: Medium — PostgreSQL may need to scan more rows if the index doesn't include the filter column.
  - **Mitigation**: Consider adding a partial index or composite index including `requires_purchase` if performance testing reveals issues. For initial implementation, test with EXPLAIN ANALYZE to verify query plan.

- **Repository interface expansion**: Adding `searchByRequiresPurchase()` to the interface could impact other implementations (if any exist beyond PostgresInventoryItemRepository).
  - **Impact**: Low — currently only one repository implementation exists. Future implementations would need to implement the new method, but this is expected when extending an interface.

- **Dependency injection registration**: Forgetting to register `ShoppingItemLister` in `diod.config.ts` would cause runtime errors.
  - **Impact**: Low — the pattern is well-established in the codebase and would be caught during testing.

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| AC1 | Successful listing of pending items | Yes | Covered by filtering by `requires_purchase = true` and returning `PaginatedInventoryItems` |
| AC2 | Empty shopping list | Yes | Covered by `emptyPaginatedInventoryItems()` factory when no items match filter |
| AC3 | Infinite scroll with multiple pending items | Yes | Covered by existing cursor pagination logic with `limit + 1` fetch pattern |
| AC4 | Alphabetical ordering respected | Yes | Covered by `ORDER BY name ASC, created_at ASC` in SQL query |
| AC5 | Only includes items with requires_purchase true | Yes | Covered by WHERE clause filtering in repository implementation |
| AC6 | List updates after replenishing item | Yes | Covered by existing `InventoryItemReplenisher` which updates state to Available (requires_purchase becomes false) |
| AC7 | Cursor works independently of non-pending items | Yes | Covered by WHERE clause placement before cursor comparison in SQL query |

**Coverage Assessment**: All 7 acceptance criteria are fully addressable with the proposed approach. No gaps identified.

---

## Implementation Complexity Assessment

**Estimated complexity**: Low to Medium

**Factors contributing to low complexity**:
- Existing patterns can be reused (application service, repository method, API route)
- Domain concepts are already well-established
- Pagination logic is already implemented
- No new domain concepts or business rules need to be created

**Factors contributing to medium complexity**:
- New repository method requires careful SQL construction to ensure AC7 compliance
- Index performance should be verified with the additional WHERE clause
- Cursor pagination with filtering requires precise SQL ordering

**Recommended implementation order**:
1. Add `searchByRequiresPurchase()` to `InventoryItemRepository` interface
2. Implement in `PostgresInventoryItemRepository` with SQL query
3. Create `ShoppingItemLister` application service
4. Add dependency injection configuration
5. Create API route `GET /api/inventory/shopping-list`
6. Add tests for all acceptance criteria (especially AC7 for cursor behavior with filtered items)

---

## Codebase Context Summary

**Project type**: Fullstack (Next.js 16 with API routes + Hexagonal Architecture backend)

**Tech stack**:
- Frontend: Next.js 16.1.1, React 19.2.0
- Backend: TypeScript 5.9.3, DIOD 3.0.0 (dependency injection)
- Database: PostgreSQL with `postgres` package driver
- Validation: Zod 4.1.12
- Architecture: Hexagonal/Onion with clear layer separation

**Existing inventory context patterns**:
- Domain: InventoryItem aggregate, InventoryItemState value object, Cursor value object, PaginatedInventoryItems interface
- Application: Separate use case services (Creator, Lister, Replenisher, LowMarker, Depleter)
- Infrastructure: PostgresInventoryItemRepository with cursor-based pagination on (name, created_at)
- API: Next.js routes with reflect-metadata, HttpNextResponse utilities, consistent error handling

**Architecture conventions to follow**:
- One use case per application service class
- Repository interface in domain, implementation in infrastructure
- `@Service()` decorator for DIOD registration
- `import "reflect-metadata"` at top of API routes
- HttpNextResponse for consistent HTTP responses
- Cursor pagination with limit validation (1-100, default 20)
- Error propagation to global handler for unexpected errors

---

## Next Steps

This enriched context provides the strategic foundation for REASONS Canvas generation. The analysis has:

1. ✅ Validated and consolidated the business requirement (Spanish-language story for shopping list endpoint)
2. ✅ Explored the codebase using concept-driven scoping (inventory items, pagination patterns, hexagonal architecture)
3. ✅ Identified domain concepts (existing InventoryItem aggregate, filtering requirement for shopping list use case)
4. ✅ Determined strategic approach (new ShoppingItemLister service, filtered repository method, dedicated API route)
5. ✅ Analyzed trade-offs and alternatives (separate service vs parameterized, WHERE clause placement)
6. ✅ Surfaced risks and ambiguities (index usage, concurrent state changes, cursor validation)
7. ✅ Confirmed all 7 acceptance criteria are addressable with no gaps

The REASONS Canvas generation can now proceed with concrete details about:
- **Entity design**: Reuse existing InventoryItem aggregate, no new entities needed
- **Architecture flow**: API → ShoppingItemLister → PostgresInventoryItemRepository.searchByRequiresPurchase() → PaginatedInventoryItems
- **Standards enforcement**: Follow established patterns for DIOD registration, HttpNextResponse usage, cursor pagination
- **Operations sequence**: Repository method → Application service → API route → DIOD config → Tests (especially AC7)
