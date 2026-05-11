# My Home Storefront

Inventory system to manage product stock in the home pantry.

## Prerequisites

- **Node.js** 20+
- **Docker Desktop** - Required for PostgreSQL database used by integration tests

### Installing Docker Desktop

Docker Desktop is needed to run the PostgreSQL database. Install it from:
- https://www.docker.com/products/docker-desktop/
- Or using Homebrew: `brew install --cask docker`

## Development

### Start the database

```bash
docker compose up
```

### Useful commands

```bash
npm run checks    # lint + build + test
npm run dev       # local dev server (not Docker)
npm run lint:fix
npm run test
```

### Running tests

- **All tests**: `npm test` (requires Docker Desktop running for integration tests)
- **Unit tests only**: `npx jest --testPathIgnorePatterns=".*infrastructure.*"`
- **Pantry tests**: `npx jest --testPathPatterns="pantry"`

## Project structure

### AI development configuration

- **AGENTS.md** - Acts as the "identity and operations manual" for AI agents interacting with this project. It defines rules, context, and specific preferences that agents should follow when working on the codebase.
- **scripts/generate-claude-symlinks.sh** - Creates `CLAUDE.md → AGENTS.md` symlinks for compatibility with tools that look for different config file names
- **Makefile** - Target `make claude-symlinks` to run the symlink script
