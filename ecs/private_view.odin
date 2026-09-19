#+private
package ecs

find_lead_pool :: proc(pools: []^Component_Pool) -> ^Component_Pool {
	if len(pools) == 0 do return nil
	lead := pools[0]
	if lead == nil do return nil
	for p in pools[1:] {
		if p == nil do return nil
		if len(p.dense) < len(lead.dense) {
			lead = p
		}
	}
	return lead
}

pool_resolve_index :: #force_inline proc(
	pool: ^Component_Pool,
	entity: Entity,
	lead_idx: int,
	is_lead: bool,
) -> (
	int,
	bool,
) {
	if is_lead do return lead_idx, true
	return pool_get_index(pool, entity)
}

pool_component_ptr :: #force_inline proc(pool: ^Component_Pool, dense_idx: int, $T: typeid) -> ^T {
	if pool.element_size == 0 do return cast(^T)rawptr(pool)
	return cast(^T)&pool.component_data[dense_idx * pool.element_size]
}


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
		a = pool_component_ptr(view.pool_a, curr_index, A)
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
	index:          int,
}

view2_create :: proc(world: ^World, $A: typeid, $B: typeid) -> View2(A, B) {
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	return View2(A, B){pool_a = pa, pool_b = pb, lead_pool = find_lead_pool({pa, pb}), index = 0}
}

view2_next :: proc(view: ^View2($A, $B)) -> (entity: Entity, a: ^A, b: ^B, ok: bool) {
	if view.lead_pool == nil do return {}, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		return entity, a, b, true
	}
	return {}, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 3
// ---------------------------------------------------------

View3 :: struct($A: typeid, $B: typeid, $C: typeid) {
	pool_a, pool_b, pool_c: ^Component_Pool,
	lead_pool:              ^Component_Pool,
	index:                  int,
}

view3_create :: proc(world: ^World, $A: typeid, $B: typeid, $C: typeid) -> View3(A, B, C) {
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	pc := world._component_pools[C]
	return View3(A, B, C) {
		pool_a = pa,
		pool_b = pb,
		pool_c = pc,
		lead_pool = find_lead_pool({pa, pb, pc}),
		index = 0,
	}
}

view3_next :: proc(view: ^View3($A, $B, $C)) -> (entity: Entity, a: ^A, b: ^B, c: ^C, ok: bool) {
	if view.lead_pool == nil do return {}, nil, nil, nil, false

	for view.index < len(view.lead_pool.dense) {
		curr_idx := view.index
		view.index += 1

		entity = view.lead_pool.dense[curr_idx]

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue
		idx_c, ok_c := pool_resolve_index(
			view.pool_c,
			entity,
			curr_idx,
			view.lead_pool == view.pool_c,
		)
		if !ok_c do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		c = pool_component_ptr(view.pool_c, idx_c, C)
		return entity, a, b, c, true
	}
	return {}, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 4
// ---------------------------------------------------------

View4 :: struct($A: typeid, $B: typeid, $C: typeid, $D: typeid) {
	pool_a, pool_b, pool_c, pool_d: ^Component_Pool,
	lead_pool:                      ^Component_Pool,
	index:                          int,
}

view4_create :: proc(
	world: ^World,
	$A: typeid,
	$B: typeid,
	$C: typeid,
	$D: typeid,
) -> View4(A, B, C, D) {
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	pc := world._component_pools[C]
	pd := world._component_pools[D]
	return View4(A, B, C, D) {
		pool_a = pa,
		pool_b = pb,
		pool_c = pc,
		pool_d = pd,
		lead_pool = find_lead_pool({pa, pb, pc, pd}),
		index = 0,
	}
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

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue
		idx_c, ok_c := pool_resolve_index(
			view.pool_c,
			entity,
			curr_idx,
			view.lead_pool == view.pool_c,
		)
		if !ok_c do continue
		idx_d, ok_d := pool_resolve_index(
			view.pool_d,
			entity,
			curr_idx,
			view.lead_pool == view.pool_d,
		)
		if !ok_d do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		c = pool_component_ptr(view.pool_c, idx_c, C)
		d = pool_component_ptr(view.pool_d, idx_d, D)
		return entity, a, b, c, d, true
	}
	return {}, nil, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 5
// ---------------------------------------------------------

View5 :: struct($A: typeid, $B: typeid, $C: typeid, $D: typeid, $E: typeid) {
	pool_a, pool_b, pool_c, pool_d, pool_e: ^Component_Pool,
	lead_pool:                              ^Component_Pool,
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
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	pc := world._component_pools[C]
	pd := world._component_pools[D]
	pe := world._component_pools[E]
	return View5(A, B, C, D, E) {
		pool_a = pa,
		pool_b = pb,
		pool_c = pc,
		pool_d = pd,
		pool_e = pe,
		lead_pool = find_lead_pool({pa, pb, pc, pd, pe}),
		index = 0,
	}
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

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue
		idx_c, ok_c := pool_resolve_index(
			view.pool_c,
			entity,
			curr_idx,
			view.lead_pool == view.pool_c,
		)
		if !ok_c do continue
		idx_d, ok_d := pool_resolve_index(
			view.pool_d,
			entity,
			curr_idx,
			view.lead_pool == view.pool_d,
		)
		if !ok_d do continue
		idx_e, ok_e := pool_resolve_index(
			view.pool_e,
			entity,
			curr_idx,
			view.lead_pool == view.pool_e,
		)
		if !ok_e do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		c = pool_component_ptr(view.pool_c, idx_c, C)
		d = pool_component_ptr(view.pool_d, idx_d, D)
		e = pool_component_ptr(view.pool_e, idx_e, E)
		return entity, a, b, c, d, e, true
	}
	return {}, nil, nil, nil, nil, nil, false
}


