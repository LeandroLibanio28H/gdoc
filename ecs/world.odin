package ecs


World :: struct {
	_next_index:       int,
	_initial_capacity: int,
	_free_indices:     [dynamic]int,
	_generations:      [dynamic]int,
	_component_pools:  map[typeid]^Component_Pool,
}

world_init :: proc(world: ^World, initial_capacity: int) {
	world._next_index = 0
	world._initial_capacity = initial_capacity
	world._free_indices = make([dynamic]int, 0, initial_capacity)
	world._generations = make([dynamic]int, 0, initial_capacity)
	world._component_pools = make(map[typeid]^Component_Pool)
}

world_destroy :: proc(world: ^World) {
	for _, pool in world._component_pools {
		pool_destroy(pool)
		free(pool)
	}
	delete(world._component_pools)
	delete(world._free_indices)
	delete(world._generations)
}

world_register_component :: proc(world: ^World, $T: typeid) {
	if T in world._component_pools {
		return
	}

	pool := pool_init(T, world._initial_capacity)
	world._component_pools[T] = pool
}
