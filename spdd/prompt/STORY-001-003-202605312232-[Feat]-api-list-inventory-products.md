# [STORY-001-003] List All Inventory Products with Cursor-Based Pagination

## Requirements
Implement a read-only list operation for inventory items that provides complete pantry visibility through alphabetical ordering and cursor-based infinite scroll pagination, enabling users to view all products regardless of state while supporting efficient navigation through large inventories without traditional pagination limitations.

## Entities
```mermaid
classDiagram
    direction TB

    class InventoryItem {
        +String id
        +String name
        +InventoryItemState state
        +Date createdAt
        +Boolean requiresPurchase
        +toPrimitives() InventoryItemPrimitives
    }

    class InventoryItemState {
        +String value
        +isAvailable() Boolean
        +derivesRequiresPurchase() Boolean
        +static Available() InventoryItemState
        +static Low() InventoryItemState
        +static Depleted() InventoryItemState
    }

    class InventoryItemLister {
        +listAll(limit, cursor) PaginatedInventoryItems
    }

    class InventoryItemRepository {
        +save(item) Promise~void~
        +searchById(id) Promise~InventoryItem | null~
        +findById(id) Promise~InventoryItem~
        +searchAll(limit, cursor) Promise~PaginatedInventoryItems~
    }

    class PostgresInventoryItemRepository {
        +sql Sql
        +save(item) Promise~void~
        +searchById(id) Promise~InventoryItem | null~
        +findById(id) Promise~InventoryItem~
        +searchAll(limit, cursor) Promise~PaginatedInventoryItems~
    }

    class Cursor {
        +String name
        +Date createdAt
        +encode() String
        +static decode(token) Cursor
        +static fromPrimitives(primitives) Cursor
    }

    class PaginatedInventoryItems {
        +Array~InventoryItemPrimitives~ items
        +String nextCursor
        +Boolean hasMore
    }

    class GETRequestParams {
        +Number limit
        +String cursor
    }

    InventoryItemLister "1" --> "1" InventoryItemRepository : uses
    InventoryItemRepository "1" --> "1" PostgresInventoryItemRepository : implemented by
    InventoryItem "1" --> "1" InventoryItemState : contains
    GETRequestParams --> InventoryItemLister : triggers
    InventoryItemLister --> PaginatedInventoryItems : returns
    Cursor --> InventoryItemLister : used by
    PaginatedInventoryItems "1" --> "*" InventoryItem : contains primitives of
```

## Approach
1. **API Design Pattern**:
   - Extend existing `/api/inventory/items` route to support GET method alongside current POST
   - Follow REST conventions: GET for collection retrieval, POST for creation
   - Implement cursor-based pagination using opaque tokens for infinite scroll experience
   - Return structured response with `items`, `nextCursor`, and `hasMore` metadata

2. **Technical Implementation**:
   - **Framework**: Next.js 16 API Routes with TypeScript strict mode
   - **Architecture**: Hexagonal/DDD pattern with clear layer separation (Controller → Application → Repository → Database)
   - **Pagination Strategy**: Composite keyset cursor using `[name, created_at]` for correct alphabetical ordering
   - **Cursor Encoding**: Base64-encoded JSON to make implementation details opaque
   - **Performance**: Single-query pagination with composite index on `(name, created_at)`
   - **Exception Handling**: Custom domain exceptions with unified HttpNextResponse error handling

3. **Business Logic**:
   - **Core Rule**: Return ALL products regardless of state or `requires_purchase` value (no filtering)
   - **Alphabetical Ordering**: Primary sort by `name` ASC, secondary by `created_at` for uniqueness
   - **Default Behavior**: Default `limit=20`, return first page when no cursor provided
   - **Empty Inventory**: Return empty array with `nextCursor: null` and `hasMore: false` (not 404)
   - **Cursor Validation**: Reject malformed cursors with 400 Bad Request, decode safely with try-catch
   - **Limit Validation**: Validate `limit` parameter (1-100 range), default to 20 if invalid

## Structure

### Inheritance Relationships
1. **InventoryItemRepository** interface defines persistence contract for inventory items
2. **PostgresInventoryItemRepository** implements InventoryItemRepository interface, extends PostgresRepository~InventoryItem~
3. **InventoryItem** extends AggregateRoot base class from shared domain
4. **InventoryItemState** extends StringValueObject from shared domain
5. **Cursor** extends ValueObject base pattern (new value object)
6. **InvalidCursorError** extends Error or CodelyError base class (new domain exception)

