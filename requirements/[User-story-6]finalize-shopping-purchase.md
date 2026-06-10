# Story Decomposition: Finalize Shopping Purchase and Update Inventory

## INVEST Analysis

### Abstract Task: "Finalize Shopping Purchase"

**Analysis Dimensions**:
- **Core Responsibility**: Allow users to complete their shopping session and automatically update inventory for all collected items
- **Primary Operations**: 
  - Finalize purchase (bulk operation)
  - Update inventory state for all items in cart
  - Clear shopping list and cart status
- **Key Constraints**: 
  - Only items marked as "in cart" should be replenished
  - Items not in cart should remain in shopping list
  - This is a destructive operation — it modifies both shopping list and inventory state
- **Technical Complexity**: Medium — bulk operation with transaction semantics across multiple entities
- **Business Complexity**: Medium — cascading effects on both shopping list and inventory, needs clear business rules

### INVEST Evaluation:

- ✅ **Independent**: Can be developed, tested, and deployed independently
- ✅ **Negotiable**: Implementation details (endpoint design, transaction handling) can be discussed
- ✅ **Valuable**: Completes the shopping workflow, providing automatic inventory updates
- ✅ **Estimable**: Team can accurately estimate the effort
- ✅ **Small**: Can be completed in 2-3 days
- ✅ **Testable**: Clear acceptance criteria with specific scenarios

**Conclusion**: Ready as-is — contiene 3 core functional points que lógicamente pertenecen juntos (finalizar, actualizar inventario, limpiar lista)

### Split Strategy:

This feature remains as a **single story** porque:
- Contains 3 logical operations that are tightly coupled to the same business transaction
- All operations serve the same "complete shopping" purpose
- Estimated workload: 2-3 days
- Delivers complete business value independently

---

## [STORY-002-002] Finalize Shopping Purchase API Development

### Background

Los usuarios utilizan la lista de la compra mientras realizan sus compras en el supermercado. Han marcado los productos que han recogido con el estado "en el carrito" (STORY-002-001). Una vez terminada la compra, necesitan una forma de finalizar la sesión de compra que actualice automáticamente su inventario doméstico con los productos comprados.

Esta historia implementa la operación de "finalizar compra" que, de forma atómica, replanifica (replenish) todos los productos marcados como "en el carrito", los elimina de la lista de la compra y restablece el estado de carrito. Esta operación cierra el ciclo de compra: desde que el usuario detecta que un producto está bajo, lo añade a la lista, lo marca en el carrito, finaliza la compra y actualiza su inventario.

**Importante**: Esta operación solo afecta a los productos marcados como "en el carrito" (in_cart: true). Los productos que quedan pendientes (in_cart: false) deben permanecer en la lista de la compra para la próxima visita al supermercado.

**Separación de responsabilidades**: La lista de la compra y el inventario son conceptos separados. Los productos del inventario NO tienen un campo que indique si están en la lista de compra. La lista de compra es una entidad propia que referencia productos del inventario pero el inventario no conoce la lista.

### Business Value

- Permite al usuario completar el flujo de compra con una única acción en lugar de actualizar productos uno a uno
- Actualiza automáticamente el inventario doméstico cuando el usuario llega a casa, evitando tener que recordar qué compró
- Mantiene la lista de la compra limpia — solo muestra productos que realmente faltan
- Cierra el ciclo completo de gestión de inventario: detectar baja → añadir a lista → marcar en carrito → finalizar compra → inventario actualizado

### Dependencies and Assumptions

- **Prerequisites**: 
  - [STORY-001-002] Inventory Item State Transitions — debe existir la operación de replenish
  - [STORY-002-001] Shopping List Item Collection Tracking — deben existir productos con estado in_cart
  - [STORY-001-003] List All Inventory Products — debe existir el endpoint para verificar el estado del inventario
- **Data assumptions**: 
  - Existen productos en la lista de la compra
  - Algunos productos están marcados como in_cart: true, otros como in_cart: false
  - La lista de compra es una entidad separada que referencia productos del inventario
- **Integration points**: 
  - Modifica el estado de inventario de los productos (transiciona a Available)
  - Modifica la lista de la compra (elimina productos, restablece in_cart)
- **Business constraints**: 
  - Solo los productos con in_cart: true deben ser replanificados (replenished)
  - Los productos con in_cart: false deben permanecer en la lista de la compra
  - La operación debe ser atómica: o se actualizan todos los productos o ninguno
  - La lista de la compra después de finalizar solo contiene productos pendientes (in_cart: false)
  - Para finalizar la compra, debe haber al menos un producto marcado como in_cart: true

### Scope In

- Implementar `POST /api/inventory/shopping-list/finalize-purchase` para finalizar la compra
- Para cada producto con in_cart: true en la lista de la compra:
  - Ejecutar la operación de replenish (transicionar estado a Available)
  - Eliminar el producto de la lista de la compra
