package ecs

import "core:mem"
import "core:testing"

// ---------------------------------------------------------
// TEST COMPONENT TYPES
// ---------------------------------------------------------

Align16_Comp :: struct #align (16) {
	values: [4]f32,
}

Align32_Comp :: struct #align (32) {
	values: [8]f32,
}

Normal_Comp :: struct {
	x: int,
	y: int,
}

Pos_Comp :: struct {
	x: f32,
	y: f32,
}

Vel_Comp :: struct {
	vx: f32,
	vy: f32,
}


// ---------------------------------------------------------
// 1. COMPONENT POOL & MEMORY ALIGNMENT TESTS
// ---------------------------------------------------------

@(test)
test_component_pool_alignment :: proc(t: ^testing.T) {
	// Verify compacted Entity footprint is 8 bytes
	testing.expect_value(t, size_of(Entity), 8)

	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 4, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Align16_Comp)
	world_register_component(&world, Align32_Comp)
	world_register_component(&world, Normal_Comp)

	// Insert enough entities to trigger exponential capacity expansion
	for i in 0 ..< 32 {
		e := entity_create(&world)
		entity_add_component(
			&world,
			e,
			Align16_Comp{values = {f32(i), f32(i * 2), f32(i * 3), f32(i * 4)}},
		)
		entity_add_component(&world, e, Align32_Comp{values = {f32(i), 0, 0, 0, 0, 0, 0, 0}})
		entity_add_component(&world, e, Normal_Comp{x = i, y = i * 10})
	}

	// Verify pointer memory alignment and component values
	for i in 0 ..< 32 {
		e := Entity {
			id  = u32(i),
			gen = 1,
		}
		c16 := entity_get_component(&world, e, Align16_Comp)
		c32 := entity_get_component(&world, e, Align32_Comp)
		cn := entity_get_component(&world, e, Normal_Comp)

		testing.expect(t, c16 != nil, "Align16_Comp should exist")
		testing.expect(t, c32 != nil, "Align32_Comp should exist")
		testing.expect(t, cn != nil, "Normal_Comp should exist")

		ptr16 := uintptr(rawptr(c16))
		ptr32 := uintptr(rawptr(c32))

		testing.expect_value(t, ptr16 % 16, 0)
		testing.expect_value(t, ptr32 % 32, 0)

		testing.expect_value(t, c16.values[0], f32(i))
		testing.expect_value(t, c32.values[0], f32(i))
		testing.expect_value(t, cn.x, i)
		testing.expect_value(t, cn.y, i * 10)
	}

	// Verify removal and swap-and-pop behavior
	entity_destroy(&world, Entity{id = 0, gen = 1})
	testing.expect(t, !entity_alive(&world, Entity{id = 0, gen = 1}), "Entity 0 should be dead")
	testing.expect(t, entity_get_component(&world, Entity{id = 0, gen = 1}, Normal_Comp) == nil)

	// Verify remaining entities are intact
	for i in 1 ..< 32 {
		e := Entity {
			id  = u32(i),
			gen = 1,
		}
		cn := entity_get_component(&world, e, Normal_Comp)
		testing.expect(t, cn != nil)
		testing.expect_value(t, cn.x, i)
	}

	// Ensure zero bad frees occurred
	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 2. COMMAND BUFFER & SAFE VIEW ITERATION TESTS
// ---------------------------------------------------------

