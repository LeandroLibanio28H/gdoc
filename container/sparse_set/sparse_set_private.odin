#+private 
package sparse_set


import "base:intrinsics"
import "core:slice"


// Base Sparse Set struct Sparse_Set_Auto and Sparse_Set_Manual are subtypes of Sparse_Set
// Sparse_Set should not be used directly, that's why it's in private scope.
Sparse_Set :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	dense:    [dynamic]T, // dense, contiguous array
	sparse:   [dynamic]int, // sparse array, used for ids
	count:    int, // the current count of valid elements
	_is_init: bool, // flag to determine wether _init has been called. (Of course it can be set manually, but it shoudn't be)
}


/*	###################################################################
	INIT
###################################################################  */


// Initialises Sparse_Set_Auto.
// @param sset: pointer to Sparse_Set_Auto
// @param allocator: a custom allocator for dense and sparse dynamic arrays. Defaults to context.allocator.
// Set's next_id (exclusive to Sparse_Set_Auto) to 0 and calls common Sparse_Set initialisation (see _init)
init_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
	allocator := context.allocator,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	sset.next_id = 0
	_init(&sset.set, allocator)
}


// Initialises Sparse_Set_Manual.
// @param sset: pointer to Sparse_Set_Manual
// @param allocator: a custom allocator for dense and sparse dynamic arrays. Defaults to context.allocator.
// Calls common Sparse_Set initialisation (see _init)
init_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
	allocator := context.allocator,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_init(&sset.set, allocator)
}


// Initialises Sparse_Set.
// @param sset: pointer to Sparse_Set
// @param allocator: a custom allocator for dense and sparse dynamic arrays. Defaults to context.allocator.
// Creates dense and sparse using provided allocator.
// Set's count to 0.
// Checks _is_init flag (it will be considered initialised from now)
_init :: proc(
	sset: ^Sparse_Set($T),
	allocator := context.allocator,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	if sset._is_init do return

	sset.dense = make([dynamic]T, 0, allocator)
	sset.sparse = make([dynamic]int, 0, allocator)
	sset.count = 0
	sset._is_init = true
}


/*	###################################################################
	INSERT
###################################################################  */


// Inserts item to Sparse_Set_Auto.
// @param sset: pointer to Sparse_Set_Auto
// @param item: element to be inserted.
// Creates ids automatically, ids are never reused.
// 	There are 9.2 * 10¹⁸ available ids and it's virtually impossible to run out of them
// Increases count and next_id values.
// Returns a handle to inserted element
// Algorithm complexity: O(1)
insert_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
	item: T,
) -> (
	Sparse_Set_Handle,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	if !sset._is_init {
		init_sset_auto(sset)
	}
	if sset.next_id < 0 {
		return {}, false
	}
	item := item
	item.id = sset.next_id
	if item.id < 0 {
		return {}, false
	}

	handle := Sparse_Set_Handle {
		id = item.id,
	}

	if contains(sset, handle) {
		return {}, false
	}

	append(&sset.dense, item)
	sset_id := len(sset.dense) - 1

	if len(sset.sparse) <= item.id {
		resize(&sset.sparse, item.id + 1)
	}
	sset.sparse[item.id] = sset_id

	sset.count += 1
	sset.next_id += 1

	return handle, true
}


// Inserts item to Sparse_Set_Manual if there's not a valid element with given handle.id.
// @param sset: pointer to Sparse_Set_Manual
// @param item: element to be inserted.
// @param handle: Sparse_Set_Handle containing the id of the element
// Increases count value.
// Returns a handle to inserted element with id equals to provided handle.id
// Algorithm complexity: O(1)
insert_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
	item: T,
	handle: Sparse_Set_Handle,
) -> (
	Sparse_Set_Handle,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	if !sset._is_init {
		init_sset_manual(sset)
	}
	item := item
	item.id = handle.id
	if item.id < 0 {
		return {}, false
	}

	if contains(sset, handle) {
		return {}, false
	}

	append(&sset.dense, item)
	sset_id := len(sset.dense) - 1
	if len(sset.sparse) <= item.id {
		resize(&sset.sparse, item.id + 1)
	}

	sset.sparse[item.id] = sset_id

	sset.count += 1

	return handle, true
}


/*	###################################################################
	REMOVE
###################################################################  */


// Removes item of Sparse_Set_Auto if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set_Auto
// @param handle: Sparse_Set_Handle containing the id of the element
// Calls common Sparse_Set remove (see _remove).
// Algorithm complexity: O(1)
remove_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
	handle: Sparse_Set_Handle,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_remove(&sset.set, handle)
}


