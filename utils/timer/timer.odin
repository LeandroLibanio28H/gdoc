package timer


import odin_time "core:time"


Timer :: struct {
	wait_time:        f64,
	paused:           bool,
	one_shoot:        bool,
	timeout_callback: proc() -> bool,
	_time:            f64,
	_last_time:       odin_time.Time,
}


update_timer :: proc(timer: ^Timer, scale: f64 = 1.0) -> bool {
	if timer.paused do return false
	elapsed: f64 = auto_cast odin_time.since(timer._last_time) / auto_cast odin_time.Second
	timer._time += elapsed
	timer._last_time = odin_time.now()
	if timer._time >= timer.wait_time {
		timer._time -= timer.wait_time
		if timer.one_shoot {
			timer._time = 0.0
			timer.paused = true
		}
		return timer.timeout_callback()
	}
	return false
}

