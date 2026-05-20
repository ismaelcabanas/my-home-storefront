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
