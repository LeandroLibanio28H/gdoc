package ecs

import "core:mem"
import "core:testing"

// ---------------------------------------------------------
// TEST TYPES
// ---------------------------------------------------------

// Component with standard alignments
Position :: struct {
	x: f32,
	y: f32,
}

Velocity :: struct {
	vx: f32,
	vy: f32,
}

Name :: struct {
	value: string,
}

// SIMD-aligned components to verify custom alignments
Align16 :: struct #align (16) {
	values: [4]f32,
}

Align32 :: struct #align (32) {
	data: [8]f32,
}

// Zero-sized tag component to test edge cases
Tag_Enemy :: struct {}


// ---------------------------------------------------------
// 1. ENTITY LIFECYCLE TESTS
// ---------------------------------------------------------

@(test)
test_entity_lifecycle :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 8, allocator)
	defer world_destroy(&world)

	// Verify initial counts
	testing.expect_value(t, world_entity_count(&world), 0)

	// Create entities and verify they are alive
	e0 := entity_create(&world)
	e1 := entity_create(&world)
	e2 := entity_create(&world)

	testing.expect(t, entity_alive(&world, e0))
	testing.expect(t, entity_alive(&world, e1))
	testing.expect(t, entity_alive(&world, e2))
	testing.expect_value(t, world_entity_count(&world), 3)

	// Destroy e1 and verify status
	entity_destroy(&world, e1)
	testing.expect(t, entity_alive(&world, e0))
	testing.expect(t, !entity_alive(&world, e1))
	testing.expect(t, entity_alive(&world, e2))
	testing.expect_value(t, world_entity_count(&world), 2)

	// Create a new entity - it should reuse the ID of e1 but with an incremented generation
	e1_reused := entity_create(&world)
	testing.expect_value(t, e1_reused.id, e1.id)
	testing.expect(t, e1_reused.gen > e1.gen, "Reused entity must have a higher generation")
	testing.expect(t, entity_alive(&world, e1_reused))
	testing.expect(t, !entity_alive(&world, e1), "Old entity handle should remain dead")
	testing.expect_value(t, world_entity_count(&world), 3)

	// Verify list of alive entities
	alive := world_get_all_alive_entities(&world, context.temp_allocator)
	testing.expect_value(t, len(alive), 3)

	has_e0, has_e2, has_reused := false, false, false
	for ent in alive {
		if ent == e0 do has_e0 = true
		if ent == e2 do has_e2 = true
		if ent == e1_reused do has_reused = true
	}
	testing.expect(t, has_e0)
	testing.expect(t, has_e2)
	testing.expect(t, has_reused)

	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 2. COMPONENT STORAGE & ALIGNMENT TESTS
// ---------------------------------------------------------

@(test)
test_component_storage_and_alignment :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 4, allocator)
	defer world_destroy(&world)

	// Register with various initial capacities and alignments
	world_register_component(&world, Position, 16)
	world_register_component(&world, Align16, 2)
	world_register_component(&world, Align32) // should use default World capacity

	// Verify capacities
	testing.expect_value(t, world._component_pools[Position].capacity, 16)
	testing.expect_value(t, world._component_pools[Align16].capacity, 2)
	testing.expect_value(t, world._component_pools[Align32].capacity, 4)

	// Insert elements
	e0 := entity_create(&world)
	e1 := entity_create(&world)

	entity_add_component(&world, e0, Position{x = 1.5, y = 2.5})
	entity_add_component(&world, e0, Align16{values = {1, 2, 3, 4}})
	entity_add_component(&world, e1, Align32{data = {5, 6, 7, 8, 9, 10, 11, 12}})

	// Verify retrieval and memory alignments
	pos0 := entity_get_component(&world, e0, Position)
	a16_0 := entity_get_component(&world, e0, Align16)
	a32_1 := entity_get_component(&world, e1, Align32)

	testing.expect(t, pos0 != nil)
	testing.expect_value(t, pos0.x, f32(1.5))
	testing.expect_value(t, pos0.y, f32(2.5))

	testing.expect(t, a16_0 != nil)
	testing.expect(
		t,
		uintptr(rawptr(a16_0)) % 16 == 0,
		"Align16 component must be 16-byte aligned",
	)
	testing.expect_value(t, a16_0.values[1], f32(2))

	testing.expect(t, a32_1 != nil)
	testing.expect(
		t,
		uintptr(rawptr(a32_1)) % 32 == 0,
		"Align32 component must be 32-byte aligned",
	)
	testing.expect_value(t, a32_1.data[3], f32(8))

	// Verify component overwrite
	entity_add_component(&world, e0, Position{x = 99.0, y = 100.0})
	pos0_updated := entity_get_component(&world, e0, Position)
	testing.expect_value(t, pos0_updated.x, f32(99.0))

	// Verify component removal
	entity_remove_component(&world, e0, Align16)
	testing.expect(
		t,
		entity_get_component(&world, e0, Align16) == nil,
		"Component must be nil after removal",
	)

	// Ensure zero bad frees occurred
	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 3. ZERO-SIZED TAG COMPONENT TESTS
