package ecs
// files ended with "test" are private


import "core:testing"


@(test)
test_world_add_entities :: proc(t: ^testing.T) {
	world: World
	defer destroy_world(&world)
	count := 0

	entity, ok := create_entity(&world)
	testing.expect(t, ok, "First insert failed")
	count += 1

	for e in 0 ..< 100 {
		create_entity(&world)
		count += 1
	}

	testing.expect(t, world.entities.set.count == count, "Entity count check failed")
}

@(test)
test_add_and_destroy_entities :: proc(t: ^testing.T) {
	world: World
	defer destroy_world(&world)
	count := 0

	for e in 0 ..< 100 {
		create_entity(&world)
		count += 1
	}

	for e in 0 ..< 50 {
		destroy_entity(&world, Entity{id = e * 2})
		count -= 1
	}

	testing.expect(
		t,
		world.entities.set.count == count,
		"Entity count check after removing failed",
	)
}

@(test)
test_add_components :: proc(t: ^testing.T) {
	world: World
	defer destroy_world(&world)
	count := 0

	Test_Component :: struct {
		ref_int: ^int,
	}

	test_query := build_query(&world, {Test_Component})
	test_system :: proc(world: ^World, entity: Entity) {
		test_component := get_component(world, entity, Test_Component)

		test_component.ref_int^ += 1
	}

	for e in 0 ..< 100 {
		entity := create_entity(&world)
		add_component(&world, entity, Test_Component{ref_int = &count})
	}

	query_system(test_query, test_system)

	testing.expect(t, count == 100, "Compoennt count in 100 entities check failed")
}


@(test)
test_add_and_remove_components :: proc(t: ^testing.T) {
	world: World
	defer destroy_world(&world)
	count := 0

	Test_Component :: struct {
		ref_int: ^int,
	}

	test_query := build_query(&world, {Test_Component})
	test_system :: proc(world: ^World, entity: Entity) {
		test_component := get_component(world, entity, Test_Component)

		test_component.ref_int^ += 1
	}

	for e in 0 ..< 100 {
		entity := create_entity(&world)
		add_component(&world, entity, Test_Component{ref_int = &count})
	}
	query_system(test_query, test_system)

	testing.expect(t, count == 100, "Component count in 100 entities check failed")

	for e in 0 ..< 50 {
		remove_component(&world, Entity{id = e}, Test_Component)
	}
	query_system(test_query, test_system)
	testing.expect(t, count == 150, "Component count in 150 entities check failed")
}
