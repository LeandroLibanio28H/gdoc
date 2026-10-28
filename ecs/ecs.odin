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

world_init :: proc(world: ^World, initial_capacity: int = 0, allocator := context.allocator) {
	world.allocator = allocator
	world.next_index = 0
	world.initial_capacity = max(initial_capacity, 0)
	world.defer_depth = 0
	world.free_indices = make([dynamic]u32, 0, world.initial_capacity, allocator)
	world.generations = make([dynamic]u32, 0, world.initial_capacity, allocator)
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
	world^ = {}
}

world_clear :: proc(world: ^World) {
	if world.defer_depth != 0 {
		log.error("Cannot clear world while in deferred mode")
		panic("ECS Deferred Mode Clear Violation")
	}
	for pool in world.pool_list {
		pool_clear(pool)
	}
	clear(&world.free_indices)
	for id := int(world.next_index) - 1; id >= 0; id -= 1 {
		if (world.generations[id] & 1) == 1 {
			world.generations[id] += 1
		}
		append(&world.free_indices, u32(id))
	}
	clear(&world.cmd_buffer.commands)
	mem.dynamic_arena_reset(&world.cmd_buffer.arena)
}

world_defer_begin :: proc(world: ^World) {
	world.defer_depth += 1
}

world_defer_end :: proc(world: ^World) {
	if world.defer_depth <= 0 {
		log.error(
			"Mismatched world_defer_end: defer_depth is already 0. Did you forget a world_defer_begin?",
		)
		panic("ECS Defer Underflow")
	}
	world.defer_depth -= 1
	if world.defer_depth == 0 {
		world_flush(world)
	}
}

world_flush :: proc(world: ^World) {
	if world.defer_depth != 0 {
		log.error("Cannot flush command buffer while world is still in deferred mode")
		panic("ECS Deferred Mode Flush Violation")
	}
	command_buffer_flush(world, &world.cmd_buffer)
}

@(require_results)
world_is_deferred :: #force_inline proc(world: ^World) -> bool {
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

@(require_results)
world_entity_count :: #force_inline proc(world: ^World) -> int {
	return int(world.next_index) - len(world.free_indices)
}

@(require_results)
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

@(require_results)
world_component_count :: proc(world: ^World, $T: typeid) -> int {
	if pool, ok := world.component_pools[T]; ok {
		return len(pool.dense)
	}
	return 0
}

@(require_results)
world_component_slice :: proc(world: ^World, $T: typeid) -> (entities: []Entity, components: []T) {
	pool, ok := world.component_pools[T]
	if !ok || len(pool.dense) == 0 do return nil, nil
	when size_of(T) == 0 {
		comp_ptr := cast([^]T)pool
		return pool.dense[:], comp_ptr[:len(pool.dense)]
	} else {
		comp_ptr := cast([^]T)pool.component_data
		return pool.dense[:], comp_ptr[:len(pool.dense)]
	}
}

// ============================================================================
// ENTITY API
// ============================================================================

@(require_results)
entity_alive :: #force_inline proc(world: ^World, entity: Entity) -> bool {
	if (entity.gen & 1) == 0 do return false
	if entity.id >= u32(len(world.generations)) do return false
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
	pool, ok := world.component_pools[T]
	if !ok {
		log.errorf("Attempt to add unregistered component: %v", typeid_of(T))
		panic("ECS Unregistered Component")
	}
	if !entity_alive(world, entity) do return

	if world.defer_depth > 0 {
		command_buffer_add_component(&world.cmd_buffer, pool, entity, component)
		return
	}

	comp_copy := component
	pool_add(pool, entity, &comp_copy)
}

@(require_results)
entity_get_component :: #force_inline proc(
	world: ^World,
	entity: Entity,
	$T: typeid,
) -> (
	^T,
	bool,
) #optional_ok {
	pool, ok := world.component_pools[T]
	if !ok do return nil, false

	dense_idx, found := pool_get_index(pool, entity)
	if !found do return nil, false

	when size_of(T) == 0 {
		return cast(^T)rawptr(pool), true
	} else {
		comp_slice := cast([^]T)pool.component_data
		return &comp_slice[dense_idx], true
	}
}

@(require_results)
entity_has_component :: #force_inline proc(world: ^World, entity: Entity, $T: typeid) -> bool {
	pool, ok := world.component_pools[T]
	if !ok do return false
	return pool_has(pool, entity)
}

entity_remove_component :: proc(world: ^World, entity: Entity, $T: typeid) {
	pool, ok := world.component_pools[T]
	if !ok {
		log.errorf("Attempt to remove unregistered component: %v", typeid_of(T))
		panic("ECS Unregistered Component")
	}
	if !entity_alive(world, entity) do return

	if world.defer_depth > 0 {
		command_buffer_remove_component(&world.cmd_buffer, pool, entity)
		return
	}

	pool_remove(pool, entity)
}

// ============================================================================
// COMPONENT VIEWS (FAST PATH QUERIES)
// ============================================================================

Component_View :: struct($T: typeid) {
	pool: ^Component_Pool,
}

@(require_results)
world_component_view :: #force_inline proc(world: ^World, $T: typeid) -> Component_View(T) {
	return Component_View(T){pool = world.component_pools[T]}
}