### Dependencies
1. **API Route Handler** (`/api/inventory/items/route.ts`) calls InventoryItemLister
2. **InventoryItemLister** depends on InventoryItemRepository and Cursor value object
3. **PostgresInventoryItemRepository** depends on PostgresConnection and extends PostgresRepository
4. **InventoryItemLister** uses Cursor for encoding/decoding pagination tokens
5. **DI Container** (diod.config.ts) registers InventoryItemLister as @Service()

### Layered Architecture
1. **Controller Layer**: Next.js API route handler (`/api/inventory/items/route.ts`)
   - Responsibilities: Request parsing, parameter validation, response serialization
   - Handles HTTP concerns (status codes, content-type, error responses)

2. **Application Layer**: InventoryItemLister (`src/contexts/inventory/inventory-items/application/list/`)
   - Responsibilities: Orchestrate list retrieval, cursor decoding, response building
   - Contains business logic for pagination and empty inventory handling

3. **Domain Layer**: InventoryItem aggregate, InventoryItemState, Cursor value object
   - Responsibilities: Business rules, entity state management, value object validation
   - Enforces invariants (valid state values, cursor encoding rules)

4. **Repository Layer**: InventoryItemRepository interface, PostgresInventoryItemRepository implementation
   - Responsibilities: Data access, SQL query execution, aggregate reconstruction
   - Implements searchAll method with cursor-based pagination logic

5. **Infrastructure Layer**: PostgresConnection, HttpNextResponse
   - Responsibilities: Database connection management, HTTP response formatting
   - Provides cross-cutting utilities for persistence and API communication

6. **Exception Handling Layer**: Domain-specific exceptions with unified HttpNextResponse error handling
   - Responsibilities: Centralized error handling, consistent error response format
   - Maps domain exceptions to appropriate HTTP status codes

## Operations

### Create Value Object - Cursor
1. **Responsibility**: Encode and decode composite cursor tokens for pagination
2. **Attributes**:
   - `name`: String - Last seen product name for cursor continuation
   - `createdAt`: Date - Timestamp for uniqueness with duplicate names
3. **Methods**:
   - `encode(): String`
     - Logic: Serialize `{name, createdAt}` to JSON, then base64-encode
     - Error handling: Throws error if encoding fails (should not occur with valid data)
   - `static decode(token: String): Cursor`
     - Logic: Base64-decode token, parse JSON, validate structure, reconstruct Cursor
     - Conditional logic: Return null or throw InvalidCursorError if malformed
     - Error handling: Try-catch parsing, throw InvalidCursorError with descriptive message
   - `static fromPrimitives(primitives: {name: String, createdAt: String}): Cursor`
     - Logic: Validate name non-empty, parse createdAt as ISO string, create Cursor instance
     - Conditional logic: Throw error if name empty or createdAt invalid
4. **Annotations**: None (value object)
5. **Constraints**:
   - Name must be non-empty string
   - CreatedAt must be valid ISO 8601 date string
   - Encoded token must be base64 string (not encrypted, just opaque)

### Create DTO - PaginatedInventoryItems
1. **Responsibility**: Container for paginated list response with metadata
2. **Attributes**:
   - `items`: Array~InventoryItemPrimitives~ - Array of product data for current page
   - `nextCursor`: String | null - Opaque token for next page, null if no more results
   - `hasMore`: Boolean - Indicates whether additional pages exist
3. **Methods**:
   - `static empty(): PaginatedInventoryItems`
     - Logic: Return instance with empty items array, null nextCursor, false hasMore
   - `static fromItems(items: Array~InventoryItem~, nextCursor: String | null, hasMore: Boolean): PaginatedInventoryItems`
     - Logic: Map items to primitives, construct response with provided metadata
     - Conditional logic: Set nextCursor to null if hasMore is false
4. **Annotations**: None (simple DTO)
5. **Constraints**:
   - Items array cannot be null (use empty array instead)
   - nextCursor must be null when hasMore is false
   - nextCursor must be non-null when hasMore is true

### Create Domain Exception - InvalidCursorError
1. **Responsibility**: Represent malformed or invalid cursor tokens
2. **Attributes**:
   - `message`: String - Descriptive error message for debugging
   - `cursor`: String - The malformed cursor value (for debugging)
3. **Methods**:
   - `constructor(message: String, cursor: String)`
     - Logic: Store message and cursor for error reporting
4. **Inheritance**: Extends Error or CodelyError base class
5. **Usage Scenarios**: Thrown when client provides malformed base64 or invalid cursor structure

