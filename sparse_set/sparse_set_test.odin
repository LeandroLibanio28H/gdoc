package sparse_set
// files ended with "test" are private

import "core:fmt"
import "core:testing"


make_handle :: proc(id: int) -> Sparse_Set_Handle {
	return Sparse_Set_Handle{id = id}
}


EntityTest :: struct {
	name:         string,
	data:         f32,
	value:        int,
	using handle: Sparse_Set_Handle,
}


@(test)
test_init_and_basic_insert :: proc(t: ^testing.T) {
	// Auto ID test
	auto_set: Sparse_Set_Auto(EntityTest)
	defer destroy(&auto_set)

	// Should not be initialised
	testing.expect(t, !is_initialized(auto_set), "Auto set should start uninitialized")

	// Implicit intialisation test
	handle, ok := insert(&auto_set, EntityTest{})
	testing.expect(t, ok, "First insert failed")
	testing.expect(t, is_initialized(auto_set), "Auto-init failed")

	// Manual ID test
	manual_set: Sparse_Set_Manual(EntityTest)
	defer destroy(&manual_set)

	init(&manual_set)
	testing.expect(t, is_initialized(manual_set), "Manual init failed")

	h := make_handle(42)
	_, ok = insert(&manual_set, EntityTest{}, h)
	testing.expect(t, ok, "Manual insert failed")
}

@(test)
test_contains_and_remove :: proc(t: ^testing.T) {
	set: Sparse_Set_Auto(EntityTest)
	defer destroy(&set)

	// Insert 3 elements
	h1, _ := insert(&set, EntityTest{data = 1.0})
	h2, _ := insert(&set, EntityTest{data = 2.0})
	h3, _ := insert(&set, EntityTest{data = 3.0})

	// Check contains
	testing.expect(t, contains(&set, h1), "Contains failed for h1")
	testing.expect(t, contains(&set, h2), "Contains failed for h2")

	// Remove and check again
	remove(&set, h2)
	testing.expect(t, !contains(&set, h2), "Remove failed")
	testing.expect(t, contains(&set, h3), "Post-remove invariant failed")

	// Trying to remove already removed element
	remove(&set, h2)
}

@(test)
test_handles_and_iteration :: proc(t: ^testing.T) {
	set: Sparse_Set_Manual(EntityTest)
	defer destroy(&set)
	init(&set)

	// Insert specifing ids
	handles := [3]Sparse_Set_Handle{make_handle(100), make_handle(200), make_handle(300)}

	insert(&set, EntityTest{id = -1, name = "Alice"}, handles[0])
	insert(&set, EntityTest{id = -1, name = "Bob"}, handles[1])
	insert(&set, EntityTest{id = -1, name = "Charlie"}, handles[2])

	// Get all handles test
	all_handles, ok_all := get_all_handles(&set)
	defer delete(all_handles)
	testing.expect(t, ok_all && len(all_handles) == 3, "get_all_handles failed")

	// Map field test
	names, ok_map := map_field(&set, proc(item: EntityTest) -> string {
		return item.name
	})
	testing.expect(t, ok_map && len(names) == 3, "map_field failed")
	delete(names)
}


@(test)
test_edge_cases :: proc(t: ^testing.T) {
	// empty sset test
	empty_set: Sparse_Set_Auto(EntityTest)
	defer destroy(&empty_set)

	testing.expect(
		t,
		!contains(&empty_set, make_handle(0)),
		"Empty set should not contain anything",
	)

	// large ids test
	big_set: Sparse_Set_Manual(EntityTest)
	defer destroy(&big_set)
	init(&big_set)

	big_handle := make_handle(1_000_000)
	_, ok := insert(&big_set, EntityTest{}, big_handle)
	testing.expect(t, ok, "Failed to insert large ID")
	testing.expect(t, contains(&big_set, big_handle), "Large ID containment failed")
}

@(test)
test_invariants :: proc(t: ^testing.T) {
	set: Sparse_Set_Auto(EntityTest)
	defer destroy(&set)

	// insert elements
	items := [?]struct {
		value: int,
	}{{10}, {20}, {30}, {40}}
	handles: [len(items)]Sparse_Set_Handle

	for item, i in items {
		handles[i], _ = insert(&set, EntityTest{id = -1, value = item.value})
	}

	// checks if items are inside set
	for h in handles {
		if contains(&set, h) {
			elem, ok := get(&set, h)
			testing.expect(t, ok && elem.id == h.id, "Invariant violated")
		}
	}

	// remove and checks count value
	remove(&set, handles[1])
	remove(&set, handles[3])

	remaining := set.count
	testing.expect(t, remaining == 2, "Size invariant failed after removal")
}

@(test)
test_stress :: proc(t: ^testing.T) {
	set: Sparse_Set_Auto(EntityTest)
	defer destroy(&set)

	// Inserting 100_000 elements
	for i in 0 ..< 100_000 {
		_, ok := insert(&set, EntityTest{id = -1})
		testing.expect(t, ok, "Mass insert failed")
	}

	// checks size
	testing.expect(t, set.count == 100_000, "Size mismatch")
}
