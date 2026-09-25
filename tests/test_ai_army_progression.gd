extends "res://tests/TestCase.gd"
## The AI's random armies: chess pieces only in round 1, extra pieces unlocking gradually
## by tier as a run goes on. See PieceSelector.EXTRA_TIER_UNLOCK.

func _rng(seed_value: int = 4242) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _is_chess(type: Piece.Type) -> bool:
	return [QUEEN, ROOK, BISHOP, KNIGHT, PAWN].has(type)

# ---- the weight table itself ------------------------------------------------------------------

func test_with_no_round_context_only_chess_pieces_are_in_the_table() -> void:
	var weights := PieceSelector.working_weights("normal")
	for type in weights:
		check(_is_chess(type), "%s: the sandbox (-1) stays chess-only" % Piece.Type.find_key(type))

func test_round_one_is_chess_pieces_only() -> void:
	var weights := PieceSelector.working_weights("normal", 1)
	check_eq(weights.keys().size(), 5, "still just the five chess types")
	for type in weights:
		check(_is_chess(type), Piece.Type.find_key(type))

func test_legendaries_never_appear_at_any_round() -> void:
	for round_number in [1, 2, 5, 8, 12, 13, 20]:
		var weights := PieceSelector.working_weights("normal", round_number)
		for type in weights:
			check(not Piece.is_reward_only(type), "%s shouldn't be buyable at round %d" % [Piece.Type.find_key(type), round_number])
			check(type == QUEEN or Piece.tier(type) != Piece.Tier.LEGENDARY, "%s: no other legendary belongs here either" % Piece.Type.find_key(type))
	check(not PieceSelector._extra_types().has(Piece.Type.QUEEN), "the queen was never an 'extra' to begin with - it's one of the five base chess types")

func test_a_tier_is_absent_before_it_starts_and_present_once_it_does() -> void:
	var before := PieceSelector.working_weights("normal", PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.COMMON].start - 1)
	var after := PieceSelector.working_weights("normal", PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.COMMON].start)
	for type in PieceDefs.types():
		if PieceDefs.tier(type) == Piece.Tier.COMMON:
			check(not before.has(type), "%s absent the round before it starts" % Piece.Type.find_key(type))
	check(after.keys().any(func(t): return PieceDefs.has(t) and PieceDefs.tier(t) == Piece.Tier.COMMON), "at least one common extra appears once its round arrives")

func test_weight_ramps_linearly_then_holds_at_full_strength() -> void:
	var range: Dictionary = PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.UNCOMMON]
	var one_type: Piece.Type = PieceDefs.types().filter(func(t): return PieceDefs.tier(t) == Piece.Tier.UNCOMMON)[0]
	var full_weight: float = PieceSelector.EXTRA_TIER_WEIGHTS[Piece.Tier.UNCOMMON]
	check_eq(PieceSelector.working_weights("normal", range.start - 1).get(one_type, 0.0), 0.0, "nothing the round before it starts")
	check(PieceSelector.working_weights("normal", range.start)[one_type] > 0.0, "already a little unlocked right on the start round")
	var last := 0.0
	for round_number in range(int(range.start), int(range.full) + 1):
		var weight: float = PieceSelector.working_weights("normal", round_number)[one_type]
		check(weight >= last, "round %d: never dips back down (%f -> %f)" % [round_number, last, weight])
		check(is_equal_approx(weight, full_weight * PieceSelector.extras_factor(Piece.Tier.UNCOMMON, round_number)), "round %d matches its own factor" % round_number)
		last = weight
	check(is_equal_approx(last, full_weight), "full strength by the last round of the ramp")
	check(is_equal_approx(PieceSelector.working_weights("normal", range.full + 20)[one_type], full_weight), "and it stays there afterward, doesn't keep climbing")

func test_each_tier_unlocks_later_than_the_one_before_it() -> void:
	var common: Dictionary = PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.COMMON]
	var uncommon: Dictionary = PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.UNCOMMON]
	var rare: Dictionary = PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.RARE]
	check(common.start < uncommon.start and uncommon.start < rare.start, "common, then uncommon, then rare")
	check(common.start >= 2, "round 1 is untouched")

