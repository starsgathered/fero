# Fero

**Fero** is a lightweight, scalable **sync orchestration SDK** designed to standardize and simplify data synchronization across platforms and frameworks.
It abstracts **retry logic, backoff strategies, sync state, and orchestration**, so application code stays clean while sync behavior remains consistent.

> Build once. Sync everywhere.

---

## Why Fero?

Modern apps need reliable syncing—offline support, retries, partial failures, background recovery—but implementing this logic repeatedly in every app and platform quickly becomes messy.

**Fero solves this by acting as the sync brain.**

You provide:

* What to sync
* How to sync (handlers)

Fero handles:

* Retry & backoff
* Orchestration
* Sync state tracking
* Failure recovery
* Consistent behavior across platforms

---

## What Fero Is (and Is Not)

### ✅ Fero *is*

* A **Sync Orchestration SDK**
* A **platform-agnostic core**
* A **stateful sync coordinator**
* Designed for **Flutter, Rust, JS, and beyond**

### ❌ Fero is *not*

* A UI framework
* A database
* A network client
* A simple utility library

If your app only needs a helper function—Fero is overkill.
If your app needs **reliable, repeatable sync at scale**—Fero fits.

---

## Core Concepts

### Sync Item

A single unit of synchronization (feature, resource, or module).

### Sync Handler

User-provided logic that performs the actual sync operation.

### Orchestrator

Coordinates when, how, and in what order syncs run.

### Backoff Strategy

Controls retry behavior on failure (exponential, fixed, custom).

### Sync State

Tracks progress, failures, retries, and completion.

---

## High-Level Architecture

```
App / UI Layer
     ↓
Sync Handlers (User Code)
     ↓
Fero Orchestrator
     ↓
Retry + Backoff + State Engine
```

Fero owns **policy and orchestration**.
You own **business logic**.

---

## Typical Use Case

* Offline-first apps
* Multi-feature sync pipelines
* Background sync
* SDKs used across multiple apps
* Shared sync logic across Flutter, Web, and Native

---

## Example Flow

1. App triggers sync
2. Fero checks sync state
3. Required items are scheduled
4. Handlers are executed
5. Failures trigger retries via backoff
6. State is updated and reported

---

## Design Principles

* **SDK-first** — built to be embedded, not hacked in
* **Deterministic behavior** — same input, same sync result
* **Platform-agnostic core**
* **Minimal surface API**
* **Extensible, not opinionated**

---

## Supported Platforms

* Flutter / Dart
* JavaScript / TypeScript (planned)
* Any platform that can call handlers

---

## When Should You Use Fero?

Use Fero if:

* Sync logic is repeating across apps
* You need consistent retry behavior
* You want sync logic independent of UI
* You’re building an SDK, not just an app

Don’t use Fero if:

* You only sync once
* Failures don’t matter
* You want quick hacks instead of systems

---

## Status

🚧 **Active Development**
APIs may evolve before stable release.

---

## Philosophy

> Sync is not a feature.
> Sync is infrastructure.

Fero treats synchronization as a **first-class system**, not an afterthought.

---

## License

MIT License
