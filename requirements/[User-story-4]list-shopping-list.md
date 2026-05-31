# [STORY-001-004] List Shopping List

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
