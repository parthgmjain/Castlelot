extends "res://tests/TestCase.gd"
## A whole match through the real UI and the AI.

# A random legal player move (captures preferred), made by clicking.
func _player_move(main: Node) -> bool:
	var options := []
	for entry in pieces_of(main.state.boards, WHITE):
		for m in Piece.get_legal_moves(entry.piece.type, WHITE, entry.board, entry.square):
			options.append({ "board": entry.board, "square": entry.square, "move": m })
	if options.is_empty():
		return false
	var captures := options.filter(func(o): return o.move.capture)
	var pick = (captures if not captures.is_empty() and randf() < 0.7 else options).pick_random()
	main._on_square_selected(pick.square, pick.board)
	main._on_square_selected(pick.move.square, pick.move.board)
	if main.promotion_picker.visible:
		main.promotion_picker._buttons[PawnMovement.PROMOTION_CHOICES.pick_random()].pressed.emit()
	return true

func test_start_match_without_kings_just_says_so() -> void:
	var main = await load_main()
	main.panel.start_match_button.pressed.emit()
	check(not main.state.current_match.active, "not started")
	check(main.panel.match_status_label.text.begins_with("Both sides need a king"), main.panel.match_status_label.text)
	check(not main.panel.refresh_button.disabled, "setup stays open")

func test_starting_a_match_locks_setup_and_ignores_enemy_clicks() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	await new_world(main, 8, 8, true)
	panel.moves_spin_box.value = 10
	panel.target_spin_box.value = 60
	panel.start_match_button.pressed.emit()
	var current: MatchState = main.state.current_match
	check(current.active and current.turn_side == WHITE and current.moves_left == 10, "match running")
	check(panel.refresh_button.disabled and panel.generate_zones_button.disabled and panel.start_match_button.disabled and panel.king_button.disabled, "setup buttons locked")
	check(not panel.moves_spin_box.editable, "spin boxes locked")
	check(panel.match_status_label.text.begins_with("Your turn | Moves left: 10"), panel.match_status_label.text)
	var enemy: Dictionary = pieces_of(main.state.boards, BLACK)[0]
	main._on_square_selected(enemy.square, enemy.board)
	check(main.state.active_board == null, "clicking an enemy piece selects nothing")

func test_full_matches_against_the_ai_always_end_in_a_rules_consistent_result() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	var state: GameState = main.state
	var wins := 0
	for game in 8:
		await new_world(main, randi_range(6, 12), randi_range(6, 12), true)
		panel.moves_spin_box.value = randi_range(8, 20)
		panel.target_spin_box.value = randi_range(40, 140)
		panel.start_match_button.pressed.emit()
		var current: MatchState = state.current_match
		check(current.active, "game %d started" % game)
		var rounds := 0
		while current.active and rounds < 120:
			rounds += 1
			var before := current.moves_left
			if not _player_move(main):
				break
			var waited := 0
			while current.active and current.turn_side == BLACK and waited < 30:
				await pump()
				waited += 1
			if current.active:
				check_eq(current.moves_left, before - 1, "exactly one move spent per round trip")
				check_eq(current.turn_side, WHITE, "back to the player")
		check(not current.active and current.result != "", "game %d ended" % game)
		check(not panel.refresh_button.disabled and not panel.start_match_button.disabled, "setup unlocked afterwards")
		check(panel.match_status_label.text.begins_with(current.result.to_upper()), "status shows the result")
		if current.result == "win":
			wins += 1
		match current.result_reason:
			"King captured":
				check(not king_alive(state.boards, BLACK) if current.result == "win" else not king_alive(state.boards, WHITE), "a king really was captured")
			"Target score reached":
				check(current.result == "win" and current.scores[WHITE] >= current.target_score, "target met")
			"Out of moves":
				check(current.result == "loss" and current.moves_left <= 0 and current.scores[WHITE] < current.target_score, "out of moves without the target")
			"No legal moves":
				check(current.result == "loss", "no-moves is a loss")
			_:
				check(false, "unknown reason '%s'" % current.result_reason)
	check(wins <= 8, "%d wins" % wins)

func test_the_last_move_is_highlighted() -> void:
	var main = await load_main()
	await new_world(main, 8, 8, true)
	main.panel.start_match_button.pressed.emit()
	check(_player_move(main), "player moved")
	var marked := 0
	for board in main.state.boards:
		marked += board.last_move_squares.size()
	check(marked >= 2, "from and to squares highlighted (%d)" % marked)

func test_the_ai_promotes_to_a_queen_without_opening_the_picker() -> void:
	var main = await load_main()
	await new_world(main)
	var state: GameState = main.state
	for board in state.boards:
		board.pieces.clear()
	var field := PawnMovement.distance_field(state.boards[0], BLACK)
	var pawn_board: Board = null
	var pawn_square := Vector2i.ZERO
	for board in state.boards:
		for square in field[board]:
			if field[board][square] == 1 and board.zone_owner.get(square) == null and pawn_board == null:
				pawn_board = board
				pawn_square = square
	check(pawn_board != null, "found a square one step from the white zone")
	var king_board: Board = state.boards[0]
	for square in king_board.zone_owner:
		if king_board.zone_owner[square] == WHITE:
			put(king_board, square, KING, WHITE)
			break
	put(pawn_board, pawn_square, PAWN, BLACK)
	var ai_match := MatchState.new()
	ai_match.active = true
	ai_match.turn_side = BLACK
	ai_match.moves_left = 5
	ai_match.target_score = 999
	state.current_match = ai_match
	await main._run_ai_turn()
	var black_piece: Dictionary = pieces_of(state.boards, BLACK)[0].piece
	check_eq(black_piece.type, PawnMovement.PROMOTION_CHOICES[0], "promoted to a queen")
	check(not main.promotion_picker.visible and state.pending_promotion.is_empty(), "no picker for the AI")
	check_eq(ai_match.turn_side, WHITE, "turn returns to you")

func test_your_promotion_mid_match_waits_for_the_picker_before_the_turn_ends() -> void:
	var main = await load_main()
	await new_world(main)
	var state: GameState = main.state
	for board in state.boards:
		board.pieces.clear()
	var field := PawnMovement.distance_field(state.boards[0], WHITE)
	var pawn_board: Board = null
	var pawn_square := Vector2i.ZERO
	for board in state.boards:
		for square in field[board]:
			if field[board][square] == 1 and board.zone_owner.get(square) == null and pawn_board == null:
				pawn_board = board
				pawn_square = square
	put(pawn_board, pawn_square, PAWN, WHITE)
	var king_board: Board = state.boards[0]
	for square in king_board.zone_owner:
		if king_board.zone_owner[square] == BLACK:
			put(king_board, square, KING, BLACK)
			break
	var current := MatchState.new()
	current.active = true
	current.turn_side = WHITE
	current.moves_left = 5
	current.target_score = 999
	state.current_match = current
	main._on_square_selected(pawn_square, pawn_board)
	check(not state.current_moves.is_empty(), "the pawn has its step")
	var destination: Dictionary = state.current_moves[0]
	main._on_square_selected(destination.square, destination.board)
	check(main.promotion_picker.visible and current.moves_left == 5 and current.turn_side == WHITE, "the turn is not over yet")
	main.promotion_picker._buttons[KNIGHT].pressed.emit()
	check_eq(destination.board.pieces[destination.square].type, KNIGHT, "promoted to the chosen piece")
	check_eq(current.moves_left, 4, "now the move is spent")
