package ecs


Event_Stream :: struct($T: typeid) {
	events: [dynamic]T,
}


event_stream_init :: proc(
	stream: ^Event_Stream($T),
	capacity: int = 128,
	allocator := context.allocator,
) {
	stream.events = make([dynamic]T, 0, capacity, allocator)
}

event_stream_destroy :: proc(stream: ^Event_Stream($T)) {
	delete(stream.events)
}

event_stream_push :: proc(stream: ^Event_Stream($T), event: T) {
    if stream.events.allocator.procedure == nil {
        event_stream_init(stream)
    }
    append(&stream.events, event)
}

event_stream_clear :: proc(stream: ^Event_Stream($T)) {
	clear(&stream.events)
}

event_stream_events :: proc(stream: ^Event_Stream($T)) -> []T {
	return stream.events[:]
}
