<img width="1664" height="768" alt="gdoc-logo" src="https://github.com/user-attachments/assets/60233324-51ce-4824-8f9b-6482d3843a1b" style="image-rendering: pixelated;" />

**GDOC** is a modular, platform-agnostic library of utilities for game development in [Odin](https://odin-lang.org/), focused on performance, clarity, and reusability.

GDOC has zero external dependencies beyond the Odin programming language.

> Built by [Leandro Libanio](https://libaniol.com).  
> Logo by [Kevin França](https://kevinfranca.carrd.co/).

---

## Modules

### ECS - Entity Component System (`gdoc/ecs`)

A high-performance, memory-efficient ECS based on a sparse-set architecture:

- **Cache-Friendly Storage**: Components are stored in contiguous memory to maximize cache hits.
- **DOD-first Queries**: Direct memory slice extraction for ultra-fast, linear iteration over components.
- **O(1) Static Views**: Fast path for component lookups that bypasses type-erased overhead in the hot loop.
- **Generational Entities**: Safe handles to prevent stale references and dangling pointers.
- **Zero-Allocation Clear**: Rapidly resets scenes while preserving memory capacities to avoid allocation stuttering.
- **Deferred Commands**: Safely queue entity and component mutations while iterating over data.
- **Tag Components**: Zero-sized types (ZSTs) support with no memory overhead.
- **Custom Allocators**: Native support for Odin allocators.

### Containers (`gdoc/containers`)

- **Sparse Set**: Platform-agnostic generic container featuring smart memory paging to map disparate IDs without RAM bloat.
- **MPMC Queue**: Lock-free, atomic-based ring buffer for multi-producer, multi-consumer scenarios.

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

### Core Systems

- [x] **ECS (Entity Component System)**: High-performance, generational sparse-set ECS.
- [ ] **Job System (`gdoc/jobs`)**: Thread-pool to process ECS data concurrently.

### Advanced Containers (`gdoc/containers`)

- [x] **Sparse Set**: Standalone, paged sparse set for mapping arbitrary IDs to contiguous data without RAM bloat.
- [x] **Lock-Free Ring Buffer (MPMC Queue)**: An atomic-based, mutex-free circular queue. Essential for building high-performance Job Systems without thread contention.
- [ ] **Flat B-Tree**: An array-based tree structure that maintains sorted data (like Z-depth for rendering) without pointer-chasing, keeping the CPU cache hot.
- [ ] **Dense Grid (2D/3D)**: A DOD-wrapper around a 1D array to handle multi-dimensional spatial data (like Tilemaps or Voxel chunks) while respecting spatial locality (Morton/Z-Curve).

### Spatial Partitioning (`gdoc/spatial`)

- [ ] **Spatial Hash Grid**: Cache-friendly flat grid for broad-phase collisions.
- [ ] **Linear QuadTree / Octree**: Pointer-free space partitioning.
- [ ] **Math Primitives**: AABBs, OBBs, Frustum culling, and Ray/Sphere intersections.

### Asset Management (`gdoc/assets`)

- [ ] **Asset Cache**: Reference-counted asset lifecycle management.
- [ ] **Passive Hot-Reloading**: Hooks to swap pointers at runtime.

---

## Testing

GDOC includes built-in tests with memory tracking to ensure zero leaks:

```bash
odin test ecs
odin test containers
```