- Mantener en la lista de la compra los productos con in_cart: false (no modificados)
- Retornar确认简单 de que la operación se completó (HTTP 200)
- Validar que exista al menos un producto con in_cart: true antes de finalizar
- Validar que exista al menos un producto en la lista de la compra antes de finalizar

### Scope Out

- Retornar listas de productos en la respuesta del endpoint de finalizar compra (la verificación se hace vía otros endpoints)
- Finalizar compra parcial (solo algunos productos del carrito)
- Deshacer la operación de finalizar compra
- Notificaciones de compra completada
- Historial de compras finalizadas
- Estadísticas de frecuencia de compra
- Gestión de múltiples listas de compra simultáneas
- Sincronización con tickets de compra físicos
- Campos en el inventario que indiquen si el producto está en la lista de compra

## Acceptance Criteria

### AC1: Finalizar compra actualiza correctamente el inventario

**Given** una lista de la compra con 3 productos marcados como "en el carrito":
  - "Leche" (in_cart: true), "Café" (in_cart: true), "Pan" (in_cart: true)
  - Y estos productos están en estado de inventario "Low" o "Depleted"
**When** el usuario finaliza la compra invocando `POST /api/inventory/shopping-list/finalize-purchase`
**Then** el sistema devuelve HTTP 200
**And** al consultar el inventario vía `GET /api/inventory/items`, los productos "Leche", "Café" y "Pan" tienen estado: "Available"
**And** al consultar la lista de la compra vía `GET /api/inventory/shopping-list`, estos productos NO aparecen

### AC2: Productos pendientes permanecen en la lista

**Given** una lista de la compra con productos mezclados:
  - "Leche" (in_cart: true), "Aceite" (in_cart: false), "Café" (in_cart: true), "Huevos" (in_cart: false)
**When** el usuario finaliza la compra invocando `POST /api/inventory/shopping-list/finalize-purchase`
**Then** el sistema devuelve HTTP 200
**And** al consultar `GET /api/inventory/shopping-list`:
  - Solo aparecen "Aceite" y "Huevos" (los que tenían in_cart: false)
  - "Leche" y "Café" ya no aparecen (fueron replanificados)
**And** al consultar `GET /api/inventory/items`, "Leche" y "Café" tienen estado "Available"
**And** "Aceite" y "Huevos" mantienen su estado de inventario original sin cambios

### AC3: Finalizar compra cuando ningún producto está en el carrito

**Given** una lista de la compra con 3 productos:
  - "Leche" (in_cart: false), "Aceite" (in_cart: false), "Café" (in_cart: false)
**When** el usuario finaliza la compra invocando `POST /api/inventory/shopping-list/finalize-purchase`
**Then** el sistema devuelve HTTP 400 con mensaje: "No hay productos en el carrito para finalizar la compra"
**And** al consultar `GET /api/inventory/shopping-list`, los 3 productos siguen apareciendo
**And** al consultar `GET /api/inventory/items`, el estado de inventario de los 3 productos NO ha cambiado

### AC4: Finalizar compra cuando todos los productos están en el carrito

**Given** una lista de la compra con 4 productos:
  - "Leche" (in_cart: true), "Aceite" (in_cart: true), "Café" (in_cart: true), "Pan" (in_cart: true)
**When** el usuario finaliza la compra
**Then** el sistema devuelve HTTP 200
**And** al consultar `GET /api/inventory/shopping-list`, el array está vacío []
**And** al consultar `GET /api/inventory/items`, los 4 productos tienen estado "Available"

### AC5: Finalizar compra con lista vacía

**Given** no existen productos en la lista de la compra
**When** el usuario invoca `POST /api/inventory/shopping-list/finalize-purchase`
**Then** el sistema devuelve HTTP 400 con mensaje: "No hay productos en la lista de la compra"

### AC6: Operación es atómica — todos o nada

**Given** una lista de la compra con múltiples productos en el carrito
**When** el usuario finaliza la compra
**Then** si la operación falla para cualquier producto, ningún producto se modifica
**And** el estado del sistema permanece igual que antes de la operación
**And** el sistema devuelve HTTP 500 con mensaje de error apropiado
**And** al consultar `GET /api/inventory/items` y `GET /api/inventory/shopping-list`, el estado es idéntico al anterior a la operación

### Non-Functional Expectations

- La operación de finalizar compra debe completarse rápido incluso con listas grandes (100+ productos) para que la UX sea fluida
- El sistema debe manejar correctamente finalizar compra de forma concurrente si el mismo usuario tiene múltiples dispositivos (prevenir carreras)
- La operación debe ser consistente — después de finalizar, el inventario y la lista de la compra deben estar sincronizados correctamente
