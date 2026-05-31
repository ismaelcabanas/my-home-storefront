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
