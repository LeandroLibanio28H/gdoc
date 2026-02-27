#+private
package timer


import "core:testing"


@(test)
test_timer :: proc(t: ^testing.T) {
	timer_container := create_timer_container()
	defer destroy_timer_container(&timer_container)
	count_normal: int = 0
	done: bool = false
	add_timer_to_container(
		&timer_container,
		1.0,
		false,
		&count_normal,
		proc(user_data: rawptr) -> bool {
			data := (^int)(user_data)
			data^ += 1
			return true
		},
	)
	for count_normal < 1 {
		update_timer_container(&timer_container)
	}
	testing.expect(t, count_normal == 1, "Timer counter failed")
}

@(test)
test_scaled_timer :: proc(t: ^testing.T) {
	timer_container := create_timer_container()
	timer_container.scale = 0.5
	defer destroy_timer_container(&timer_container)
	count_scaled: int = 0
	done: bool = false
	add_timer_to_container(
		&timer_container,
		0.5,
		false,
		&count_scaled,
		proc(user_data: rawptr) -> bool {
			data := (^int)(user_data)
			data^ += 1
			return true
		},
	)
	for count_scaled < 1 {
		update_timer_container(&timer_container)
	}
	testing.expect(t, count_scaled == 1, "Scaled timer counter failed")
}

@(test)
test_multiple_timers :: proc(t: ^testing.T) {
	timer_container := create_timer_container()
	defer destroy_timer_container(&timer_container)
	count_1: int = 0
	count_2: int = 0
	done: bool = false
	add_timer_to_container(
		&timer_container,
		1.0,
		false,
		&count_1,
		proc(user_data: rawptr) -> bool {
			data := (^int)(user_data)
			data^ += 1
			return true
		},
	)
	add_timer_to_container(
		&timer_container,
		1.0,
		false,
		&count_2,
		proc(user_data: rawptr) -> bool {
			data := (^int)(user_data)
			data^ += 1
			return true
		},
		"other_timer",
	)
	for count_1 < 1 || count_2 < 1 {
		update_timer_container(&timer_container)
	}
	testing.expect(t, count_1 == 1 && count_2 == 1, "Multiple timers counter failed")
}

