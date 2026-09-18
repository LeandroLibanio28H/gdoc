#+private
package ecs

import mem "core:mem"

Command_Kind :: enum {
	Destroy_Entity,
	Remove_Component,
	Add_Component,
}

Command :: struct {
	kind:        Command_Kind,
	entity:      Entity,
	comp_type:   typeid,
	data_offset: int,
	data_size:   int,
}

Command_Buffer :: struct {
	commands:  [dynamic]Command,
	data:      [dynamic]byte,
	allocator: mem.Allocator,
}

command_buffer_init :: proc(
	cb: ^Command_Buffer,
	initial_capacity: int = 64,
	allocator := context.allocator,
) {
	cb.allocator = allocator
	cb.commands = make([dynamic]Command, 0, initial_capacity, allocator)
	cb.data = make([dynamic]byte, 0, initial_capacity * 32, allocator)
}

command_buffer_destroy :: proc(cb: ^Command_Buffer) {
	delete(cb.commands)
	delete(cb.data)
}

command_buffer_destroy_entity :: proc(cb: ^Command_Buffer, entity: Entity) {
	append(&cb.commands, Command{kind = .Destroy_Entity, entity = entity})
}

command_buffer_remove_component :: proc(cb: ^Command_Buffer, entity: Entity, $T: typeid) {
	append(
		&cb.commands,
		Command{kind = .Remove_Component, entity = entity, comp_type = typeid_of(T)},
	)
}

command_buffer_add_component :: proc(cb: ^Command_Buffer, entity: Entity, component: $T) {
	elem_size := size_of(T)
	elem_align := max(align_of(T), 1)

	offset := len(cb.data)
	aligned_offset := mem.align_forward_int(offset, elem_align)

	padding := aligned_offset - offset
	if padding > 0 {
		for _ in 0 ..< padding {
			append(&cb.data, byte(0))
		}
	}

	comp_copy := component
	data_start := len(cb.data)

	if elem_size > 0 {
		resize(&cb.data, data_start + elem_size)
		mem.copy(&cb.data[data_start], &comp_copy, elem_size)
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

command_buffer_flush :: proc(world: ^World, cb: ^Command_Buffer) {
	for cmd in cb.commands {
		switch cmd.kind {
		case .Destroy_Entity:
			if !entity_alive(world, cmd.entity) do continue
			for _, pool in world._component_pools {
				pool_remove(pool, cmd.entity)
			}
			world._generations[cmd.entity.id] += 1
			append(&world._free_indices, cmd.entity.id)

		case .Remove_Component:
			if !entity_alive(world, cmd.entity) do continue
			if pool, ok := world._component_pools[cmd.comp_type]; ok {
				pool_remove(pool, cmd.entity)
			}

		case .Add_Component:
			if !entity_alive(world, cmd.entity) do continue
			if pool, ok := world._component_pools[cmd.comp_type]; ok {
				data_ptr: rawptr = nil
				if cmd.data_size > 0 {
					data_ptr = &cb.data[cmd.data_offset]
				}
				pool_add(pool, cmd.entity, data_ptr)
			}
		}
	}

	clear(&cb.commands)
	clear(&cb.data)
}