// ---------------------------------------------------------

@(test)
test_zero_sized_components :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 8, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Tag_Enemy)

	e0 := entity_create(&world)
	e1 := entity_create(&world)

	// Add zero-sized component
	entity_add_component(&world, e0, Tag_Enemy{})

	// Check presence
	testing.expect(
		t,
		entity_get_component(&world, e0, Tag_Enemy) != nil,
		"Zero-sized component should be retrievable",
	)
	testing.expect(t, entity_get_component(&world, e1, Tag_Enemy) == nil)

	// Remove tag
	entity_remove_component(&world, e0, Tag_Enemy)
	testing.expect(
		t,
		entity_get_component(&world, e0, Tag_Enemy) == nil,
		"Zero-sized component should be removed cleanly",
	)

	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 4. VIEW QUERY & MULTI-COMPONENT ITERATION TESTS
// ---------------------------------------------------------

@(test)
test_views_and_iteration :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 8, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Position)
	world_register_component(&world, Velocity)
	world_register_component(&world, Name)

	// Create entities with varied component combinations
	e0 := entity_create(&world) // Position, Velocity, Name
	entity_add_component(&world, e0, Position{1, 1})
	entity_add_component(&world, e0, Velocity{10, 10})
	entity_add_component(&world, e0, Name{"Player"})

	e1 := entity_create(&world) // Position, Velocity
	entity_add_component(&world, e1, Position{2, 2})
	entity_add_component(&world, e1, Velocity{20, 20})

	e2 := entity_create(&world) // Velocity only
	entity_add_component(&world, e2, Velocity{30, 30})

	e3 := entity_create(&world) // Position, Velocity, Name
	entity_add_component(&world, e3, Position{4, 4})
	entity_add_component(&world, e3, Velocity{40, 40})
	entity_add_component(&world, e3, Name{"Enemy"})

	// Query single component (View1)
	count1 := 0
	view1 := view_create(&world, Position)
	for _, pos, ok := view_next(&view1); ok; _, pos, ok = view_next(&view1) {
		count1 += 1
		testing.expect(t, pos != nil)
	}
	testing.expect_value(t, count1, 3)

	// Query two components (View2) - should match e0, e1, e3
	count2 := 0
	view2 := view_create(&world, Position, Velocity)
	for _, pos, vel, ok := view_next(&view2); ok; _, pos, vel, ok = view_next(&view2) {
		count2 += 1
		testing.expect(t, pos != nil)
		testing.expect(t, vel != nil)
	}
	testing.expect_value(t, count2, 3)

	// Query three components (View3) - should match e0 and e3
	count3 := 0
	view3 := view_create(&world, Position, Velocity, Name)
	for e, pos, vel, name, ok := view_next(&view3); ok; e, pos, vel, name, ok = view_next(&view3) {
		count3 += 1
		testing.expect(t, e == e0 || e == e3)
		testing.expect(t, pos != nil)
		testing.expect(t, vel != nil)
		testing.expect(t, name != nil)
	}
	testing.expect_value(t, count3, 2)

	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 5. DEFERRED OPERATIONS & INTEGRITY TESTS
// ---------------------------------------------------------

