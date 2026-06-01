# SPDD Analysis: [STORY-001-003] List All Inventory Products

## Original Business Requirement

# [STORY-001-003] List All Inventory Products

## Background

Una vez que los usuarios han registrado productos en su inventario doméstico, necesitan una forma de visualizar todos los artículos de su despensa para tener una visión general del estado actual. Esta historia implementa el endpoint de listado que permite recuperar todos los productos sin filtrar por estado ni por indicador de compra, proporcionando una vista completa de la despensa.

## Business Value

- Permite al usuario tener una visión completa de su despensa en todo momento
- Facilita la identificación rápida de productos que necesitan compra mediante indicadores visuales en la UI
- Sirve como base para futuras funcionalidades de filtrado y búsqueda
- Proporciona una experiencia de usuario fluida mediante scroll infinito, eliminando la necesidad de paginación tradicional

## Dependencies and Assumptions

- **Prerequisites**: [STORY-001-001] Create Inventory Item — deben existir productos en el sistema
- **Data assumptions**: Puede haber desde cero hasta cientos de productos registrados
- **Integration points**: Ninguno en esta historia
- **Business constraints**: 
  - El listado devuelve TODOS los productos independientemente de su estado
  - El ordenamiento es alfabético por nombre para facilitar encontrar productos

## Scope In

- Implementar `GET /api/inventory/items` para listar todos los productos
- Implementar paginación mediante scroll infinito usando cursor basado en timestamp (interno)
- Parámetros de consulta:
  - `limit` (opcional, default 20): número de items a retornar
  - `cursor` (opcional): token opaco para obtener el siguiente lote de productos
- Retornar para cada producto:
  - ID único
  - Nombre
  - Estado (Available/Low/Depleted)
  - Indicador de compra (requires_purchase) — permite a la UI mostrar iconos/badges de lista de compra
- Ordenamiento alfabético ascendente por nombre
- Retornar metadatos de paginación:
  - `items`: array de productos
  - `nextCursor`: token para siguiente página (null si no hay más)
  - `hasMore`: boolean indicando si existen más productos

## Scope Out

- Filtrado por estado (futura historia)
- Búsqueda por nombre (futura historia)
- Listado específico de productos pendientes de compra (historia separada)
- Ordenamiento configurable por el usuario
- Categorización de productos
- Eliminar productos del listado
- Exposición de timestamp de creación en la respuesta (usado internamente para cursor)

## Acceptance Criteria

### AC1: Listado exitoso de productos (primera página)

**Given** existen productos registrados en el sistema: "Leche" (estado Available, requires_purchase: false), "Aceite" (estado Low, requires_purchase: true), "Café" (estado Depleted, requires_purchase: true)
**When** el sistema invoca `GET /api/inventory/items` sin parámetros
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con 3 productos ordenados alfabéticamente ["Aceite", "Café", "Leche"]
  - `nextCursor`: un token opaco para continuar
  - `hasMore`: false (si no hay más productos) o true (si existen más)
  - Cada producto incluye: ID, nombre, estado, requires_purchase

### AC2: Listado con límite personalizado

**Given** existen 25 productos registrados en el sistema
**When** el sistema invoca `GET /api/inventory/items?limit=10`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con exactamente 10 productos ordenados alfabéticamente
  - `nextCursor`: token para obtener los siguientes 15 productos
  - `hasMore`: true

### AC3: Scroll infinito - obtener página siguiente

**Given** existen 25 productos registrados y se obtuvo la primera página con `limit=10`
**When** el sistema invoca `GET /api/inventory/items?limit=10&cursor=<nextCursor-anterior>`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con los siguientes 10 productos (posiciones 11-20 en orden alfabético)
  - `nextCursor`: nuevo token para los productos restantes
  - `hasMore`: true (quedan 5 productos)

### AC4: Scroll infinito - última página

**Given** existen 25 productos y se ha navegado hasta el último lote usando cursores
**When** el sistema invoca `GET /api/inventory/items?limit=10&cursor=<penultimo-cursor>`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con los últimos 5 productos restantes
  - `nextCursor`: null (no hay más productos)
  - `hasMore`: false

### AC5: Inventario vacío

**Given** no existen productos registrados en el sistema
**When** el sistema invoca `GET /api/inventory/items`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array vacío []
  - `nextCursor`: null
  - `hasMore`: false

### AC6: Incluye productos con todos los estados e indicadores