@(require_results)
view_get :: #force_inline proc(
	view: Component_View($T),
	entity: Entity,
) -> (
	^T,
	bool,
) #optional_ok {
	if view.pool == nil do return nil, false

	dense_idx, found := pool_get_index(view.pool, entity)
	if !found do return nil, false

	when size_of(T) == 0 {
		return cast(^T)rawptr(view.pool), true
	} else {
		comp_slice := cast([^]T)view.pool.component_data
		return &comp_slice[dense_idx], true
	}
}

@(require_results)
view_has :: #force_inline proc(view: Component_View($T), entity: Entity) -> bool {
	if view.pool == nil do return false
	return pool_has(view.pool, entity)
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
entity_add_component_immediate :: proc(
	world: ^World,
	entity: Entity,
	pool: ^Component_Pool,
	data: rawptr,
) {
	if !entity_alive(world, entity) do return
	pool_add(pool, entity, data)
}

@(private)
entity_remove_component_immediate :: proc(world: ^World, entity: Entity, pool: ^Component_Pool) {
	if !entity_alive(world, entity) do return
	pool_remove(pool, entity)
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

	if pool.capacity > 0 && pool.type_size > 0 {
		bytes_to_alloc := pool.capacity * pool.type_size
		raw_mem, err := mem.alloc_bytes_non_zeroed(bytes_to_alloc, pool.type_align, allocator)
		if err != .None {
			log.errorf("CRITICAL ERROR: Out of memory to init pool for '%v'.", typeid_of(T))
			panic("Out of memory")
		}
		pool.component_data = raw_data(raw_mem)
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
pool_clear :: proc(pool: ^Component_Pool) {
	for entity in pool.dense {
		page_idx := entity.id >> POOL_PAGE_SHIFT
		offset := entity.id & POOL_PAGE_MASK
		pool.sparse_pages[page_idx][offset] = POOL_INVALID_INDEX
	}
	clear(&pool.dense)
}

@(private, require_results)
pool_get_index :: #force_inline proc(pool: ^Component_Pool, entity: Entity) -> (int, bool) {
	page_idx := entity.id >> POOL_PAGE_SHIFT
	offset := entity.id & POOL_PAGE_MASK

	if int(page_idx) >= len(pool.sparse_pages) do return -1, false
	page := pool.sparse_pages[page_idx]
	if page == nil do return -1, false

	dense_idx := page[offset]
	if dense_idx == POOL_INVALID_INDEX do return -1, false

	if pool.dense[dense_idx] == entity {
		return int(dense_idx), true
	}
	return -1, false
}

@(private, require_results)
pool_has :: #force_inline proc(pool: ^Component_Pool, entity: Entity) -> bool {
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

@(private, require_results)
pool_get :: #force_inline proc(pool: ^Component_Pool, entity: Entity) -> rawptr {
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
	kind:   Command_Kind,
	entity: Entity,
	pool:   ^Component_Pool,
	data:   rawptr,
}

@(private)
Command_Buffer :: struct {
	commands:  [dynamic]Command,
	arena:     mem.Dynamic_Arena,
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

	// Dynamic Arena handles block allocations gracefully and automatically
	mem.dynamic_arena_init(&cb.arena, allocator, allocator)
}

@(private)
command_buffer_destroy :: proc(cb: ^Command_Buffer) {
	delete(cb.commands)
	mem.dynamic_arena_destroy(&cb.arena)
}


@(private)
command_buffer_destroy_entity :: proc(cb: ^Command_Buffer, entity: Entity) {
	append(&cb.commands, Command{kind = .Destroy_Entity, entity = entity})
}

@(private)
command_buffer_remove_component :: proc(
	cb: ^Command_Buffer,
	pool: ^Component_Pool,
	entity: Entity,
) {
	append(&cb.commands, Command{kind = .Remove_Component, entity = entity, pool = pool})
}

@(private)
command_buffer_add_component :: proc(
	cb: ^Command_Buffer,
	pool: ^Component_Pool,
	entity: Entity,
	component: $T,
) {
	ptr: rawptr = nil

	when size_of(T) > 0 {
		raw_mem, err := mem.dynamic_arena_alloc_non_zeroed(&cb.arena, size_of(T), align_of(T))
		if err != .None || raw_mem == nil {
			log.error("CRITICAL ERROR: Command Buffer Arena OOM")
			panic("Out of memory")
		}
		typed_ptr := cast(^T)raw_mem
		typed_ptr^ = component
		ptr = raw_mem
	}

	append(&cb.commands, Command{kind = .Add_Component, entity = entity, pool = pool, data = ptr})
}

@(private)
command_buffer_flush :: proc(world: ^World, cb: ^Command_Buffer) {
	for cmd in cb.commands {
		switch cmd.kind {
		case .Destroy_Entity:
			entity_destroy_immediate(world, cmd.entity)

		case .Remove_Component:
			entity_remove_component_immediate(world, cmd.entity, cmd.pool)

		case .Add_Component:
			entity_add_component_immediate(world, cmd.entity, cmd.pool, cmd.data)
		}
	}

	clear(&cb.commands)
	mem.dynamic_arena_reset(&cb.arena)
}
