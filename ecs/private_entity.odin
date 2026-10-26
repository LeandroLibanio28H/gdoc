#+private
package ecs

entity_destroy_immediate :: proc(world: ^World, entity: Entity) {
	if !entity_alive(world, entity) do return

	for pool in world._pool_list {
		pool_remove(pool, entity)
	}

	world._generations[entity.id] += 1
	append(&world._free_indices, entity.id)
}

entity_add_component_immediate :: proc(world: ^World, entity: Entity, tid: typeid, data: rawptr) {
	if !entity_alive(world, entity) do return
	pool_add(world._component_pools[tid], entity, data)
}

entity_remove_component_immediate :: proc(world: ^World, entity: Entity, tid: typeid) {
	if !entity_alive(world, entity) do return
	pool_remove(world._component_pools[tid], entity)
}
