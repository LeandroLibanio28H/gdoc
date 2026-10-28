<img width="1664" height="768" alt="gdoc-logo" src="https://github.com/user-attachments/assets/60233324-51ce-4824-8f9b-6482d3843a1b" style="image-rendering: pixelated;" />

**GDOC** is a modular, platform-agnostic library of utilities for game development in [Odin](https://odin-lang.org/), focused on performance, clarity, and reusability. It is not a monolithic game engine, but a collection of decoupled building blocks designed to help you construct your own specialized game engines.

GDOC has zero external dependencies beyond the Odin programming language.

> Built by [Leandro Libanio](https://libaniol.com).  
> Logo by [Kevin França](https://kevinfranca.carrd.co/).

---

## Modules

### ECS (Entity Component System)

The first core module of GDOC is a high-performance, memory-efficient ECS designed around a sparse-set architecture:

- **Cache-Friendly Storage**: Components are stored in contiguous memory for fast cache-coherent iterations.
- **DOD-first Queries**: Raw memory slice extraction (`world_component_slice`) for ultra-fast, linear iteration without generic pointer-hopping.
- **O(1) Static Typed Views**: `view_get` and `entity_get_component` leverage compile-time type resolution (`size_of(T)`) to perform static stride scaling. This bypasses the generic type-erased multiplication in the hot loop, generating raw `LEA` assembly instructions as fast as standard array lookups.
- **Generational Entities**: Safe entity handles that prevent stale references when entities are created and destroyed.
- **Zero-Allocation Scene Reset**: `world_clear` wipes all entities and components in $O(N_{\text{dense}})$ while preserving generational history and allocated capacities across scenes.
- **Deferred Command Buffer**: Queue entity creation, destruction, and component changes safely during system iterations.
- **Tag Components**: Full support for zero-sized tag markers (ZSTs) without memory overhead.
- **Custom Allocators**: Native support for Odin allocators (arenas, temporary allocators, tracking).

### Containers

High-performance data structures built specifically for Data-Oriented Design (DOD).

- **Sparse Set (`gdoc/containers`)**: Strongly-typed, platform-agnostic generic container `Sparse_Set($T)`. Unlike the internal ECS sparse set (which uses type erasure), this is built for developers to use directly. It features smart 4KB memory paging to prevent RAM bloat when dealing with disparate IDs.

---

## Getting Started

### Add as a Git Submodule

```bash
git submodule add https://github.com/LeandroLibanio28H/gdoc.git
```

### Import into your project

```odin
import ecs "path/to/gdoc/ecs"
import containers "path/to/gdoc/containers"
```

---

## Example

```odin
package main

import "core:fmt"
import ecs "path/to/gdoc/ecs"

Position :: struct {
    x, y: f32,
}

Velocity :: struct {
    vx, vy: f32,
}

Enemy :: struct {} // Tag component

main :: proc() {
    // Initialize the ECS world
    world: ecs.World
    ecs.world_init(&world, initial_capacity = 64)
    defer ecs.world_destroy(&world)

    // Initialize a standalone Sparse Set to map Entity IDs to Player Names
    // (Useful for external data that shouldn't pollute ECS CPU Cache, like strings or textures)
    player_names: containers.Sparse_Set(string)
    containers.sparse_set_init(&player_names, initial_capacity = 64)
    defer containers.sparse_set_destroy(&player_names)

    // Register components
    ecs.world_register_component(&world, Position)
    ecs.world_register_component(&world, Velocity)
    ecs.world_register_component(&world, Enemy)

    // Create an entity and attach components
    entity := ecs.entity_create(&world)
    ecs.entity_add_component(&world, entity, Position{x = 0, y = 0})
    ecs.entity_add_component(&world, entity, Velocity{vx = 100, vy = 50})
    ecs.entity_add_component(&world, entity, Enemy{})

    // Map external data to the entity ID using the standalone Sparse Set
    containers.sparse_set_insert(&player_names, entity.id, "Boss_Omega")

    // Query and update entities (Idiomatic DOD iteration)
    entities, positions := ecs.world_component_slice(&world, Position)
    velocity_view := ecs.world_component_view(&world, Velocity)

    for ent, i in entities {
        pos := &positions[i] // Direct contiguous memory access

        // Sparse access for secondary components using Views (O(1) fast path)
        if vel := ecs.view_get(velocity_view, ent); vel != nil {
            pos.x += vel.vx * 0.016
            pos.y += vel.vy * 0.016

            // Retrieve external data in O(1) from our standalone container
            name := containers.sparse_set_get(&player_names, ent.id)
            fmt.printfln("Enemy '%s' (ID: %d) moved to: (%.2f, %.2f)", name^, ent.id, pos.x, pos.y)
        }
    }

    // Safe mutations during iteration using deferred commands
    ecs.world_defer_begin(&world)

    enemies, _ := ecs.world_component_slice(&world, Enemy)
    for ent in enemies {
        ecs.entity_destroy(&world, ent)
    }

    ecs.world_defer_end(&world) // Flushes all changes atomically
}
```

---

## Roadmap

GDOC is continuously evolving to provide a full suite of low-level tools for game developers. Here is our progress and planned features:

### Core Systems

- [x] **ECS (Entity Component System)**: High-performance, generational sparse-set ECS.
- [ ] **Task Graph / Job System (`gdoc/jobs`)**: A game-focused thread-pool designed to batch and process massive arrays of ECS data concurrently across multiple CPU cores without lock contention.

### Advanced Containers (`gdoc/containers`)

- [x] **Sparse Set**: Standalone, paged sparse set for mapping arbitrary IDs to contiguous data without RAM bloat.
- [ ] **Slot Map (Generational Arena)**: Generates safe `Handle { index, generation }` keys to prevent dangling pointers. Essential for managing the lifecycle of Assets, Textures, and Network connections.
- [ ] **Generic Pool (Free-list)**: A true `O(1)` allocation/deallocation structure without index fragmentation. Perfect for high-churn, request-based objects where linear iteration isn't needed.
- [ ] **Ring Buffer**: Circular buffers for input event queues and audio streaming.

### Spatial Partitioning (`gdoc/spatial`)

- [ ] **Spatial Hash Grid**: Cache-friendly structure to map 2D/3D entities into a flat grid, enabling near-zero cost collision broad-phase tests.
- [ ] **Linear QuadTree / Octree**: Pointer-free, DOD-first implementations for hierarchical space partitioning.
- [ ] **Math Primitives**: AABBs, OBBs, Frustum culling, and Ray/Sphere intersections.

### Generic Asset Management (`gdoc/assets`)

- [ ] **Asset Cache**: Pure reference-counted asset lifecycle management.
- [ ] **Passive Hot-Reloading**: Hooks and indirection layers to swap pointers (like shaders or textures) at runtime without crashing the engine.

---

## Testing

GDOC includes built-in tests with memory tracking to ensure zero leaks:

```bash
odin test ecs
odin test containers
```