func test_working_decays_and_supply_extend_to_unlocked_extras() -> void:
	var decays := PieceSelector.working_decays("normal", 12)
	var supply := PieceSelector.working_supply(12)
	for type in PieceSelector._extra_types():
		check(decays.has(type), "%s has a decay" % Piece.Type.find_key(type))
		check_eq(decays[type], PieceSelector.EXTRA_TIER_DECAYS[PieceDefs.tier(type)], "matching its tier")
		check_eq(supply[type], PieceSelector.EXTRA_TIER_SUPPLY[PieceDefs.tier(type)], "and a supply cap")
	check(PieceSelector.working_decays("normal")[PAWN] == PieceSelector.DECAY_FACTORS[PAWN], "chess decays are untouched")

func test_shared_config_tables_are_never_mutated() -> void:
	var before := PieceSelector.EXTRA_TIER_WEIGHTS.duplicate(true)
	PieceSelector.working_weights("normal", 12)
	check_eq(PieceSelector.EXTRA_TIER_WEIGHTS, before, "reading the table for round 12 doesn't change it for round 1 next time")
	check(PieceSelector.working_weights("normal", 1).keys().size() == 5, "round 1 is still pure chess afterward")

# ---- drawing armies ----------------------------------------------------------------------------

func test_select_army_at_round_one_never_draws_an_extra_piece() -> void:
	var rng := _rng()
	for trial in 50:
		var picks := PieceSelector.select_army(rng.randi_range(10, 60), "normal", rng, true, -1, 1)
		for p in picks:
			check(_is_chess(p), "round 1: %s shouldn't be drawable" % Piece.Type.find_key(p))

func test_select_army_at_a_late_round_can_draw_extras() -> void:
	var rng := _rng(9)
	var saw_extra := false
	for trial in 200:
		var picks := PieceSelector.select_army(40, "normal", rng, true, -1, 12)
		if picks.any(func(p): return not _is_chess(p)):
			saw_extra = true
			break
	check(saw_extra, "an extra piece turns up somewhere across 200 late-round armies")

func test_select_army_never_exceeds_its_supply_cap_for_extras() -> void:
	var rng := _rng(3)
	for trial in 60:
		var picks := PieceSelector.select_army(80, "normal", rng, true, -1, 12)
		var counts := {}
		for p in picks:
			counts[p] = counts.get(p, 0) + 1
		for type in counts:
			var cap: int = PieceSelector.working_supply(12).get(type, 1 << 30)
			check(counts[type] <= cap, "%s: %d copies, cap %d" % [Piece.Type.find_key(type), counts[type], cap])

func test_the_army_still_respects_its_budget_with_extras_unlocked() -> void:
	var rng := _rng(5)
	for trial in 100:
		var budget := rng.randi_range(0, 50)
		var picks := PieceSelector.select_army(budget, "normal", rng, true, -1, 10)
		var cost := 0
		for p in picks:
			cost += Piece.value(p)
		check(cost <= budget, "never overspends even with the bigger pool")

# ---- through the real run --------------------------------------------------------------------

func _black_pieces(boards: Array) -> Array:
	var found: Array = []
	for board in boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == BLACK and piece.type != KING:
				found.append(piece.type)
	return found

func test_round_one_of_a_real_run_fields_only_chess_pieces() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	check_eq(main.state.run.round_number, 1, "round 1")
	for type in _black_pieces(main.state.boards):
		check(_is_chess(type), "%s shouldn't appear in round 1's army" % Piece.Type.find_key(type))

func test_a_late_round_of_a_real_run_can_field_extra_pieces() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	var saw_extra := false
	for round_number in range(9, RunConfig.ROUNDS + 1):
		for attempt in 6:
			run.round_number = round_number
			run.match_number = 1
			main.run_flow.begin_match()
			if _black_pieces(main.state.boards).any(func(t): return not _is_chess(t)):
				saw_extra = true
				break
		if saw_extra:
			break
	check(saw_extra, "somewhere in rounds 9-12, an extra piece is fielded")

func test_the_boss_own_piece_is_unaffected_by_the_progression() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	run.round_number = 1
	run.match_number = 3                         # a round-1 boss match
	run.boss_order[0] = Piece.Type.DRAGON
	main.run_flow.begin_match()
	check(_black_pieces(main.state.boards).has(Piece.Type.DRAGON), "the boss still fields its own legendary even in round 1")
