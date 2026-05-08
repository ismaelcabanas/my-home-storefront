# My Home Storefront

Inventory system to manage product stock in the home pantry.

## Project structure

### AI development configuration

- **AGENTS.md** - Acts as the "identity and operations manual" for AI agents interacting with this project. It defines rules, context, and specific preferences that agents should follow when working on the codebase.
- **scripts/generate-claude-symlinks.sh** - Creates `CLAUDE.md → AGENTS.md` symlinks for compatibility with tools that look for different config file names
- **Makefile** - Target `make claude-symlinks` to run the symlink script
