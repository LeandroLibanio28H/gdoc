package containers

import intrinsics "base:intrinsics"
import log "core:log"
import math "core:math"
import mem "core:mem"

// ============================================================================
// CONSTANTS & TYPES
// ============================================================================

MPMC_QUEUE_CACHE_LINE_SIZE :: 64

@(private)
MPMC_Cell :: struct($T: typeid) {
	sequence: uint,
	data:     T,
}

MPMC_Queue :: struct($T: typeid) #align (MPMC_QUEUE_CACHE_LINE_SIZE) {
	buffer:      []MPMC_Cell(T),
	mask:        uint,
	allocator:   mem.Allocator,
	_pad0:       [MPMC_QUEUE_CACHE_LINE_SIZE]u8,
	enqueue_pos: uint,
	_pad1:       [MPMC_QUEUE_CACHE_LINE_SIZE - size_of(uint)]u8,
	dequeue_pos: uint,
	_pad2:       [MPMC_QUEUE_CACHE_LINE_SIZE - size_of(uint)]u8,
}

// ============================================================================
// INITIALIZATION & LIFECYCLE
// ============================================================================

mpmc_queue_init :: proc(q: ^MPMC_Queue($T), capacity: int, allocator := context.allocator) {
	cap := max(capacity, 2)
	pow2 := math.next_power_of_two(cap)

	q.allocator = allocator
	q.mask = uint(pow2 - 1)
	q.enqueue_pos = 0
	q.dequeue_pos = 0

	err: mem.Allocator_Error
	q.buffer, err = make([]MPMC_Cell(T), pow2, allocator)
	if err != .None {
		msg := "Failed to allocate MPMC_Queue buffer (OOM)"
		log.fatal(msg)
		panic(msg)
	}

	for i in 0 ..< pow2 {
		intrinsics.atomic_store_explicit(&q.buffer[i].sequence, uint(i), .Relaxed)
	}
}

mpmc_queue_destroy :: proc(q: ^MPMC_Queue($T)) {
	delete(q.buffer, q.allocator)
	q^ = {}
}

// ============================================================================
// LOCK-FREE OPERATIONS
// ============================================================================

@(require_results)
mpmc_queue_enqueue :: proc(q: ^MPMC_Queue($T), item: T) -> bool {
	cell: ^MPMC_Cell(T)
	pos := intrinsics.atomic_load_explicit(&q.enqueue_pos, .Relaxed)

	for {
		cell = &q.buffer[pos & q.mask]
		seq := intrinsics.atomic_load_explicit(&cell.sequence, .Acquire)
		dif := int(seq - pos)

		if dif == 0 {
			if _, ok := intrinsics.atomic_compare_exchange_weak_explicit(
				&q.enqueue_pos,
				pos,
				pos + 1,
				.Relaxed,
				.Relaxed,
			); ok {
				break
			}
		} else if dif < 0 {
			return false
		} else {
			pos = intrinsics.atomic_load_explicit(&q.enqueue_pos, .Relaxed)
		}
	}

	cell.data = item
	intrinsics.atomic_store_explicit(&cell.sequence, pos + 1, .Release)
	return true
}

@(require_results)
mpmc_queue_dequeue :: proc(q: ^MPMC_Queue($T)) -> (item: T, ok: bool) {
	cell: ^MPMC_Cell(T)
	pos := intrinsics.atomic_load_explicit(&q.dequeue_pos, .Relaxed)

	for {
		cell = &q.buffer[pos & q.mask]
		seq := intrinsics.atomic_load_explicit(&cell.sequence, .Acquire)
		dif := int(seq - (pos + 1))

		if dif == 0 {
			if _, exchanged := intrinsics.atomic_compare_exchange_weak_explicit(
				&q.dequeue_pos,
				pos,
				pos + 1,
				.Relaxed,
				.Relaxed,
			); exchanged {
				break
			}
		} else if dif < 0 {
			return item, false
		} else {
			pos = intrinsics.atomic_load_explicit(&q.dequeue_pos, .Relaxed)
		}
	}

	item = cell.data
	intrinsics.atomic_store_explicit(&cell.sequence, pos + q.mask + 1, .Release)
	return item, true
}