**Given** existen productos en estado "Available", "Low" y "Depleted" mezclados con diferentes valores de `requires_purchase`
**When** el sistema invoca `GET /api/inventory/items`
**Then** el sistema devuelve HTTP 200 con:
  - Todos los productos independientemente de su estado
  - Productos con `requires_purchase: true` y `requires_purchase: false` mezclados
  - La UI puede identificar productos pendientes de compra mediante el campo `requires_purchase`

### AC7: Respeta ordenamiento alfabético independiente de paginación

**Given** existen productos: "Zanahoria", "Arroz", "Manzana", "Banana", "Tomate" (5 productos)
**When** el sistema invoca `GET /api/inventory/items?limit=2` y luego continúa con cursores hasta obtener todos
**Then** el sistema devuelve productos en orden: "Arroz", "Banana", "Manzana", "Tomate", "Zanahoria" (alfabético A-Z)

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **InventoryItem** (Domain Aggregate): Core business entity representing products in the home inventory. Located at `src/contexts/inventory/inventory-items/domain/InventoryItem.ts`. Contains id, name, state, and createdAt. Exposes `requiresPurchase` derived property based on state.

- **InventoryItemState** (Value Object): Represents the three valid states (Available, Low, Depleted). Contains business logic: `derivesRequiresPurchase()` returns true for Low/Depleted states. Enforces valid state values through factory methods.

- **InventoryItemRepository** (Repository Interface): Defines contract for persistence operations. Currently has `save()`, `searchById()`, and `findById()` methods. Implemented by `PostgresInventoryItemRepository`.

- **PostgresInventoryItemRepository** (Infrastructure): Concrete repository implementation using PostgreSQL. Extends `PostgresRepository<T>` base class which provides `searchOne()`, `searchMany()`, and `execute()` template methods for SQL queries.

- **Database Schema** (`inventory.inventory_items`): PostgreSQL table with columns `id` (UUID), `name` (VARCHAR), `state` (VARCHAR), `requires_purchase` (BOOLEAN), `created_at` (TIMESTAMPTZ). The `created_at` column is essential for cursor-based pagination.

### New Concepts Required

- **Cursor Pagination Pattern**: Infinite scroll mechanism using opaque tokens. Cursor will internally use `created_at` timestamp but should not expose this in API responses. Needs cursor encoding/decoding strategy.

- **InventoryItemLister** (Application Service): New use case class following existing patterns (similar to `InventoryItemCreator`, `InventoryItemReplenisher`). Will orchestrate list retrieval with pagination logic.

- **PaginatedInventoryItems** (DTO/Response Model): New response shape containing `items` (array), `nextCursor` (string or null), and `hasMore` (boolean). Different from single entity responses used in other endpoints.

### Conceptual Relationships

```
InventoryItemLister (new application service)
    → depends on → InventoryItemRepository (needs new method)
    → returns → PaginatedInventoryItems (new DTO)
    → uses → Cursor encoding strategy (new concept)

InventoryItemRepository (existing)
    → extends → PostgresRepository<InventoryItem> (existing base class)
    → needs → listAll() or searchAll() method with cursor pagination

PaginatedInventoryItems (new)
    → contains → array of InventoryItem.toPrimitives() (existing)
    → contains → nextCursor (new field)
    → contains → hasMore (new field)
```

### Key Business Rules

- **Alphabetical Ordering**: All products must be returned in A-Z order by name, regardless of state or purchase indicator. This is the primary sort order.

- **No Filtering**: Unlike the separate shopping list endpoint, this endpoint returns ALL products irrespective of state or `requires_purchase` value.

- **Cursor Opacity**: Cursors must be opaque tokens to clients. The internal use of `created_at` for cursor pagination is an implementation detail not exposed in the API response.

- **Default Pagination**: When no cursor is provided, return the first page. When no limit is provided, default to 20 items.

- **Empty Inventory Handling**: Empty array should be returned (not 404) when no products exist, with `nextCursor: null` and `hasMore: false`.

---

## Strategic Approach

### Solution Direction

The requirement involves implementing a read-only list operation with cursor-based pagination, following the existing DDD/hexagonal architecture patterns in the codebase.

**Architecture alignment**: 
- Introduce new application service (`InventoryItemLister`) in the application layer
- Extend `InventoryItemRepository` interface with a new `searchAll()` method supporting cursor pagination
- Add GET handler to existing `/api/inventory/items` route (currently only handles POST)
- Return response using existing `HttpNextResponse.ok()` pattern

