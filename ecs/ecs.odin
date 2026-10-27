package ecs

import log "core:log"
import mem "core:mem"

// ============================================================================
// CONSTANTS & TYPES
// ============================================================================

POOL_INVALID_INDEX :: max(u32)
POOL_PAGE_SHIFT :: 10
POOL_PAGE_SIZE :: 1 << POOL_PAGE_SHIFT
POOL_PAGE_MASK :: POOL_PAGE_SIZE - 1

Entity :: struct {
	id:  u32,
	gen: u32,
}

World :: struct {
	next_index:       u32,
	initial_capacity: int,
	free_indices:     [dynamic]u32,
	generations:      [dynamic]u32,
	component_pools:  map[typeid]^Component_Pool,
	pool_list:        [dynamic]^Component_Pool,
	cmd_buffer:       Command_Buffer,
	defer_depth:      int,
	allocator:        mem.Allocator,
}

// ============================================================================
// WORLD API
// ============================================================================

world_init :: proc(world: ^World, initial_capacity: int, allocator := context.allocator) {
	world.allocator = allocator
	world.next_index = 0
	world.initial_capacity = initial_capacity
	world.defer_depth = 0
	world.free_indices = make([dynamic]u32, 0, initial_capacity, allocator)
	world.generations = make([dynamic]u32, 0, initial_capacity, allocator)
	world.component_pools = make(map[typeid]^Component_Pool, allocator)
	world.pool_list = make([dynamic]^Component_Pool, 0, 32, allocator)
	command_buffer_init(&world.cmd_buffer, 64, allocator)
}

world_destroy :: proc(world: ^World) {
	command_buffer_destroy(&world.cmd_buffer)
	for pool in world.pool_list {
		pool_destroy(pool)
	}
	delete(world.pool_list)
	delete(world.component_pools)
	delete(world.free_indices)
	delete(world.generations)
}

world_defer_begin :: proc(world: ^World) {
	world.defer_depth += 1
}

world_defer_end :: proc(world: ^World) {
	if world.defer_depth > 0 {
		world.defer_depth -= 1
		if world.defer_depth == 0 {
			world_flush(world)
		}
	}
}

world_flush :: proc(world: ^World) {
	command_buffer_flush(world, &world.cmd_buffer)
}

world_is_deferred :: proc(world: ^World) -> bool {
	return world.defer_depth > 0
}

world_register_component :: proc(world: ^World, $T: typeid, initial_capacity: int = -1) {
	if T in world.component_pools {
		return
	}

	cap := initial_capacity >= 0 ? initial_capacity : world.initial_capacity
	pool := pool_init(T, cap, world.allocator)
	world.component_pools[T] = pool
	append(&world.pool_list, pool)
}

world_entity_count :: proc(world: ^World) -> int {
	return int(world.next_index) - len(world.free_indices)
}

world_get_all_alive_entities :: proc(
	world: ^World,
	allocator := context.temp_allocator,
) -> []Entity {
	count := world_entity_count(world)
	if count <= 0 do return nil

	entities := make([]Entity, count, allocator)
	idx := 0

	for id in 0 ..< world.next_index {
		gen := world.generations[id]
		if (gen & 1) == 1 {
			entities[idx] = Entity {
				id  = id,
				gen = gen,
			}
			idx += 1
		}
	}
	return entities[:idx]
}

world_component_count :: proc(world: ^World, $T: typeid) -> int {
	if pool, ok := world.component_pools[T]; ok {
		return len(pool.dense)
	}
	return 0
}

world_component_slice :: proc(world: ^World, $T: typeid) -> (entities: []Entity, components: []T) {
	pool, ok := world.component_pools[T]
	if !ok || len(pool.dense) == 0 do return nil, nil
	when size_of(T) == 0 {
		return pool.dense[:], nil
	} else {
		comp_ptr := cast([^]T)pool.component_data
		return pool.dense[:], comp_ptr[:len(pool.dense)]
	}
}

// ============================================================================
// ENTITY API
// ============================================================================

entity_alive :: proc(world: ^World, entity: Entity) -> bool {
	if (entity.gen & 1) == 0 do return false
	if auto_cast entity.id >= len(world.generations) do return false
	return world.generations[entity.id] == entity.gen
}

entity_create :: proc(world: ^World) -> Entity {
	idx: u32
	gen: u32

	if len(world.free_indices) > 0 {
		idx = pop(&world.free_indices)
		gen = world.generations[idx] + 1
	} else {
		idx = world.next_index
		world.next_index += 1
		append(&world.generations, u32(0))
		gen = 1
	}

	world.generations[idx] = gen

	return Entity{id = idx, gen = gen}
}

