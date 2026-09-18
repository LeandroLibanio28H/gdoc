package ecs


import log "core:log"


Entity :: struct {
	id:  u32,
	gen: u32,
}


entity_alive :: proc(world: ^World, entity: Entity) -> bool {
	if int(entity.id) >= len(world._generations) do return false
	return world._generations[entity.id] == entity.gen
}

entity_create :: proc(world: ^World) -> Entity {
	idx: u32

	if len(world._free_indices) > 0 {
		idx = pop(&world._free_indices)
	} else {
		idx = world._next_index
		world._next_index += 1
		append(&world._generations, u32(1))
	}
	return Entity{id = idx, gen = world._generations[idx]}
}

entity_destroy :: proc(world: ^World, entity: Entity) {
	if world._defer_depth > 0 {
		command_buffer_destroy_entity(&world._cmd_buffer, entity)
		return
	}

	if !entity_alive(world, entity) do return

	for _, pool in world._component_pools {
		pool_remove(pool, entity)
	}

	world._generations[entity.id] += 1
	append(&world._free_indices, entity.id)
}

entity_add_component :: proc(world: ^World, entity: Entity, component: $T) {
	tid := typeid_of(T)

	if tid not_in world._component_pools {
		log.error("Attempt to add unregistered component", tid)
		return
	}

	if world._defer_depth > 0 {
		command_buffer_add_component(&world._cmd_buffer, entity, component)
		return
	}

	if !entity_alive(world, entity) do return

	comp_copy := component
	pool_add(world._component_pools[tid], entity, &comp_copy)
}

entity_get_component :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
	if !entity_alive(world, entity) do return nil
	if T not_in world._component_pools do return nil
	raw_ptr := pool_get(world._component_pools[T], entity)
	if raw_ptr == nil do return nil
	return cast(^T)(raw_ptr)
}

entity_remove_component :: proc(world: ^World, entity: Entity, $T: typeid) {
	tid := typeid_of(T)
	if tid not_in world._component_pools {
		log.error("Attempt to remove unregistered component", tid)
		return
	}

	if world._defer_depth > 0 {
		command_buffer_remove_component(&world._cmd_buffer, entity, T)
		return
	}

	if !entity_alive(world, entity) do return
	pool_remove(world._component_pools[tid], entity)
}
