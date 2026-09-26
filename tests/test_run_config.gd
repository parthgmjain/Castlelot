extends "res://tests/TestCase.gd"
## The placeholder scaling table: the shape of a match setup, not its balance.

func _setup_at(round_number: int, match_number: int) -> Dictionary:
	var run := RunState.new()
	run.begin()
	run.round_number = round_number
	run.match_number = match_number
	return RunConfig.match_setup(run)

func test_a_setup_has_everything_needed_to_build_a_match() -> void:
	var setup := _setup_at(1, 1)
	for key in ["board_sizes", "white_zone", "black_zone", "ai_budget", "moves", "target", "round_type", "boss_name", "boss_piece"]:
		check(setup.has(key), "has %s" % key)

func test_boss_matches_use_the_boss_round_type_and_others_do_not() -> void:
	check_eq(_setup_at(1, 1).round_type, "normal", "match 1")
	check_eq(_setup_at(1, 2).round_type, "normal", "match 2")
	check_eq(_setup_at(1, 3).round_type, "boss", "match 3")
	check_eq(_setup_at(13, 1).round_type, "boss", "Arthur")
	check(PieceSelector.ROUND_MODIFIERS.has("boss"), "the selector knows the boss type")

func test_bosses_are_harder_than_the_match_before_them() -> void:
	for round_number in [1, 6, 12]:
		var normal := _setup_at(round_number, 2)
		var boss := _setup_at(round_number, 3)
		check(boss.target > normal.target, "round %d: boss target above the match before it" % round_number)
		check(boss.ai_budget >= normal.ai_budget, "round %d: boss army at least as big" % round_number)

func test_difficulty_never_drops_as_a_run_goes_on() -> void:
	var last_target := 0
	var last_budget := 0
	var run := RunState.new()
	run.begin()
	var boss_pairs_checked := 0
	while true:
		var setup := RunConfig.match_setup(run)
		if not run.is_boss():
			check(setup.target >= last_target, "target at %s" % run.title())
			check(setup.ai_budget >= last_budget, "budget at %s" % run.title())
			last_target = setup.target
			last_budget = setup.ai_budget
			boss_pairs_checked += 1
		if not run.advance():
			break
	check(boss_pairs_checked > 20, "walked the whole run")

func test_boards_and_values_stay_inside_the_ranges_the_ui_accepts() -> void:
	var run := RunState.new()
	run.begin()
	while true:
		var setup := RunConfig.match_setup(run)
		check(setup.board_sizes.size() >= 1 and setup.board_sizes.size() <= 5, "board count %d" % setup.board_sizes.size())
		for size in setup.board_sizes:
			check(size.x >= ControlPanel.MIN_DIM and size.x <= ControlPanel.MAX_DIM and size.y >= ControlPanel.MIN_DIM and size.y <= ControlPanel.MAX_DIM, "board size %s" % str(size))
		check(setup.white_zone >= 1 and setup.white_zone <= 50 and setup.black_zone >= 1 and setup.black_zone <= 50, "zone tiles")
		check(setup.ai_budget <= 100, "budget")
		check(setup.moves >= 1 and setup.moves <= 99, "moves")
		check(setup.target >= 1 and setup.target <= 9999, "target")
		if not run.advance():
			break

func test_the_later_the_round_the_more_boards_up_to_the_cap() -> void:
	check_eq(_setup_at(1, 1).board_sizes.size(), RunConfig.BOARD_COUNT_MIN, "starts at the minimum")
	check(_setup_at(13, 1).board_sizes.size() <= RunConfig.BOARD_COUNT_MAX, "never above the cap")
	check(_setup_at(13, 1).board_sizes.size() >= _setup_at(1, 1).board_sizes.size(), "never fewer than at the start")
	var last := RunConfig.BOARD_COUNT_MIN
	for round_number in range(1, RunConfig.ROUNDS + 2):
		var count: int = _setup_at(round_number, 1).board_sizes.size()
		check(count >= last, "round %d: never fewer boards than the round before" % round_number)
		last = count
	check_eq(last, RunConfig.BOARD_COUNT_MAX, "by the last round it actually reached the cap, not just held at the start")
	check(last > RunConfig.BOARD_COUNT_MIN, "board count genuinely grows over the run")

