/* Generic ECS implementation - By Leandro "LibanioL" Libanio (https://libaniol.com)

Example (assumes this package is imported under the alias `ecs` and raylib is imported under the alias `rl`):

	SCREEN_WIDTH :: 1280
	SCREEN_HEIGHT :: 720
	SECONDS_PER_UPDATE: f64 : 1.0 / 100.0


	Transform :: struct {
		position: [2]f32,
		rotation: f32,
	}


	Drawable :: struct {
		radius: f32,
		color:  rl.Color,
	}


	Movement :: struct {
		velocity: [2]f32,
		speed:    f32,
	}


	Bounce :: struct {}


	get_random_color :: proc() -> rl.Color {
		return rl.Color {
			auto_cast rand.int_max(255),
			auto_cast rand.int_max(255),
			auto_cast rand.int_max(255),
			255,
		}
	}


	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "GDOC Test")


	world := ecs.World{}
	defer ecs.destroy_world(&world)


	for _ in 0 ..< 100 {
		entity := ecs.create_entity(&world)
		ecs.add_component(
			&world,
			entity,
			Transform{position = {rand.float32() * SCREEN_WIDTH, rand.float32() * SCREEN_HEIGHT}},
		)
		ecs.add_component(&world, entity, Drawable{radius = 10.0, color = get_random_color()})

		ecs.add_component(
			&world,
			entity,
			Movement {
				velocity = {rand.float32_range(-1.0, 1.0), rand.float32_range(-1.0, 1.0)},
				speed = 3,
			},
		)

		ecs.add_component(&world, entity, Bounce{})
	}


	drawable_query := ecs.build_query(&world, {Transform, Drawable})
	draw_system :: proc(world: ^ecs.World, entity: ecs.Entity) {
		drawable := ecs.get_component(world, entity, Drawable)
		transform := ecs.get_component(world, entity, Transform)

		rl.DrawCircle(
			auto_cast transform.position.x,
			auto_cast transform.position.y,
			drawable.radius,
			drawable.color,
		)
	}


	movement_query := ecs.build_query(&world, {Transform, Movement})
	movement_system :: proc(world: ^ecs.World, entity: ecs.Entity) {
		transform := ecs.get_component(world, entity, Transform)
		movement := ecs.get_component(world, entity, Movement)

		transform.position += linalg.normalize(movement.velocity) * movement.speed
	}


	bounce_query := ecs.build_query(&world, {Transform, Movement, Bounce, Drawable})
	bounce_system :: proc(world: ^ecs.World, entity: ecs.Entity) {
		transform := ecs.get_component(world, entity, Transform)
		movement := ecs.get_component(world, entity, Movement)
		drawable := ecs.get_component(world, entity, Drawable)

		resolve_bounce :: proc(
			position_axis: f32,
			limits: f32,
			movement_axis: ^f32,
			drawable: ^Drawable,
		) {
			if position_axis > limits || position_axis < 0.0 {
				movement_axis^ = -movement_axis^
				drawable.color = get_random_color()
			}
		}

		resolve_bounce(
			transform.position.x,
			auto_cast SCREEN_WIDTH,
			&movement.velocity.x,
			drawable,
		)
		resolve_bounce(
			transform.position.y,
			auto_cast SCREEN_HEIGHT,
			&movement.velocity.y,
			drawable,
		)
	}


	previous_time := rl.GetTime()
	lag: f64 = 0.0
	for !rl.WindowShouldClose() {
		current_time := rl.GetTime()
		elapsed: f64 = current_time - previous_time
		previous_time = current_time
		lag += elapsed

		for lag >= SECONDS_PER_UPDATE {
			ecs.query_basic_system(movement_query, movement_system)
			ecs.query_basic_system(bounce_query, bounce_system)
			lag -= SECONDS_PER_UPDATE
		}

		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)
		ecs.query_basic_system(drawable_query, draw_system)
		rl.DrawFPS(10, 10)

		rl.EndDrawing()
	}

*/

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


// Destroys the entities sparse set, the components map and it's speciallized sparse sets and the components arena. 
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
create_entity :: proc(world: ^World) -> (Entity, bool) #optional_ok {
	entity, ok_entity := sset.insert(&world.entities, Entity{})
	if !ok_entity do return {}, false
	return entity, true
}


// Destroys an entity, first, deletes every component it has, then, deletes the entity handle itself.
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


// Removes a component from given entity.
// Returns true if component was removed, false if the component was not registered in the world
remove_component :: proc(world: ^World, entity: Entity, $T: typeid) -> bool {
	if T not_in world.components {
		return false
	}

	sset.remove(&world.components[T], entity)

	return true
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
	return Query{world = world, withall = withall}
}


// Query the entities based on given query.
// It's used for basic systems that don't require parameters.
query_basic_system :: proc(q: Query, system: proc(world: ^World, entity: Entity)) {
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