// Removes item of Sparse_Set_Manual if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set_Manual
// @param handle: Sparse_Set_Handle containing the id of the element
// Calls common Sparse_Set remove (see _remove).
// Algorithm complexity: O(1)
remove_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
	handle: Sparse_Set_Handle,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_remove(&sset.set, handle)
}


// Removes item of Sparse_Set if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set
// @param handle: Sparse_Set_Handle containing the id of the element
// Swaps removed element with last element of dense array preventing complex resizing and moving elements.
// Algorithm complexity: O(1)
_remove :: proc(
	sset: ^Sparse_Set($T),
	handle: Sparse_Set_Handle,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	if !sset._is_init do return
	if !_contains(sset, handle) do return

	last_idx := len(sset.dense) - 1
	last_item := sset.dense[last_idx]
	remove_idx := sset.sparse[handle.id]

	sset.dense[remove_idx] = last_item
	sset.sparse[last_item.id] = remove_idx
	sset.sparse[handle.id] = -1

	pop(&sset.dense)
	sset.count -= 1
}


/*	###################################################################
	GET
###################################################################  */


// Gets and item of Sparse_Set_Auto if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set_Auto
// @param handle: Sparse_Set_Handle containing the id of the element
// Calls common Sparse_Set get (see _get).
// Returns a pointer to the element
// Algorithm complexity: O(1)
get_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
	handle: Sparse_Set_Handle,
) -> (
	^T,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	return _get(&sset.set, handle)
}


// Gets and item of Sparse_Set_Manual if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set_Manual
// @param handle: Sparse_Set_Handle containing the id of the element
// Calls common Sparse_Set get (see _get).
// Returns a pointer to the element
// Algorithm complexity: O(1)
get_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
	handle: Sparse_Set_Handle,
) -> (
	^T,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	return _get(&sset.set, handle)
}


// Gets and item of Sparse_Set if there's a valid element with given handle.id.
// @param sset: pointer to Sparse_Set
// @param handle: Sparse_Set_Handle containing the id of the element
// Returns a pointer to the element
// Algorithm complexity: O(1)
_get :: proc(
	sset: ^Sparse_Set($T),
	handle: Sparse_Set_Handle,
) -> (
	^T,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	if !sset._is_init do return nil, false
	if !_contains(sset, handle) do return nil, false
	return &sset.dense[sset.sparse[handle.id]], true
}


/*	###################################################################
	GET ALL HANDLES
###################################################################  */


// Gets handles for all valid elements of Sparse_Set_Auto.
// @param sset: pointer to Sparse_Set_Auto
// Uses _map_field.
// Calls common Sparse_Set _get_all_handles.
// Returns a slice of selected handles
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
get_all_handles_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
) -> (
	[]Sparse_Set_Handle,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	return _get_all_handles(&sset.set)
}


// Gets handles for all valid elements of Sparse_Set_Manual.
// @param sset: pointer to Sparse_Set_Manual
// Uses _map_field.
// Calls common Sparse_Set _get_all_handles.
// Returns a slice of selected handles
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
get_all_handles_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
) -> (
	[]Sparse_Set_Handle,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	return _get_all_handles(&sset.set)
}


// Gets handles for all valid elements of Sparse_Set.
// @param sset: pointer to Sparse_Set
// Uses _map_field with tranform proc that returns Sparse_Set_Handle
// Returns a slice of selected handles
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
_get_all_handles :: proc(
	sset: ^Sparse_Set($T),
) -> (
	[]Sparse_Set_Handle,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	if !sset._is_init {
		return nil, false
	}
	if sset.count == 0 {
		return nil, false
	}

	return _map_field(sset, proc(val: T) -> Sparse_Set_Handle {
		return Sparse_Set_Handle{id = val.id}
	})
}


/*	###################################################################
	MAP FIELD
###################################################################  */


// Maps properties for all valid elements of Sparse_Set_Auto.
// @param sset: pointer to Sparse_Set_Auto
// @param transform: proc that get's T value and returns given property
// Calls common Sparse_Set _map_field.
// Returns a slice of selected fields
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
map_field_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
	transform: proc(val: T) -> $R,
) -> (
	[]R,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	return _map_field(&sset.set, transform)
}


// Maps properties for all valid elements of Sparse_Set_Manual.
// @param sset: pointer to Sparse_Set_Manual
// @param transform: proc that get's T value and returns given property
// Calls common Sparse_Set _map_field.
// Returns a slice of selected fields
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
map_field_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
	transform: proc(val: T) -> $R,
) -> (
	[]R,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	return _map_field(&sset.set, transform)
}


