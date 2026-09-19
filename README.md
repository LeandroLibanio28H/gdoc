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
- **Generational Entities**: Safe entity handles that prevent stale references when entities are created and destroyed.
- **Multi-Component Views**: Query entities with combinations of up to 8 components with automatic query optimization.
- **Deferred Command Buffer**: Queue entity creation, destruction, and component changes safely during system iterations.
- **Tag Components**: Full support for zero-sized tag markers without memory overhead.
- **Custom Allocators**: Native support for Odin allocators (arenas, temporary allocators, tracking).
- **Event Streams**: Generic message streams for decoupled communication across systems.

---

## Getting Started

### Add as a Git Submodule

```bash
git submodule add https://github.com/LeandroLibanio28H/gdoc.git
```

### Import into your project

```odin
import ecs "path/to/gdoc/ecs"
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
    world: ecs.World
    ecs.world_init(&world, initial_capacity = 64)
    defer ecs.world_destroy(&world)

    // Register components
    ecs.world_register_component(&world, Position)
    ecs.world_register_component(&world, Velocity)
    ecs.world_register_component(&world, Enemy)

    // Create an entity and attach components
    entity := ecs.entity_create(&world)
    ecs.entity_add_component(&world, entity, Position{x = 0, y = 0})
    ecs.entity_add_component(&world, entity, Velocity{vx = 100, vy = 50})
    ecs.entity_add_component(&world, entity, Enemy{})

    // Query and update entities
    view := ecs.view_create(&world, Position, Velocity)
    for ent, pos, vel, ok := ecs.view_next(&view); ok; ent, pos, vel, ok = ecs.view_next(&view) {
        pos.x += vel.vx * 0.016
        pos.y += vel.vy * 0.016
        fmt.printfln("Entity #%d position: (%.2f, %.2f)", ent.id, pos.x, pos.y)
    }

    // Safe mutations during iteration using deferred commands
    ecs.world_defer_begin(&world)
    view_enemies := ecs.view_create(&world, Enemy)
    for ent, _, ok := ecs.view_next(&view_enemies); ok; ent, _, ok = ecs.view_next(&view_enemies) {
        ecs.entity_destroy(&world, ent)
    }
    ecs.world_defer_end(&world) // Flushes all changes atomically
}
```

---

## Testing

GDOC includes built-in tests with memory tracking to ensure zero leaks:

```bash
odin test ecs
```

---

## Roadmap

GDOC is an evolving toolkit. Future utility modules under consideration:

- [x] **ECS**: Sparse-set entity component system, views, command buffer, and event streams.
- [ ] **Math**: Common game math helpers.
- [ ] **Data Structures**: Specialized game containers (ring buffers, object pools, arena helpers).