entity_destroy :: proc(world: ^World, entity: Entity) {
	if world.defer_depth > 0 {
		command_buffer_destroy_entity(&world.cmd_buffer, entity)
		return
	}
	entity_destroy_immediate(world, entity)
}

entity_add_component :: proc(world: ^World, entity: Entity, component: $T) {
	tid := typeid_of(T)

	if tid not_in world.component_pools {
		log.error("Attempt to add unregistered component", tid)
		return
	}

	if world.defer_depth > 0 {
		command_buffer_add_component(&world.cmd_buffer, entity, component)
		return
	}

	comp_copy := component
	entity_add_component_immediate(world, entity, tid, &comp_copy)
}

entity_get_component :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
	if !entity_alive(world, entity) do return nil
	pool, ok := world.component_pools[T]
	if !ok do return nil
	raw_ptr := pool_get(pool, entity)
	if raw_ptr == nil do return nil
	return cast(^T)(raw_ptr)
}

entity_has_component :: proc(world: ^World, entity: Entity, $T: typeid) -> bool {
	if !entity_alive(world, entity) do return false
	pool, ok := world.component_pools[T]
	if !ok do return false
	return pool_has(pool, entity)
}

entity_remove_component :: proc(world: ^World, entity: Entity, $T: typeid) {
	tid := typeid_of(T)

	if tid not_in world.component_pools {
		log.error("Attempt to remove unregistered component", tid)
		return
	}

	if world.defer_depth > 0 {
		command_buffer_remove_component(&world.cmd_buffer, entity, T)
		return
	}

	entity_remove_component_immediate(world, entity, tid)
}

// ============================================================================
// INTERNAL: IMMEDIATE ACTIONS
// ============================================================================

@(private)
entity_destroy_immediate :: proc(world: ^World, entity: Entity) {
	if !entity_alive(world, entity) do return

	for pool in world.pool_list {
		pool_remove(pool, entity)
	}

	world.generations[entity.id] += 1
	append(&world.free_indices, entity.id)
}

@(private)
entity_add_component_immediate :: proc(world: ^World, entity: Entity, tid: typeid, data: rawptr) {
	if !entity_alive(world, entity) do return
	pool_add(world.component_pools[tid], entity, data)
}

@(private)
entity_remove_component_immediate :: proc(world: ^World, entity: Entity, tid: typeid) {
	if !entity_alive(world, entity) do return
	pool_remove(world.component_pools[tid], entity)
}

// ============================================================================
// INTERNAL: COMPONENT POOL
// ============================================================================

@(private)
Pool_Page :: ^[POOL_PAGE_SIZE]u32

@(private)
Component_Pool :: struct {
	type_size:      int,
	type_align:     int,
	capacity:       int,
	sparse_pages:   [dynamic]Pool_Page,
	dense:          [dynamic]Entity,
	component_data: rawptr,
	allocator:      mem.Allocator,
}

@(private)
pool_init :: proc($T: typeid, initial_capacity: int, allocator: mem.Allocator) -> ^Component_Pool {
	pool := new(Component_Pool, allocator)
	pool.allocator = allocator
	pool.type_size = size_of(T)
	pool.type_align = max(align_of(T), 1)
	pool.capacity = max(initial_capacity, 0)
	pool.sparse_pages = make([dynamic]Pool_Page, allocator)
	pool.dense = make([dynamic]Entity, 0, pool.capacity, allocator)

	if pool.capacity > 0 {
		initial_pages := ((pool.capacity - 1) >> POOL_PAGE_SHIFT) + 1
		resize(&pool.sparse_pages, initial_pages)
		for i in 0 ..< initial_pages {
			pool.sparse_pages[i] = new([POOL_PAGE_SIZE]u32, allocator)
			mem.set(pool.sparse_pages[i], 0xFF, size_of([POOL_PAGE_SIZE]u32))
		}

		if pool.type_size > 0 {
			bytes_to_alloc := pool.capacity * pool.type_size
			raw_mem, err := mem.alloc(bytes_to_alloc, pool.type_align, allocator)
			if err != .None {
				log.errorf("CRITICAL ERROR: Out of memory to init pool for '%v'.", typeid_of(T))
				panic("Out of memory")
			}
			pool.component_data = raw_mem
		}
	}

	return pool
}

@(private)
pool_destroy :: proc(pool: ^Component_Pool) {
	for page in pool.sparse_pages {
		if page != nil do free(page, pool.allocator)
	}
	delete(pool.sparse_pages)
	delete(pool.dense)

	if pool.component_data != nil && pool.capacity > 0 {
		mem.free(pool.component_data, pool.allocator)
	}
	free(pool, pool.allocator)
}

