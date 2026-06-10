# Story Decomposition: Shopping List Item Collection Tracking

## INVEST Analysis

### Abstract Task: "Shopping List Item Collection Tracking"

**Analysis Dimensions**:
- **Core Responsibility**: Allow users to mark items in their shopping list as "collected in cart" to track shopping progress
- **Primary Operations**: 
  - Mark an item as "in cart" (collected)
  - Mark an item as "not in cart" (pending collection)
  - List items with their cart status
- **Key Constraints**: 
  - Items must be in the shopping list to be marked
  - Cart status is separate from inventory state — the shopping list doesn't expose stock status
  - Shopping list only knows: product ID, name, and in_cart status
- **Technical Complexity**: Medium — new field for cart status, endpoints for marking, update to shopping list response
- **Business Complexity**: Low — straightforward user need with clear operations

### INVEST Evaluation:

- ✅ **Independent**: Can be developed, tested, and deployed independently from inventory features
- ✅ **Negotiable**: Implementation details (cart status field, endpoint design) can be discussed
- ✅ **Valuable**: Provides clear business value for shoppers tracking progress
- ✅ **Estimable**: Team can accurately estimate the effort
- ✅ **Small**: Can be completed in 1-5 days
- ✅ **Testable**: Clear acceptance criteria with specific scenarios

**Conclusion**: Ready as-is — contains 3 core functional points that logically belong together

### Split Strategy:

This feature remains as a **single story** because:
- Contains 3 logical operations that are tightly related to the same user need
- All operations serve the same shopping progress tracking purpose
- Estimated workload: 2-3 days
- Delivers complete business value independently

---

## [STORY-002-001] Shopping List Item Collection Tracking API Development

### Background

Los usuarios utilizan la lista de la compra mientras realizan sus compras en el supermercado. Actualmente, pueden ver qué productos necesitan comprar (la lista de la compra), pero no tienen forma de marcar los productos que ya han añadido al carrito para diferenciarlos de los que aún les falta por recoger.

Esta historia implementa la capacidad de marcar productos individuales de la lista de la compra como "en el carrito" (collected), permitiendo a los usuarios seguir su progreso de compra y evitar olvidar productos o comprarlos por duplicado.

**Importante**: La lista de la compra es un concepto separado del inventario. Un producto en la lista de compra NO expone su estado de stock (Available/Low/Depleted). La lista solo conoce: ID del producto, nombre, y estado de carrito (`in_cart`). Esta separación permite que la experiencia de compra sea simple y enfocada, sin exponer detalles del inventario doméstico mientras el usuario está en el supermercado.

### Business Value

- Permite al usuario diferenciar visualmente los productos ya recogidos de los pendientes mientras compra
- Evita que el usuario olvide productos o compre por duplicado en el supermercado
- Mejora la experiencia de compra proporcionando feedback visual del progreso
- Facilita la compra rápida permitiendo verificar qué falta antes de ir a caja
- Separa la preocupación de inventario de la preocupación de compra, simplificando la UX

### Dependencies and Assumptions

- **Prerequisites**: 
  - [STORY-001-004] List Shopping List — debe existir el endpoint base de la lista de la compra
  - La lista de la compra ya contiene productos que necesitan ser comprados
- **Data assumptions**: 
  - Existen productos en la lista de la compra
  - Cada producto de la lista tiene un estado de carrito: `in_cart: true` (en el carrito) o `in_cart: false` (pendiente)
  - Por defecto, los productos se añaden a la lista con `in_cart: false`
- **Integration points**: 
  - El endpoint `GET /api/inventory/shopping-list` se actualiza para incluir el nuevo campo `in_cart`
  - Los nuevos endpoints de marking operan sobre productos existentes en la lista
- **Business constraints**: 
  - Solo los productos que están en la lista de la compra pueden ser marcados
  - La lista de la compra NO expone el estado de inventario (Available/Low/Depleted)
  - El estado de "en el carrito" es un indicador temporal de progreso, no un estado permanente

### Scope In

- Implementar `POST /api/inventory/shopping-list/{id}/mark-in-cart` para marcar un producto como "en el carrito"
- Implementar `POST /api/inventory/shopping-list/{id}/mark-not-in-cart` para marcar un producto como "no en el carrito" (deshacer marca)
- Actualizar `GET /api/inventory/shopping-list` para incluir el campo `in_cart` en cada producto
- Validar que el producto existe y está en la lista de la compra antes de marcar
- El campo `in_cart` debe ser booleano: `true` si el producto está marcado como en el carrito, `false` si no
- Mantener paginación y scroll infinito en el listado con el nuevo campo
- La lista de compra solo retorna: ID, nombre, e `in_cart` por cada producto

### Scope Out

- Exposición del estado de inventario (Available/Low/Depleted) en la lista de compra
- Eliminar productos de la lista de la compra (historia separada)
- Marcar todos los productos como "en el carrito" a la vez (acción masiva)
- Sincronización automática del estado "en el carrito" con el estado de inventario
- Compartir estado de carrito entre múltiples usuarios
- Historial de cambios de estado de carrito
- Categorización de productos en el carrito
- Notificaciones de productos olvidados en el carrito

