#+private
package ecs

import log "core:log"
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
	data:      []byte,
	data_len:  int,
	data_cap:  int,
	allocator: mem.Allocator,
}

command_buffer_init :: proc(
	cb: ^Command_Buffer,
	initial_capacity: int = 64,
	allocator := context.allocator,
) {
	cb.allocator = allocator
	cb.commands = make([dynamic]Command, 0, initial_capacity, allocator)

	initial_data_cap := initial_capacity * 32
	cb.data = nil
	cb.data_cap = 0
	if initial_data_cap > 0 {
		raw_mem, err := mem.alloc(initial_data_cap, 64, allocator)
		if err != .None {
			log.errorf(
				"CRITICAL ERROR: Out of memory to initialize command buffer data (%d bytes). Error: %v",
				initial_data_cap,
				err,
			)
			panic("Out of memory")
		}
		cb.data = ([^]byte)(raw_mem)[:initial_data_cap]
		cb.data_cap = initial_data_cap
	}
	cb.data_len = 0
}

command_buffer_destroy :: proc(cb: ^Command_Buffer) {
	delete(cb.commands)
	if cb.data != nil {
		mem.free(raw_data(cb.data), cb.allocator)
		cb.data = nil
	}
	cb.data_len = 0
	cb.data_cap = 0
}

command_buffer_grow_data :: proc(cb: ^Command_Buffer, min_capacity: int) {
	curr_cap := cb.data_cap
	if min_capacity <= curr_cap do return

	new_cap := max(256, curr_cap * 2)
	for new_cap < min_capacity {
		new_cap *= 2
	}

	new_mem, err := mem.alloc(new_cap, 64, cb.allocator)
	if err != .None {
		log.errorf(
			"CRITICAL ERROR: Out of memory to expand command buffer data to capacity of %d bytes. Error: %v",
			new_cap,
			err,
		)
		panic("Out of memory")
	}

	if cb.data != nil {
		if cb.data_len > 0 {
			mem.copy(new_mem, raw_data(cb.data), cb.data_len)
		}
		mem.free(raw_data(cb.data), cb.allocator)
	}

	cb.data = ([^]byte)(new_mem)[:new_cap]
	cb.data_cap = new_cap
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
