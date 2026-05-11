# Implementation Plan: Core Pantry Management

## Context
Implementing the Core Pantry Management specification following Spec-Driven Development (SDD) and Outside-In TDD. This feature provides minimal and robust tracking of pantry product counts with uniqueness constraints and stock validation.

**Source:** `/specs/core-pantry-management.md`

## Business Rules
- **BR1**: Unique product names (case-insensitive)
- **BR2**: Stock levels cannot be negative
- **BR3**: Stock must be an integer

## Data Model (camelCase)
- `id`: UUID (String)
- `name`: String (Required)
- `currentStock`: Integer (Default: 0)
- `lastUpdated`: Timestamp (managed at application layer, NOT database triggers)

---

## Directory Structure

```
src/contexts/shared/domain/
│   └── ApplicationError.ts                  # New base error class (similar to CodelyError)
src/contexts/pantry/products/
├── domain/
│   ├── Product.ts                           # Aggregate Root
│   ├── ProductId.ts                         # Value Object (extends Identifier)
│   ├── ProductName.ts                       # Value Object with case-insensitive equals()
│   ├── ProductStock.ts                      # Value Object with validation (BR2, BR3)
│   ├── ProductAlreadyExistsError.ts         # Domain Error (extends ApplicationError)
│   ├── InvalidStockLevelError.ts            # Domain Error (extends ApplicationError)
│   └── ProductRepository.ts                 # Repository Interface
├── application/
│   ├── create/
│   │   └── ProductCreator.ts                # @Service() use case
│   ├── update-stock/
│   │   └── ProductStockUpdater.ts           # @Service() use case
│   ├── search-all/
│   │   └── AllProductsSearcher.ts           # @Service() use case
│   └── search-by-id/
│       └── ProductByIdSearcher.ts           # @Service() use case
└── infrastructure/
    └── PostgresProductRepository.ts         # Extends PostgresRepository<Product>

src/app/api/products/
├── route.ts                                 # GET (list), POST (create)
└── [id]/
    └── route.ts                             # GET (by-id), PATCH (update-stock)

tests/contexts/pantry/products/
├── domain/
│   ├── ProductMother.ts                     # Faker-based Object Mother
│   ├── ProductIdMother.ts
│   ├── ProductNameMother.ts
│   └── ProductStockMother.ts
├── infrastructure/
│   └── MockProductRepository.ts             # Jest-based mock
└── application/
    ├── create/
    │   └── ProductCreator.test.ts
    ├── update-stock/
    │   └── ProductStockUpdater.test.ts
    └── search-all/
        └── AllProductsSearcher.test.ts

databases/
└── 2-pantry.sql                             # Schema migration (no triggers)
```

---

## Implementation Order (Outside-In TDD)

### Phase 1: RED - Integration Tests First
Create API integration tests based on Gherkin scenarios (using supertest):

1. `tests/contexts/pantry/api/products/POST-products.test.ts`
   - Scenario: Successfully adding a new product
   - Scenario: Preventing duplicate products (case-insensitive)
   - Scenario: Preventing negative stock on create

2. `tests/contexts/pantry/api/products/[id]/PATCH-products-by-id.test.ts`
   - Scenario: Updating stock levels
   - Scenario: Preventing negative stock on update

### Phase 2: GREEN - Make Tests Pass
Implement bottom-up to satisfy integration tests:

3. Database schema `databases/2-pantry.sql`:
   ```sql
   CREATE SCHEMA IF NOT EXISTS pantry;

   CREATE TABLE pantry.products (
       id UUID PRIMARY KEY NOT NULL,
       name TEXT NOT NULL,
       name_normalized TEXT GENERATED ALWAYS AS (LOWER(TRIM(name))) STORED NOT NULL,
       current_stock INTEGER NOT NULL DEFAULT 0 CHECK (current_stock >= 0),
       last_updated TIMESTAMP WITH TIME ZONE NOT NULL,
       created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
   );

   CREATE UNIQUE INDEX products_name_normalized_idx ON pantry.products(name_normalized);
   ```

