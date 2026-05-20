## Background
El control del inventario doméstico mediante cantidades exactas genera una alta fricción y el abandono de las aplicaciones por parte de los usuarios. Para solucionar esto, el sistema adoptará un modelo basado en estados visuales y cualitativos ("Suficiente", "Por Agotarse", "Agotado"), permitiendo una actualización rápida mediante acciones directas según la percepción visual del usuario en la despensa.

## Business Value
1. **Reducción de Fricción**: El usuario puede actualizar el estado de su despensa con un solo clic a través de acciones semánticas y directas, sin necesidad de interactuar con menús desplegables o formularios complejos.
2. **Automatización de Lista de la Compra**: Identificar instantáneamente qué productos necesitan reposición basándose únicamente en si han entrado en un estado crítico ("Por Agotarse" o "Agotado").

## Scope In
* Implementar el endpoint `POST /api/inventory/items` para registrar nuevos productos en la despensa.
* Campos requeridos en la solicitud de creación:
  * Nombre del producto (requerido, texto no vacío)
  * Estado inicial (requerido, valores permitidos: "Suficiente", "Por Agotarse", "Agotado")
* Implementar endpoints dedicados y específicos para transicionar el estado de un producto:
  * `POST /api/inventory/items/{id}/replenish` -> Cambia el estado a "Suficiente".
  * `POST /api/inventory/items/{id}/mark-low` -> Cambia el estado a "Por Agotarse".
  * `POST /api/inventory/items/{id}/deplete` -> Cambia el estado a "Agotado".
* Regla de negocio: Todo producto en estado "Por Agotarse" o "Agotado" se clasificará automáticamente como "Pendiente de compra" (`requires_purchase: true`).

## Scope Out
* Categorización de productos (comida, limpieza, higiene, etc.); todos los artículos se gestionan en una lista única y unificada sin separaciones.
* Control de stock numérico (cantidades, unidades, gramos, mililitros).
* Gestión de alertas de stock mínimo basado en números.
* Autenticación de usuarios y gestión de múltiples viviendas.
* Sugerencia automática de recetas basadas en los ingredientes disponibles.
* Integración con plataformas de supermercados para realizar la compra online.

## Acceptance Criteria (ACs)
1. Validar campos obligatorios al registrar producto
   **Given** el nombre del producto o el estado inicial están vacíos
   **When** el backend recibe la solicitud de creación
   **Then** devuelve un HTTP 400 con el mensaje "El nombre y el estado inicial son obligatorios".

2. Validar valores permitidos para el estado inicial
   **Given** un estado inicial enviado en la creación que no sea "Suficiente", "Por Agotarse" o "Agotado"
   **When** el backend valida la solicitud
   **Then** devuelve un HTTP 400 con el mensaje "Estado inicial no válido".

3. Acción de agotar producto mediante endpoint dedicado
   **Given** un producto registrado con el estado "Suficiente"
   **When** el usuario consume el producto por completo y el sistema invoca `POST /api/inventory/items/{id}/deplete`
   **Then** devuelve un HTTP 200, el estado cambia a "Agotado" y se activa automáticamente el indicador de compra (`requires_purchase: true`).

4. Acción de reponer producto mediante endpoint dedicado
   **Given** un producto en estado "Agotado" que tiene activado `requires_purchase: true`
   **When** el usuario compra el producto y el sistema invoca `POST /api/inventory/items/{id}/replenish`
   **Then** devuelve un HTTP 200, el estado cambia a "Suficiente" y se desmarca de la lista de la compra (`requires_purchase: false`).

5. Retorno exitoso de creación
   **Given** una solicitud de creación con datos válidos
   **When** el producto se procesa en el backend
   **Then** devuelve un HTTP 201 con los detalles básicos: ID único, nombre, estado actual, indicador de compra (`requires_purchase`) y la marca de tiempo del registro.