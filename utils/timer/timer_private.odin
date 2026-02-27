#+private
package timer

import sset "../../container/sparse_set"
import odin_time "core:time"


/*  ###################################################################
	TYPEDEFS
###################################################################  */


Timer_Timeout :: #type proc(user_data: rawptr) -> bool


Timer :: struct {
	using handle:     sset.Sparse_Set_Handle,
	settings:         Timer_Settings,
	paused:           bool,
	timeout_callback: Timer_Timeout_Callback_Data,
	timer_container:  ^Timer_Container,
	_time:            f64,
	_last_time:       odin_time.Time,
}


Timer_Timeout_Callback_Data :: struct {
	callback:  Timer_Timeout,
	user_data: rawptr,
}


Timer_Settings :: struct {
	wait_time: f64,
	one_shoot: bool,
}


/*  ###################################################################
	TIMER CONTAINER
###################################################################  */


// Updates the timer container flag
// All timers in the container flag will be updated
// Shouldn't be called directly, use update_timer_container instead to update all the timers
// @param timer_container: pointer to Timer_Container
// @param flag: flag to update
update_timer_container_flag :: proc(timer_container: ^Timer_Container, flag: string = "default") {
	sset_flag, ok_flag := timer_container.timers[flag]
	if !ok_flag {
		return
	}
	all := sset.get_all_handles(&sset_flag)
	defer delete(all)
	for handle in all {
		timer := sset.get(&sset_flag, handle)
		update_timer(timer, timer_container.scale)
	}
}


/*  ###################################################################
	TIMER
###################################################################  */


// Updates given timer.
// It uses odin.time to gather the elapsed time since the last update.
// @param timer: pointer to Timer
// @param scale: scale factor to apply to the elapsed time
update_timer :: proc(timer: ^Timer, scale: f64 = 1.0) -> bool {
	if timer.paused do return false
	elapsed: f64 = auto_cast odin_time.since(timer._last_time) / auto_cast odin_time.Second
	timer._time += elapsed
	timer._last_time = odin_time.now()
	result := false
	if timer._time >= timer.settings.wait_time {
		timer._time -= timer.settings.wait_time
		result = timer.timeout_callback.callback(timer.timeout_callback.user_data)
		if timer.settings.one_shoot {
			remove_timer_from_container(timer.timer_container, timer.handle)
			return result
		}
	}
	return result
}


// Creates a new timer.
// @param wait_time: time to wait before triggering the timeout callback.
// @param one_shoot: whether the timer should be removed after the timeout.
// @param timeout_callback: callback to be called when the timer times out.
create_timer :: proc(
	wait_time: f64,
	one_shoot: bool = false,
	timer_container: ^Timer_Container,
	timeout_callback: Timer_Timeout_Callback_Data = {},
) -> Timer {
	settings := Timer_Settings {
		wait_time = wait_time,
		one_shoot = one_shoot,
	}
	return Timer {
		settings = settings,
		paused = false,
		timeout_callback = timeout_callback,
		timer_container = timer_container,
		_time = 0.0,
		_last_time = odin_time.now(),
	}
}

