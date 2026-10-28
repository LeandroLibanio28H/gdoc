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

	// Inicio do bloco diferido
	world_defer_begin(&world)

	entity_add_component(&world, ent, Position{100, 100}) // Sobrescreve (Adição)
	ent2 := entity_create(&world) // Cria entidade 2
	entity_destroy(&world, ent) // Destrói entidade 1

	// Durante o Defer, o componente e estado de vida ainda não deve ter mudado no pool bruto
	pos := entity_get_component(&world, ent, Position)
	testing.expect(t, pos.x == 0, "Position should not be updated while in defer mode")

	world_defer_end(&world) // Descarrega comandos

	// Checa pós-Flush
	testing.expect(t, !entity_alive(&world, ent), "Ent1 should be dead after defer flush")
	testing.expect(t, entity_alive(&world, ent2), "Ent2 should be alive after defer flush")

	world_destroy(&world)

	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Command Buffer")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Command Buffer")
}
