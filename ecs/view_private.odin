#+private
package ecs

// ---------------------------------------------------------
// VIEW 1
// ---------------------------------------------------------

View1 :: struct($A: typeid) {
	pool_a: ^Component_Pool,
	index:  int,
}

view1_create :: proc(world: ^World, $A: typeid) -> View1(A) {
	return View1(A){pool_a = world._component_pools[A], index = 0}
}

view1_next :: proc(view: ^View1($A)) -> (entity: Entity, a: ^A, ok: bool) {
	if view.pool_a == nil do return {}, nil, false

	for view.index < len(view.pool_a.dense) {
		curr_index := view.index
		view.index += 1

		entity = view.pool_a.dense[curr_index]
		a =
			view.pool_a.element_size > 0 ? cast(^A)&view.pool_a.component_data[curr_index * view.pool_a.element_size] : nil

		return entity, a, true
	}
	return {}, nil, false
}


// ---------------------------------------------------------
// VIEW 2
// ---------------------------------------------------------

View2 :: struct($A: typeid, $B: typeid) {
	pool_a, pool_b: ^Component_Pool,
	lead_pool:      ^Component_Pool,
	test_pool_1:    ^Component_Pool,
	lead_role:      int,
	test1_role:     int,
	index:          int,
}

view2_create :: proc(world: ^World, $A: typeid, $B: typeid) -> View2(A, B) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]

	view := View2(A, B) {
		pool_a = pool_a,
		pool_b = pool_b,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)

	if len_a <= len_b {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
	} else {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
	}

	return view
}

view2_next :: proc(view: ^View2($A, $B)) -> (entity: Entity, a: ^A, b: ^B, ok: bool) {
	if view.lead_pool == nil || view.test_pool_1 == nil do return {}, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil

		ptrs: [2]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr

		return entity, cast(^A)ptrs[0], cast(^B)ptrs[1], true
	}
	return {}, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 3
// ---------------------------------------------------------

View3 :: struct($A: typeid, $B: typeid, $C: typeid) {
	pool_a, pool_b, pool_c: ^Component_Pool,
	lead_pool:              ^Component_Pool,
	test_pool_1:            ^Component_Pool,
	test_pool_2:            ^Component_Pool,
	lead_role:              int,
	test1_role:             int,
	test2_role:             int,
	index:                  int,
}

view3_create :: proc(world: ^World, $A: typeid, $B: typeid, $C: typeid) -> View3(A, B, C) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]
	pool_c := world._component_pools[C]

	view := View3(A, B, C) {
		pool_a = pool_a,
		pool_b = pool_b,
		pool_c = pool_c,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil || pool_c == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)
	len_c := len(pool_c.dense)

	if len_a <= len_b && len_a <= len_c {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
		view.test_pool_2 = pool_c; view.test2_role = 2
	} else if len_b <= len_a && len_b <= len_c {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_c; view.test2_role = 2
	} else {
		view.lead_pool = pool_c; view.lead_role = 2
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
	}

	return view
}

view3_next :: proc(view: ^View3($A, $B, $C)) -> (entity: Entity, a: ^A, b: ^B, c: ^C, ok: bool) {
	if view.lead_pool == nil do return {}, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue
		idx2, ok2 := pool_get_index(view.test_pool_2, entity)
		if !ok2 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil
		test2_ptr :=
			view.test_pool_2.element_size > 0 ? &view.test_pool_2.component_data[idx2 * view.test_pool_2.element_size] : nil

		ptrs: [3]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr
		ptrs[view.test2_role] = test2_ptr

		return entity, cast(^A)ptrs[0], cast(^B)ptrs[1], cast(^C)ptrs[2], true
	}
	return {}, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 4
// ---------------------------------------------------------

View4 :: struct($A: typeid, $B: typeid, $C: typeid, $D: typeid) {
	pool_a, pool_b, pool_c, pool_d: ^Component_Pool,
	lead_pool:                      ^Component_Pool,
	test_pool_1:                    ^Component_Pool,
	test_pool_2:                    ^Component_Pool,
	test_pool_3:                    ^Component_Pool,
	lead_role:                      int,
	test1_role:                     int,
	test2_role:                     int,
	test3_role:                     int,
	index:                          int,
}

