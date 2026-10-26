package ecs

import mem "core:mem"


World :: struct {
	_next_index:       u32,
	_initial_capacity: int,
	_free_indices:     [dynamic]u32,
	_generations:      [dynamic]u32,
	_component_pools:  map[typeid]^Component_Pool,
	_pool_list:        [dynamic]^Component_Pool,
	_cmd_buffer:       Command_Buffer,
	_defer_depth:      int,
	allocator:         mem.Allocator,
}

world_init :: proc(world: ^World, initial_capacity: int, allocator := context.allocator) {
	world.allocator = allocator
	world._next_index = 0
	world._initial_capacity = initial_capacity
	world._defer_depth = 0
	world._free_indices = make([dynamic]u32, 0, initial_capacity, allocator)
	world._generations = make([dynamic]u32, 0, initial_capacity, allocator)
	world._component_pools = make(map[typeid]^Component_Pool, allocator)
	world._pool_list = make([dynamic]^Component_Pool, 0, 32, allocator)
	command_buffer_init(&world._cmd_buffer, 64, allocator)
}

world_destroy :: proc(world: ^World) {
	command_buffer_destroy(&world._cmd_buffer)
	for pool in world._pool_list {
		pool_destroy(pool)
	}
	delete(world._pool_list)
	delete(world._component_pools)
	delete(world._free_indices)
	delete(world._generations)
}

world_defer_begin :: proc(world: ^World) {
	world._defer_depth += 1
}

world_defer_end :: proc(world: ^World) {
	if world._defer_depth > 0 {
		world._defer_depth -= 1
		if world._defer_depth == 0 {
			world_flush(world)
		}
	}
}

world_flush :: proc(world: ^World) {
	command_buffer_flush(world, &world._cmd_buffer)
}

world_is_deferred :: proc(world: ^World) -> bool {
	return world._defer_depth > 0
}

world_register_component :: proc(world: ^World, $T: typeid, initial_capacity: int = -1) {
	if T in world._component_pools {
		return
	}

	cap := initial_capacity >= 0 ? initial_capacity : world._initial_capacity
	pool := pool_init(T, cap, world.allocator)
	world._component_pools[T] = pool
	append(&world._pool_list, pool)
}

world_entity_count :: proc(world: ^World) -> int {
	return int(world._next_index) - len(world._free_indices) - world._cmd_buffer.pending_creates
}

world_get_all_alive_entities :: proc(
	world: ^World,
	allocator := context.temp_allocator,
) -> []Entity {
	count := world_entity_count(world)
	if count <= 0 do return nil

	entities := make([]Entity, count, allocator)
	idx := 0

	for id in 0 ..< world._next_index {
		gen := world._generations[id]
		if (gen & 1) == 1 {
			entities[idx] = Entity {
				id  = id,
				gen = gen,
			}
			idx += 1
		}
	}
	return entities[:idx]
}

world_component_slice :: proc(world: ^World, $T: typeid) -> (entities: []Entity, components: []T) {
	pool, ok := world._component_pools[T]
	if !ok || len(pool.dense) == 0 do return nil, nil
	when size_of(T) == 0 {
		return pool.dense[:], nil
	} else {
		comp_ptr := cast([^]T)pool.component_data
		return pool.dense[:], comp_ptr[:len(pool.dense)]
	}
}
