# SPDD Analysis: Create Inventory Item API

## Original Business Requirement

# [STORY-001-001] Create Inventory Item API Development

## Background

El control del inventario doméstico mediante cantidades exactas genera alta fricción y abandono de las aplicaciones. Para solucionar esto, el sistema adoptará un modelo basado en estados visuales y cualitativos ("Suficiente", "Por Agotarse", "Agotado"), permitiendo una actualización rápida mediante la percepción visual del usuario.

Esta historia implementa la capacidad fundamental de registrar productos en la despensa. Todo producto nuevo se crea en estado "Suficiente" por defecto, asumiendo que el usuario registra productos que acaba de comprar o que tiene disponibles.

## Business Value

- Permite al usuario registrar rápidamente productos en su despensa con mínima fricción
- Establece la base para el sistema de inventario basado en estados visuales
- Simplifica el flujo de registro al asumir un estado inicial óptimo

## Dependencies and Assumptions

- **Prerequisites**: Ninguno — esta es la historia fundacional del módulo de inventario
- **Data assumptions**: No existen productos previos; cada producto recibe un ID único al crearse
- **Integration points**: Ninguno en esta historia
- **Business constraints**: Todo producto se crea en estado "Suficiente" por defecto

## Scope In

- Implementar el endpoint `POST /api/inventory/items` para registrar nuevos productos
- Validar que el nombre del producto sea obligatorio y no vacío
- Asignar automáticamente estado "Suficiente" y `requires_purchase: false`
- Retornar los datos del producto creado incluyendo ID, nombre, estado, indicador de compra y timestamp

## Scope Out

- Estado inicial como parámetro de entrada
- Endpoints de transición de estado (historia separada)
- Listado de productos
- Búsqueda de productos
- Eliminación de productos
- Edición de nombre de productos
- Categorización de productos
- Control de stock numérico
- Autenticación de usuarios

## Acceptance Criteria

### AC1: Registro exitoso de producto

**Given** un usuario quiere registrar un nuevo producto "Leche" en su despensa
**When** el sistema recibe la solicitud de creación con nombre "Leche"
**Then** el sistema crea el producto y devuelve HTTP 201 con:
  - Un ID único generado (UUID)
  - Nombre: "Leche"
  - Estado: "Suficiente"
  - Indicador de compra: `requires_purchase: false`
  - Timestamp de creación

### AC2: Rechazo por nombre vacío o ausente

**Given** una solicitud de creación donde el nombre del producto está vacío o ausente
**When** el sistema recibe la solicitud
**Then** el sistema rechaza la solicitud con HTTP 400 y mensaje "El nombre del producto es obligatorio"

---

## Domain Concept Identification

### Existing Concepts (from codebase)

- **AggregateRoot**: Base class for domain aggregates with domain event support — all aggregates extend this
- **Identifier**: Base value object for identifiers (extends StringValueObject) — used for entity IDs like `CookedDishId`
- **UuidGenerator**: Domain interface for UUID generation — implemented by `NativeUuidGenerator`
- **Clock**: Domain interface for time abstraction — available for timestamp generation
- **PostgresRepository**: Generic base class for PostgreSQL repositories — provides `execute`, `searchOne`, `searchMany`
- **HttpNextResponse**: Utility for standardized HTTP responses — includes `created()`, `badRequest()`, `ok()`

### New Concepts Required

- **InventoryItem**: Core aggregate representing a product in the pantry — owns state, name, requires_purchase flag, and timestamps
- **InventoryItemId**: Value object for inventory item identifier — extends Identifier
- **InventoryItemState**: Value object representing qualitative stock state — constrained to "Available", "Low", "Depleted"
- **InventoryItemRepository**: Domain interface for persistence operations — follows existing repository pattern
- **InventoryItemCreator**: Application service (use case) for creating inventory items — follows existing use case naming convention

### Key Business Rules

- **Default state rule**: Every new inventory item is created with state "Available" — no user input for initial state
- **Purchase flag derivation**: `requires_purchase` is automatically `false` when state is "Available" — derived from state, not stored independently
- **Name validation**: Product name must be non-empty — enforced at domain level
- **Unique identification**: Each item receives a system-generated UUID — no user-provided IDs

---

## Strategic Approach

### Solution Direction

Create a new bounded context `inventory` following the established hexagonal architecture pattern. The flow will be:

1. Next.js API route receives POST request with product name
2. Route validates input presence, delegates to application service
3. Application service orchestrates: generate ID, create aggregate with default state, persist
4. Repository saves to new PostgreSQL table in `inventory` schema
5. Return created item primitives with HTTP 201

This mirrors the existing `CookedDish` creation flow but is simpler (fewer fields, no embeddings).

### Key Design Decisions

- **New bounded context vs. extending dishes**: Create separate `inventory` context → Recommendation: new context. Inventory management is a distinct subdomain with different lifecycle and business rules than dish tracking.

- **State as enum vs. string value object**: Use a constrained value object with explicit allowed values → Recommendation: Value object with static factory methods for each state. Provides type safety and explicit domain language.

- **requires_purchase storage**: Derive from state vs. store as separate column → Recommendation: Store as column for query simplicity (future: "list items needing purchase" query). Calculate on state change.

- **Timestamp handling**: Use database default vs. application-provided → Recommendation: Application-provided via Clock interface for testability, stored in DB.

### Alternatives Considered

- **Client-provided UUID**: Rejected — Requirement specifies system-generated ID; simplifies API contract.

---

## Risk & Gap Analysis

### Requirement Ambiguities

- **Timestamp semantics**: AC1 mentions "timestamp de creación" but doesn't specify timezone or format. Assumed: ISO 8601 UTC.
- **Name uniqueness**: Not specified whether duplicate names are allowed. Assumed: allowed (different items can have same name, distinguished by UUID).
- **Name length limits**: No maximum length specified. Assumed: reasonable limit (e.g., 255 chars) to prevent abuse.
- **Whitespace handling**: "Nombre vacío" — does whitespace-only count as empty? Assumed: yes, trim and validate.

### Edge Cases

- **Whitespace-only name**: Should "   " be rejected? Likely yes — needs clarification or defensive implementation.
- **Very long names**: No limit specified — should implement reasonable constraint.
- **Special characters in name**: Emojis, unicode — should be allowed? Assumed: yes, any non-empty string.
- **Concurrent creation**: Multiple items created simultaneously — no issue expected (UUIDs are unique).

### Technical Risks

- **New database schema**: Requires migration file for `inventory.inventory_items` table — straightforward, follows existing pattern.
- **DI container registration**: New services must be registered in `diod.config.ts` — follows existing pattern, low risk.
- **No existing inventory code**: Greenfield module — no conflicts, but no reuse either.

### Acceptance Criteria Coverage

| AC# | Description | Addressable? | Gaps/Notes |
|-----|-------------|--------------|------------|
| AC1 | Successful creation with valid name | Yes | Response format not fully specified (JSON structure) |
| AC2 | Rejection for empty/missing name | Yes | Exact error response structure follows existing `HttpNextResponse.badRequest()` pattern |
