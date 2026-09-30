extends "res://tests/TestCase.gd"
## Arthur (round ROUNDS + 1, the final boss): 4 guaranteed random legendaries, a doubled
## effective army budget (his pieces cost half against it), and half score value for capturing
## any of his pieces.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

func _black_pieces(boards: Array) -> Array:
	var found: Array = []
	for board in boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == BLACK and piece.type != KING:
				found.append({ "piece": piece, "board": board, "square": square })
	return found

func _deal_arthur(main: Node) -> RunState:
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	run.round_number = RunConfig.ROUNDS + 1
	run.match_number = 1
	main.run_flow.begin_match()
	return run

# ---- the four guaranteed legendaries -----------------------------------------------------------

func test_arthur_always_fields_exactly_four_distinct_legendaries() -> void:
	var main = await load_main()
	for trial in 10:
		_deal_arthur(main)
		var legendaries := _black_pieces(main.state.boards).filter(func(p): return Piece.is_reward_only(p.piece.type)).map(func(p): return p.piece.type)
		var unique := {}
		for t in legendaries:
			unique[t] = true
		check_eq(unique.size(), RunConfig.ARTHUR_LEGENDARY_COUNT, "trial %d: four distinct legendaries" % trial)
		check_eq(legendaries.size(), RunConfig.ARTHUR_LEGENDARY_COUNT, "no duplicates among them")
		for t in legendaries:
			check(RunConfig.BOSSES.has(t), "%s is one of the twelve boss legendaries" % Piece.display_name(t))

func test_the_four_legendaries_vary_between_fights() -> void:
	var main = await load_main()
	var seen := {}
	for trial in 15:
		_deal_arthur(main)
		var legendaries := _black_pieces(main.state.boards).filter(func(p): return Piece.is_reward_only(p.piece.type)).map(func(p): return p.piece.type)
		legendaries.sort()
		seen[str(legendaries)] = true
	check(seen.size() > 1, "different sets of four turn up across fights")

func test_ordinary_boss_matches_still_get_only_their_own_one_legendary() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	run.round_number = 3
	run.match_number = 3
	run.boss_order[2] = Piece.Type.DRAGON
	main.run_flow.begin_match()
	var legendaries := _black_pieces(main.state.boards).filter(func(p): return Piece.is_reward_only(p.piece.type)).map(func(p): return p.piece.type)
	check_eq(legendaries, [Piece.Type.DRAGON], "still just the one boss piece, not four")

# ---- doubled effective budget ---------------------------------------------------------------

func test_arthurs_budget_matches_an_ordinary_bosss_now_they_share_the_half_cost_rule() -> void:
	# Arthur's own extra difficulty is the 4 legendaries and the score-halving, not a bigger
	# budget than a regular boss any more - both get BOSS_HALF_COST_MULTIPLIER the same way, so
	# the only difference left between them is the one extra match's worth of natural growth.
	var normal := RunState.new()
	normal.begin()
	normal.round_number = RunConfig.ROUNDS
	normal.match_number = 3
	var boss_budget: int = RunConfig.match_setup(normal).ai_budget

	var arthur_run := RunState.new()
	arthur_run.begin()
	arthur_run.round_number = RunConfig.ROUNDS + 1
	arthur_run.match_number = 1
	var arthur_budget: int = RunConfig.match_setup(arthur_run).ai_budget
	check(absi(arthur_budget - boss_budget) <= 2, "close, not double any more: %d vs %d" % [arthur_budget, boss_budget])

func test_arthur_fields_noticeably_more_material_than_the_round_before() -> void:
	var main = await load_main()
	var last_round_material := 0
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	run.round_number = RunConfig.ROUNDS
	run.match_number = 3
	main.run_flow.begin_match()
	for entry in _black_pieces(main.state.boards):
		last_round_material += Piece.value(entry.piece.type)
	var arthur_material := 0
	_deal_arthur(main)
	for entry in _black_pieces(main.state.boards):
		arthur_material += Piece.value(entry.piece.type)
	check(arthur_material > last_round_material, "arthur %d > previous boss %d" % [arthur_material, last_round_material])

# ---- half score value -------------------------------------------------------------------------

func test_arthurs_pieces_are_flagged_half_value() -> void:
	var main = await load_main()
	_deal_arthur(main)
	for entry in _black_pieces(main.state.boards):
		check_eq(entry.piece.get("score_multiplier", 1.0), RunConfig.ARTHUR_SCORE_MULTIPLIER, "%s is flagged half value" % Piece.display_name(entry.piece.type))

func test_capturing_one_of_arthurs_pieces_scores_half() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE], [V(0, 7), ROOK, WHITE], [V(0, 4), ROOK, BLACK]])
	board.pieces[V(0, 4)]["score_multiplier"] = RunConfig.ARTHUR_SCORE_MULTIPLIER
	MatchController.start(state, 10, 999)
	state.active_board = board
	state.active_square = V(0, 7)
	MoveController.refresh(state)
	var result := MoveController.click(state, board, V(0, 4))
	MatchController.record_move(state, result)
	check_eq(state.current_match.scores[WHITE], (Piece.value(ROOK) * Scoring.CHIPS_PER_VALUE) / 2, "half the ordinary rook score")

func test_an_unflagged_piece_still_scores_in_full() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE], [V(0, 7), ROOK, WHITE], [V(0, 4), ROOK, BLACK]])
	MatchController.start(state, 10, 999)
	state.active_board = board
	state.active_square = V(0, 7)
	MoveController.refresh(state)
	var result := MoveController.click(state, board, V(0, 4))
	MatchController.record_move(state, result)
	check_eq(state.current_match.scores[WHITE], Piece.value(ROOK) * Scoring.CHIPS_PER_VALUE, "no flag, full score")

func test_prophecy_multipliers_still_stack_on_top_of_the_half_value() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE], [V(0, 7), ROOK, WHITE], [V(0, 4), ROOK, BLACK]])
	board.pieces[V(0, 4)]["score_multiplier"] = RunConfig.ARTHUR_SCORE_MULTIPLIER
	MatchController.start(state, 10, 999)
	state.run = RunState.new()
	state.run.begin()
	state.run.hand.append({ "id": "omen_of_plunder", "armed": false })
	Prophecies.play_in_match(state, 0)
	state.active_board = board
	state.active_square = V(0, 7)
	MoveController.refresh(state)
	var result := MoveController.click(state, board, V(0, 4))
	MatchController.record_move(state, result)
	check_eq(state.current_match.scores[WHITE], Piece.value(ROOK) * Scoring.CHIPS_PER_VALUE, "0.5 (Arthur) x 2 (Omen of Plunder) nets out to the ordinary value")

# ---- through a full match ----------------------------------------------------------------------

func test_playing_out_an_arthur_match_works_without_errors() -> void:
	var main = await load_main()
	var run := _deal_arthur(main)
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	check(main.state.current_match.active, "the match started")
	main.turn_flow.ai_delay = 999.0
	var made := 0
	for i in 20:
		var current: MatchState = main.state.current_match
		if not current.active:
			break
		if not current.bonus.is_empty():
			main.turn_flow.skip_bonus()
			continue
		var side: Piece.Side = current.turn_side
		var choice := GreedyAI.choose_move(main.state, side)
		if choice.is_empty():
			break
		main.state.active_board = choice.board
		main.state.active_square = choice.square
		var result := MoveController.execute(main.state, choice.move)
		main.turn_flow.after_move(result)
		if not main.state.pending_promotion.is_empty():
			main.turn_flow.promotion_chosen(QUEEN)
		made += 1
	check(made > 0, "some moves were played without a script error")
