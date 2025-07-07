#+private 
package ecs


import sset "../sparse_set"
import mem "core:mem"
import vmem "core:mem/virtual"


/*  ###################################################################
	TYPEDEFS
###################################################################  */


// Component_Data is a supertype of Sparse_Set_Handle (see Entity) therefore it can be stored in a Sparse_Set_Handle.
// Also, it's data is a rawptr which allows to use different size component sparse sets in the same map.
Component_Data :: struct {
	data:         rawptr,
	using entity: Entity,
}


// Query structure, will be used for querying entities for systems, currently it only has required component types
// TODO: Support withnone and withany
Query :: struct {
	world:   ^World,
	withall: []typeid,
}


/*  ###################################################################
	WORLD
###################################################################  */


// Initializes the world arena allocator.
init_world :: proc(world: ^World) {
	if world.arena.curr_block == nil {
		arena_err := vmem.arena_init_growing(&world.arena)
		assert(arena_err == nil)
	}
}


// Should not be called manually, that's why it's in a private scope.
// Initializes the map entry for given component type (for implicit registering of components)
init_component_storage :: proc(world: ^World, type: typeid) {
	world.components[type] = sset.Sparse_Set_Manual(Component_Data){}
}
