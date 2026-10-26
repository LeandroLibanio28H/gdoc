package ecs

import "base:intrinsics"
import "base:runtime"
import log "core:log"

MAX_VIEW_COMPONENTS :: 16

View :: struct($Q: typeid) where intrinsics.type_is_struct(Q) {
	pools:      [MAX_VIEW_COMPONENTS]^Component_Pool,
	lead_pool:  ^Component_Pool,
	lead_idx:   int,
	pool_count: int,
	index:      int,
}

view_create :: proc(
	world: ^World,
	$Q: typeid,
) -> (
	view: View(Q),
) where intrinsics.type_is_struct(Q) {

	ti := runtime.type_info_base(type_info_of(Q))
	struct_info := ti.variant.(runtime.Type_Info_Struct)

	count := int(struct_info.field_count)
	assert(
		count > 0 && count <= MAX_VIEW_COMPONENTS,
		"View struct must have between 1 and MAX_VIEW_COMPONENTS fields",
	)

	view.pool_count = count
	view.lead_idx = -1

	for i in 0 ..< count {
		field_ti := runtime.type_info_base(struct_info.types[i])
		ptr_info, is_ptr := field_ti.variant.(runtime.Type_Info_Pointer)
		assert(
			is_ptr && ptr_info.elem != nil,
			"All fields in a View query struct must be component pointers (^T)",
		)

		comp_tid := ptr_info.elem.id
		pool, ok := world._component_pools[comp_tid]
		if !ok || pool == nil {
			log.warnf("View queried unregistered component: %v", comp_tid)
			view.lead_pool = nil
			return
		}

		for prev in 0 ..< i {
			assert(view.pools[prev] != pool, "Duplicate component type in View query struct")
		}

		view.pools[i] = pool
		if view.lead_pool == nil || len(pool.dense) < len(view.lead_pool.dense) {
			view.lead_pool = pool
			view.lead_idx = i
		}
	}
	return
}

view_next :: proc(view: ^View($Q)) -> (entity: Entity, q: Q, ok: bool) {
	if view.lead_pool == nil do return {}, {}, false

	ptrs := ([^]rawptr)(&q)

	lead_loop: for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		for i in 0 ..< view.pool_count {
			pool := view.pools[i]
			dense_idx: int

			if i == view.lead_idx {
				dense_idx = curr_idx
			} else {
				found: bool
				dense_idx, found = pool_get_index(pool, entity)
				if !found do continue lead_loop
			}

			if pool.element_size == 0 {
				ptrs[i] = rawptr(pool)
			} else {
				ptrs[i] = &pool.component_data[dense_idx * pool.element_size]
			}
		}

		return entity, q, true
	}

	return {}, {}, false
}
