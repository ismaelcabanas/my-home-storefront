# Specification: Core Pantry Management (v1.2)

## 1. Goal
To provide a minimal and robust system for tracking the count of products available in the pantry.

## 2. Business Rules (BR)
- **BR1 (Uniqueness):** Each product must have a unique name (case-insensitive).
- **BR2 (Stock Integrity):** Stock levels cannot be negative.
- **BR3 (Integer Only):** Stock must be represented as a whole number (Integer).

## 3. Data Model Requirements (camelCase)
Each Product should contain:
- `id`: UUID (String)
- `name`: String (Required)
- `currentStock`: Integer (Default: 0)
- `lastUpdated`: Timestamp

## 4. Behavior Scenarios (Gherkin)

### Scenario: Successfully adding a new product
**Given** the pantry does not contain a product named "Cereal Box"
**When** the user creates a new product with:
  | name       | currentStock |
  |------------|--------------|
  | Cereal Box | 2            |
**Then** the product should be saved in the database
**And** the system should confirm success with the new product's `id`.

### Scenario: Preventing duplicate products
**Given** a product named "Pasta" already exists
**When** the user attempts to create a new product with the name "PASTA"
**Then** the system must return an error "PRODUCT_ALREADY_EXISTS"
**And** no new record should be created.

### Scenario: Updating stock levels
**Given** the product "Milk" has a `currentStock` of 1
**When** the user updates the "Milk" `currentStock` to 5
**Then** the system should save the new value
**And** the `lastUpdated` field must be refreshed to the current time.

### Scenario: Preventing negative stock
**Given** the product "Tomato Can" has a `currentStock` of 3
**When** the user tries to set the `currentStock` of "Tomato Can" to -1
**Then** the system must return an error "INVALID_STOCK_LEVEL"
**And** the `currentStock` should remain at 3.

## 5. Technical Constraints
- **Validation:** All inputs must be sanitized to prevent injection.