// Maps properties for all valid elements of Sparse_Set.
// @param sset: pointer to Sparse_Set
// @param transform: proc that get's T value and returns given property
// Returns a slice of selected fields
// The slice is allocated and it's memory should be released when not needed (delete(slice))
// Algorithm complexity: O(N)
_map_field :: proc(
	sset: ^Sparse_Set($T),
	transform: proc(val: T) -> $R,
) -> (
	[]R,
	bool,
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) #optional_ok {
	if !sset._is_init {
		return nil, false
	}
	if sset.count == 0 {
		return nil, false
	}

	result := make([]R, sset.count)

	for i in 0 ..< sset.count {
		result[i] = transform(sset.dense[i])
	}

	return result, true
}


/*	###################################################################
	CONTAINS
###################################################################  */


// Checks if there's a valid element with given handle in Sparse_Set_Auto.
// @param sset: pointer to Sparse_Set_Auto
// @param handle: Sparse_Set_Handle containing the id of the element
// Calls common Sparse_Set _contains.
// Returns true if there's a valid element with given handle in Sparse_Set
// Algorithm complexity: O(1)
contains_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
	handle: Sparse_Set_Handle,
) -> bool where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	return _contains(&sset.set, handle)
}


// Checks if there's a valid element with given handle in Sparse_Set_Manual.
// @param sset: pointer to Sparse_Set_Manual
// @param handle: Sparse_Set_Handle containing the id of the element
// Calls common Sparse_Set _contains.
// Returns true if there's a valid element with given handle in Sparse_Set
// Algorithm complexity: O(1)
contains_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
	handle: Sparse_Set_Handle,
) -> bool where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	return _contains(&sset.set, handle)
}


// Checks if there's a valid element with given handle in Sparse_Set.
// @param sset: pointer to Sparse_Set
// @param handle: Sparse_Set_Handle containing the id of the element
// Returns true if there's a valid element with given handle in Sparse_Set
// Algorithm complexity: O(1)
_contains :: proc(
	sset: ^Sparse_Set($T),
	handle: Sparse_Set_Handle,
) -> bool where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	if !sset._is_init do return false
	if handle.id < 0 || handle.id >= len(sset.sparse) || sset.sparse[handle.id] >= sset.count do return false

	dense_idx := sset.sparse[handle.id]
	if dense_idx >= len(sset.dense) || dense_idx < 0 do return false

	return sset.dense[dense_idx].id == handle.id
}


/*	###################################################################
	RESET
###################################################################  */


// Resets Sparse_Set_Auto while keeping memory allocated.
// @param sset: pointer to Sparse_Set_Auto
// Calls common Sparse_Set _reset.
// Algorithm complexity: O(1)
reset_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_reset(&sset.set)
}


// Resets Sparse_Set_Manual while keeping memory allocated.
// @param sset: pointer to Sparse_Set_Manual
// Calls common Sparse_Set _reset.
// Algorithm complexity: O(1)
reset_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_reset(&sset.set)
}


// Resets Sparse_Set while keeping memory allocated.
// @param sset: pointer to Sparse_Set
// Sets count to 0. That way every item in sset will be invalidated.
// Ideal for cleaning elements but keep use of sparse set possible
// Algorithm complexity: O(1)
_reset :: proc(sset: ^Sparse_Set($T)) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	sset.count = 0
}


/*	###################################################################
	DESTROY
###################################################################  */


// Releases Sparse_Set_Auto allocated memory.
// @param sset: pointer to Sparse_Set_Auto
// Calls common Sparse_Set _destroy.
// Set next_id back to 0
destroy_sset_auto :: proc(
	sset: ^Sparse_Set_Auto($T),
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_destroy(&sset.set)
	sset.next_id = 0
}


// Releases Sparse_Set_Manual allocated memory.
// @param sset: pointer to Sparse_Set_Manual
// Calls common Sparse_Set _destroy.
destroy_sset_manual :: proc(
	sset: ^Sparse_Set_Manual($T),
) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	_destroy(&sset.set)
}


// Releases Sparse_Set allocated memory.
// @param sset: pointer to Sparse_Set
// Releases dense and sparse.
// Set values to default.
// Destroyed Sparse Sets can still be used, but they will be initilised again.
_destroy :: proc(sset: ^Sparse_Set($T)) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	delete(sset.dense)
	delete(sset.sparse)
	sset._is_init = false
	sset.count = 0
}
