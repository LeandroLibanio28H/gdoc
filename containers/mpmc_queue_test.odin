package containers

import "base:intrinsics"
import "core:sync"
import "core:testing"
import "core:thread"

@(test)
test_mpmc_queue_basic :: proc(t: ^testing.T) {
	q: MPMC_Queue(int)

	// Requisitar 10 irá forçar o arredondamento para próxima pot. de 2 (16)
	mpmc_queue_init(&q, 10)
	defer mpmc_queue_destroy(&q)

	testing.expect_value(t, len(q.buffer), 16)
	testing.expect_value(t, q.mask, 15)

	// Fila inicia vazia
	_, ok := mpmc_queue_dequeue(&q)
	testing.expect(t, !ok, "Dequeue on empty queue should return false")

	// Preencher até a capacidade máxima (16)
	for i in 0 ..< 16 {
		ok := mpmc_queue_enqueue(&q, i * 10)
		testing.expect(t, ok, "Enqueue should succeed")
	}

	// Inserir em fila cheia deve falhar
	ok = mpmc_queue_enqueue(&q, 999)
	testing.expect(t, !ok, "Enqueue on full queue should return false")

	// Desfileirar todos
	for i in 0 ..< 16 {
		val, ok := mpmc_queue_dequeue(&q)
		testing.expect(t, ok, "Dequeue should succeed")
		testing.expect_value(t, val, i * 10)
	}
}

@(test)
test_mpmc_queue_wrap_around :: proc(t: ^testing.T) {
	q: MPMC_Queue(int)
	mpmc_queue_init(&q, 4) // Capacidade cravada em 4
	defer mpmc_queue_destroy(&q)

	// Adiciona 3, Remove 3 (Sobra 1 slot, move os ponteiros)
	_ = mpmc_queue_enqueue(&q, 1)
	_ = mpmc_queue_enqueue(&q, 2)
	_ = mpmc_queue_enqueue(&q, 3)

	v, _ := mpmc_queue_dequeue(&q); testing.expect_value(t, v, 1)
	v, _ = mpmc_queue_dequeue(&q); testing.expect_value(t, v, 2)
	v, _ = mpmc_queue_dequeue(&q); testing.expect_value(t, v, 3)

	// Ponteiros agora estão deslocados (índice 3). Adicionar mais 4 itens para forçar travessia (wrap-around)
	testing.expect(t, mpmc_queue_enqueue(&q, 4))
	testing.expect(t, mpmc_queue_enqueue(&q, 5))
	testing.expect(t, mpmc_queue_enqueue(&q, 6))
	testing.expect(t, mpmc_queue_enqueue(&q, 7))

	// Fila deve acusar cheia corretamente, mesmo na margem do wrap-around
	testing.expect(t, !mpmc_queue_enqueue(&q, 8), "Should be full")

	// Remoção deve ser perfeitamente ordenada
	v, _ = mpmc_queue_dequeue(&q); testing.expect_value(t, v, 4)
	v, _ = mpmc_queue_dequeue(&q); testing.expect_value(t, v, 5)
	v, _ = mpmc_queue_dequeue(&q); testing.expect_value(t, v, 6)
	v, _ = mpmc_queue_dequeue(&q); testing.expect_value(t, v, 7)
}

@(test)
test_mpmc_queue_concurrent_stress :: proc(t: ^testing.T) {
	q: MPMC_Queue(int)
	mpmc_queue_init(&q, 1024)
	defer mpmc_queue_destroy(&q)

	NUM_PRODUCERS :: 4
	NUM_CONSUMERS :: 4
	ITEMS_PER_PRODUCER :: 100_000
	TOTAL_ITEMS :: NUM_PRODUCERS * ITEMS_PER_PRODUCER

	Shared_State :: struct {
		q:              ^MPMC_Queue(int),
		items_consumed: uint,
		total_sum:      u64,
		start_signal:   sync.Wait_Group,
	}

	state := Shared_State {
		q              = &q,
		items_consumed = 0,
		total_sum      = 0,
	}

	sync.wait_group_add(&state.start_signal, 1)

	producer_proc :: proc(t: ^thread.Thread) {
		state := cast(^Shared_State)t.user_args[0]
		sync.wait(&state.start_signal)

		for i in 1 ..= ITEMS_PER_PRODUCER {
			// Spin-loop até conseguir injetar
			for !mpmc_queue_enqueue(state.q, i) {
				thread.yield()
			}
		}
	}

	consumer_proc :: proc(t: ^thread.Thread) {
		state := cast(^Shared_State)t.user_args[0]
		sync.wait(&state.start_signal)

		for {
			// Sai do loop se todos os itens já foram processados globalmente
			if intrinsics.atomic_load_explicit(&state.items_consumed, .Relaxed) >= TOTAL_ITEMS {
				break
			}

			if item, ok := mpmc_queue_dequeue(state.q); ok {
				// Usa atômicos para agregar o resultado com segurança
				intrinsics.atomic_add_explicit(&state.total_sum, u64(item), .Relaxed)
				intrinsics.atomic_add_explicit(&state.items_consumed, 1, .Relaxed)
			} else {
				thread.yield()
			}
		}
	}

	// Inicializando Produtores
	producers: [NUM_PRODUCERS]^thread.Thread
	for i in 0 ..< NUM_PRODUCERS {
		producers[i] = thread.create(producer_proc)
		producers[i].user_args[0] = &state
		thread.start(producers[i])
	}

	// Inicializando Consumidores
	consumers: [NUM_CONSUMERS]^thread.Thread
	for i in 0 ..< NUM_CONSUMERS {
		consumers[i] = thread.create(consumer_proc)
		consumers[i].user_args[0] = &state
		thread.start(consumers[i])
	}

	// Dá a largada para todas as threads simultaneamente
	sync.wait_group_done(&state.start_signal)

	// Aguarda conclusão do teste de estresse
	for p in producers {thread.join(p); thread.destroy(p)}
	for c in consumers {thread.join(c); thread.destroy(c)}

	// Verificação Matemática
	// Cada produtor emitiu os números de 1 até ITEMS_PER_PRODUCER.
	// Pela fórmula da soma de Progressão Aritmética (PA): Soma = N * (N + 1) / 2
	expected_sum_per_producer := u64(ITEMS_PER_PRODUCER) * u64(ITEMS_PER_PRODUCER + 1) / 2
	expected_total_sum := expected_sum_per_producer * u64(NUM_PRODUCERS)

	testing.expect_value(t, state.items_consumed, uint(TOTAL_ITEMS))
	testing.expect_value(t, state.total_sum, expected_total_sum)
}