## Acceptance Criteria

### AC1: Marcar producto como "en el carrito"

**Given** un producto "Leche" que está en la lista de la compra
**When** el usuario añade la leche al carrito y el sistema invoca `POST /api/inventory/shopping-list/{id}/mark-in-cart`
**Then** el sistema devuelve HTTP 200 con:
  - El producto "Leche" con su ID
  - Campo `in_cart: true`
  - La respuesta NO incluye estado de inventario (no hay campo Available/Low/Depleted)

### AC2: Marcar producto como "no en el carrito" (deshacer)

**Given** un producto "Aceite" que está marcado como "en el carrito" (in_cart: true)
**When** el usuario saca el aceite del carrito y el sistema invoca `POST /api/inventory/shopping-list/{id}/mark-not-in-cart`
**Then** el sistema devuelve HTTP 200 con:
  - El producto "Aceite" con su ID
  - Campo `in_cart: false`
  - El producto permanece en la lista de la compra (no se elimina)

### AC3: Listado de la compra incluye estado de carrito

**Given** existen productos en la lista de la compra:
  - "Leche" (in_cart: true)
  - "Aceite" (in_cart: false)
  - "Café" (in_cart: true)
**When** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con ["Aceite", "Café", "Leche"] (orden alfabético)
  - Cada producto incluye: ID, nombre, e `in_cart` (true o false)
  - "Aceite" tiene `in_cart: false`
  - "Café" tiene `in_cart: true`
  - "Leche" tiene `in_cart: true`
  - Ningún producto incluye estado de inventario

### AC4: Rechazo al marcar producto que no está en la lista de la compra

**Given** un producto "Pan" que existe en el sistema pero NO está en la lista de la compra
**When** el sistema invoca `POST /api/inventory/shopping-list/{id}/mark-in-cart`
**Then** el sistema devuelve HTTP 400 con mensaje: "El producto no está en la lista de la compra"

### AC5: Rechazo al marcar producto que no existe

**Given** un ID de producto que no existe en el sistema (por ejemplo, UUID "550e8400-e29b-41d4-a716-446655440000")
**When** el sistema invoca `POST /api/inventory/shopping-list/550e8400-e29b-41d4-a716-446655440000/mark-in-cart`
**Then** el sistema devuelve HTTP 404 indicando que el producto no fue encontrado

### AC6: Marcar como "en el carrito" es idempotente

**Given** un producto "Yogur" que ya está marcado como "en el carrito" (in_cart: true)
**When** el sistema invoca `POST /api/inventory/shopping-list/{id}/mark-in-cart` de nuevo
**Then** el sistema devuelve HTTP 200 con:
  - El producto "Yogur"
  - `in_cart: true` (sin cambio, no hay error)

### AC7: Marcar como "no en el carrito" es idempotente

**Given** un producto "Queso" que NO está marcado como "en el carrito" (in_cart: false)
**When** el sistema invoca `POST /api/inventory/shopping-list/{id}/mark-not-in-cart`
**Then** el sistema devuelve HTTP 200 con:
  - El producto "Queso"
  - `in_cart: false` (sin cambio, no hay error)

### AC8: Flujo completo de compra con marcado de carrito

**Given** un usuario tiene una lista de la compra con 5 productos:
  - "Leche", "Aceite", "Café", "Huevos", "Pan"
  - Todos inicialmente con `in_cart: false`
**When** el usuario marca "Leche", "Café" y "Pan" como "en el carrito"
**And** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con los 5 productos ordenados alfabéticamente
  - "Aceite", "Huevos" tienen `in_cart: false`
  - "Café", "Leche", "Pan" tienen `in_cart: true**
**And** la UI puede mostrar visualmente qué productos están en el carrito y cuáles faltan

### AC9: Scroll infinito funciona con estado de carrito

**Given** existen 35 productos en la lista de la compra con diferentes estados de carrito
**When** el sistema invoca `GET /api/inventory/shopping-list?limit=10`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array con 10 productos
  - Cada producto incluye: ID, nombre, e `in_cart` (su valor correspondiente)
  - `nextCursor`: token para los siguientes 25 productos
  - `hasMore`: true

### AC10: Lista de la compra vacía

**Given** no existen productos en la lista de la compra
**When** el sistema invoca `GET /api/inventory/shopping-list`
**Then** el sistema devuelve HTTP 200 con:
  - `items`: array vacío []
  - `nextCursor`: null
  - `hasMore`: false

### Non-Functional Expectations

- El estado `in_cart` debe actualizarse inmediatamente cuando se marca un producto para que la UI pueda reflejar el cambio en tiempo real
- El sistema debe manejar correctamente marcar productos como "en el carrito" y "no en el carrito" de forma concurrente si el mismo usuario tiene múltiples dispositivos
- La adición del campo `in_cart` no debe afectar el rendimiento del endpoint `GET /api/inventory/shopping-list` (debe mantener el mismo nivel de rendimiento que antes)
- La lista de compra debe ser simple y ligera, solo exponiendo la información necesaria para la compra (ID, nombre, in_cart)