view4_create :: proc(
	world: ^World,
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
) -> View4(A, B, C, D) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]
	pool_c := world._component_pools[C]
	pool_d := world._component_pools[D]

	view := View4(A, B, C, D) {
		pool_a = pool_a,
		pool_b = pool_b,
		pool_c = pool_c,
		pool_d = pool_d,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil || pool_c == nil || pool_d == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)
	len_c := len(pool_c.dense)
	len_d := len(pool_d.dense)

	if len_a <= len_b && len_a <= len_c && len_a <= len_d {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
	} else if len_b <= len_a && len_b <= len_c && len_b <= len_d {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
	} else if len_c <= len_a && len_c <= len_b && len_c <= len_d {
		view.lead_pool = pool_c; view.lead_role = 2
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_d; view.test3_role = 3
	} else {
		view.lead_pool = pool_d; view.lead_role = 3
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
	}

	return view
}

view4_next :: proc(
	view: ^View4($A, $B, $C, $D),
) -> (
	entity: Entity,
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	ok: bool,
) {
	if view.lead_pool == nil do return {}, nil, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue
		idx2, ok2 := pool_get_index(view.test_pool_2, entity)
		if !ok2 do continue
		idx3, ok3 := pool_get_index(view.test_pool_3, entity)
		if !ok3 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil
		test2_ptr :=
			view.test_pool_2.element_size > 0 ? &view.test_pool_2.component_data[idx2 * view.test_pool_2.element_size] : nil
		test3_ptr :=
			view.test_pool_3.element_size > 0 ? &view.test_pool_3.component_data[idx3 * view.test_pool_3.element_size] : nil

		ptrs: [4]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr
		ptrs[view.test2_role] = test2_ptr
		ptrs[view.test3_role] = test3_ptr

		return entity, cast(^A)ptrs[0], cast(^B)ptrs[1], cast(^C)ptrs[2], cast(^D)ptrs[3], true
	}
	return {}, nil, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 5
// ---------------------------------------------------------

View5 :: struct($A: typeid, $B: typeid, $C: typeid, $D: typeid, $E: typeid) {
	pool_a, pool_b, pool_c, pool_d, pool_e: ^Component_Pool,
	lead_pool:                              ^Component_Pool,
	test_pool_1:                            ^Component_Pool,
	test_pool_2:                            ^Component_Pool,
	test_pool_3:                            ^Component_Pool,
	test_pool_4:                            ^Component_Pool,
	lead_role:                              int,
	test1_role:                             int,
	test2_role:                             int,
	test3_role:                             int,
	test4_role:                             int,
	index:                                  int,
}

view5_create :: proc(
	world: ^World,
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
	$E: typeid,
) -> View5(A, B, C, D, E) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]
	pool_c := world._component_pools[C]
	pool_d := world._component_pools[D]
	pool_e := world._component_pools[E]

	view := View5(A, B, C, D, E) {
		pool_a = pool_a,
		pool_b = pool_b,
		pool_c = pool_c,
		pool_d = pool_d,
		pool_e = pool_e,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil || pool_c == nil || pool_d == nil || pool_e == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)
	len_c := len(pool_c.dense)
	len_d := len(pool_d.dense)
	len_e := len(pool_e.dense)

	if len_a <= len_b && len_a <= len_c && len_a <= len_d && len_a <= len_e {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
	} else if len_b <= len_a && len_b <= len_c && len_b <= len_d && len_b <= len_e {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
	} else if len_c <= len_a && len_c <= len_b && len_c <= len_d && len_c <= len_e {
		view.lead_pool = pool_c; view.lead_role = 2
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
	} else if len_d <= len_a && len_d <= len_b && len_d <= len_c && len_d <= len_e {
		view.lead_pool = pool_d; view.lead_role = 3
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_e; view.test4_role = 4
	} else {
		view.lead_pool = pool_e; view.lead_role = 4
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
	}

	return view
}