func test_board_sizes_grow_with_the_round_up_to_a_cap() -> void:
	var early: Array = _setup_at(1, 1).board_sizes
	var late: Array = _setup_at(RunConfig.BOARD_GROWTH_FULL_ROUND, 1).board_sizes
	var beyond: Array = _setup_at(RunConfig.ROUNDS + 1, 1).board_sizes
	for size in early:
		check(size.x >= RunConfig.BOARD_SIZE_MIN_START and size.x <= RunConfig.BOARD_SIZE_MAX_START, "round 1 starts at a proper size, not tiny: %s" % str(size))
		check(size.y >= RunConfig.BOARD_SIZE_MIN_START and size.y <= RunConfig.BOARD_SIZE_MAX_START, "round 1 starts at a proper size, not tiny: %s" % str(size))
	for size in late + beyond:
		check(size.x <= RunConfig.BOARD_SIZE_MAX_CAP and size.y <= RunConfig.BOARD_SIZE_MAX_CAP, "never bigger than the cap: %s" % str(size))
	check(RunConfig.board_growth(1) == 0.0, "no growth at round 1")
	check(RunConfig.board_growth(RunConfig.BOARD_GROWTH_FULL_ROUND) == 1.0, "fully grown by the target round")
	check(RunConfig.board_growth(RunConfig.ROUNDS + 1) == 1.0, "and Arthur stays at the cap, not beyond it")

# ---- zone size is also capped per round --------------------------------------------------------

func test_the_zone_you_can_use_is_capped_per_round_even_if_you_bought_more() -> void:
	var run := RunState.new()
	run.begin()
	run.zone_tiles = RunConfig.MAX_ZONE_TILES     # as if fully upgraded from turn one
	run.round_number = 1
	run.match_number = 1
	check_eq(RunConfig.match_setup(run).white_zone, RunConfig.PLAYER_ZONE_CAP_START, "round 1 clips it to the early cap")

func test_the_zone_cap_grows_to_the_shops_own_ceiling_by_the_target_round() -> void:
	var run := RunState.new()
	run.begin()
	run.zone_tiles = RunConfig.MAX_ZONE_TILES
	run.round_number = RunConfig.BOARD_GROWTH_FULL_ROUND
	run.match_number = 1
	check_eq(RunConfig.match_setup(run).white_zone, RunConfig.MAX_ZONE_TILES, "by the fully-grown round, the whole purchased amount is usable")

func test_an_early_zone_purchase_is_not_wasted_it_just_activates_later() -> void:
	var run := RunState.new()
	run.begin()
	run.zone_tiles = RunConfig.MAX_ZONE_TILES
	run.round_number = 3
	var early: int = RunConfig.match_setup(run).white_zone
	run.round_number = RunConfig.BOARD_GROWTH_FULL_ROUND
	var later: int = RunConfig.match_setup(run).white_zone
	check(later > early, "the same purchase gives you more usable zone once the world has grown")
	check_eq(later, RunConfig.MAX_ZONE_TILES, "and eventually all of it")

func test_round_one_boards_start_reasonably_sized_not_cramped() -> void:
	# a concrete floor, not derived from BOARD_SIZE_MIN_START itself, so a future drop back
	# toward a cramped starting size fails this test; many trials since sizes are randomized
	for trial in 50:
		for size in _setup_at(1, 1).board_sizes:
			check(size.x >= 5 and size.y >= 5, "round 1 board %s is at least 5x5" % str(size))

func test_the_zone_cap_never_shrinks_what_you_can_already_use() -> void:
	var run := RunState.new()
	run.begin()
	run.zone_tiles = RunConfig.PLAYER_ZONE_TILES   # the starting amount, well under the round-1 cap
	check_eq(RunConfig.match_setup(run).white_zone, run.zone_tiles, "an ordinary early zone isn't clipped at all")
