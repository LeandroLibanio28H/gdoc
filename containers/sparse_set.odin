package containers

import "core:mem"

// ============================================================================
// CONSTANTS & TYPES
// ============================================================================

SPARSE_SET_INVALID_INDEX :: max(u32)
SPARSE_SET_PAGE_SHIFT :: 10
SPARSE_SET_PAGE_SIZE :: 1 << SPARSE_SET_PAGE_SHIFT
SPARSE_SET_PAGE_MASK :: SPARSE_SET_PAGE_SIZE - 1

Sparse_Set_Page :: ^[SPARSE_SET_PAGE_SIZE]u32

Sparse_Set :: struct($T: typeid) {
	dense:        [dynamic]T,
	dense_ids:    [dynamic]u32,
	sparse_pages: [dynamic]Sparse_Set_Page,
	allocator:    mem.Allocator,
}

// ============================================================================
// INITIALIZATION & LIFECYCLE
// ============================================================================

sparse_set_init :: proc(
	sset: ^Sparse_Set($T),
	initial_capacity: int = 0,
	allocator := context.allocator,
) {
	sset.allocator = allocator
	sset.dense = make([dynamic]T, 0, initial_capacity, allocator)
	sset.dense_ids = make([dynamic]u32, 0, initial_capacity, allocator)
	sset.sparse_pages = make([dynamic]Sparse_Set_Page, allocator)
}

sparse_set_destroy :: proc(sset: ^Sparse_Set($T)) {
	for page in sset.sparse_pages {
		if page != nil do free(page, sset.allocator)
	}
	delete(sset.sparse_pages)
	delete(sset.dense_ids)
	delete(sset.dense)
}

// ============================================================================
// QUERIES
// ============================================================================

sparse_set_has :: proc(sset: ^Sparse_Set($T), id: u32) -> bool {
	page_idx := id >> SPARSE_SET_PAGE_SHIFT
	offset := id & SPARSE_SET_PAGE_MASK

	if int(page_idx) >= len(sset.sparse_pages) do return false
	page := sset.sparse_pages[page_idx]
	if page == nil do return false

	return page[offset] != SPARSE_SET_INVALID_INDEX
}

sparse_set_get :: proc(sset: ^Sparse_Set($T), id: u32) -> (^T, bool) {
	page_idx := id >> SPARSE_SET_PAGE_SHIFT
	offset := id & SPARSE_SET_PAGE_MASK

	if int(page_idx) >= len(sset.sparse_pages) do return nil, false
	page := sset.sparse_pages[page_idx]
	if page == nil do return nil, false

	dense_idx := page[offset]
	if dense_idx == SPARSE_SET_INVALID_INDEX do return nil, false

	return &sset.dense[dense_idx], true
}

// ============================================================================
// MUTATIONS
// ============================================================================

sparse_set_insert :: proc(sset: ^Sparse_Set($T), id: u32, item: T) {
	page_idx := id >> SPARSE_SET_PAGE_SHIFT
	offset := id & SPARSE_SET_PAGE_MASK

	if int(page_idx) >= len(sset.sparse_pages) {
		resize(&sset.sparse_pages, int(page_idx) + 1)
	}

	if sset.sparse_pages[page_idx] == nil {
		new_page := new([SPARSE_SET_PAGE_SIZE]u32, sset.allocator)
		mem.set(new_page, 0xFF, size_of([SPARSE_SET_PAGE_SIZE]u32))
		sset.sparse_pages[page_idx] = new_page
	}

	dense_idx := sset.sparse_pages[page_idx][offset]
	if dense_idx != SPARSE_SET_INVALID_INDEX {
		sset.dense[dense_idx] = item
		return
	}

	new_dense_idx := u32(len(sset.dense))
	sset.sparse_pages[page_idx][offset] = new_dense_idx
	append(&sset.dense, item)
	append(&sset.dense_ids, id)
}

sparse_set_remove :: proc(sset: ^Sparse_Set($T), id: u32) {
	page_idx := id >> SPARSE_SET_PAGE_SHIFT
	offset := id & SPARSE_SET_PAGE_MASK

	if int(page_idx) >= len(sset.sparse_pages) do return
	page := sset.sparse_pages[page_idx]
	if page == nil do return

	dense_idx := page[offset]
	if dense_idx == SPARSE_SET_INVALID_INDEX do return

	last_dense_idx := u32(len(sset.dense) - 1)

	if dense_idx != last_dense_idx {
		last_item := sset.dense[last_dense_idx]
		last_id := sset.dense_ids[last_dense_idx]

		sset.dense[dense_idx] = last_item
		sset.dense_ids[dense_idx] = last_id

		last_page_idx := last_id >> SPARSE_SET_PAGE_SHIFT
		last_offset := last_id & SPARSE_SET_PAGE_MASK
		sset.sparse_pages[last_page_idx][last_offset] = dense_idx
	}

	pop(&sset.dense)
	pop(&sset.dense_ids)
	page[offset] = SPARSE_SET_INVALID_INDEX
}

sparse_set_clear :: proc(sset: ^Sparse_Set($T)) {
	for page in sset.sparse_pages {
		if page != nil do mem.set(page, 0xFF, size_of([SPARSE_SET_PAGE_SIZE]u32))
	}
	clear(&sset.dense)
	clear(&sset.dense_ids)
}

// ============================================================================
// RAW SLICES (DOD ITERATION)
// ============================================================================

sparse_set_values :: proc(sset: ^Sparse_Set($T)) -> []T {
	return sset.dense[:]
}

sparse_set_ids :: proc(sset: ^Sparse_Set($T)) -> []u32 {
	return sset.dense_ids[:]
}
