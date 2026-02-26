/* Sparse Set data structure - By Leandro "LibanioL" Libanio (https://libaniol.com)


A sparse set is a simple data structure that has a few interesting properties:
    O(1) to add an item.
    O(1) to remove an item.
    O(1) to lookup an item.
    O(1) to clear the set.
    O(n) to iterate over the set.
    A set does not require its internal items storage to be initialised upon creation (!).

Sparse sets use two arrays internally: dense and sparse.
The former is a packed array that stores the set’s items in the insertion order.
The latter is an array that can have holes (hence the name – sparse) and it maps the set’s items to their indices in dense.
The set also keeps track of how many items it has. We call it 'count'.


This implementation provides two types of Sparse Sets:

	Sparse_Set_Auto -> a sparse set that creates ids as elements are inserted.
		Can be used as a list with sparse set performance

	Sparse_Set_Manual -> a traditional sparse set, ids are user-provided.
		Can be used as a way to have common ids between multiple sparse sets.


Example (assumes this package is imported under the alias `sset` and fmt is imported under the alias `fmt`):

	Entity :: struct {
		name:       string,
		dialogue:   string,
		using item: sset.Sparse_Set_Handle,
	}

	entities := sset.Sparse_Set_Auto(Entity){}
	defer sset.destroy(&entities)


	mizaru := sset.insert(&entities, Entity{name = "Mizaru", dialogue = "I can't see evil"})
	kikazaru := sset.insert(&entities, Entity{name = "Kikazaru", dialogue = "I can't hear evil"})
	iwazaru := sset.insert(&entities, Entity{name = "Iwazaru", dialogue = "..."})


	fmt.println(sset.get(&entities, mizaru).dialogue)
	fmt.println(sset.get(&entities, kikazaru).dialogue)
	fmt.println(sset.get(&entities, iwazaru).dialogue)


	fmt.println("\n")

	sset.remove(&entities, kikazaru)

	leandro := sset.insert(
		&entities,
		Entity{name = "Leandro", dialogue = "I can see, hear and talk about evil"},
	)

	all := sset.get_all_handles(&entities)
	defer delete(all)
	for entity_handle in all {
		entity := sset.get(&entities, entity_handle)
		fmt.printfln("Hi!, I'm %v and %v", entity.name, entity.dialogue)
	}

*/

package sparse_set


import "base:intrinsics"


/*  ###################################################################
	TYPEDEFS
###################################################################  */


// A handle to an element in the sparse set.
Sparse_Set_Handle :: struct {
	id: int,
}


// An invalid handle to an element in the sparse set.
Empty_Sparse_Set_Handle :: Sparse_Set_Handle {
	id = -1,
}


// Manually managed sparse set.
Sparse_Set_Manual :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	using set: Sparse_Set(T),
}


// Automatically managed sparse set.
Sparse_Set_Auto :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	using set: Sparse_Set(T),
	next_id:   int,
}


/*  ###################################################################
	HELPERS
###################################################################  */


// Checks if Sparse_Set is initialized.
// @param sset: pointer to Sparse_Set
is_initialized :: proc(sset: $T) -> bool where intrinsics.type_is_subtype_of(T, Sparse_Set) {
	return sset._is_init
}


/*  ###################################################################
	PROC GROUPS
###################################################################  */


// Initialises Sparse_Set.
// @param sset: pointer to Sparse_Set
// @param allocator: a custom allocator for dense and sparse dynamic arrays. Defaults to context.allocator.
// Creates dense and sparse using provided allocator.
// Set's count to 0.
// Checks _is_init flag (it will be considered initialised from now)
init :: proc {
	init_sset_auto,
	init_sset_manual,
}


// Inserts item to Sparse_Set.
// Returns a handle to inserted element
// Algorithm complexity: O(1)
insert :: proc {
	insert_sset_auto,
	insert_sset_manual,
}


// Removes item of Sparse_Set if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set
// @param handle: Sparse_Set_Handle containing the id of the element
// Swaps removed element with last element of dense array preventing complex resizing and moving elements.
// Algorithm complexity: O(1)
remove :: proc {
	remove_sset_auto,
	remove_sset_manual,
}


// Gets and item of Sparse_Set if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set
// @param handle: Sparse_Set_Handle containing the id of the element
// Returns a pointer to the element
// Algorithm complexity: O(1)
get :: proc {
	get_sset_auto,
	get_sset_manual,
}


// Gets handles for all valid elements of Sparse_Set.
// @param sset: pointer to Sparse_Set
// Uses _map_field with tranform proc that returns Sparse_Set_Handle
// Returns a slice of selected handles
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
get_all_handles :: proc {
	get_all_handles_sset_auto,
	get_all_handles_sset_manual,
}


// Maps properties for all valid elements of Sparse_Set.
// @param sset: pointer to Sparse_Set
// @param transform: proc that get's T value and returns given property
// Returns a slice of selected fields
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
map_field :: proc {
	map_field_sset_auto,
	map_field_sset_manual,
}


// Checks if there's a valid element with given handle in Sparse_Set.
// @param sset: pointer to Sparse_Set
// @param handle: Sparse_Set_Handle containing the id of the element
// Returns true if there's a valid element with given handle in Sparse_Set
// Algorithm complexity: O(1)
contains :: proc {
	contains_sset_auto,
	contains_sset_manual,
}


// Resets Sparse_Set while keeping memory allocated.
// @param sset: pointer to Sparse_Set
// Sets count to 0. That way every item in sset will be invalidated.
// Ideal for cleaning elements but keep use of sparse set possible
// Algorithm complexity: O(1)
reset :: proc {
	reset_sset_auto,
	reset_sset_manual,
}


// Releases Sparse_Set allocated memory.
// @param sset: pointer to Sparse_Set
// Releases dense and sparse.
// Set values to default.
// Destroyed Sparse Sets can still be used, but they will be initilised again.
destroy :: proc {
	destroy_sset_auto,
	destroy_sset_manual,
}

