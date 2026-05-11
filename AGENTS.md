# Useful commands

```bash
docker compose up # start database
npm run checks    # lint + build + test
npm run dev       # local dev server (not Docker)
npm run lint:fix
npm run test
```

# Architecture

- Next.js 16, Hexagonal Architecture / DDD.
- Frontend: `src/app/`. API routes: `src/app/api/`. Backend: `src/contexts/`.
- Layers: Domain → Application (one use case per class) → Infrastructure.
- DI: DIOD with `@Service()`, container at `src/contexts/shared/infrastructure/dependency-injection/diod.config.ts`.
- API routes require `import "reflect-metadata"` at top

# DB
- PostgreSQL + pgvector.
- Embeddings `vector(1024)`.

# Testing

- Always use object mothers to instantiate aggregates in tests (`tests/contexts/*/domain/`)
- Mock objects are implementations of domain interfaces (e.g. `MockEventBus` implements `EventBus`) in `tests/contexts/*/infrastructure/`

# Code Style

- `eslint-config-codely` preset
- `explicit-function-return-type: error`
- TypeScript strict mode with decorators

# Spec-Driven Development (SDD)

- **Source of Truth:** All features must start with a specification file in `/specs`. 
- **Format:** Use Markdown + Gherkin scenarios (Given/When/Then).
- **Process:** Specification → Integration Tests → Implementation.
- **Constraints:** Never implement logic that is not explicitly described in a Business Rule (BR) within the spec.

# Testing Strategy

- **API-First Integration:** Prioritize testing the API layer (`src/app/api/`) to validate Gherkin scenarios from the specs.
- **Tools:** Use `supertest` for API integration and `jest` for unit tests.
- **Coverage:** Focus on Business Rules (BR) enforcement rather than 100% line coverage.
- **Object Mothers:** (Existing rule) Always use object mothers to instantiate aggregates in tests.
- **Mocking:** (Existing rule) Mock domain interfaces at the infrastructure layer.

# Outside-In TDD Workflow

- **Step 1 (Red):** Create a high-level Integration Test in `src/app/api/` based on a Gherkin scenario. It must fail.
- **Step 2 (Green):** Implement the Infrastructure (Controller) and the Application layer (Use Case).
- **Step 3 (Refactor):** Move domain logic to the Domain layer (Aggregates/Entities) and use Object Mothers for testing.
- **Rule:** Do not write Application or Domain code without a failing test at the API or Application level first.
