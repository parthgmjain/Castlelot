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
	for key in ["board_sizes", "white_zone", "black_zone", "player_budget", "ai_budget", "moves", "target", "round_type", "boss_name"]:
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
		check(setup.ai_budget <= 100 and setup.player_budget <= 100, "budgets")
		check(setup.moves >= 1 and setup.moves <= 99, "moves")
		check(setup.target >= 1 and setup.target <= 9999, "target")
		if not run.advance():
			break

func test_the_later_the_match_the_more_boards_up_to_the_cap() -> void:
	check_eq(_setup_at(1, 1).board_sizes.size(), RunConfig.BOARDS_BASE, "starts at the base")
	check(_setup_at(13, 1).board_sizes.size() <= RunConfig.BOARDS_MAX, "never above the cap")
	check(_setup_at(13, 1).board_sizes.size() >= _setup_at(1, 1).board_sizes.size(), "never fewer than at the start")