view5_next :: proc(
	view: ^View5($A, $B, $C, $D, $E),
) -> (
	entity: Entity,
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	e: ^E,
	ok: bool,
) {
	if view.lead_pool == nil do return {}, nil, nil, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue
		idx2, ok2 := pool_get_index(view.test_pool_2, entity)
		if !ok2 do continue
		idx3, ok3 := pool_get_index(view.test_pool_3, entity)
		if !ok3 do continue
		idx4, ok4 := pool_get_index(view.test_pool_4, entity)
		if !ok4 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil
		test2_ptr :=
			view.test_pool_2.element_size > 0 ? &view.test_pool_2.component_data[idx2 * view.test_pool_2.element_size] : nil
		test3_ptr :=
			view.test_pool_3.element_size > 0 ? &view.test_pool_3.component_data[idx3 * view.test_pool_3.element_size] : nil
		test4_ptr :=
			view.test_pool_4.element_size > 0 ? &view.test_pool_4.component_data[idx4 * view.test_pool_4.element_size] : nil

		ptrs: [5]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr
		ptrs[view.test2_role] = test2_ptr
		ptrs[view.test3_role] = test3_ptr
		ptrs[view.test4_role] = test4_ptr

		return entity,
			cast(^A)ptrs[0],
			cast(^B)ptrs[1],
			cast(^C)ptrs[2],
			cast(^D)ptrs[3],
			cast(^E)ptrs[4],
			true
	}
	return {}, nil, nil, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 6
// ---------------------------------------------------------

View6 :: struct($A: typeid, $B: typeid, $C: typeid, $D: typeid, $E: typeid, $F: typeid) {
	pool_a, pool_b, pool_c, pool_d, pool_e, pool_f: ^Component_Pool,
	lead_pool:                                      ^Component_Pool,
	test_pool_1:                                    ^Component_Pool,
	test_pool_2:                                    ^Component_Pool,
	test_pool_3:                                    ^Component_Pool,
	test_pool_4:                                    ^Component_Pool,
	test_pool_5:                                    ^Component_Pool,
	lead_role:                                      int,
	test1_role:                                     int,
	test2_role:                                     int,
	test3_role:                                     int,
	test4_role:                                     int,
	test5_role:                                     int,
	index:                                          int,
}

view6_create :: proc(
	world: ^World,
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
	$E: typeid,
	$F: typeid,
) -> View6(A, B, C, D, E, F) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]
	pool_c := world._component_pools[C]
	pool_d := world._component_pools[D]
	pool_e := world._component_pools[E]
	pool_f := world._component_pools[F]

	view := View6(A, B, C, D, E, F) {
		pool_a = pool_a,
		pool_b = pool_b,
		pool_c = pool_c,
		pool_d = pool_d,
		pool_e = pool_e,
		pool_f = pool_f,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil || pool_c == nil || pool_d == nil || pool_e == nil || pool_f == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)
	len_c := len(pool_c.dense)
	len_d := len(pool_d.dense)
	len_e := len(pool_e.dense)
	len_f := len(pool_f.dense)

	if len_a <= len_b && len_a <= len_c && len_a <= len_d && len_a <= len_e && len_a <= len_f {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
	} else if len_b <= len_a &&
	   len_b <= len_c &&
	   len_b <= len_d &&
	   len_b <= len_e &&
	   len_b <= len_f {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
	} else if len_c <= len_a &&
	   len_c <= len_b &&
	   len_c <= len_d &&
	   len_c <= len_e &&
	   len_c <= len_f {
		view.lead_pool = pool_c; view.lead_role = 2
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
	} else if len_d <= len_a &&
	   len_d <= len_b &&
	   len_d <= len_c &&
	   len_d <= len_e &&
	   len_d <= len_f {
		view.lead_pool = pool_d; view.lead_role = 3
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
	} else if len_e <= len_a &&
	   len_e <= len_b &&
	   len_e <= len_c &&
	   len_e <= len_d &&
	   len_e <= len_f {
		view.lead_pool = pool_e; view.lead_role = 4
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_f; view.test5_role = 5
	} else {
		view.lead_pool = pool_f; view.lead_role = 5
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_e; view.test5_role = 4
	}

	return view
}

