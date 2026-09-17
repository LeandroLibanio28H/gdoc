#+private
package ecs

import mem "core:mem"


INVALID_INDEX :: -1

PAGE_SHIFT :: 10
PAGE_SIZE :: 1 << PAGE_SHIFT
PAGE_MASK :: PAGE_SIZE - 1


Page :: ^[PAGE_SIZE]int


Component_Pool :: struct {
	element_size:   int,
	sparse_pages:   [dynamic]Page,
	dense:          [dynamic]Entity,
	component_data: [dynamic]byte,
}

pool_init :: proc($T: typeid, initial_capacity: int) -> ^Component_Pool {
	pool := new(Component_Pool)
	pool.element_size = size_of(T)
	pool.sparse_pages = make([dynamic]Page)
	pool.dense = make([dynamic]Entity, 0, initial_capacity)
	pool.component_data = make([dynamic]byte, 0, initial_capacity)
	return pool
}

pool_destroy :: proc(pool: ^Component_Pool) {
	for page in pool.sparse_pages {
		free(page)
	}
	delete(pool.sparse_pages)
	delete(pool.dense)
	delete(pool.component_data)
}

pool_get_index :: proc(pool: ^Component_Pool, entity: Entity) -> (int, bool) {
	page_idx := entity.id >> PAGE_SHIFT
	offset := entity.id & PAGE_MASK

	if page_idx >= len(pool.sparse_pages) do return -1, false
	page := pool.sparse_pages[page_idx]
	if page == nil do return -1, false
	dense_idx := page[offset]
	if dense_idx == INVALID_INDEX do return -1, false

	if pool.dense[dense_idx].id == entity.id && pool.dense[dense_idx].gen == entity.gen {
		return dense_idx, true
	}
	return -1, false
}

pool_has :: proc(pool: ^Component_Pool, entity: Entity) -> bool {
	_, ok := pool_get_index(pool, entity)
	return ok
}

pool_add :: proc(pool: ^Component_Pool, entity: Entity, data: rawptr) {
	if pool_has(pool, entity) do return

	page_idx := entity.id >> PAGE_SHIFT
	offset := entity.id & PAGE_MASK

	if page_idx >= len(pool.sparse_pages) {
		resize(&pool.sparse_pages, page_idx + 1)
	}

	if pool.sparse_pages[page_idx] == nil {
		new_page: Page = new([PAGE_SIZE]int)
		for i in 0 ..< PAGE_SIZE {
			new_page[i] = INVALID_INDEX
		}
		pool.sparse_pages[page_idx] = new_page
	}

	dense_idx := len(pool.dense)

	pool.sparse_pages[page_idx][offset] = dense_idx
	append(&pool.dense, entity)

	if pool.element_size > 0 {
		new_len := (dense_idx + 1) * pool.element_size
		if new_len > cap(pool.component_data) {
			new_cap := max(16 * pool.element_size, cap(pool.component_data) * 2)
			for new_cap < new_len {
				new_cap *= 2
			}
			reserve(&pool.component_data, new_cap)
		}
		resize(&pool.component_data, new_len)
		dest_ptr := &pool.component_data[dense_idx * pool.element_size]
		mem.copy(dest_ptr, data, pool.element_size)
	}
}

pool_remove :: proc(pool: ^Component_Pool, entity: Entity) {
	if !pool_has(pool, entity) do return

	page_idx := entity.id >> PAGE_SHIFT
	offset := entity.id & PAGE_MASK

	dense_idx := pool.sparse_pages[page_idx][offset]
	last_dense_idx := len(pool.dense) - 1
	last_entity := pool.dense[last_dense_idx]

	if dense_idx != last_dense_idx {
		pool.dense[dense_idx] = last_entity

		if pool.element_size > 0 {
			dest_bytes := &pool.component_data[dense_idx * pool.element_size]
			src_bytes := &pool.component_data[last_dense_idx * pool.element_size]
			mem.copy(dest_bytes, src_bytes, pool.element_size)
		}

		last_id := int(last_entity.id)
		last_page_idx := last_id >> PAGE_SHIFT
		last_offset := last_id & PAGE_MASK

		pool.sparse_pages[last_page_idx][last_offset] = dense_idx
	}

	pop(&pool.dense)
	if pool.element_size > 0 {
		resize(&pool.component_data, len(pool.component_data) - pool.element_size)
	}

	pool.sparse_pages[page_idx][offset] = INVALID_INDEX
}

pool_get :: proc(pool: ^Component_Pool, entity: Entity) -> rawptr {
	dense_idx, ok := pool_get_index(pool, entity)
	if !ok do return nil

	if pool.element_size == 0 do return rawptr(pool)

	byte_offset := dense_idx * pool.element_size
	return &pool.component_data[byte_offset]
}
