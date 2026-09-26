extends "res://tests/TestCase.gd"
## The two kings/zones are guaranteed a minimum graph distance apart, and that
## minimum grows with the round - see RunConfig.ZONE_MIN_DISTANCE_START/CAP and
## ZoneController._pick_black_king.

func _distance_between_kings(boards: Array) -> int:
	var white_king: Dictionary = pieces_of(boards, WHITE)[0]
	var black_king: Dictionary = pieces_of(boards, BLACK)[0]
	var field := BoardGraph.distance_field(boards, [{ "board": white_king.board, "square": white_king.square }])
	return field[black_king.board][black_king.square]

func _min_distance_for_round(round_number: int) -> int:
	return int(round(lerp(float(RunConfig.ZONE_MIN_DISTANCE_START), float(RunConfig.ZONE_MIN_DISTANCE_CAP), RunConfig.board_growth(round_number))))

# a wide chain of boards so there's always plenty of room to satisfy any minimum this run uses
func _make_chain(count: int, size: int = 4) -> Array:
	var boards: Array = []
	for i in count:
		boards.append(make_board(size, size))
	for i in count - 1:
		var a: Board = boards[i]
		var b: Board = boards[i + 1]
		a.set_portals({ Vector2i(size - 1, 0): [{ "direction": Vector2i(1, 0), "target_board": b, "target_square": Vector2i(0, 0) }] })
		b.set_portals({ Vector2i(0, 0): [{ "direction": Vector2i(-1, 0), "target_board": a, "target_square": Vector2i(size - 1, 0) }] })
	return boards

func test_a_single_board_still_places_both_kings() -> void:
	var board := make_board(8, 8)
	ZoneController.generate([board], 1, 1, 1)
	check(king_alive([board], WHITE) and king_alive([board], BLACK), "both kings placed")
	check(_distance_between_kings([board]) >= RunConfig.ZONE_MIN_DISTANCE_START, "round 1's minimum is met when the board allows it")

func test_the_round_one_minimum_is_always_met_when_the_world_allows_it() -> void:
	var boards := _make_chain(3)
	for trial in 20:
		for b in boards:
			b.pieces.clear()
			b.zone_owner.clear()
		ZoneController.generate(boards, 1, 1, 1)
		check(_distance_between_kings(boards) >= RunConfig.ZONE_MIN_DISTANCE_START, "trial %d: round 1's minimum is honored" % trial)

func test_a_late_round_demands_more_distance_than_round_one() -> void:
	var early := _min_distance_for_round(1)
	var late := _min_distance_for_round(RunConfig.BOARD_GROWTH_FULL_ROUND)
	check_eq(early, RunConfig.ZONE_MIN_DISTANCE_START, "round 1 uses the starting minimum")
	check_eq(late, RunConfig.ZONE_MIN_DISTANCE_CAP, "the fully-grown round uses the cap")
	check(late > early, "the guarantee is genuinely stricter later")

func test_a_late_round_minimum_is_honored_on_a_big_enough_world() -> void:
	var boards := _make_chain(6)     # long enough to offer distances well past the late-round minimum
	for trial in 10:
		for b in boards:
			b.pieces.clear()
			b.zone_owner.clear()
		ZoneController.generate(boards, 1, 1, RunConfig.BOARD_GROWTH_FULL_ROUND)
		check(_distance_between_kings(boards) >= RunConfig.ZONE_MIN_DISTANCE_CAP, "trial %d: the fully-grown minimum is honored" % trial)

func test_a_tiny_board_falls_back_to_the_farthest_spot_available_instead_of_breaking() -> void:
	var board := make_board(2, 2)
	ZoneController.generate([board], 1, 1, RunConfig.BOARD_GROWTH_FULL_ROUND)     # demands 16 on a board that can offer at most 2
	check(king_alive([board], WHITE) and king_alive([board], BLACK), "both kings still placed")
	check_eq(_distance_between_kings([board]), 2, "falls back to the farthest corner even though it falls short of the guarantee")

func test_pick_black_king_never_returns_whites_own_square() -> void:
	var board := make_board(3, 3)
	for trial in 20:
		var spot := ZoneController._pick_black_king([board], board, Vector2i(0, 0), 6)
		check(not (spot.board == board and spot.square == Vector2i(0, 0)), "never doubles up on white's square")

func test_placement_varies_across_matches_instead_of_always_the_same_corner() -> void:
	var board := make_board(8, 8)
	var seen := {}
	for trial in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = trial
		var spot := ZoneController._pick_black_king([board], board, Vector2i(0, 0), RunConfig.ZONE_MIN_DISTANCE_START, rng)
		seen[spot.square] = true
	check(seen.size() > 1, "different matches land Black's king on different qualifying corners")

func test_zones_still_grow_from_wherever_the_kings_actually_land() -> void:
	var board := make_board(6, 6)
	ZoneController.generate([board], 5, 7, 1)
	check_eq(count_zone([board], WHITE), 5, "white's zone size is honored")
	check_eq(count_zone([board], BLACK), 7, "black's zone size is honored")
	var white_king: Dictionary = pieces_of([board], WHITE)[0]
	var black_king: Dictionary = pieces_of([board], BLACK)[0]
	check_eq(board.zone_owner.get(white_king.square), WHITE, "white's zone starts at its own king")
	check_eq(board.zone_owner.get(black_king.square), BLACK, "black's zone starts at its own king")

func test_a_real_run_threads_the_round_number_into_the_distance_guarantee() -> void:
	# a fully-grown round's real matches should cluster near ZONE_MIN_DISTANCE_CAP (16); if the
	# round number were never threaded through, the floor would silently stay at round 1's
	# ZONE_MIN_DISTANCE_START (6) instead, giving a wide, often-much-lower spread - 30 real matches
	# is enough to reliably tell the two apart (confirmed against both versions during development).
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	run.round_number = RunConfig.BOARD_GROWTH_FULL_ROUND
	run.match_number = 1
	var minimum_seen := 9999
	for attempt in 30:
		main.run_flow.begin_match()
		minimum_seen = mini(minimum_seen, _distance_between_kings(main.state.boards))
	check(minimum_seen > 10, "a fully-grown round's real matches ask for real separation (saw a minimum of %d across 30 matches), not just round 1's baseline" % minimum_seen)

func test_sandbox_generation_defaults_to_round_one_distance() -> void:
	var main = await load_main()
	await new_world(main, 6, 6)
	check(_distance_between_kings(main.state.boards) >= RunConfig.ZONE_MIN_DISTANCE_START or main.state.boards.size() == 1, "the sandbox (no run) still gets the baseline guarantee")
