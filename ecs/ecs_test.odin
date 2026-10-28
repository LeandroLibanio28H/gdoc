package ecs

import "core:mem"
import "core:testing"

Position :: struct {
	x, y: f32,
}

Tag :: struct {}

@(test)
test_entity_lifecycle :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	world: World
	world_init(&world, 10)

	// Teste 1: Criação e geração
	ent1 := entity_create(&world)
	testing.expectf(
		t,
		ent1.id == 0 && ent1.gen == 1,
		"Expected ID 0, Gen 1, got ID %d, Gen %d",
		ent1.id,
		ent1.gen,
	)
	testing.expect(t, entity_alive(&world, ent1), "Entity 1 should be alive")

	// Teste 2: Destruição
	entity_destroy(&world, ent1)
	testing.expect(t, !entity_alive(&world, ent1), "Entity 1 should be dead after destruction")

	// Teste 3: Reciclagem e nova geração
	ent2 := entity_create(&world)
	testing.expect(t, ent2.id == 0 && ent2.gen == 3, "Entity 2 should reuse ID 0 with Gen 3")

	world_destroy(&world)

	// Validação de Memory Leak
	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Entity Lifecycle")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Entity Lifecycle")
}

@(test)
test_components_and_slices :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	world: World
	world_init(&world, 10)
	world_register_component(&world, Position)
	world_register_component(&world, Tag) // Componente de tamanho zero (ZST)

	ent1 := entity_create(&world)
	ent2 := entity_create(&world)

	entity_add_component(&world, ent1, Position{10, 20})
	entity_add_component(&world, ent2, Position{30, 40})
	entity_add_component(&world, ent1, Tag{})

	// Validação de inserção
	testing.expect(t, entity_has_component(&world, ent1, Position), "Ent1 should have Position")
	testing.expect(t, entity_has_component(&world, ent1, Tag), "Ent1 should have Tag")
	testing.expect(t, !entity_has_component(&world, ent2, Tag), "Ent2 should NOT have Tag")

	// Validação de Valores
	pos := entity_get_component(&world, ent1, Position)
	testing.expect(t, pos != nil && pos.x == 10, "Ent1 Position X should be 10")

	// Validação do DOD (Slice extração)
	entities, positions := world_component_slice(&world, Position)
	testing.expect(t, len(entities) == 2, "Should have 2 entities with Position")
	testing.expect(t, len(positions) == 2, "Should have 2 contiguous Position structs")

	// Validação de ZST slice
	tag_entities, tags := world_component_slice(&world, Tag)
	testing.expect(t, len(tag_entities) == 1 && len(tags) == 1, "ZST slice lengths should match")

	// Somando posições pelo DOD (Simulação de sistema)
	for p in positions {
		testing.expect(t, p.x == 10 || p.x == 30, "Position X values must match inserted data")
	}

	// Validação de exclusão
	entity_remove_component(&world, ent1, Position)
	testing.expect(
		t,
		!entity_has_component(&world, ent1, Position),
		"Ent1 should not have Position anymore",
	)

	// Validação de world_clear e segurança geracional entre cenas
	world_clear(&world)
	testing.expect(t, world_entity_count(&world) == 0, "World should have 0 entities after clear")
	testing.expect(
		t,
		world_component_count(&world, Position) == 0,
		"Position pool should be empty after clear",
	)
	testing.expect(t, !entity_alive(&world, ent2), "Ent2 should not be alive after world_clear")

	// Nova entidade criada após world_clear não deve colidir com handles antigos (ent1)
	ent_new_scene := entity_create(&world)
	testing.expect(
		t,
		ent_new_scene.id == 0 && ent_new_scene.gen == 3,
		"First entity after world_clear should reuse ID 0 with incremented Gen 3",
	)
	testing.expect(
		t,
		!entity_alive(&world, ent1),
		"Stale handle ent1 from previous scene must remain dead",
	)

	world_destroy(&world)

	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Components")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Components")
}

@(test)
test_deferred_commands :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	world: World
	world_init(&world, 10)
	world_register_component(&world, Position)

	ent := entity_create(&world)
	entity_add_component(&world, ent, Position{0, 0})

	// Inicio do bloco diferido (com aninhamento defer_depth = 2)
	world_defer_begin(&world)
	world_defer_begin(&world)

	entity_add_component(&world, ent, Position{100, 100}) // Sobrescreve (Adição)
	ent2 := entity_create(&world) // Cria entidade 2
	entity_add_component(&world, ent2, Position{50, 60})
	entity_destroy(&world, ent) // Destrói entidade 1

	// Primeiro defer_end apenas reduz a profundidade para 1 (não deve executar flush ainda)
	world_defer_end(&world)
	testing.expect(t, world_is_deferred(&world), "World should still be in deferred mode")

	// Durante o Defer, o componente e estado de vida ainda não deve ter mudado no pool bruto
	pos := entity_get_component(&world, ent, Position)
	testing.expect(t, pos.x == 0, "Position should not be updated while in defer mode")
	testing.expect(t, entity_alive(&world, ent), "Ent1 should still be alive before final flush")

	world_defer_end(&world) // Descarrega comandos (defer_depth == 0)

	// Checa pós-Flush
	testing.expect(t, !entity_alive(&world, ent), "Ent1 should be dead after defer flush")
	testing.expect(t, entity_alive(&world, ent2), "Ent2 should be alive after defer flush")
	pos2, ok2 := entity_get_component(&world, ent2, Position)
	testing.expect(t, ok2 && pos2.x == 50 && pos2.y == 60, "Ent2 Position should be flushed")

	world_destroy(&world)

	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Command Buffer")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Command Buffer")
}

@(test)
test_pool_growth_and_swap_pop :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	alloc := mem.tracking_allocator(&track)

	world: World
	world_init(&world, 2, alloc)
	world_register_component(&world, Position, 2)

	// Inserir 100 entidades para forçar múltiplos mem.resize_non_zeroed e paginação
	entities_created: [100]Entity
	for i in 0 ..< 100 {
		e := entity_create(&world)
		entities_created[i] = e
		entity_add_component(&world, e, Position{f32(i), f32(i * 10)})
	}

	testing.expect(t, world_component_count(&world, Position) == 100, "Should have 100 components")

	// Remover o primeiro elemento (índice 0) para forçar Swap-and-Pop com o último (índice 99)
	entity_remove_component(&world, entities_created[0], Position)
	testing.expect(
		t,
		!entity_has_component(&world, entities_created[0], Position),
		"Entity 0 should no longer have Position",
	)
	testing.expect(
		t,
		world_component_count(&world, Position) == 99,
		"Should have 99 components after removal",
	)

	// Verificar integridade do elemento 99 que sofreu swap para o índice 0
	view := world_component_view(&world, Position)
	last_pos, ok := view_get(view, entities_created[99])
	testing.expect(
		t,
		ok && last_pos.x == 99 && last_pos.y == 990,
		"Swapped last entity must retain intact component data",
	)

	world_destroy(&world)

	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Pool Growth")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Pool Growth")
}