**Data flow direction**:
```
HTTP GET /api/inventory/items?limit=10&cursor=xxx
  → Next.js API Route handler
    → InventoryItemLister (application service)
      → InventoryItemRepository.searchAll(cursor, limit)
        → PostgreSQL query with ORDER BY name ASC, cursor filter
      → Build PaginatedInventoryItems response
    → HttpNextResponse.ok(response)
```

**Pagination strategy**:
- Use timestamp-based cursor internally (leveraging existing `created_at` column)
- Encode cursor as base64 or JSON-encoded string to make it opaque
- Sort primarily by `name` (alphabetical), use `created_at` only for cursor continuation
- Return `null` for `nextCursor` when no more results exist

### Key Design Decisions

#### 1. Cursor Implementation Strategy

**Options considered**:
- **A) Offset-based pagination**: Simple `?page=2&limit=20`
- **B) Keyset pagination with composite cursor**: Encode both `name` and `created_at` in cursor
- **C) Timestamp-only cursor**: Use only `created_at` for cursor

**Recommendation**: **Option B (Composite cursor)**

**Rationale**:
- Alphabetical sorting is primary (by name), so cursor must include last seen `name`
- `created_at` provides uniqueness for items with same name
- Composite cursor `[name, created_at]` encoded as base64 ensures correct pagination without duplicates
- Offset-based pagination fails with real-time data (items added/removed during scrolling)
- Timestamp-only cursor doesn't support alphabetical ordering requirement

**Trade-offs**:
- Pro: Handles concurrent modifications gracefully
- Pro: Supports required alphabetical ordering
- Con: More complex encoding/decoding logic
- Con: Larger cursor size (~50-60 bytes vs ~8 bytes)

#### 2. Repository Extension Approach

**Options considered**:
- **A) Add `searchAll(limit, cursor)` method to existing interface**
- **B) Create separate `InventoryItemSearcher` repository interface**
- **C) Extend existing repository with multiple specific methods**

**Recommendation**: **Option A (extend existing interface)**

**Rationale**:
- Maintains consistency with existing repository pattern
- `searchById()` already exists in interface, `searchAll()` is natural extension
- Follows single responsibility principle (one repository per aggregate)
- Keeps dependency injection simple

**Trade-offs**:
- Pro: Minimal code changes, follows established patterns
- Pro: Repository remains focused on single aggregate
- Con: Interface grows (but bounded by aggregate operations)

#### 3. Response Model Design

**Options considered**:
- **A) Return raw InventoryItem array with metadata in headers**
- **B) Return wrapped PaginatedInventoryItems DTO**
- **C) Return array with special last item containing metadata**

**Recommendation**: **Option B (Wrapped DTO)**

**Rationale**:
- Explicit structure mirrors AC requirements (`items`, `nextCursor`, `hasMore`)
- Type-safe and self-documenting
- Consistent with REST API best practices for paginated responses
- Easy to evolve (add total count, filters, etc. in future)

**Trade-offs**:
- Pro: Clear contract, matches AC structure exactly
- Pro: Easy to add metadata in future without breaking changes
- Con: Slightly more verbose than array-only response
- Con: Requires new DTO class

#### 4. Route Handler Organization

**Options considered**:
- **A) Add GET method to existing `/api/inventory/items/route.ts`**
- **B) Create new `/api/inventory/items/list/route.ts`**
- **C) Use separate file `/api/inventory/items/list-items/route.ts`**

**Recommendation**: **Option A (extend existing route)**

**Rationale**:
- REST convention: `GET /api/inventory/items` is the natural endpoint for listing
- Existing file only handles POST, adding GET is standard pattern
- Keeps related operations in single file
- Follows Next.js App Router conventions

**Trade-offs**:
- Pro: RESTful API design
- Pro: Minimal file proliferation
- Con: File grows (but manageable for simple CRUD+ list operations)

### Alternatives Considered

#### Alternative: Offset-based pagination

**Why rejected**: Offset pagination doesn't work well with infinite scroll when data is modified during pagination. If a user is scrolling through items and a new item is added, offset-based pagination can show duplicate items or skip items. Cursor-based pagination is the industry standard for infinite scroll for this reason.

#### Alternative: Expose `created_at` in API response

**Why rejected**: Requirement explicitly states `created_at` is internal-only. Exposing it couples API to implementation details and limits future flexibility (e.g., changing cursor strategy).

#### Alternative: Separate "list" endpoint

**Why rejected**: `GET /api/inventory/items/list` would be non-RESTful. The standard pattern is `GET /api/inventory/items` for collection, `POST /api/inventory/items` for creation (already implemented).

---

## Risk & Gap Analysis

### Requirement Ambiguities