@(test)
test_deferred_operations_integrity :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 8, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Position)
	world_register_component(&world, Velocity)

	// Setup initial entity
	e0 := entity_create(&world)
	entity_add_component(&world, e0, Position{0, 0})

	// Begin defer mode (structural changes queued)
	world_defer_begin(&world)
	testing.expect(t, world_is_deferred(&world))

	// Attempt queueing destruction of e0
	entity_destroy(&world, e0)
	testing.expect(t, entity_alive(&world, e0), "e0 must remain alive until flush occurs")
	testing.expect(t, entity_get_component(&world, e0, Position) != nil)

	// Attempt queueing creation of a new entity
	e1 := entity_create(&world)
	entity_add_component(&world, e1, Position{10, 20})
	entity_add_component(&world, e1, Velocity{1, 1})

	testing.expect(t, entity_alive(&world, e1), "Entity ID is allocated immediately")
	testing.expect(
		t,
		entity_get_component(&world, e1, Position) == nil,
		"Components are deferred and not yet attached",
	)

	// Flush the command buffer by ending defer mode
	world_defer_end(&world)
	testing.expect(t, !world_is_deferred(&world))

	// Verify deferred changes are fully flushed
	testing.expect(t, !entity_alive(&world, e0), "e0 must be destroyed now")
	testing.expect(t, entity_alive(&world, e1))

	pos1 := entity_get_component(&world, e1, Position)
	vel1 := entity_get_component(&world, e1, Velocity)
	testing.expect(t, pos1 != nil)
	testing.expect_value(t, pos1.x, f32(10))
	testing.expect(t, vel1 != nil)
	testing.expect_value(t, vel1.vx, f32(1))

	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 6. SAFE ITERATION ITERATOR INVALIDATION TESTS
// ---------------------------------------------------------

@(test)
test_safe_iteration_during_view_mutations :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 8, allocator)
	defer world_destroy(&world)

	world_register_component(&world, Position)

	// Create 4 entities
	entities: [4]Entity
	for i in 0 ..< 4 {
		entities[i] = entity_create(&world)
		entity_add_component(&world, entities[i], Position{f32(i), 0})
	}

	visited_count := 0
	visited_mask: [4]bool

	// Mutating the world structurally inside iteration using deferred buffer
	world_defer_begin(&world)

	view := view_create(&world, Position)
	for e, pos, ok := view_next(&view); ok; e, pos, ok = view_next(&view) {
		visited_count += 1
		visited_mask[e.id] = true

		// Destroy the 2nd entity during loop
		if e.id == 1 {
			entity_destroy(&world, e)
		}
	}

	// Without deferred, swap-and-pop would swap entity 4 to index 1 and we'd skip it.
	// With deferred, all 4 are safely visited.
	testing.expect_value(t, visited_count, 4)
	for visited in visited_mask {
		testing.expect(t, visited)
	}

	// Verify entity is still alive during loop
	testing.expect(
		t,
		entity_alive(&world, entities[1]),
		"Entity 1 should survive until defer ends",
	)

	world_defer_end(&world)

	// Verify entity is dead now after flush
	testing.expect(t, !entity_alive(&world, entities[1]))

	testing.expect_value(t, len(track.bad_free_array), 0)
}


// ---------------------------------------------------------
// 7. EVENT STREAM COMPREHENSIVE TESTS
// ---------------------------------------------------------

// Custom game events
DamageEvent :: struct {
	target: Entity,
	amount: int,
}

@(test)
test_event_stream_functionality :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	allocator := mem.tracking_allocator(&track)

	// Test with custom allocator (e.g. scratch or arena allocator simulation)
	stream: Event_Stream(DamageEvent)
	event_stream_init(&stream, 16, allocator)
	defer event_stream_destroy(&stream)

	testing.expect_value(t, len(event_stream_events(&stream)), 0)

	// Push events
	e0 := Entity {
		id  = 0,
		gen = 1,
	}
	e1 := Entity {
		id  = 1,
		gen = 1,
	}

	event_stream_push(&stream, DamageEvent{target = e0, amount = 15})
	event_stream_push(&stream, DamageEvent{target = e1, amount = 30})

	events := event_stream_events(&stream)
	testing.expect_value(t, len(events), 2)
	testing.expect_value(t, events[0].amount, 15)
	testing.expect_value(t, events[1].target, e1)

	// Clear stream
	event_stream_clear(&stream)
	testing.expect_value(t, len(event_stream_events(&stream)), 0)

	testing.expect_value(t, len(track.bad_free_array), 0)
}