@(private)
pool_get_index :: proc(pool: ^Component_Pool, entity: Entity) -> (int, bool) {
	page_idx := entity.id >> POOL_PAGE_SHIFT
	offset := entity.id & POOL_PAGE_MASK

	if int(page_idx) >= len(pool.sparse_pages) do return -1, false
	page := pool.sparse_pages[page_idx]
	if page == nil do return -1, false

	dense_idx := page[offset]
	if dense_idx == POOL_INVALID_INDEX do return -1, false

	if pool.dense[dense_idx].id == entity.id && pool.dense[dense_idx].gen == entity.gen {
		return int(dense_idx), true
	}
	return -1, false
}

@(private)
pool_has :: proc(pool: ^Component_Pool, entity: Entity) -> bool {
	_, ok := pool_get_index(pool, entity)
	return ok
}

@(private)
pool_add :: proc(pool: ^Component_Pool, entity: Entity, data: rawptr) {
	if dense_idx, exists := pool_get_index(pool, entity); exists {
		if pool.type_size > 0 && data != nil {
			dest := mem.ptr_offset(cast(^byte)pool.component_data, dense_idx * pool.type_size)
			mem.copy(dest, data, pool.type_size)
		}
		return
	}

	page_idx := entity.id >> POOL_PAGE_SHIFT
	offset := entity.id & POOL_PAGE_MASK

	if int(page_idx) >= len(pool.sparse_pages) {
		resize(&pool.sparse_pages, int(page_idx) + 1)
	}

	if pool.sparse_pages[page_idx] == nil {
		new_page := new([POOL_PAGE_SIZE]u32, pool.allocator)
		mem.set(new_page, 0xFF, size_of([POOL_PAGE_SIZE]u32))
		pool.sparse_pages[page_idx] = new_page
	}

	dense_idx := len(pool.dense)
	pool.sparse_pages[page_idx][offset] = u32(dense_idx)
	append(&pool.dense, entity)

	if pool.type_size > 0 {
		if dense_idx >= pool.capacity {
			new_cap := max(16, pool.capacity * 2)
			for new_cap <= dense_idx do new_cap *= 2

			old_bytes := pool.capacity * pool.type_size
			new_bytes := new_cap * pool.type_size
			new_mem, err := mem.resize_non_zeroed(
				pool.component_data,
				old_bytes,
				new_bytes,
				pool.type_align,
				pool.allocator,
			)
			if err != .None {
				log.errorf("CRITICAL ERROR: Failed expanding pool to %d capacity.", new_cap)
				panic("Out of memory")
			}
			pool.component_data = new_mem
			pool.capacity = new_cap
		}

		if data != nil {
			dest := mem.ptr_offset(cast(^byte)pool.component_data, dense_idx * pool.type_size)
			mem.copy(dest, data, pool.type_size)
		}
	}
}

@(private)
pool_remove :: proc(pool: ^Component_Pool, entity: Entity) {
	dense_idx, ok := pool_get_index(pool, entity)
	if !ok do return

	page_idx := entity.id >> POOL_PAGE_SHIFT
	offset := entity.id & POOL_PAGE_MASK

	last_dense_idx := len(pool.dense) - 1
	last_entity := pool.dense[last_dense_idx]

	if dense_idx != last_dense_idx {
		pool.dense[dense_idx] = last_entity

		if pool.type_size > 0 {
			dest := mem.ptr_offset(cast(^byte)pool.component_data, dense_idx * pool.type_size)
			src := mem.ptr_offset(cast(^byte)pool.component_data, last_dense_idx * pool.type_size)
			mem.copy(dest, src, pool.type_size)
		}

		last_page_idx := last_entity.id >> POOL_PAGE_SHIFT
		last_offset := last_entity.id & POOL_PAGE_MASK
		pool.sparse_pages[last_page_idx][last_offset] = u32(dense_idx)
	}

	pop(&pool.dense)
	pool.sparse_pages[page_idx][offset] = POOL_INVALID_INDEX
}

@(private)
pool_get :: proc(pool: ^Component_Pool, entity: Entity) -> rawptr {
	dense_idx, ok := pool_get_index(pool, entity)
	if !ok do return nil

	if pool.type_size == 0 do return rawptr(pool)

	return mem.ptr_offset(cast(^byte)pool.component_data, dense_idx * pool.type_size)
}

// ============================================================================
// INTERNAL: COMMAND BUFFER
// ============================================================================

