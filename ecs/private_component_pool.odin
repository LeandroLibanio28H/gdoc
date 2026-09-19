#+private
package ecs

import log "core:log"
import mem "core:mem"


INVALID_INDEX :: max(u32)

PAGE_SHIFT :: 10
PAGE_SIZE :: 1 << PAGE_SHIFT
PAGE_MASK :: PAGE_SIZE - 1


Page :: ^[PAGE_SIZE]u32


Component_Pool :: struct {
	element_size:   int,
	element_align:  int,
	capacity:       int,
	sparse_pages:   [dynamic]Page,
	dense:          [dynamic]Entity,
	component_data: [^]byte,
	allocator:      mem.Allocator,
}

pool_init :: proc(
	$T: typeid,
	initial_capacity: int,
	allocator := context.allocator,
) -> ^Component_Pool {
	pool := new(Component_Pool, allocator)
	pool.allocator = allocator
	pool.element_size = mem.align_forward_int(size_of(T), align_of(T))
	pool.element_align = max(align_of(T), 1)
	pool.capacity = initial_capacity
	pool.sparse_pages = make([dynamic]Page, allocator)
	pool.dense = make([dynamic]Entity, 0, initial_capacity, allocator)

	if pool.element_size > 0 && initial_capacity > 0 {
		bytes_to_alloc := pool.capacity * pool.element_size
		raw_mem, err := mem.alloc(bytes_to_alloc, pool.element_align, allocator)
		if err != .None {
			log.errorf(
				"CRITICAL ERROR: Out of memory to initialize component pool for '%v'. Requested: %d bytes. Error: %v",
				typeid_of(T),
				bytes_to_alloc,
				err,
			)
			panic("Out of memory")
		}
		pool.component_data = cast([^]byte)raw_mem
	}

	return pool
}

pool_destroy :: proc(pool: ^Component_Pool) {
	for page in pool.sparse_pages {
		if page != nil {
			free(page, pool.allocator)
		}
	}
	delete(pool.sparse_pages)
	delete(pool.dense)

	if pool.component_data != nil && pool.capacity > 0 {
		mem.free(pool.component_data, pool.allocator)
		pool.component_data = nil
		pool.capacity = 0
	}
}

pool_get_index :: proc(pool: ^Component_Pool, entity: Entity) -> (int, bool) {
	page_idx := entity.id >> PAGE_SHIFT
	offset := entity.id & PAGE_MASK

	if int(page_idx) >= len(pool.sparse_pages) do return -1, false
	page := pool.sparse_pages[page_idx]
	if page == nil do return -1, false
	dense_idx := page[offset]
	if dense_idx == INVALID_INDEX do return -1, false

	if pool.dense[dense_idx].id == entity.id && pool.dense[dense_idx].gen == entity.gen {
		return int(dense_idx), true
	}
	return -1, false
}

pool_has :: proc(pool: ^Component_Pool, entity: Entity) -> bool {
	_, ok := pool_get_index(pool, entity)
	return ok
}

pool_add :: proc(pool: ^Component_Pool, entity: Entity, data: rawptr) {
	if dense_idx, exists := pool_get_index(pool, entity); exists {
		if pool.element_size > 0 && data != nil {
			dest_ptr := &pool.component_data[dense_idx * pool.element_size]
			mem.copy(dest_ptr, data, pool.element_size)
		}
		return
	}

	page_idx := entity.id >> PAGE_SHIFT
	offset := entity.id & PAGE_MASK

	if int(page_idx) >= len(pool.sparse_pages) {
		resize(&pool.sparse_pages, int(page_idx) + 1)
	}

	if pool.sparse_pages[page_idx] == nil {
		new_page: Page = new([PAGE_SIZE]u32, pool.allocator)
		if new_page == nil {
			log.errorf(
				"CRITICAL ERROR: Out of memory to allocate sparse page for entity ID %d in component pool.",
				entity.id,
			)
			panic("Out of memory")
		}
		for i in 0 ..< PAGE_SIZE {
			new_page[i] = INVALID_INDEX
		}
		pool.sparse_pages[page_idx] = new_page
	}

	dense_idx := len(pool.dense)

	pool.sparse_pages[page_idx][offset] = u32(dense_idx)
	append(&pool.dense, entity)

	if pool.element_size > 0 {
		if dense_idx >= pool.capacity {
			new_cap := max(16, pool.capacity * 2)
			for new_cap <= dense_idx {
				new_cap *= 2
			}

			new_bytes := new_cap * pool.element_size
			new_mem, err := mem.alloc(new_bytes, pool.element_align, pool.allocator)
			if err != .None {
				log.errorf(
					"CRITICAL ERROR: Out of memory to expand component pool to capacity %d (%d bytes). Error: %v",
					new_cap,
					new_bytes,
					err,
				)
				panic("Out of memory")
			}
			if pool.component_data != nil && dense_idx > 0 {
				mem.copy(new_mem, pool.component_data, dense_idx * pool.element_size)
				mem.free(pool.component_data, pool.allocator)
			}
			pool.component_data = cast([^]byte)new_mem
			pool.capacity = new_cap
		}

		dest_ptr := &pool.component_data[dense_idx * pool.element_size]
		mem.copy(dest_ptr, data, pool.element_size)
	}
}

pool_remove :: proc(pool: ^Component_Pool, entity: Entity) {
	if !pool_has(pool, entity) do return

	page_idx := entity.id >> PAGE_SHIFT
	offset := entity.id & PAGE_MASK

	dense_idx := int(pool.sparse_pages[page_idx][offset])
	last_dense_idx := len(pool.dense) - 1
	last_entity := pool.dense[last_dense_idx]

	if dense_idx != last_dense_idx {
		pool.dense[dense_idx] = last_entity

		if pool.element_size > 0 {
			dest_bytes := &pool.component_data[dense_idx * pool.element_size]
			src_bytes := &pool.component_data[last_dense_idx * pool.element_size]
			mem.copy(dest_bytes, src_bytes, pool.element_size)
		}

		last_page_idx := last_entity.id >> PAGE_SHIFT
		last_offset := last_entity.id & PAGE_MASK

		pool.sparse_pages[last_page_idx][last_offset] = u32(dense_idx)
	}

	pop(&pool.dense)
	pool.sparse_pages[page_idx][offset] = INVALID_INDEX
}

pool_get :: proc(pool: ^Component_Pool, entity: Entity) -> rawptr {
	dense_idx, ok := pool_get_index(pool, entity)
	if !ok do return nil

	if pool.element_size == 0 do return rawptr(pool)

	byte_offset := dense_idx * pool.element_size
	return &pool.component_data[byte_offset]
}