view6_next :: proc(
	view: ^View6($A, $B, $C, $D, $E, $F),
) -> (
	entity: Entity,
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	e: ^E,
	f: ^F,
	ok: bool,
) {
	if view.lead_pool == nil do return {}, nil, nil, nil, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue
		idx2, ok2 := pool_get_index(view.test_pool_2, entity)
		if !ok2 do continue
		idx3, ok3 := pool_get_index(view.test_pool_3, entity)
		if !ok3 do continue
		idx4, ok4 := pool_get_index(view.test_pool_4, entity)
		if !ok4 do continue
		idx5, ok5 := pool_get_index(view.test_pool_5, entity)
		if !ok5 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil
		test2_ptr :=
			view.test_pool_2.element_size > 0 ? &view.test_pool_2.component_data[idx2 * view.test_pool_2.element_size] : nil
		test3_ptr :=
			view.test_pool_3.element_size > 0 ? &view.test_pool_3.component_data[idx3 * view.test_pool_3.element_size] : nil
		test4_ptr :=
			view.test_pool_4.element_size > 0 ? &view.test_pool_4.component_data[idx4 * view.test_pool_4.element_size] : nil
		test5_ptr :=
			view.test_pool_5.element_size > 0 ? &view.test_pool_5.component_data[idx5 * view.test_pool_5.element_size] : nil

		ptrs: [6]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr
		ptrs[view.test2_role] = test2_ptr
		ptrs[view.test3_role] = test3_ptr
		ptrs[view.test4_role] = test4_ptr
		ptrs[view.test5_role] = test5_ptr

		return entity,
			cast(^A)ptrs[0],
			cast(^B)ptrs[1],
			cast(^C)ptrs[2],
			cast(^D)ptrs[3],
			cast(^E)ptrs[4],
			cast(^F)ptrs[5],
			true
	}
	return {}, nil, nil, nil, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 7
// ---------------------------------------------------------

View7 :: struct(
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
	$E: typeid,
	$F: typeid,
	$G: typeid,
) {
	pool_a, pool_b, pool_c, pool_d, pool_e, pool_f, pool_g: ^Component_Pool,
	lead_pool:                                              ^Component_Pool,
	test_pool_1:                                            ^Component_Pool,
	test_pool_2:                                            ^Component_Pool,
	test_pool_3:                                            ^Component_Pool,
	test_pool_4:                                            ^Component_Pool,
	test_pool_5:                                            ^Component_Pool,
	test_pool_6:                                            ^Component_Pool,
	lead_role:                                              int,
	test1_role:                                             int,
	test2_role:                                             int,
	test3_role:                                             int,
	test4_role:                                             int,
	test5_role:                                             int,
	test6_role:                                             int,
	index:                                                  int,
}

view7_create :: proc(
	world: ^World,
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
	$E: typeid,
	$F: typeid,
	$G: typeid,
) -> View7(A, B, C, D, E, F, G) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]
	pool_c := world._component_pools[C]
	pool_d := world._component_pools[D]
	pool_e := world._component_pools[E]
	pool_f := world._component_pools[F]
	pool_g := world._component_pools[G]

	view := View7(A, B, C, D, E, F, G) {
		pool_a = pool_a,
		pool_b = pool_b,
		pool_c = pool_c,
		pool_d = pool_d,
		pool_e = pool_e,
		pool_f = pool_f,
		pool_g = pool_g,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil || pool_c == nil || pool_d == nil || pool_e == nil || pool_f == nil || pool_g == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)
	len_c := len(pool_c.dense)
	len_d := len(pool_d.dense)
	len_e := len(pool_e.dense)
	len_f := len(pool_f.dense)
	len_g := len(pool_g.dense)

	if len_a <= len_b &&
	   len_a <= len_c &&
	   len_a <= len_d &&
	   len_a <= len_e &&
	   len_a <= len_f &&
	   len_a <= len_g {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
	} else if len_b <= len_a &&
	   len_b <= len_c &&
	   len_b <= len_d &&
	   len_b <= len_e &&
	   len_b <= len_f &&
	   len_b <= len_g {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
	} else if len_c <= len_a &&
	   len_c <= len_b &&
	   len_c <= len_d &&
	   len_c <= len_e &&
	   len_c <= len_f &&
	   len_c <= len_g {
		view.lead_pool = pool_c; view.lead_role = 2
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
	} else if len_d <= len_a &&
	   len_d <= len_b &&
	   len_d <= len_c &&
	   len_d <= len_e &&
	   len_d <= len_f &&
	   len_d <= len_g {
		view.lead_pool = pool_d; view.lead_role = 3
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
	} else if len_e <= len_a &&
	   len_e <= len_b &&
	   len_e <= len_c &&
	   len_e <= len_d &&
	   len_e <= len_f &&
	   len_e <= len_g {
		view.lead_pool = pool_e; view.lead_role = 4
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
	} else if len_f <= len_a &&
	   len_f <= len_b &&
	   len_f <= len_c &&
	   len_f <= len_d &&
	   len_f <= len_e &&
	   len_f <= len_g {
		view.lead_pool = pool_f; view.lead_role = 5
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_e; view.test5_role = 4
		view.test_pool_6 = pool_g; view.test6_role = 6
	} else {
		view.lead_pool = pool_g; view.lead_role = 6
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_e; view.test5_role = 4
		view.test_pool_6 = pool_f; view.test6_role = 5
	}

	return view
}