3.5. Create ApplicationError base class at `/src/contexts/shared/domain/ApplicationError.ts`:
   ```typescript
   type ApplicationErrorPrimitives = {
     type: string;
     params: Record<string, unknown>;
   };

   export abstract class ApplicationError extends Error {
     constructor(public readonly params: Record<string, unknown> = {}) {
       super();
     }

     abstract override get message(): string;

     toPrimitives(): ApplicationErrorPrimitives {
       return {
         type: this.message,
         params: this.params,
       };
     }
   }
   ```

4. Domain Layer:
   - `ProductId.ts` - extends `Identifier` from `/src/contexts/shared/domain/Identifier.ts`
   - `ProductStock.ts` - extends `NumberValueObject`, validates integer >= 0
   - `ProductName.ts` - extends `StringValueObject`, adds `equals()` for case-insensitive comparison
   - `ProductAlreadyExistsError.ts` - extends `ApplicationError`, message = "PRODUCT_ALREADY_EXISTS"
   - `InvalidStockLevelError.ts` - extends `ApplicationError`, message = "INVALID_STOCK_LEVEL"
   - `ProductRepository.ts` - abstract interface with `save()`, `searchById()`, `searchAll()`, `searchByName()`
   - `Product.ts` - AggregateRoot with `create()`, `fromPrimitives()`, `updateStock()`, `toPrimitives()`

5. Infrastructure Layer:
   - `PostgresProductRepository.ts` - extends `PostgresRepository<Product>` from `/src/contexts/shared/infrastructure/postgres/PostgresRepository.ts`
   - Override `toAggregate()` to map Row → Product
   - Implement `save()`, `searchById()`, `searchAll()`, `searchByName()` using template queries

6. Application Layer (all decorated with `@Service()`):
   - `ProductCreator.ts` - checks uniqueness via `searchByName()`, calls `Product.create()`, saves
   - `ProductStockUpdater.ts` - loads product, validates new stock, calls `updateStock()`, saves
   - `AllProductsSearcher.ts` - returns `toPrimitives()` for all products
   - `ProductByIdSearcher.ts` - returns single product or null

7. API Routes (both import "reflect-metadata" at top):
   - `/api/products/route.ts` - POST (create), GET (list all)
   - `/api/products/[id]/route.ts` - PATCH (update stock), GET (by id)
   - Use `HttpNextResponse` from `/src/contexts/shared/infrastructure/http/HttpNextResponse.ts`
   - Handle errors with appropriate status codes (409 for duplicate, 400 for invalid stock)

8. DI Container Registration (`/src/contexts/shared/infrastructure/dependency-injection/diod.config.ts`):
   ```typescript
   import { ProductRepository } from "../../../pantry/products/domain/ProductRepository";
   import { PostgresProductRepository } from "../../../pantry/products/infrastructure/PostgresProductRepository";
   import { ProductCreator } from "../../../pantry/products/application/create/ProductCreator";
   import { ProductStockUpdater } from "../../../pantry/products/application/update-stock/ProductStockUpdater";
   import { AllProductsSearcher } from "../../../pantry/products/application/search-all/AllProductsSearcher";
   import { ProductByIdSearcher } from "../../../pantry/products/application/search-by-id/ProductByIdSearcher";

   builder.register(ProductRepository).use(PostgresProductRepository);
   builder.registerAndUse(PostgresProductRepository);
   builder.registerAndUse(ProductCreator);
   builder.registerAndUse(ProductStockUpdater);
   builder.registerAndUse(AllProductsSearcher);
   builder.registerAndUse(ProductByIdSearcher);
   ```

### Phase 3: REFACTOR - Improve Design
Add Object Mothers and unit tests:

