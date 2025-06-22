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


Example (assumes this package is imported under the alias `sset`):

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


Sparse_Set_Handle :: struct {
	id: int,
}


Sparse_Set_Manual :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	using set: Sparse_Set(T),
}


Sparse_Set_Auto :: struct($T: typeid) where intrinsics.type_is_subtype_of(T, Sparse_Set_Handle) {
	using set: Sparse_Set(T),
	next_id:   int,
}


init :: proc {
	init_sset_auto,
	init_sset_manual,
}


is_initialized :: proc(sset: $T) -> bool where intrinsics.type_is_subtype_of(T, Sparse_Set) {
	return sset._is_init
}


insert :: proc {
	insert_sset_auto,
	insert_sset_manual,
}


remove :: proc {
	remove_sset_auto,
	remove_sset_manual,
}


get :: proc {
	get_sset_auto,
	get_sset_manual,
}


get_all_handles :: proc {
	get_all_handles_sset_auto,
	get_all_handles_sset_manual,
}


map_field :: proc {
	map_field_sset_auto,
	map_field_sset_manual,
}


contains :: proc {
	contains_sset_auto,
	contains_sset_manual,
}

reset :: proc {
	reset_sset_auto,
	reset_sset_manual,
}


destroy :: proc {
	destroy_sset_auto,
	destroy_sset_manual,
}
