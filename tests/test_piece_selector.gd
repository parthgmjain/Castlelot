extends "res://tests/TestCase.gd"
## The weighted-random-with-decay army buyer.

func _cost(picks: Array) -> int:
	var total := 0
	for p in picks:
		total += Piece.value(p)
	return total

func _rng(seed_value: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_probabilities_renormalize_to_one_over_any_subset() -> void:
	var weights := PieceSelector.working_weights("normal")
	for subset in [[PAWN], [PAWN, KNIGHT], weights.keys()]:
		var sum := 0.0
		for p in PieceSelector.normalized(weights, subset).values():
			sum += p
		check(absf(sum - 1.0) < 0.0001, "subset %s sums to 1" % str(subset))

func test_budget_supply_and_king_rules_hold_and_it_spends_until_nothing_fits() -> void:
	var rng := _rng()
	for trial in 300:
		var budget := rng.randi_range(0, 60)
		var picks := PieceSelector.select_army(budget, "normal", rng)
		check(_cost(picks) <= budget, "never overspends")
		check(not picks.has(KING), "never buys a king")
		var counts := {}
		for p in picks:
			counts[p] = counts.get(p, 0) + 1
		for t in counts:
			check(counts[t] <= PieceSelector.SUPPLY_LIMITS[t], "supply limit")
		var leftover := budget - _cost(picks)
		for t in PieceSelector.SUPPLY_LIMITS:
			if counts.get(t, 0) < PieceSelector.SUPPLY_LIMITS[t]:
				check(Piece.value(t) > leftover, "it only stops when nothing affordable remains")

func test_edge_budgets() -> void:
	var rng := _rng()
	check(PieceSelector.select_army(0, "normal", rng).is_empty(), "no points, no army")
	check_eq(PieceSelector.select_army(1, "normal", rng), [PAWN], "one point buys a pawn")

func test_decay_zero_allows_each_piece_once_and_one_repeats() -> void:
	var rng := _rng()
	var flat := { QUEEN: 1.0, ROOK: 1.0, BISHOP: 1.0, KNIGHT: 1.0, PAWN: 1.0 }
	var no_decay := { QUEEN: 1.0, ROOK: 1.0, BISHOP: 1.0, KNIGHT: 1.0, PAWN: 1.0 }
	var full_decay := { QUEEN: 0.0, ROOK: 0.0, BISHOP: 0.0, KNIGHT: 0.0, PAWN: 0.0 }
	var once := PieceSelector.pick_pieces(1000, flat.duplicate(), full_decay, {}, rng)
	check_eq(once.size(), 5, "each type exactly once")
	check_eq(once.duplicate().size(), 5, "")
	var seen := {}
	for p in once:
		check(not seen.has(p), "no repeats")
		seen[p] = true
	check(PieceSelector.pick_pieces(50, flat.duplicate(), no_decay, {}, rng).size() > 5, "without decay pieces repeat")

func test_weights_reset_every_game_and_shared_config_is_never_touched() -> void:
	var rng := _rng()
	var base_before := PieceSelector.BASE_WEIGHTS.duplicate()
	PieceSelector.select_army(39, "normal", rng)
	check_eq(PieceSelector.BASE_WEIGHTS, base_before, "base weights unchanged")
	check_eq(PieceSelector.working_weights("normal"), base_before, "a new game starts from base")

func test_boss_modifiers_decay_overrides_and_budget_scaling() -> void:
	var rng := _rng()
	var boss := PieceSelector.working_weights("boss")
	check(is_equal_approx(boss[QUEEN], 5.0 * 2.5) and is_equal_approx(boss[PAWN], 45.0 * 0.5), "weights = base x modifier")
	check(is_equal_approx(PieceSelector.working_decays("boss")[QUEEN], 0.75), "boss queen decay override")
	check(is_equal_approx(PieceSelector.working_decays("boss")[ROOK], 0.5), "other decays untouched")
	check(is_equal_approx(PieceSelector.working_decays("normal")[QUEEN], 0.4), "normal keeps the base")
	check(is_equal_approx(PieceSelector.DECAY_FACTORS[QUEEN], 0.4), "the override didn't mutate the shared table")
	for trial in 100:
		check(_cost(PieceSelector.select_army(10, "boss", rng)) <= 15, "boss budget scaled x1.5")

func test_boss_rounds_field_queens_far_more_often() -> void:
	var rng := _rng()
	var normal := 0
	var boss := 0
	for trial in 1500:
		if PieceSelector.select_army(12, "normal", rng).has(QUEEN):
			normal += 1
		if PieceSelector.select_army(12, "boss", rng).has(QUEEN):
			boss += 1
	check(boss > normal * 2, "queen in army: boss %d vs normal %d" % [boss, normal])

func test_free_slots_cap_the_army_and_zero_slots_buys_nothing() -> void:
	var rng := _rng(777)
	for trial in 300:
		var budget := rng.randi_range(0, 40)
		var slots := rng.randi_range(0, 10)
		var picks := PieceSelector.select_army(budget, "normal", rng, true, slots)
		check(picks.size() <= slots and _cost(picks) <= budget and not picks.has(KING), "slots %d budget %d" % [slots, budget])
	check(PieceSelector.select_army(30, "normal", rng, true, 0).is_empty(), "zero slots")

func test_slot_pressure_is_inert_when_slots_are_plentiful() -> void:
	for budget in [5, 12, 20, 39]:
		var unlimited := PieceSelector.select_army(budget, "normal", _rng(99), true, -1)
		var roomy := PieceSelector.select_army(budget, "normal", _rng(99), true, 100)
		check_eq(unlimited, roomy, "budget %d: same picks as no slot limit" % budget)

func test_slot_pressure_spends_more_of_the_budget_when_slots_are_scarce() -> void:
	for scenario in [[20, 3], [15, 2], [9, 1], [30, 5]]:
		var rng_with := _rng(5)
		var rng_without := _rng(5)
		var with_bias := 0
		var without := 0
		for i in 1500:
			with_bias += _cost(PieceSelector.pick_pieces(scenario[0], PieceSelector.working_weights("normal"), PieceSelector.working_decays("normal"), PieceSelector.SUPPLY_LIMITS, rng_with, scenario[1], PieceSelector.SLOT_PRESSURE_STRENGTH))
			without += _cost(PieceSelector.pick_pieces(scenario[0], PieceSelector.working_weights("normal"), PieceSelector.working_decays("normal"), PieceSelector.SUPPLY_LIMITS, rng_without, scenario[1], 0.0))
		check(with_bias > without, "%d points in %d slots: %d with bias vs %d without" % [scenario[0], scenario[1], with_bias, without])

func test_slot_pressure_only_decays_the_picked_piece() -> void:
	var weights := PieceSelector.working_weights("normal")
	var decays := PieceSelector.working_decays("normal")
	var picks := PieceSelector.pick_pieces(9, weights, decays, PieceSelector.SUPPLY_LIMITS, _rng(), 1)
	var expected := PieceSelector.working_weights("normal")
	expected[picks[0]] *= decays[picks[0]]
	check_eq(weights, expected, "the bias never leaks into the decaying weights")