9. Object Mothers (all use `faker` from `@faker-js/faker`):
   - `ProductMother.ts` - main mother with `create(params?: Partial<ProductPrimitives>)`
   - `ProductIdMother.ts`, `ProductNameMother.ts`, `ProductStockMother.ts`

10. Mock Repository (`MockProductRepository.ts`):
    - Implements `ProductRepository`
    - Uses Jest mocks internally (`jest.fn()`)
    - Provides `should*()` methods to set expectations
    - Follow pattern from `/tests/contexts/dishes/cooked-dishes/infrastructure/MockCookedDishRepository.ts`

11. Unit Tests for Application Layer:
    - `ProductCreator.test.ts` - test success, duplicate error, invalid stock error
    - `ProductStockUpdater.test.ts` - test update, not found, invalid stock
    - `AllProductsSearcher.test.ts` - test empty list, populated list

12. Unit Tests for Domain Layer:
    - `ProductStock.test.ts` - test negative throws, non-integer throws
    - `ProductName.test.ts` - test case-insensitive equality

---

## Key Patterns to Reference

| Pattern | Reference File |
|---------|----------------|
| Aggregate Root | `/src/contexts/dishes/cooked-dishes/domain/CookedDish.ts` |
| Value Object | `/src/contexts/shared/domain/StringValueObject.ts` |
| Domain Error | `/src/contexts/shared/domain/ApplicationError.ts` (new, similar to CodelyError.ts) |
| Repository | `/src/contexts/dishes/cooked-dishes/domain/CookedDishRepository.ts` |
| Postgres Repo | `/src/contexts/dishes/cooked-dishes/infrastructure/PostgresCookedDishRepository.ts` |
| Use Case | `/src/contexts/dishes/cooked-dishes/application/create/CookedDishCreator.ts` |
| API Route | `/src/app/api/cooked-dishes/route.ts` |
| Object Mother | `/tests/contexts/dishes/cooked-dishes/domain/CookedDishMother.ts` |
| Mock Repo | `/tests/contexts/dishes/cooked-dishes/infrastructure/MockCookedDishRepository.ts` |
| App Test | `/tests/contexts/dishes/cooked-dishes/application/create/CookedDishCreator.test.ts` |
| DI Config | `/src/contexts/shared/infrastructure/dependency-injection/diod.config.ts` |
| HTTP Response | `/src/contexts/shared/infrastructure/http/HttpNextResponse.ts` |
| UUID Generator | `/src/contexts/shared/infrastructure/NativeUuidGenerator.ts` |

---

## Important Notes

1. **No Database Triggers**: `lastUpdated` is set in the domain layer (`Product.updateStock()`) and passed through to the database. The application layer manages this timestamp.

2. **Case-Insensitive Uniqueness**: Implemented via:
   - `name_normalized` column with `LOWER(TRIM(name))` stored value
   - Unique index on `name_normalized`
   - `ProductName.equals()` method for domain comparison

3. **Stock Validation**: `ProductStock` value object enforces both BR2 (non-negative) and BR3 (integer) at the domain level.

4. **API Response Format**: All responses use `camelCase` matching `ProductPrimitives` interface.

5. **Error Handling**: Domain errors extend `ApplicationError` (new class at `/src/contexts/shared/domain/ApplicationError.ts`) with specific `message` values ("PRODUCT_ALREADY_EXISTS", "INVALID_STOCK_LEVEL").

---

## Verification

Run the following to verify implementation:

```bash
# Start database
docker compose up

# Run linting
npm run lint:fix

# Run tests
npm run test

# Run all checks
npm run checks

# Manual API testing
curl -X POST http://localhost:3000/api/products -H "Content-Type: application/json" -d '{"name":"Pasta","currentStock":5}'
curl http://localhost:3000/api/products
curl -X PATCH http://localhost:3000/api/products/<id> -H "Content-Type: application/json" -d '{"currentStock":10}'
```