view7_next :: proc(
	view: ^View7($A, $B, $C, $D, $E, $F, $G),
) -> (
	entity: Entity,
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	e: ^E,
	f: ^F,
	g: ^G,
	ok: bool,
) {
	if view.lead_pool == nil do return {}, nil, nil, nil, nil, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue
		idx2, ok2 := pool_get_index(view.test_pool_2, entity)
		if !ok2 do continue
		idx3, ok3 := pool_get_index(view.test_pool_3, entity)
		if !ok3 do continue
		idx4, ok4 := pool_get_index(view.test_pool_4, entity)
		if !ok4 do continue
		idx5, ok5 := pool_get_index(view.test_pool_5, entity)
		if !ok5 do continue
		idx6, ok6 := pool_get_index(view.test_pool_6, entity)
		if !ok6 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil
		test2_ptr :=
			view.test_pool_2.element_size > 0 ? &view.test_pool_2.component_data[idx2 * view.test_pool_2.element_size] : nil
		test3_ptr :=
			view.test_pool_3.element_size > 0 ? &view.test_pool_3.component_data[idx3 * view.test_pool_3.element_size] : nil
		test4_ptr :=
			view.test_pool_4.element_size > 0 ? &view.test_pool_4.component_data[idx4 * view.test_pool_4.element_size] : nil
		test5_ptr :=
			view.test_pool_5.element_size > 0 ? &view.test_pool_5.component_data[idx5 * view.test_pool_5.element_size] : nil
		test6_ptr :=
			view.test_pool_6.element_size > 0 ? &view.test_pool_6.component_data[idx6 * view.test_pool_6.element_size] : nil

		ptrs: [7]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr
		ptrs[view.test2_role] = test2_ptr
		ptrs[view.test3_role] = test3_ptr
		ptrs[view.test4_role] = test4_ptr
		ptrs[view.test5_role] = test5_ptr
		ptrs[view.test6_role] = test6_ptr

		return entity,
			cast(^A)ptrs[0],
			cast(^B)ptrs[1],
			cast(^C)ptrs[2],
			cast(^D)ptrs[3],
			cast(^E)ptrs[4],
			cast(^F)ptrs[5],
			cast(^G)ptrs[6],
			true
	}
	return {}, nil, nil, nil, nil, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 8
// ---------------------------------------------------------

View8 :: struct(
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
	$E: typeid,
	$F: typeid,
	$G: typeid,
	$H: typeid,
) {
	pool_a, pool_b, pool_c, pool_d, pool_e, pool_f, pool_g, pool_h: ^Component_Pool,
	lead_pool:                                                      ^Component_Pool,
	test_pool_1:                                                    ^Component_Pool,
	test_pool_2:                                                    ^Component_Pool,
	test_pool_3:                                                    ^Component_Pool,
	test_pool_4:                                                    ^Component_Pool,
	test_pool_5:                                                    ^Component_Pool,
	test_pool_6:                                                    ^Component_Pool,
	test_pool_7:                                                    ^Component_Pool,
	lead_role:                                                      int,
	test1_role:                                                     int,
	test2_role:                                                     int,
	test3_role:                                                     int,
	test4_role:                                                     int,
	test5_role:                                                     int,
	test6_role:                                                     int,
	test7_role:                                                     int,
	index:                                                          int,
}

