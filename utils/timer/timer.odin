package timer


import sset "../../container/sparse_set"


/*  ###################################################################
	TYPEDEFS
###################################################################  */


Timer_Container :: struct {
	timers: map[string]sset.Sparse_Set_Auto(Timer),
	scale:  f64,
}


/*  ###################################################################
	TIMER CONTAINER
###################################################################  */


// Creates a Timer_Container (map[string]sset.Sparse_Set_Auto(Timer)).
create_timer_container :: proc() -> Timer_Container {
	return Timer_Container{timers = make(map[string]sset.Sparse_Set_Auto(Timer)), scale = 1.0}
}


// Destroys a Timer_Container.
// Handles the destruction of the sparse sets.
// @param timer_container: pointer to Timer_Container
destroy_timer_container :: proc(timer_container: ^Timer_Container) {
	for key, &value in timer_container.timers {
		sset.destroy(&value)
	}
	delete(timer_container.timers)
}


// Adds a timer to the container.
// Returns the handle of the added timer.
// @param timer_container: pointer to Timer_Container
// @param wait_time: wait time in seconds
// @param one_shoot: whether the timer is one-shot or repeating
// @param user_data: pointer to the custom data to be passed to the callback
// @param timeout_callback: callback function to be called when the timer expires
// @param flag: string flag to identify the timer type (just for organization purposes)
add_timer_to_container :: proc(
	timer_container: ^Timer_Container,
	wait_time: f64,
	one_shoot: bool = false,
	user_data: rawptr = nil,
	timeout_callback: Timer_Timeout = nil,
	flag: string = "default",
) -> sset.Sparse_Set_Handle {
	timeout_callback_data := Timer_Timeout_Callback_Data {
		callback  = timeout_callback,
		user_data = user_data,
	}
	timer := create_timer(wait_time, one_shoot, timeout_callback_data)
	sset_flag, ok_flag := timer_container.timers[flag]
	if !ok_flag {
		timer_container.timers[flag] = sset.Sparse_Set_Auto(Timer){}
	}
	handle, ok_insert := sset.insert(&timer_container.timers[flag], timer)
	if ok_insert {
		return handle
	}
	return {id = -1}
}


// Removes a timer from the container.
// @param timer_container: pointer to Timer_Container
// @param handle: handle of the timer to be removed
// @param flag: string flag to identify the timer type
remove_timer_from_container :: proc(
	timer_container: ^Timer_Container,
	handle: sset.Sparse_Set_Handle,
	flag: string = "default",
) {
	sset_flag, ok_flag := timer_container.timers[flag]
	if !ok_flag {
		return
	}
	sset.remove(&sset_flag, handle)
}


// Updates all timers in the container.
// @param timer_container: pointer to Timer_Container
update_timer_container :: proc(timer_container: ^Timer_Container) {
	for key, _ in timer_container.timers {
		update_timer_container_flag(timer_container, key)
	}
}