// ---------------------------------------------------------
// VIEW 6
// ---------------------------------------------------------

View6 :: struct($A: typeid, $B: typeid, $C: typeid, $D: typeid, $E: typeid, $F: typeid) {
	pool_a, pool_b, pool_c, pool_d, pool_e, pool_f: ^Component_Pool,
	lead_pool:                                      ^Component_Pool,
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
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	pc := world._component_pools[C]
	pd := world._component_pools[D]
	pe := world._component_pools[E]
	pf := world._component_pools[F]
	return View6(A, B, C, D, E, F) {
		pool_a = pa,
		pool_b = pb,
		pool_c = pc,
		pool_d = pd,
		pool_e = pe,
		pool_f = pf,
		lead_pool = find_lead_pool({pa, pb, pc, pd, pe, pf}),
		index = 0,
	}
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

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue
		idx_c, ok_c := pool_resolve_index(
			view.pool_c,
			entity,
			curr_idx,
			view.lead_pool == view.pool_c,
		)
		if !ok_c do continue
		idx_d, ok_d := pool_resolve_index(
			view.pool_d,
			entity,
			curr_idx,
			view.lead_pool == view.pool_d,
		)
		if !ok_d do continue
		idx_e, ok_e := pool_resolve_index(
			view.pool_e,
			entity,
			curr_idx,
			view.lead_pool == view.pool_e,
		)
		if !ok_e do continue
		idx_f, ok_f := pool_resolve_index(
			view.pool_f,
			entity,
			curr_idx,
			view.lead_pool == view.pool_f,
		)
		if !ok_f do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		c = pool_component_ptr(view.pool_c, idx_c, C)
		d = pool_component_ptr(view.pool_d, idx_d, D)
		e = pool_component_ptr(view.pool_e, idx_e, E)
		f = pool_component_ptr(view.pool_f, idx_f, F)
		return entity, a, b, c, d, e, f, true
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
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	pc := world._component_pools[C]
	pd := world._component_pools[D]
	pe := world._component_pools[E]
	pf := world._component_pools[F]
	pg := world._component_pools[G]
	return View7(A, B, C, D, E, F, G) {
		pool_a = pa,
		pool_b = pb,
		pool_c = pc,
		pool_d = pd,
		pool_e = pe,
		pool_f = pf,
		pool_g = pg,
		lead_pool = find_lead_pool({pa, pb, pc, pd, pe, pf, pg}),
		index = 0,
	}
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

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue
		idx_c, ok_c := pool_resolve_index(
			view.pool_c,
			entity,
			curr_idx,
			view.lead_pool == view.pool_c,
		)
		if !ok_c do continue
		idx_d, ok_d := pool_resolve_index(
			view.pool_d,
			entity,
			curr_idx,
			view.lead_pool == view.pool_d,
		)
		if !ok_d do continue
		idx_e, ok_e := pool_resolve_index(
			view.pool_e,
			entity,
			curr_idx,
			view.lead_pool == view.pool_e,
		)
		if !ok_e do continue
		idx_f, ok_f := pool_resolve_index(
			view.pool_f,
			entity,
			curr_idx,
			view.lead_pool == view.pool_f,
		)
		if !ok_f do continue
		idx_g, ok_g := pool_resolve_index(
			view.pool_g,
			entity,
			curr_idx,
			view.lead_pool == view.pool_g,
		)
		if !ok_g do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		c = pool_component_ptr(view.pool_c, idx_c, C)
		d = pool_component_ptr(view.pool_d, idx_d, D)
		e = pool_component_ptr(view.pool_e, idx_e, E)
		f = pool_component_ptr(view.pool_f, idx_f, F)
		g = pool_component_ptr(view.pool_g, idx_g, G)
		return entity, a, b, c, d, e, f, g, true
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
	pa := world._component_pools[A]
	pb := world._component_pools[B]
	pc := world._component_pools[C]
	pd := world._component_pools[D]
	pe := world._component_pools[E]
	pf := world._component_pools[F]
	pg := world._component_pools[G]
	ph := world._component_pools[H]
	return View8(A, B, C, D, E, F, G, H) {
		pool_a = pa,
		pool_b = pb,
		pool_c = pc,
		pool_d = pd,
		pool_e = pe,
		pool_f = pf,
		pool_g = pg,
		pool_h = ph,
		lead_pool = find_lead_pool({pa, pb, pc, pd, pe, pf, pg, ph}),
		index = 0,
	}
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

		idx_a, ok_a := pool_resolve_index(
			view.pool_a,
			entity,
			curr_idx,
			view.lead_pool == view.pool_a,
		)
		if !ok_a do continue
		idx_b, ok_b := pool_resolve_index(
			view.pool_b,
			entity,
			curr_idx,
			view.lead_pool == view.pool_b,
		)
		if !ok_b do continue
		idx_c, ok_c := pool_resolve_index(
			view.pool_c,
			entity,
			curr_idx,
			view.lead_pool == view.pool_c,
		)
		if !ok_c do continue
		idx_d, ok_d := pool_resolve_index(
			view.pool_d,
			entity,
			curr_idx,
			view.lead_pool == view.pool_d,
		)
		if !ok_d do continue
		idx_e, ok_e := pool_resolve_index(
			view.pool_e,
			entity,
			curr_idx,
			view.lead_pool == view.pool_e,
		)
		if !ok_e do continue
		idx_f, ok_f := pool_resolve_index(
			view.pool_f,
			entity,
			curr_idx,
			view.lead_pool == view.pool_f,
		)
		if !ok_f do continue
		idx_g, ok_g := pool_resolve_index(
			view.pool_g,
			entity,
			curr_idx,
			view.lead_pool == view.pool_g,
		)
		if !ok_g do continue
		idx_h, ok_h := pool_resolve_index(
			view.pool_h,
			entity,
			curr_idx,
			view.lead_pool == view.pool_h,
		)
		if !ok_h do continue

		a = pool_component_ptr(view.pool_a, idx_a, A)
		b = pool_component_ptr(view.pool_b, idx_b, B)
		c = pool_component_ptr(view.pool_c, idx_c, C)
		d = pool_component_ptr(view.pool_d, idx_d, D)
		e = pool_component_ptr(view.pool_e, idx_e, E)
		f = pool_component_ptr(view.pool_f, idx_f, F)
		g = pool_component_ptr(view.pool_g, idx_g, G)
		h = pool_component_ptr(view.pool_h, idx_h, H)
		return entity, a, b, c, d, e, f, g, h, true
	}
	return {}, nil, nil, nil, nil, nil, nil, nil, nil, false
}