view8_create :: proc(
	world: ^World,
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
	$E: typeid,
	$F: typeid,
	$G: typeid,
	$H: typeid,
) -> View8(A, B, C, D, E, F, G, H) {
	pool_a := world._component_pools[A]
	pool_b := world._component_pools[B]
	pool_c := world._component_pools[C]
	pool_d := world._component_pools[D]
	pool_e := world._component_pools[E]
	pool_f := world._component_pools[F]
	pool_g := world._component_pools[G]
	pool_h := world._component_pools[H]

	view := View8(A, B, C, D, E, F, G, H) {
		pool_a = pool_a,
		pool_b = pool_b,
		pool_c = pool_c,
		pool_d = pool_d,
		pool_e = pool_e,
		pool_f = pool_f,
		pool_g = pool_g,
		pool_h = pool_h,
		index  = 0,
	}

	if pool_a == nil || pool_b == nil || pool_c == nil || pool_d == nil || pool_e == nil || pool_f == nil || pool_g == nil || pool_h == nil do return view

	len_a := len(pool_a.dense)
	len_b := len(pool_b.dense)
	len_c := len(pool_c.dense)
	len_d := len(pool_d.dense)
	len_e := len(pool_e.dense)
	len_f := len(pool_f.dense)
	len_g := len(pool_g.dense)
	len_h := len(pool_h.dense)

	if len_a <= len_b &&
	   len_a <= len_c &&
	   len_a <= len_d &&
	   len_a <= len_e &&
	   len_a <= len_f &&
	   len_a <= len_g &&
	   len_a <= len_h {
		view.lead_pool = pool_a; view.lead_role = 0
		view.test_pool_1 = pool_b; view.test1_role = 1
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else if len_b <= len_a &&
	   len_b <= len_c &&
	   len_b <= len_d &&
	   len_b <= len_e &&
	   len_b <= len_f &&
	   len_b <= len_g &&
	   len_b <= len_h {
		view.lead_pool = pool_b; view.lead_role = 1
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_c; view.test2_role = 2
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else if len_c <= len_a &&
	   len_c <= len_b &&
	   len_c <= len_d &&
	   len_c <= len_e &&
	   len_c <= len_f &&
	   len_c <= len_g &&
	   len_c <= len_h {
		view.lead_pool = pool_c; view.lead_role = 2
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_d; view.test3_role = 3
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else if len_d <= len_a &&
	   len_d <= len_b &&
	   len_d <= len_c &&
	   len_d <= len_e &&
	   len_d <= len_f &&
	   len_d <= len_g &&
	   len_d <= len_h {
		view.lead_pool = pool_d; view.lead_role = 3
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_e; view.test4_role = 4
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else if len_e <= len_a &&
	   len_e <= len_b &&
	   len_e <= len_c &&
	   len_e <= len_d &&
	   len_e <= len_e &&
	   len_e <= len_f &&
	   len_e <= len_g &&
	   len_e <= len_h {
		view.lead_pool = pool_e; view.lead_role = 4
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_f; view.test5_role = 5
		view.test_pool_6 = pool_g; view.test6_role = 6
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else if len_f <= len_a &&
	   len_f <= len_b &&
	   len_f <= len_c &&
	   len_f <= len_d &&
	   len_f <= len_e &&
	   len_f <= len_f &&
	   len_f <= len_g &&
	   len_f <= len_h {
		view.lead_pool = pool_f; view.lead_role = 5
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_e; view.test5_role = 4
		view.test_pool_6 = pool_g; view.test6_role = 6
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else if len_g <= len_a &&
	   len_g <= len_b &&
	   len_g <= len_c &&
	   len_g <= len_d &&
	   len_g <= len_e &&
	   len_g <= len_f &&
	   len_g <= len_g &&
	   len_g <= len_h {
		view.lead_pool = pool_g; view.lead_role = 6
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_e; view.test5_role = 4
		view.test_pool_6 = pool_f; view.test6_role = 5
		view.test_pool_7 = pool_h; view.test7_role = 7
	} else {
		view.lead_pool = pool_h; view.lead_role = 7
		view.test_pool_1 = pool_a; view.test1_role = 0
		view.test_pool_2 = pool_b; view.test2_role = 1
		view.test_pool_3 = pool_c; view.test3_role = 2
		view.test_pool_4 = pool_d; view.test4_role = 3
		view.test_pool_5 = pool_e; view.test5_role = 4
		view.test_pool_6 = pool_f; view.test6_role = 5
		view.test_pool_7 = pool_g; view.test7_role = 6
	}

	return view
}

view8_next :: proc(
	view: ^View8($A, $B, $C, $D, $E, $F, $G, $H),
) -> (
	entity: Entity,
	a: ^A,
	b: ^B,
	c: ^C,
	d: ^D,
	e: ^E,
	f: ^F,
	g: ^G,
	h: ^H,
	ok: bool,
) {
	if view.lead_pool == nil do return {}, nil, nil, nil, nil, nil, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx1, ok1 := pool_get_index(view.test_pool_1, entity)
		if !ok1 do continue
		idx2, ok2 := pool_get_index(view.test_pool_2, entity)
		if !ok2 do continue
		idx3, ok3 := pool_get_index(view.test_pool_3, entity)
		if !ok3 do continue
		idx4, ok4 := pool_get_index(view.test_pool_4, entity)
		if !ok4 do continue
		idx5, ok5 := pool_get_index(view.test_pool_5, entity)
		if !ok5 do continue
		idx6, ok6 := pool_get_index(view.test_pool_6, entity)
		if !ok6 do continue
		idx7, ok7 := pool_get_index(view.test_pool_7, entity)
		if !ok7 do continue

		lead_ptr :=
			view.lead_pool.element_size > 0 ? &view.lead_pool.component_data[curr_idx * view.lead_pool.element_size] : nil
		test1_ptr :=
			view.test_pool_1.element_size > 0 ? &view.test_pool_1.component_data[idx1 * view.test_pool_1.element_size] : nil
		test2_ptr :=
			view.test_pool_2.element_size > 0 ? &view.test_pool_2.component_data[idx2 * view.test_pool_2.element_size] : nil
		test3_ptr :=
			view.test_pool_3.element_size > 0 ? &view.test_pool_3.component_data[idx3 * view.test_pool_3.element_size] : nil
		test4_ptr :=
			view.test_pool_4.element_size > 0 ? &view.test_pool_4.component_data[idx4 * view.test_pool_4.element_size] : nil
		test5_ptr :=
			view.test_pool_5.element_size > 0 ? &view.test_pool_5.component_data[idx5 * view.test_pool_5.element_size] : nil
		test6_ptr :=
			view.test_pool_6.element_size > 0 ? &view.test_pool_6.component_data[idx6 * view.test_pool_6.element_size] : nil
		test7_ptr :=
			view.test_pool_7.element_size > 0 ? &view.test_pool_7.component_data[idx7 * view.test_pool_7.element_size] : nil

		ptrs: [8]rawptr
		ptrs[view.lead_role] = lead_ptr
		ptrs[view.test1_role] = test1_ptr
		ptrs[view.test2_role] = test2_ptr
		ptrs[view.test3_role] = test3_ptr
		ptrs[view.test4_role] = test4_ptr
		ptrs[view.test5_role] = test5_ptr
		ptrs[view.test6_role] = test6_ptr
		ptrs[view.test7_role] = test7_ptr

		return entity,
			cast(^A)ptrs[0],
			cast(^B)ptrs[1],
			cast(^C)ptrs[2],
			cast(^D)ptrs[3],
			cast(^E)ptrs[4],
			cast(^F)ptrs[5],
			cast(^G)ptrs[6],
			cast(^H)ptrs[7],
			true
	}
	return {}, nil, nil, nil, nil, nil, nil, nil, nil, false
}