@(private)
Command_Kind :: enum {
	Destroy_Entity,
	Remove_Component,
	Add_Component,
}

@(private)
Command :: struct {
	kind:        Command_Kind,
	entity:      Entity,
	comp_type:   typeid,
	data_offset: int,
	data_size:   int,
}

@(private)
Command_Buffer :: struct {
	commands:  [dynamic]Command,
	data:      []byte,
	data_len:  int,
	data_cap:  int,
	allocator: mem.Allocator,
}

@(private)
command_buffer_init :: proc(
	cb: ^Command_Buffer,
	initial_capacity: int = 64,
	allocator: mem.Allocator,
) {
	cb.allocator = allocator
	cb.commands = make([dynamic]Command, 0, initial_capacity, allocator)

	initial_data_cap := initial_capacity * 32
	cb.data = nil
	cb.data_cap = 0
	if initial_data_cap > 0 {
		raw_mem, err := mem.alloc(initial_data_cap, 64, allocator)
		if err != .None {
			log.errorf("CRITICAL ERROR: Out of memory to initialize command buffer data.")
			panic("Out of memory")
		}
		cb.data = ([^]byte)(raw_mem)[:initial_data_cap]
		cb.data_cap = initial_data_cap
	}
	cb.data_len = 0
}

@(private)
command_buffer_destroy :: proc(cb: ^Command_Buffer) {
	delete(cb.commands)
	if cb.data != nil {
		mem.free(raw_data(cb.data), cb.allocator)
		cb.data = nil
	}
	cb.data_len = 0
	cb.data_cap = 0
}

@(private)
command_buffer_grow_data :: proc(cb: ^Command_Buffer, min_capacity: int) {
	curr_cap := cb.data_cap
	if min_capacity <= curr_cap do return

	new_cap := max(256, curr_cap * 2)
	for new_cap < min_capacity {
		new_cap *= 2
	}

	new_mem, err := mem.resize_non_zeroed(
		raw_data(cb.data),
		cb.data_cap,
		new_cap,
		64,
		cb.allocator,
	)
	if err != .None {
		log.errorf("CRITICAL ERROR: Out of memory to expand command buffer.")
		panic("Out of memory")
	}

	cb.data = ([^]byte)(new_mem)[:new_cap]
	cb.data_cap = new_cap
}

@(private)
command_buffer_destroy_entity :: proc(cb: ^Command_Buffer, entity: Entity) {
	append(&cb.commands, Command{kind = .Destroy_Entity, entity = entity})
}

@(private)
command_buffer_remove_component :: proc(cb: ^Command_Buffer, entity: Entity, $T: typeid) {
	append(
		&cb.commands,
		Command{kind = .Remove_Component, entity = entity, comp_type = typeid_of(T)},
	)
}

@(private)
command_buffer_add_component :: proc(cb: ^Command_Buffer, entity: Entity, component: $T) {
	elem_size := size_of(T)
	elem_align := max(align_of(T), 1)
	assert(elem_align <= 64, "Component alignment exceeds max alignment (64 bytes)")

	offset := cb.data_len
	aligned_offset := mem.align_forward_int(offset, elem_align)

	padding := aligned_offset - offset
	total_needed := cb.data_len + padding + elem_size

	if total_needed > cb.data_cap {
		command_buffer_grow_data(cb, total_needed)
	}

	if padding > 0 {
		mem.zero(&cb.data[cb.data_len], padding)
		cb.data_len += padding
	}

	comp_copy := component
	data_start := cb.data_len

	if elem_size > 0 {
		mem.copy(&cb.data[data_start], &comp_copy, elem_size)
		cb.data_len += elem_size
	}

	append(
		&cb.commands,
		Command {
			kind = .Add_Component,
			entity = entity,
			comp_type = typeid_of(T),
			data_offset = data_start,
			data_size = elem_size,
		},
	)
}

@(private)
command_buffer_flush :: proc(world: ^World, cb: ^Command_Buffer) {
	for cmd in cb.commands {
		switch cmd.kind {
		case .Destroy_Entity:
			entity_destroy_immediate(world, cmd.entity)

		case .Remove_Component:
			entity_remove_component_immediate(world, cmd.entity, cmd.comp_type)

		case .Add_Component:
			data_ptr: rawptr = nil
			if cmd.data_size > 0 {
				data_ptr = &cb.data[cmd.data_offset]
			}
			entity_add_component_immediate(world, cmd.entity, cmd.comp_type, data_ptr)
		}
	}

	clear(&cb.commands)
	cb.data_len = 0
}
