extends "res://tests/TestCase.gd"
## The twelve round bosses are the twelve legendary pieces: each is named after its piece,
## takes the field with the boss's army, and joins your roster when you win.

func _run_at(round_number: int, match_number: int, boss: int = -1) -> RunState:
	var run := RunState.new()
	run.begin()
	if boss >= 0:
		run.boss_order[round_number - 1] = boss
	run.round_number = round_number
	run.match_number = match_number
	return run

# The real game, dealt the given match of a fresh run (Round 1 unless told otherwise).
func _deal(main: Node, match_number: int, boss: int = -1, round_number: int = 1) -> RunState:
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	if boss >= 0:
		run.boss_order[round_number - 1] = boss
	run.round_number = round_number
	run.match_number = match_number
	main.run_flow.begin_match()
	return run

func _black_pieces(board_list: Array, include_king: bool = false) -> Array:
	var found: Array = []
	for board in board_list:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == BLACK and (include_king or piece.type != KING):
				found.append({ "piece": piece, "board": board, "square": square })
	return found

func _win(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()

# ---- the boss list -------------------------------------------------------------------------

func test_the_twelve_bosses_are_exactly_the_reward_pieces() -> void:
	check_eq(RunConfig.BOSSES.size(), 12, "twelve bosses")
	var unique := {}
	for type in RunConfig.BOSSES:
		unique[type] = true
		check(Piece.is_reward_only(type) and Piece.tier(type) == Piece.Tier.LEGENDARY, "%s is a legendary reward" % Piece.display_name(type))
	check_eq(unique.size(), 12, "no repeats")
	for type in PieceDefs.types():
		check_eq(RunConfig.BOSSES.has(type), Piece.is_reward_only(type), "%s: a reward piece if and only if a boss" % Piece.display_name(type))

func test_a_boss_is_named_after_its_piece() -> void:
	for type in RunConfig.BOSSES:
		var run := _run_at(3, 3, type)
		check_eq(run.boss_piece(), type, "the piece")
		check_eq(run.boss_name(), Piece.display_name(type), "the name")
		check(not run.boss_name().begins_with("Sir "), "no knights any more")
	check_eq(Piece.display_name(Piece.Type.STORM_WITCH), "Storm Witch", "two-word names read properly")

func test_only_round_bosses_have_a_piece() -> void:
	for match_number in [1, 2]:
		check_eq(_run_at(4, match_number).boss_piece(), -1, "ordinary match %d has none" % match_number)
		check_eq(RunConfig.match_setup(_run_at(4, match_number)).boss_piece, -1, "and neither does its setup")
	var arthur := _run_at(RunConfig.ROUNDS + 1, 1)
	check_eq(arthur.boss_piece(), -1, "Arthur has no legendary piece")
	check_eq(arthur.boss_name(), "Arthur", "but is still a boss")
	var boss := _run_at(4, 3)
	check_eq(RunConfig.match_setup(boss).boss_piece, boss.boss_order[3], "a round boss's setup carries its piece")

func test_every_boss_appears_once_in_a_run() -> void:
	var run := RunState.new()
	run.begin()
	var seen := {}
	for round_number in range(1, RunConfig.ROUNDS + 1):
		run.round_number = round_number
		run.match_number = 3
		seen[run.boss_piece()] = true
	check_eq(seen.size(), 12, "all twelve, once each")

# ---- the boss's army ---------------------------------------------------------------------------

func test_every_boss_takes_the_field_with_its_own_piece() -> void:
	var main = await load_main()
	for type in RunConfig.BOSSES:
		_deal(main, 3, type)
		var ours := _black_pieces(main.state.boards).filter(func(p): return p.piece.type == type)
		check_eq(ours.size(), 1, "%s fields exactly one of itself" % Piece.display_name(type))
		if not ours.is_empty():
			check_eq(ours[0].board.zone_owner.get(ours[0].square), BLACK, "%s stands in the boss's own zone" % Piece.display_name(type))

func test_the_boss_brings_a_full_army_as_well_as_its_piece() -> void:
	var main = await load_main()
	for type in RunConfig.BOSSES:
		var run := _deal(main, 3, type)
		var budget: int = RunConfig.match_setup(run).ai_budget
		var army := 0
		var count := 0
		for entry in _black_pieces(main.state.boards):
			if entry.piece.type != type:
				army += Piece.value(entry.piece.type)
				count += 1
		check(count > 0, "%s comes with other pieces, not alone" % Piece.display_name(type))
		check(army <= budget, "%s: the rest of the army (%d) stays within the budget (%d)" % [Piece.display_name(type), army, budget])
		check(army >= mini(budget, 3), "%s: and it is a real army (%d points)" % [Piece.display_name(type), army])

func test_the_points_readout_counts_the_bosss_piece() -> void:
	var main = await load_main()
	var run := _deal(main, 3, Piece.Type.DRAGON)
	var budget: int = RunConfig.match_setup(run).ai_budget
	check_eq(int(main.panel.black_points_spin_box.value), budget + Piece.value(Piece.Type.DRAGON), "the allocation shown includes the dragon")
	var ordinary := _deal(main, 2)
	check_eq(int(main.panel.black_points_spin_box.value), RunConfig.match_setup(ordinary).ai_budget, "an ordinary match shows just the budget")

func test_ordinary_matches_and_arthur_field_no_boss_pieces() -> void:
	var main = await load_main()
	for match_number in [1, 2]:
		_deal(main, match_number)
		check(_black_pieces(main.state.boards).all(func(p): return not Piece.is_reward_only(p.piece.type)), "match %d has only ordinary pieces" % match_number)
	_deal(main, 1, -1, RunConfig.ROUNDS + 1)
	check(_black_pieces(main.state.boards).all(func(p): return not Piece.is_reward_only(p.piece.type)), "Arthur brings no legendary piece yet")

func test_a_reserved_piece_comes_on_top_of_the_budget_not_out_of_it() -> void:
	var board := make_board(6, 6)
	for x in 6:
		board.zone_owner[Vector2i(x, 0)] = BLACK
		board.zone_owner[Vector2i(x, 1)] = BLACK
	put(board, Vector2i(0, 0), KING, BLACK)
	ArmyPlacer.auto_place([board], BLACK, 4, "boss", [Piece.Type.DRAGON])
	var dragons := board.pieces.values().filter(func(p): return p.type == Piece.Type.DRAGON and p.side == BLACK)
	check_eq(dragons.size(), 1, "the dragon is there")
	var others := 0
	for piece in board.pieces.values():
		if piece.side == BLACK and piece.type != KING and piece.type != Piece.Type.DRAGON:
			others += Piece.value(piece.type)
	check(others > 0 and others <= 4, "and the 4 points still buy an army: %d" % others)

func test_a_reserved_piece_is_still_placed_when_the_zone_is_nearly_full() -> void:
	var board := make_board(6, 6)
	board.zone_owner[Vector2i(0, 0)] = BLACK
	board.zone_owner[Vector2i(1, 0)] = BLACK
	board.zone_owner[Vector2i(2, 0)] = BLACK
	put(board, Vector2i(0, 0), KING, BLACK)
	ArmyPlacer.auto_place([board], BLACK, 30, "boss", [Piece.Type.HYDRA])
	check_eq(board.pieces.values().filter(func(p): return p.type == Piece.Type.HYDRA).size(), 1, "the boss piece gets a square before the army does")

func test_auto_place_without_reserved_pieces_works_as_before() -> void:
	var board := make_board(6, 6)
	for x in 6:
		board.zone_owner[Vector2i(x, 0)] = BLACK
	put(board, Vector2i(0, 0), KING, BLACK)
	var message := ArmyPlacer.auto_place([board], BLACK, 6, "normal")
	check(message.begins_with("Placed"), message)
	check(ArmyPlacer.points_used([board], BLACK) <= 6, "within the allocation")

# ---- the reward ----------------------------------------------------------------------------------

func test_winning_a_boss_match_adds_its_piece_to_your_roster() -> void:
	var main = await load_main()
	var run := _deal(main, 3, Piece.Type.DRAGON)
	var before := run.roster.size()
	_win(main)
	check_eq(run.roster.filter(func(e): return e.type == Piece.Type.DRAGON).size(), 1, "the dragon is yours")
	check_eq(run.roster.size(), before + 1, "and nothing else changed")
	check(main.result_screen.details_label.text.contains("REWARD: the Dragon joins your roster"), main.result_screen.details_label.text)
	main._refresh_view()
	check_eq(run.roster.filter(func(e): return e.type == Piece.Type.DRAGON).size(), 1, "refreshing doesn't hand it out twice")

func test_the_reward_shows_up_in_the_shop_as_a_legendary() -> void:
	var main = await load_main()
	_deal(main, 3, Piece.Type.HYDRA)
	_win(main)
	main.result_screen.continue_button.pressed.emit()
	check(main.shop_screen.visible, "the shop is open")
	var legendary_row: Node = main.shop_screen.roster_box.get_child(3)
	var buttons := legendary_row.get_children().filter(func(c): return c is Button)
	check_eq(buttons.size(), 1, "one legendary")
	check(buttons[0].text.contains("Hydra"), buttons[0].text)

func test_ordinary_wins_give_no_piece() -> void:
	var main = await load_main()
	var run := _deal(main, 1)
	_win(main)
	check(run.roster.all(func(e): return not Piece.is_reward_only(e.type)), "nothing legendary")
	check(not main.result_screen.details_label.text.contains("REWARD"), "and no reward line")

func test_beating_arthur_gives_no_legendary() -> void:
	var main = await load_main()
	var run := _deal(main, 1, -1, RunConfig.ROUNDS + 1)
	_win(main)
	check(run.roster.all(func(e): return not Piece.is_reward_only(e.type)), "Arthur drops nothing yet")

func test_losing_a_boss_match_gives_nothing() -> void:
	var main = await load_main()
	var run := _deal(main, 3, Piece.Type.LICH)
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "loss"
	current.result_reason = "Test"
	main._refresh_view()
	check(run.roster.all(func(e): return e.type != Piece.Type.LICH), "no consolation prize")

func test_a_reward_piece_can_be_deployed_next_match() -> void:
	var main = await load_main()
	var run := _deal(main, 3, Piece.Type.EMPRESS)
	_win(main)
	main.result_screen.continue_button.pressed.emit()
	main.state.run.allocated_points = 40
	main.shop_screen.leave_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	var deployed := 0
	for board in main.state.boards:
		deployed += board.pieces.values().filter(func(p): return p.side == WHITE and p.type == Piece.Type.EMPRESS).size()
	check_eq(deployed, 1, "the empress is on your side of the board")

# ---- every boss plays -------------------------------------------------------------------------------

# Plays `plies` half-moves: the AI for black, a random legal move for white. Any script error fails the test.
func _play(main: Node, plies: int) -> int:
	var made := 0
	var state: GameState = main.state
	for i in plies:
		var current: MatchState = state.current_match
		if not current.active:
			break
		if not current.bonus.is_empty():
			main.turn_flow.skip_bonus()
			continue
		var side: Piece.Side = current.turn_side
		var choice: Dictionary = {}
		if side == BLACK:
			choice = GreedyAI.choose_move(state, BLACK)
		else:
			var options: Array = []
			for board in state.boards:
				for square in board.pieces:
					if board.pieces[square].side == WHITE:
						for move in MoveEffects.moves_for(state, board.pieces[square], board, square):
							options.append({ "board": board, "square": square, "move": move })
			if not options.is_empty():
				choice = options.pick_random()
		if choice.is_empty():
			break
		state.active_board = choice.board
		state.active_square = choice.square
		var result := MoveController.execute(state, choice.move)
		main.turn_flow.after_move(result)
		if not state.pending_promotion.is_empty():
			main.turn_flow.promotion_chosen(QUEEN)
		made += 1
	return made

func test_every_boss_piece_can_be_played_by_the_ai_without_errors() -> void:
	var main = await load_main()
	main.turn_flow.ai_delay = 999.0                # this test drives both sides itself
	for type in RunConfig.BOSSES:
		_deal(main, 3, type)
		main.panel.auto_deploy_button.pressed.emit()
		main.panel.ready_button.pressed.emit()
		check(main.state.current_match.active, "%s: the match started" % Piece.display_name(type))
		var made := _play(main, 24)
		check(made > 0, "%s: some moves were played" % Piece.display_name(type))
