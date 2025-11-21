# Agent Guidelines for slot-validate

## Build & Test Commands

**Hype-Rs (Rust Core)**:
- Build: `cargo build`
- Release build: `cargo build --release`  
- Run tests: `cargo test`
- Run single test: `cargo test test_name -- --nocapture`
- Run test subset: `cargo test module_name`
- Lint: `cargo clippy -- -D warnings`
- Format check: `cargo fmt -- --check`
- Format fix: `cargo fmt`

**Slot Validation System**:
- Run validation: `hype validate-nonces.lua`
- Test validation script: `./scripts/run-validator-test.sh`
- Production validator: `./scripts/run-validator.sh`
- Validation with options: `hype validate-nonces.lua -- --verbose --concurrency=20 --only-mismatches`

## Code Style Guidelines

### Rust Code (hype-rs)
- **Imports**: std → external crates → internal modules (crate::)
- **Formatting**: Always run `cargo fmt` before committing
- **Types**: Use explicit type annotations, custom Result<T> aliases
- **Naming**: snake_case functions, PascalCase types, SCREAMING_SNAKE_CASE constants
- **Error handling**: Custom error enums with `?` propagation, implement Display trait
- **Comments**: NO comments unless absolutely necessary

### Lua Code (Validation Scripts)  
- **Module imports**: `require("module_name")`
- **Variables**: snake_case naming
- **Functions**: snake_case with descriptive names
- **Tables**: Use dot notation when possible, bracket notation for dynamic keys
- **Error handling**: Use `pcall` for safe execution, provide clear error messages
- **Formatting**: 2-space indentation, consistent spacing around operators

### Configuration
- **JSON files**: Minified, consistent key ordering
- **Shell scripts**: Use set -e, proper error handling, descriptive comments
- **Environment**: Use env vars for secrets (PAGERDUTY_ROUTING_KEY)

### CLI Interface
- **Validation script**: Comprehensive help with `--help`
- **Options parsing**: Pattern matching for flags, validation of values
- **Output**: Color-coded results (green=match, red=mismatch, yellow=error)
- **Progress**: Show processing progress for long operations