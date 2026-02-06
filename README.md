# Fero

Fero is a workspace containing a Rust `core` crate that implements sync primitives and a set of language bindings and example apps (Flutter, Next.js, Python). The repository is organized as a workspace to make it easy to build the core library and provide bindings for multiple platforms.

Contents

- `core/` - Primary Rust crate containing the sync engine, traits, implementations, FFI surface, and tests.
- `bindings/` - Language-specific binding glue (Flutter, Next.js, Python).
- `examples/` - Small example projects demonstrating how to use the core crate via bindings.
- `tests/` - Integration and unit test helpers outside crates.
- `docs/` - Project documentation and design notes.

Getting started

Prerequisites

- Rust toolchain (stable) installed: https://rustup.rs
- `cargo` on PATH

Build the core crate

```bash
cd core
cargo build
```

Run tests

```bash
cd core
cargo test
```

Workspace build (from repository root)

```bash
cargo build --workspace
```

Development notes

- The `core` crate follows a modular layout under `core/src/` with clear separation:
  - `traits/` — trait definitions for sync, network, storage, etc.
  - `sync/` — synchronization engine, incremental and initial sync logic, conflict resolution and backoff strategies.
  - `impls/` — concrete implementations wiring traits together.
  - `types/` — enums and constants used across the crate.
  - `ffi/` — C-compatible entry points consumed by language bindings.

- Bindings live in `bindings/` and are intentionally lightweight placeholders for now. Each binding should expose a stable FFI or generated wrapper that consumes `core`'s `ffi` module.

Examples

- `examples/flutter_example/` — placeholder for Flutter integration.
- `examples/nextjs_example/` — placeholder for Next.js (Node) integration.
- `examples/python_example/` — placeholder for Python integration.

Contributing

- Add well-scoped changes with tests.
- Keep design documents or API changes in `docs/`.

License

This project does not include a license file yet. Add a `LICENSE` at the repository root to make the licensing explicit.

Contact

Open issues or PRs for questions or contributions.
