package ecs


import sset "../sparse_set"
import mem "core:mem"
import vmem "core:mem/virtual"


/*  ###################################################################
	TYPEDEFS
###################################################################  */


// Just an alias to Sparse_Set_Handle
Entity :: sset.Sparse_Set_Handle


// World structure, might be instanced and destroyed after use.
// Has the following fields:
// entities: Just a Sparse_Set_Auto(Entity) for storing entities and getting new ids. Prevents id reuse.
// components: a map of typeid to Component_Data (storing components of different types and their respective handles.)
// components_raw: a dynamic array of rawptr (every component data is stored in it making easy to free the memory)
World :: struct {
	arena:      vmem.Arena,
	entities:   sset.Sparse_Set_Auto(Entity),
	components: map[typeid]sset.Sparse_Set_Manual(Component_Data),
}


/*  ###################################################################
	WORLD
###################################################################  */


// Destroys the entities sparse set, the components mapm it's speciallized sparse sets and the components arena. 
// Should be called when the world is no longer needed, releases all allocated memory.
destroy_world :: proc(world: ^World) {
	for comptype, &compset in world.components {
		sset.destroy(&compset)
	}
	delete(world.components)
	sset.destroy(&world.entities)
	vmem.arena_destroy(&world.arena)
	vmem.arena_free_all(&world.arena)
}


/*  ###################################################################
	ENTITY
###################################################################  */


// Creates an entity, generates a new handle and returns it.
// world.entities is a Sparse_Set_Auto, it's responsible for generating a new unique hadle for each entity
create_entity :: proc(world: ^World) -> Entity {
	entity, ok_entity := sset.insert(&world.entities, Entity{})
	if !ok_entity do return {}
	return entity
}


// Destroys and entity, first, deletes every component it has, then, deletes the entity handle itself.
destroy_entity :: proc(world: ^World, entity: Entity) {
	for comptype, &compset in world.components {
		if sset.contains(&compset, entity) {
			sset.remove(&compset, entity)
		}
	}
	sset.remove(&world.entities, entity)
}


/*  ###################################################################
	COMPONENT
###################################################################  */


// Adds a component to given entity.
// Component type registration is not needed, since it will first check if there's already a sparse set for given component type in compoenents map.
// If there is not, it will then create said sparse set.
add_component :: proc(world: ^World, entity: Entity, component: $T) -> bool {
	init_world(world)

	if T not_in world.components {
		init_component_storage(world, T)
	}

	new_component := new(T, vmem.arena_allocator(&world.arena))
	new_component^ = component
	raw_ptr := (rawptr)(new_component)

	_, ok := sset.insert(
		&world.components[T],
		Component_Data{data = raw_ptr, id = entity.id},
		entity,
	)

	return ok
}


// Gets component of given type for given entity handle.
get_component :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
	if data, ok := sset.get(&world.components[T], entity); ok {
		return auto_cast data.data
	}

	return nil
}


/*  ###################################################################
	QUERY
###################################################################  */


// Used to build a query
build_query :: proc(world: ^World, withall: []typeid) -> Query {
	return Query {
		world = world,
		withall = withall
	}
}


// Query the entities based on given query.
// It's used for systems.
query_system :: proc(q: Query, system: proc(world: ^World, entity: Entity)) {
	smallest_set: ^sset.Sparse_Set_Manual(Component_Data)
	for type in q.withall {
		set := &q.world.components[type]
		if smallest_set == nil || set.count < smallest_set.count {
			smallest_set = set
		}
	}

	handles, _ := sset.get_all_handles(smallest_set)
	defer delete(handles)

	for handle in handles {
		has_all := true

		for type in q.withall {
			if !sset.contains(&q.world.components[type], handle) {
				has_all = false
				break
			}
		}

		if has_all {
			system(q.world, handle)
		}
	}
}