### Extend Repository Interface - InventoryItemRepository
1. **Interface Method Addition**:
   - Add method signature: `searchAll(limit: Number, cursor: String | null): Promise~PaginatedInventoryItems~`
   - Contract: Returns paginated results, handles null cursor as "first page" request
   - Return type: PaginatedInventoryItems with items array, nextCursor, hasMore flag

2. **Implementation in PostgresInventoryItemRepository**:
   - `async searchAll(limit: Number, cursor: String | null): Promise~PaginatedInventoryItems>`
     - **Input Validation**:
       - Validate limit between 1-100, default to 20 if invalid
       - Decode cursor using Cursor.decode() if provided, treat null as first page
       - Throw InvalidCursorError if cursor malformed
     - **Business Logic**:
       - Fetch limit + 1 items to determine if more pages exist
       - If cursor provided: Filter WHERE name > cursor.name OR (name = cursor.name AND created_at > cursor.createdAt)
       - If no cursor: No WHERE filter (start from beginning)
       - Sort by ORDER BY name ASC, created_at ASC
       - If returned items > limit: Remove last item, set nextCursor from that item, hasMore = true
       - If returned items <= limit: Set nextCursor = null, hasMore = false
     - **Edge Cases**:
       - Empty result set: Return PaginatedInventoryItems.empty()
       - Last page: hasMore = false, nextCursor = null
       - Concurrent modifications handled naturally by cursor pagination
     - **Return Value**: Construct PaginatedInventoryItems with mapped primitives and metadata

### Create Application Service - InventoryItemLister
1. **Interface Definition**: No separate interface (follow existing pattern of concrete application services)
2. **Core Methods**:
   - `async listAll(limit: Number = 20, cursor: String | null = null): Promise~PaginatedInventoryItems~`
     - **Input Validation**:
       - Parse limit as number, validate range 1-100, default to 20
       - Pass cursor to repository (repository handles decoding and validation)
     - **Business Logic**:
       - Delegate to repository.searchAll(limit, cursor)
       - Return repository response directly (no additional transformation needed)
     - **Exception Handling**: Propagate InvalidCursorError from repository
     - **Return Value**: PaginatedInventoryItems from repository
3. **Dependency Injection**: Inject InventoryItemRepository through constructor
4. **Transaction Management**: Read-only operation, no transaction needed
5. **Annotations**: @Service() for DIOD registration

### Update API Route Handler - /api/inventory/items/route.ts
1. **Add GET Method alongside existing POST**:
   - `export async function GET(request: NextRequest): Promise~NextResponse~`
     - **Input Validation**:
       - Parse URL search params: limit = searchParams.get('limit'), cursor = searchParams.get('cursor')
       - Validate limit: parse as int, default to 20 if missing or invalid
       - Cursor validation handled by service layer (pass raw string or null)
     - **Business Logic**:
       - Call InventoryItemLister.listAll(limit, cursor)
       - Handle InvalidCursorError: return 400 Bad Request with error message
       - Handle unexpected errors: propagate to global error handler
     - **Return Value**: HttpNextResponse.ok(paginatedItems) with 200 status
     - **Response Format**: JSON with items, nextCursor, hasMore fields
   - **Annotations**: None (Next.js route handler)
   - **Constraints**:
     - Must not interfere with existing POST handler
     - Must handle empty query params (limit, cursor absent)
     - Must return 200 even for empty results (not 404)

### Update DI Container - diod.config.ts
1. **Register InventoryItemLister**:
   - Add `.register(InventoryItemLister)` to container configuration
   - Follow pattern of existing application service registrations
   - Ensure repository dependency is automatically injected by DIOD

### Add Database Index - Migration
1. **Create new migration file**:
   - Filename: `YYYYMMDD_add_inventory_items_name_index.sql`
   - SQL: `CREATE INDEX idx_inventory_items_name_created_at ON inventory.inventory_items(name, created_at);`
   - Rationale: Optimize ORDER BY name ASC, created_at ASC query performance
   - Note: Idempotent (use IF NOT EXISTS or CONFLICT check if needed)

## Norms
1. **Annotation Standards**:
   - Application services: `@Service()` decorator from diod
   - Repository implementations: `@Service()` decorator from diod
   - Domain entities: No annotations (plain TypeScript classes)
   - API routes: No annotations (Next.js file-based routing)
   - Value objects: No annotations (plain TypeScript classes)

