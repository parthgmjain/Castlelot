extends "res://tests/TestCase.gd"
## Difficulty's numeric effects: AI budget/target scaling (RunConfig.match_setup), gold
## income (Payout, via RunFlow), shop prices (Shop, via Difficulty.price_multiplier), the
## AI's extra-piece unlock schedule shifting (ArmyPlacer/PieceSelector), and Easy's
## Guardian-style one-time retry. Normal must reproduce the old unconditional numbers
## exactly (every Difficulty multiplier is 1.0/0 there) - see test_normal_is_neutral.
## The picker UI itself and non-numeric plumbing (RunState.difficulty storage/defaults,
## carrying difficulty through a restart) are covered in tests/test_banners.gd instead.

## Same minimal harness as test_banners.gd's _start_with_banners, but starting the run
## directly through RunFlow (no need to drive the three-step picker UI for these tests).
func _start(difficulty: Difficulty.Level) -> Node:
	var main = await load_main()
	main.run_flow.start_run([Banners.Id.WHITE], null, difficulty)
	return main

func _ready_up(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func _force_result(main: Node, result: String) -> void:
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = result
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()

func _setup_at(level: Difficulty.Level, round_number: int, match_number: int) -> Dictionary:
	var run := RunState.new()
	run.begin([], null, level)
	run.round_number = round_number
	run.match_number = match_number
	return RunConfig.match_setup(run)

# ---- match_setup: AI budget, boss multiplier, target -------------------------------------------

func test_normal_is_neutral() -> void:
	for level in [Difficulty.Level.NORMAL]:
		check_eq(Difficulty.ai_budget_multiplier(level), 1.0, "ai budget x1")
		check_eq(Difficulty.boss_multiplier(level), 1.0, "boss x1")
		check_eq(Difficulty.target_multiplier(level), 1.0, "target x1")
		check_eq(Difficulty.gold_multiplier(level), 1.0, "gold x1")
		check_eq(Difficulty.price_multiplier(level), 1.0, "prices x1")
		check_eq(Difficulty.ai_unlock_round(level, 7), 7, "unlock round unshifted")
		check(not Difficulty.grants_retry(level), "no free retry")

func test_easier_tiers_lower_the_ai_budget_and_harder_tiers_raise_it() -> void:
	var normal := _setup_at(Difficulty.Level.NORMAL, 3, 1)
	var easy := _setup_at(Difficulty.Level.EASY, 3, 1)
	var hard := _setup_at(Difficulty.Level.HARD, 3, 1)
	var nightmare := _setup_at(Difficulty.Level.NIGHTMARE, 3, 1)
	check(easy.ai_budget < normal.ai_budget, "easy fields less")
	check(hard.ai_budget > normal.ai_budget, "hard fields more")
	check(nightmare.ai_budget > hard.ai_budget, "nightmare fields the most")

func test_easier_tiers_lower_the_target_and_harder_tiers_raise_it() -> void:
	var normal := _setup_at(Difficulty.Level.NORMAL, 3, 1)
	var easy := _setup_at(Difficulty.Level.EASY, 3, 1)
	var nightmare := _setup_at(Difficulty.Level.NIGHTMARE, 3, 1)
	check(easy.target < normal.target, "easy needs less score")
	check(nightmare.target > normal.target, "nightmare needs more")

func test_boss_matches_swing_further_than_normal_matches_at_the_same_tier() -> void:
	# The gap between a normal match's ai_budget and a boss match's should widen as
	## difficulty climbs, since Difficulty.boss_multiplier stacks on top of the always-on
	## ai_budget_multiplier only for the boss match.
	var easy_normal := _setup_at(Difficulty.Level.EASY, 3, 1)
	var easy_boss := _setup_at(Difficulty.Level.EASY, 3, 3)
	var nightmare_normal := _setup_at(Difficulty.Level.NIGHTMARE, 3, 1)
	var nightmare_boss := _setup_at(Difficulty.Level.NIGHTMARE, 3, 3)
	var easy_ratio: float = float(easy_boss.ai_budget) / easy_normal.ai_budget
	var nightmare_ratio: float = float(nightmare_boss.ai_budget) / nightmare_normal.ai_budget
	check(nightmare_ratio > easy_ratio, "nightmare's boss spike is relatively bigger than easy's")

func test_match_setup_formula_matches_difficulty_multipliers_exactly() -> void:
	var run := RunState.new()
	run.begin([], null, Difficulty.Level.HARD)
	run.round_number = 6
	run.match_number = 3     # a boss match
	var setup := RunConfig.match_setup(run)
	var index := run.matches_played()
	var expected_budget := (RunConfig.AI_BUDGET_BASE + RunConfig.AI_BUDGET_PER_MATCH * index) * Difficulty.ai_budget_multiplier(Difficulty.Level.HARD)
	expected_budget *= RunConfig.BOSS_AI_BUDGET_MULTIPLIER * RunConfig.BOSS_HALF_COST_MULTIPLIER * Difficulty.boss_multiplier(Difficulty.Level.HARD)
	check_eq(setup.ai_budget, int(round(expected_budget)), "boss ai_budget matches the formula exactly")
	var expected_target := (RunConfig.TARGET_BASE + RunConfig.TARGET_PER_MATCH * index) * RunConfig.BOSS_TARGET_MULTIPLIER * Difficulty.boss_multiplier(Difficulty.Level.HARD)
	expected_target *= Difficulty.target_multiplier(Difficulty.Level.HARD)
	check_eq(setup.target, int(round(expected_target)), "boss target matches the formula exactly")

# ---- gold income ---------------------------------------------------------------------------

func test_easy_pays_more_gold_and_hard_pays_less_for_the_same_win() -> void:
	var easy_main = await _start(Difficulty.Level.EASY)
	_ready_up(easy_main)
	_force_result(easy_main, "win")
	var easy_gold: int = easy_main.state.run.currency

	var hard_main = await _start(Difficulty.Level.HARD)
	_ready_up(hard_main)
	_force_result(hard_main, "win")
	var hard_gold: int = hard_main.state.run.currency

	check(easy_gold > hard_gold, "easy's gold multiplier pays out more for an identical win")

func test_gold_multiplier_reaches_the_real_payout_exactly() -> void:
	var main = await _start(Difficulty.Level.NIGHTMARE)
	_ready_up(main)
	_force_result(main, "win")
	var expected := int(round((Payout.BASE + 6 * Payout.PER_LEFTOVER_MOVE) * Difficulty.gold_multiplier(Difficulty.Level.NIGHTMARE)))
	check_eq(main.state.run.currency, expected, "nightmare's gold multiplier reached the real payout")

# ---- shop prices ----------------------------------------------------------------------------

func test_easy_prices_are_cheaper_and_nightmare_prices_are_pricier() -> void:
	var normal := RunState.new()
	normal.begin([], null, Difficulty.Level.NORMAL)
	var easy := RunState.new()
	easy.begin([], null, Difficulty.Level.EASY)
	var nightmare := RunState.new()
	nightmare.begin([], null, Difficulty.Level.NIGHTMARE)

	check(Shop.points_upgrade_price(easy) < Shop.points_upgrade_price(normal), "easy: cheaper points upgrade")
	check(Shop.points_upgrade_price(nightmare) > Shop.points_upgrade_price(normal), "nightmare: pricier points upgrade")
	check(Shop.zone_upgrade_price(easy) < Shop.zone_upgrade_price(normal), "easy: cheaper zone upgrade")
	check(Shop.moves_upgrade_price(nightmare) > Shop.moves_upgrade_price(normal), "nightmare: pricier moves upgrade")

# ---- AI extra-piece unlock schedule -----------------------------------------------------------

func test_ai_unlock_round_shifts_by_tier_and_never_goes_negative() -> void:
	check_eq(Difficulty.ai_unlock_round(Difficulty.Level.HARD, 5), 6, "hard: 1 round earlier")
	check_eq(Difficulty.ai_unlock_round(Difficulty.Level.NIGHTMARE, 5), 7, "nightmare: 2 rounds earlier")
	check_eq(Difficulty.ai_unlock_round(Difficulty.Level.EASY, 5), 4, "easy: 1 round later")
	check_eq(Difficulty.ai_unlock_round(Difficulty.Level.EASY, 0), 0, "clamped, not negative")

func test_nightmare_can_field_extra_pieces_at_round_one_where_normal_cannot() -> void:
	# Common-tier extras start unlocking at PieceSelector.EXTRA_TIER_UNLOCK[COMMON].start
	# (round 2 normally); Nightmare's +2 shift makes round 1 behave like round 3, so an
	# extra piece should turn up in the AI's round-1 army at least once across many trials.
	var common_start: int = PieceSelector.EXTRA_TIER_UNLOCK[Piece.Tier.COMMON].start
	check(Difficulty.ai_unlock_round(Difficulty.Level.NIGHTMARE, 1) >= common_start, "shifted round clears the unlock threshold")

	var boards: Array = [make_board(8, 8)]
	for b in boards:
		for x in 8:
			b.zone_owner[Vector2i(x, 0)] = BLACK
	var saw_extra := false
	for trial in 25:
		ArmyPlacer.auto_place(boards, BLACK, 30, "normal", [], Difficulty.ai_unlock_round(Difficulty.Level.NIGHTMARE, 1))
		for square in boards[0].pieces:
			var piece: Dictionary = boards[0].pieces[square]
			if PieceDefs.has(piece.type):
				saw_extra = true
	check(saw_extra, "an extra piece turned up in at least one of 25 nightmare round-1 armies")

## Integration check that RunFlow.begin_match actually threads Difficulty.ai_unlock_round
## through to the AI's army (not just that the pure function above returns the right
## number) - drives a real run at round 1 through main.run_flow, same as a player would.
func test_nightmares_round_one_ai_army_really_uses_the_shifted_round_through_run_flow() -> void:
	var nightmare_main = await _start(Difficulty.Level.NIGHTMARE)
	var saw_extra := false
	for trial in 25:
		nightmare_main.run_flow.begin_match()
		for board in nightmare_main.state.boards:
			for square in board.pieces:
				var piece: Dictionary = board.pieces[square]
				if PieceDefs.has(piece.type):
					saw_extra = true
	check(saw_extra, "an extra piece turned up in at least one of 25 real nightmare round-1 armies")

	var normal_main = await _start(Difficulty.Level.NORMAL)
	var saw_extra_normal := false
	for trial in 25:
		normal_main.run_flow.begin_match()
		for board in normal_main.state.boards:
			for square in board.pieces:
				var piece: Dictionary = board.pieces[square]
				if PieceDefs.has(piece.type):
					saw_extra_normal = true
	check(not saw_extra_normal, "normal stays chess-only at round 1 through the same real flow, isolating the shift as the cause")

# ---- Easy's one-time retry --------------------------------------------------------------------

func test_easy_survives_its_first_loss_then_ends_the_run_on_the_second() -> void:
	var main = await _start(Difficulty.Level.EASY)
	var round_title: String = main.state.run.title()
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check(main.state.run.active, "the run survives")
	check(main.state.run.guardian_used, "the save is spent")
	check_eq(main.state.run.title(), round_title, "retrying the same match")

	_ready_up(main)
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check_eq(main.state.run.title(), "Round 1/12 - Match 1/3", "second loss really restarts")
	check_eq(main.state.run.difficulty, Difficulty.Level.EASY, "difficulty carries over the restart")

func test_hard_and_normal_get_no_retry() -> void:
	# A first loss with no retry available goes straight to a brand new RunState (via
	# start_run), which always begins with guardian_used == false; a real retry sets it
	# true right before continuing - so this is what actually distinguishes "restarted"
	# from "retried" (round 1's title looks the same either way).
	for level in [Difficulty.Level.NORMAL, Difficulty.Level.HARD, Difficulty.Level.NIGHTMARE]:
		var main = await _start(level)
		_force_result(main, "loss")
		main.result_screen.continue_button.pressed.emit()
		check(not main.state.run.guardian_used, "%s: first loss already restarted, no save spent" % Difficulty.display_name(level))

func test_easy_plus_guardian_banner_still_only_grants_one_retry() -> void:
	var main = await load_main()
	main.run_flow.start_run([Banners.Id.WHITE, Banners.Id.GUARDIAN], null, Difficulty.Level.EASY)
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check(main.state.run.guardian_used, "first loss spends the shared save")

	_ready_up(main)
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check_eq(main.state.run.title(), "Round 1/12 - Match 1/3", "second loss restarts - easy + guardian didn't stack into two retries")
