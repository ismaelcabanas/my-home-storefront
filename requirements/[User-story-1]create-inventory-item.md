# [STORY-001-001] Create Inventory Item API Development

## Background

El control del inventario doméstico mediante cantidades exactas genera alta fricción y abandono de las aplicaciones. Para solucionar esto, el sistema adoptará un modelo basado en estados visuales y cualitativos ("Suficiente", "Por Agotarse", "Agotado"), permitiendo una actualización rápida mediante la percepción visual del usuario.

Esta historia implementa la capacidad fundamental de registrar productos en la despensa. Todo producto nuevo se crea en estado "Available" por defecto, asumiendo que el usuario registra productos que acaba de comprar o que tiene disponibles.

## Business Value

- Permite al usuario registrar rápidamente productos en su despensa con mínima fricción
- Establece la base para el sistema de inventario basado en estados visuales
- Simplifica el flujo de registro al asumir un estado inicial óptimo

## Dependencies and Assumptions

- **Prerequisites**: Ninguno — esta es la historia fundacional del módulo de inventario
- **Data assumptions**: No existen productos previos; cada producto recibe un ID único al crearse
- **Integration points**: Ninguno en esta historia
- **Business constraints**: Todo producto se crea en estado "Available" por defecto

## Scope In

- Implementar el endpoint `POST /api/inventory/items` para registrar nuevos productos
- Validar que el nombre del producto sea obligatorio y no vacío
- Asignar automáticamente estado "Available" y `requires_purchase: false`
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
  - Estado: "Available"
  - Indicador de compra: `requires_purchase: false`
  - Timestamp de creación

### AC2: Rechazo por nombre vacío o ausente

**Given** una solicitud de creación donde el nombre del producto está vacío o ausente
**When** el sistema recibe la solicitud
**Then** el sistema rechaza la solicitud con HTTP 400 y mensaje "El nombre del producto es obligatorio"