2. **Dependency Injection**:
   - Use DIOD container with constructor injection
   - Register all services in `src/contexts/shared/infrastructure/dependency-injection/diod.config.ts`
   - Follow pattern: container.get(ServiceClass) in route handlers
   - Let DIOD handle dependency resolution automatically

3. **Exception Handling**:
   - **Domain Exceptions**: Create custom exception classes (InvalidCursorError)
     - Inherit from Error or CodelyError base class
     - Include descriptive message and relevant context (cursor value)
     - Throw at domain/service layer, catch at controller layer
   - **API Response**: Use HttpNextResponse for consistent error responses
     - 400 Bad Request for InvalidCursorError
     - 500 Internal Server Error for unexpected errors
     - Never expose stack traces or internal system details
   - **Logging**: Log errors with context before returning error responses

4. **Data Validation**:
   - Validate input at controller layer (limit parameter range)
   - Validate business rules at domain layer (cursor structure, entity invariants)
   - Use type guards and validation functions for complex validation
   - Return early with error responses for invalid input

5. **Logging**:
   - Log repository queries for debugging (use existing postgres logging)
   - Log cursor decoding failures with invalid cursor value
   - Log empty inventory results if unexpected (info level)
   - Follow existing logging patterns in codebase

6. **Documentation Standards**:
   - Add JSDoc comments to public methods (especially in value objects and services)
   - Document complex business logic (cursor pagination algorithm)
   - Comment non-obvious code (composite cursor reasoning)
   - Follow existing comment style in codebase (concise, purpose-focused)

7. **TypeScript Standards**:
   - Use explicit return types (as required by eslint-config-codely)
   - Leverage existing shared types (AggregateRoot, ValueObject patterns)
   - Use `readonly` for immutable properties in value objects
   - Prefer `interface` for DTOs, `class` for domain entities with behavior

## Safeguards
1. **Functional Constraints**:
   - Must return ALL inventory items without filtering by state or purchase status
   - Must maintain alphabetical ordering regardless of pagination state
   - Must handle empty inventory without error (return empty array, not 404)
   - Must support cursor pagination from any point in the result set
   - Must not expose `created_at` timestamp in API response (internal use only)

2. **Performance Constraints**:
   - Single database query per request (no N+1 queries)
   - Fetch limit + 1 items for hasMore detection (not separate count query)
   - Database query must use composite index on (name, created_at)
   - Response time should be < 500ms for typical home inventory sizes (< 1000 items)
   - Memory usage should be bounded by limit parameter (not load all items)

3. **Security Constraints**:
   - Validate limit parameter to prevent excessive resource usage (max 100)
   - Sanitize cursor input to prevent injection attacks (base64 decode safely)
   - Return generic error messages for malformed cursors (don't expose internal structure)
   - No authentication required (home inventory assumption, documented)

4. **Integration Constraints**:
   - Must not break existing POST /api/inventory/items endpoint
   - Must maintain backward compatibility with existing repository interface
   - Must follow existing DIOD registration patterns
   - Must use existing HttpNextResponse formatting (no custom response types)

5. **Business Rule Constraints**:
   - Alphabetical ordering must be case-insensitive (database collation dependent)
   - Cursor pagination must handle duplicate product names correctly
   - Empty cursor string must be treated same as null (first page)
   - hasMore must be false when nextCursor is null (consistency requirement)

6. **Exception Handling Constraints**:
   - InvalidCursorError must map to 400 Bad Request response
   - Repository errors must propagate to 500 Internal Server Error
   - Exception messages must not include sensitive system information
   - All exceptions must be caught at route handler level (no unhandled rejections)

7. **Technical Constraints**:
   - Must use TypeScript strict mode (existing project requirement)
   - Must follow ESLint config from eslint-config-codely (existing project requirement)
   - Must use existing postgres connection (no new connection pools)
   - Must use existing PostgresRepository base class pattern

8. **Data Constraints**:
   - Cursor token must be valid base64 string (enforced by decode validation)
   - Limit parameter must be positive integer between 1-100 (validated at controller)
   - Product names can be any valid string (no additional validation required)
   - created_at must be valid ISO 8601 timestamp (enforced by database schema)

9. **API Constraints**:
   - GET /api/inventory/items must return 200 status for all successful requests
   - Response must include items (array), nextCursor (string|null), hasMore (boolean)
   - Response format must match PaginatedInventoryItems structure exactly
   - Must support both ?limit=10 and ?cursor=xxx and combined parameters
