package ecs

import mem "core:mem"


World :: struct {
	_next_index:       u32,
	_initial_capacity: int,
	_free_indices:     [dynamic]u32,
	_generations:      [dynamic]u32,
	_component_pools:  map[typeid]^Component_Pool,
	allocator:         mem.Allocator,
}

world_init :: proc(world: ^World, initial_capacity: int, allocator := context.allocator) {
	world.allocator = allocator
	world._next_index = 0
	world._initial_capacity = initial_capacity
	world._free_indices = make([dynamic]u32, 0, initial_capacity, allocator)
	world._generations = make([dynamic]u32, 0, initial_capacity, allocator)
	world._component_pools = make(map[typeid]^Component_Pool, allocator)
}

world_destroy :: proc(world: ^World) {
	for _, pool in world._component_pools {
		pool_destroy(pool)
		free(pool, world.allocator)
	}
	delete(world._component_pools)
	delete(world._free_indices)
	delete(world._generations)
}

world_register_component :: proc(world: ^World, $T: typeid) {
	if T in world._component_pools {
		return
	}

	pool := pool_init(T, world._initial_capacity, world.allocator)
	world._component_pools[T] = pool
}
