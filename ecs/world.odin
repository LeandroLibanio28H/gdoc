package ecs

import mem "core:mem"


World :: struct {
	_next_index:       u32,
	_initial_capacity: int,
	_free_indices:     [dynamic]u32,
	_generations:      [dynamic]u32,
	_component_pools:  map[typeid]^Component_Pool,
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
	command_buffer_init(&world._cmd_buffer, 64, allocator)
}

world_destroy :: proc(world: ^World) {
	command_buffer_destroy(&world._cmd_buffer)
	for _, pool in world._component_pools {
		pool_destroy(pool)
		free(pool, world.allocator)
	}
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

	free_map := make([]bool, world._next_index, context.temp_allocator)
	for free_id in world._free_indices {
		free_map[free_id] = true
	}
	if world._cmd_buffer.pending_creates > 0 {
		for cmd in world._cmd_buffer.commands {
			if cmd.kind == .Create_Entity {
				free_map[cmd.entity.id] = true
			}
		}
	}

	entities := make([]Entity, count, allocator)
	idx := 0
	for id in 0 ..< world._next_index {
		if !free_map[id] && world._generations[id] > 0 {
			entities[idx] = Entity {
				id  = id,
				gen = world._generations[id],
			}
			idx += 1
		}
	}
	return entities[:idx]
}