1. **Cursor Token Format**: ACs refer to "token opaco" but don't specify format or encoding. Needs clarification on whether to use base64, JWT-like encoding, or simple string. Implementation must choose but AC doesn't constrain.

2. **Cursor Validity Period**: No specification on whether tokens expire. For home inventory scale, likely not critical, but ambiguity exists.

3. **Duplicate Name Handling**: ACs show products with unique names ("Aceite", "Café", "Leche") but real-world could have duplicates. How to handle multiple "Leche" items with different timestamps? Not explicit in ACs.

4. **Case Sensitivity in Sorting**: ACs show proper case ("Arroz", "Banana") but don't specify collation or case handling. Database default vs. application-level sorting not specified.

### Edge Cases

1. **Concurrent Modification During Pagination**: User scrolls through inventory while another client adds/deletes items. With cursor pagination, could miss newly added items or see items that were deleted. ACs don't address this real-world scenario.

2. **Last Page Detection**: AC4 shows `hasMore: false` but doesn't specify how to determine this. Need to fetch `limit + 1` items or use separate count query? Performance implications differ.

3. **Limit Boundary Values**: What happens with `limit=0`, `limit=1`, or `limit=10000`? ACs use `limit=10` and `limit=20` but don't specify validation or max limits.

4. **Cursor Tampering**: What if client provides invalid or malformed cursor? AC7 tests non-existent product ID but doesn't test tampered cursor.

5. **Empty String Cursor**: Should empty string `?cursor=` be treated as "no cursor" (first page) or invalid? Not specified.

### Technical Risks

1. **Sorting Performance**: Alphabetical sorting on `name` column requires database scan or index. No index currently exists on `name` column (only `id` is primary key). As inventory grows, this could impact performance.

2. **Cursor Encoding Size**: Composite cursor `[name, created_at]` could be ~50-60 bytes when base64-encoded. For deep pagination (100+ pages), this adds request size. Not critical for home inventory scale but worth noting.

3. **No Index on `name`**: Current schema only has primary key on `id`. Query `ORDER BY name` will require full table scan or sort. Should add `CREATE INDEX` on `name` column for performance.

4. **Database Collation**: PostgreSQL default collation may not match expected sorting for Spanish characters (ñ, accents). ACs show Spanish words but don't specify locale-aware sorting.

5. **Repository Interface Growth**: Adding `searchAll()` to interface is correct, but repeated additions for other list operations (search by state, etc.) could bloat interface. Consider Specification pattern if many search variants emerge.

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| AC1 | First page with mixed states | Yes | ✅ Fully covered |
| AC2 | Custom limit | Yes | ✅ Fully covered |
| AC3 | Next page via cursor | Yes | ✅ Fully covered |
| AC4 | Last page detection | Yes | ⚠️ Gap: Implementation strategy needed (fetch N+1 or count query) |
| AC5 | Empty inventory | Yes | ✅ Fully covered |
| AC6 | All states included | Yes | ✅ Fully covered |
| AC7 | Alphabetical ordering | Yes | ✅ Fully covered |

**Coverage Summary**: 7/7 ACs addressable, but AC4 requires design decision on last page detection strategy.

### Integration Risks

1. **Dependency on Existing Repository**: Extending `InventoryItemRepository` interface requires updating implementing class (`PostgresInventoryItemRepository`). No other implementations exist currently, so risk is low.

2. **Route File Modification**: Adding GET to existing `/api/inventory/items/route.ts` file (currently POST-only). Should not affect existing POST endpoint.

3. **DI Container Configuration**: New `InventoryItemLister` service must be registered in `diod.config.ts`. Following pattern from existing services like `InventoryItemCreator`.

### Performance Considerations

1. **N+1 Query Problem**: Avoid multiple queries for cursor pagination. Single query with `WHERE name > ? OR (name = ? AND created_at > ?)` pattern needed.

2. **Index Recommendation**: Add `CREATE INDEX idx_inventory_items_name_created_at ON inventory.inventory_items(name, created_at);` for optimal query performance.

3. **Response Size**: Each item returns ~100 bytes. With default 20 items, response is ~2KB + overhead. Well within acceptable limits.

### Security Considerations

1. **Cursor Tampering**: Implement validation to reject malformed cursids. Return 400 Bad Request rather than 500 Internal Server Error.

2. **Limit Validation**: Validate `limit` parameter to prevent excessive resource usage. Recommend max limit of 100 items.

3. **No Authentication/Authorization**: Current architecture has no auth. This is acceptable for personal home inventory but should be documented as assumption.
