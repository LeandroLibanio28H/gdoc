package containers

import mem "core:mem"
import testing "core:testing"

@(test)
test_sparse_set_basics :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	set: Sparse_Set(int)
	sparse_set_init(&set, 5)

	// Teste de inserção normal
	sparse_set_insert(&set, 10, 100)
	sparse_set_insert(&set, 25, 250)

	testing.expect(t, sparse_set_has(&set, 10), "Should have ID 10")
	testing.expect(t, sparse_set_has(&set, 25), "Should have ID 25")
	testing.expect(t, !sparse_set_has(&set, 99), "Should NOT have ID 99")

	val, ok := sparse_set_get(&set, 25)
	testing.expect(t, ok && val^ == 250, "ID 25 value should be 250")

	// Sobrescrever valor (testando também #optional_ok sem o booleano)
	sparse_set_insert(&set, 25, 300)
	val2 := sparse_set_get(&set, 25)
	testing.expect(t, val2 != nil && val2^ == 300, "ID 25 value should be updated to 300")
	testing.expect(t, sparse_set_len(&set) == 2, "Sparse set length should be 2")

	// Teste de Deleção (Swap and Pop)
	sparse_set_remove(&set, 10)
	testing.expect(t, !sparse_set_has(&set, 10), "ID 10 should be deleted")
	testing.expect(t, sparse_set_len(&set) == 1, "Sparse set length should be 1 after removal")

	// Checar array denso
	values := sparse_set_values(&set)
	testing.expect(
		t,
		len(values) == 1 && values[0] == 300,
		"Dense array should have 1 item (300) after swap and pop",
	)

	sparse_set_destroy(&set)

	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Sparse Set Basics")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Sparse Set Basics")
}

@(test)
test_sparse_set_paging :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	set: Sparse_Set(f32)
	sparse_set_init(&set)

	// Inserir IDs muito distantes para forçar a criação de múltiplas Páginas
	sparse_set_insert(&set, 5, 5.0)
	sparse_set_insert(&set, 2048, 2048.0) // Vai forçar a alocação da Página 2
	sparse_set_insert(&set, 1000000, 1.0) // Vai forçar a alocação da Página 976

	testing.expect(t, sparse_set_has(&set, 5), "Should have ID 5")
	testing.expect(t, sparse_set_has(&set, 2048), "Should have ID 2048")
	testing.expect(t, sparse_set_has(&set, 1000000), "Should have ID 1000000")

	sparse_set_clear(&set)
	testing.expect(t, !sparse_set_has(&set, 2048), "ID 2048 should be gone after clear")
	testing.expect(t, sparse_set_len(&set) == 0, "Dense array should be empty after clear")

	sparse_set_destroy(&set)

	testing.expect(t, len(track.allocation_map) == 0, "Memory leak detected in Paging")
	testing.expect(t, len(track.bad_free_array) == 0, "Bad free detected in Paging")
}