@(test)
test_command_buffer_safe_iteration :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 10, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Pos_Comp)
	world_register_component(&world, Vel_Comp)

	// Create 5 entities: 0, 1, 2, 3, 4
	entities: [5]Entity
	for i in 0 ..< 5 {
		entities[i] = entity_create(&world)
		entity_add_component(&world, entities[i], Pos_Comp{x = f32(i), y = f32(i * 10)})
		entity_add_component(&world, entities[i], Vel_Comp{vx = 1, vy = 1})
	}

	// Safe iteration: queue entity destruction during view iteration
	visited_count := 0
	visited_mask: [5]bool

	world_defer_begin(&world)

	view := view_create(&world, Pos_Comp, Vel_Comp)
	for e, pos, _ in view_next(&view) {
		visited_count += 1
		visited_mask[e.id] = true

		if e.id == 1 {
			entity_destroy(&world, e)
		}
	}

	// All 5 entities must be visited without swap-and-pop skips
	testing.expect_value(t, visited_count, 5)
	for i in 0 ..< 5 {
		testing.expect(t, visited_mask[i], "Entity should have been visited by view")
	}

	// Entity 1 is still alive before flush
	testing.expect(
		t,
		entity_alive(&world, entities[1]),
		"Entity 1 should still be alive before flush",
	)

	// Execute flush
	world_flush(&world)

	// Entity 1 must now be dead and other entities must remain alive
	testing.expect(t, !entity_alive(&world, entities[1]), "Entity 1 should be dead after flush")
	testing.expect(t, entity_alive(&world, entities[0]), "Entity 0 should be alive")
	testing.expect(t, entity_alive(&world, entities[2]), "Entity 2 should be alive")
	testing.expect(t, entity_alive(&world, entities[3]), "Entity 3 should be alive")
	testing.expect(t, entity_alive(&world, entities[4]), "Entity 4 should be alive")

	// Test deferred add and remove operations
	e_new := entity_create(&world)
	entity_add_component(&world, e_new, Pos_Comp{x = 99.0, y = 100.0})
	entity_remove_component(&world, entities[3], Vel_Comp)

	// Before flush, deferred component is not yet in pool
	testing.expect(t, entity_get_component(&world, e_new, Pos_Comp) == nil)
	testing.expect(t, entity_get_component(&world, entities[3], Vel_Comp) != nil)

	world_flush(&world)
	world_defer_end(&world)

	// After flush, changes must be applied
	pos_new := entity_get_component(&world, e_new, Pos_Comp)
	testing.expect(t, pos_new != nil)
	testing.expect_value(t, pos_new.x, f32(99.0))
	testing.expect_value(t, pos_new.y, f32(100.0))

	testing.expect(t, entity_get_component(&world, entities[3], Vel_Comp) == nil)
	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 3. DEFERRED WORLD CONTEXT TESTS (world_defer_begin / end)
// ---------------------------------------------------------

@(test)
test_world_deferred_context :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 10, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Pos_Comp)
	world_register_component(&world, Vel_Comp)

	// PHASE 1: IMMEDIATE (setup phase)
	e0 := entity_create(&world)
	entity_add_component(&world, e0, Pos_Comp{x = 10, y = 20})

	// In immediate mode, component is available right away
	pos0 := entity_get_component(&world, e0, Pos_Comp)
	testing.expect(t, pos0 != nil, "Immediate mode should attach component immediately")
	testing.expect_value(t, pos0.x, f32(10))

	// PHASE 2: DEFERRED (systems phase)
	world_defer_begin(&world)
	testing.expect(t, world_is_deferred(&world))

	// Inside deferred mode, destruction is queued internally
	entity_destroy(&world, e0)
	testing.expect(t, entity_alive(&world, e0), "Entity e0 should remain alive before defer_end")

	// Create new entity and add component during deferred mode
	e1 := entity_create(&world)
	entity_add_component(&world, e1, Vel_Comp{vx = 5, vy = 5})
	testing.expect(t, entity_get_component(&world, e1, Vel_Comp) == nil)

	// Close deferred mode (automatically triggers flush)
	world_defer_end(&world)
	testing.expect(t, !world_is_deferred(&world))

	// e0 is now destroyed and e1 has Vel attached
	testing.expect(t, !entity_alive(&world, e0), "e0 should be destroyed after defer_end")
	vel1 := entity_get_component(&world, e1, Vel_Comp)
	testing.expect(t, vel1 != nil, "e1 should have received Vel component after defer_end")
	testing.expect_value(t, vel1.vx, f32(5))

	testing.expect_value(t, len(track.bad_free_array), 0)
}
