extends "res://tests/TestCase.gd"
## Debug mode: control both sides, the AI never moves on its own, sandbox tools
## stay open during runs, plus the debug row's shortcuts.

func _debug(main: Node, on: bool = true) -> void:
	main.panel.debug_check.button_pressed = on

# White: king (0,7), rook (3,3).  Black: king (7,0), rook (6,3), pawn (6,6).  Match started.
func _setup_match(main: Node, moves: int = 10) -> Board:
	var board: Board = main.state.boards[0]
	board.pieces.clear()
	put(board, Vector2i(0, 7), KING, WHITE)
	put(board, Vector2i(3, 3), ROOK, WHITE)
	put(board, Vector2i(7, 0), KING, BLACK)
	put(board, Vector2i(6, 3), ROOK, BLACK)
	put(board, Vector2i(6, 6), PAWN, BLACK)
	main.panel.moves_spin_box.value = moves
	main.panel.target_spin_box.value = 999
	main.panel.start_match_button.pressed.emit()
	return board

func _click_move(main: Node, board: Board, from: Vector2i, to: Vector2i) -> void:
	main._on_square_selected(from, board)
	main._on_square_selected(to, board)

# Some legal move for `side`, wherever its pieces happen to be.
func _any_move(main: Node, side: Piece.Side) -> Dictionary:
	for entry in pieces_of(main.state.boards, side):
		var moves := Piece.get_legal_moves(entry.piece.type, side, entry.board, entry.square)
		if not moves.is_empty():
			return { "board": entry.board, "square": entry.square, "move": moves[0] }
	return {}

func _positions(boards: Array, side: Piece.Side) -> Array:
	var out := []
	for entry in pieces_of(boards, side):
		out.append("%s@%s" % [Piece.Type.find_key(entry.piece.type), str(entry.square)])
	out.sort()
	return out

func _begin_run(main: Node) -> void:
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func test_debug_mode_is_off_by_default_and_the_toggle_shows_the_tools() -> void:
	var main = await load_main()
	check(not main.state.debug_mode and not main.panel.debug_row.visible, "off at first")
	_debug(main)
	check(main.state.debug_mode and main.panel.debug_row.visible, "on shows the debug row")
	_debug(main, false)
	check(not main.state.debug_mode and not main.panel.debug_row.visible, "off hides it again")

func test_without_debug_the_ai_answers_and_the_other_side_is_locked_out() -> void:
	var main = await load_main()
	var board := _setup_match(main)
	main._on_square_selected(Vector2i(6, 3), board)
	check(main.state.active_board == null, "the AI's rook can't be selected on your turn")
	var black_before := _positions(main.state.boards, BLACK)
	_click_move(main, board, Vector2i(3, 3), Vector2i(3, 4))
	await pump(6)
	check_eq(main.state.current_match.turn_side, WHITE, "the AI answered and it's your turn again")
	check(_positions(main.state.boards, BLACK) != black_before, "black moved by itself")

func test_in_debug_the_ai_never_moves_on_its_own_and_you_play_black() -> void:
	var main = await load_main()
	var board := _setup_match(main)
	_debug(main)
	var black_before := _positions(main.state.boards, BLACK)
	_click_move(main, board, Vector2i(3, 3), Vector2i(3, 4))
	await pump(10)
	var current: MatchState = main.state.current_match
	check_eq(current.turn_side, BLACK, "it's black's turn")
	check_eq(_positions(main.state.boards, BLACK), black_before, "and black hasn't moved")
	check_eq(current.moves_left, 9, "your move was spent")
	_click_move(main, board, Vector2i(6, 3), Vector2i(6, 4))              # you play the AI's rook
	check(board.pieces.has(Vector2i(6, 4)) and not board.pieces.has(Vector2i(6, 3)), "black's rook moved")
	check_eq(current.turn_side, WHITE, "back to white")
	check_eq(current.moves_left, 9, "black's move costs you nothing")
	check_eq(current.last_mover, BLACK, "black moved last")

func test_in_debug_either_side_can_move_at_any_time() -> void:
	var main = await load_main()
	var board := _setup_match(main)
	_debug(main)
	var current: MatchState = main.state.current_match
	_click_move(main, board, Vector2i(6, 3), Vector2i(6, 4))              # black moves first, on white's turn
	check_eq(current.turn_side, WHITE, "the turn goes to the other side, so white is still up")
	check_eq(current.moves_left, 10, "nothing spent")
	_click_move(main, board, Vector2i(3, 3), Vector2i(3, 4))              # white
	check_eq(current.turn_side, BLACK, "now black's turn")
	_click_move(main, board, Vector2i(3, 4), Vector2i(3, 5))              # white again, out of turn
	check_eq(current.moves_left, 8, "both white moves were spent")
	check_eq(current.turn_side, BLACK, "and black is up next")
	main._on_square_selected(Vector2i(0, 7), board)
	check(main.state.active_board == board, "any square can be selected")

func test_in_debug_black_can_capture_score_and_take_your_king() -> void:
	var main = await load_main()
	var board := _setup_match(main)
	_debug(main)
	put(board, Vector2i(6, 1), PAWN, WHITE)
	_click_move(main, board, Vector2i(6, 3), Vector2i(6, 1))              # black rook takes a pawn
	check_eq(main.state.current_match.scores[BLACK], 10, "black scored")
	check(main.state.current_match.active, "still playing")
	board.pieces.erase(Vector2i(3, 3))
	_click_move(main, board, Vector2i(6, 1), Vector2i(0, 1))              # line the rook up on the white king's file
	_click_move(main, board, Vector2i(0, 1), Vector2i(0, 7))              # and take the king
	check_eq(main.state.current_match.result, "loss", "black took your king")
	check(main.result_screen.visible and main.result_screen.title_label.text == "DEFEAT", "defeat screen")

func test_turning_debug_off_hands_black_back_to_the_ai() -> void:
	var main = await load_main()
	var board := _setup_match(main)
	_debug(main)
	_click_move(main, board, Vector2i(3, 3), Vector2i(3, 4))
	await pump(6)
	var black_before := _positions(main.state.boards, BLACK)
	check_eq(main.state.current_match.turn_side, BLACK, "waiting on black")
	_debug(main, false)
	await pump(6)
	check_eq(main.state.current_match.turn_side, WHITE, "the AI played its turn")
	check(_positions(main.state.boards, BLACK) != black_before, "black moved")

func test_setup_tools_unlock_during_a_run_in_debug_and_lock_again_when_it_is_off() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var panel: ControlPanel = main.panel
	check(panel.refresh_button.disabled and panel.king_button.disabled and panel.start_run_button.disabled, "locked in a run")
	_debug(main)
	check(not panel.refresh_button.disabled and not panel.king_button.disabled and not panel.generate_zones_button.disabled and not panel.start_run_button.disabled, "unlocked in debug")
	check(panel.debug_check.disabled == false, "the toggle itself is never locked")
	_debug(main, false)
	check(panel.refresh_button.disabled and panel.king_button.disabled, "locked again")

func test_debug_placement_ignores_zones_and_budgets() -> void:
	var board := make_board()
	var state := make_state(board)
	board.zone_owner[Vector2i(1, 1)] = BLACK
	state.active_board = board
	state.active_square = Vector2i(1, 1)
	ArmyPlacer.place(state, QUEEN, 0)
	check(not board.pieces.has(Vector2i(1, 1)), "normally white can't put a queen in black's zone on no budget")
	state.debug_mode = true
	ArmyPlacer.place(state, QUEEN, 0)
	check(board.pieces.has(Vector2i(1, 1)) and board.pieces[Vector2i(1, 1)].side == WHITE, "debug places it anyway")

func test_in_debug_the_palette_works_mid_run() -> void:
	var main = await load_main()
	_begin_run(main)
	_debug(main)
	var enemy_zone: Dictionary = {}
	for board in main.state.boards:
		for square in board.zone_owner:
			if board.zone_owner[square] == BLACK and not board.pieces.has(square) and enemy_zone.is_empty():
				enemy_zone = { "board": board, "square": square }
	main._on_square_selected(enemy_zone.square, enemy_zone.board)
	main.panel.queen_button.pressed.emit()
	check(enemy_zone.board.pieces.has(enemy_zone.square) and enemy_zone.board.pieces[enemy_zone.square].type == QUEEN, "a queen dropped into the enemy zone mid-match")

func test_debug_deployment_lets_you_select_and_remove_pieces_but_still_deploys_when_armed() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	_debug(main)
	var state: GameState = main.state
	var placed: Dictionary = pieces_of(state.boards, WHITE, false)[0]
	main._on_square_selected(placed.square, placed.board)
	check(state.active_board == placed.board and state.active_square == placed.square, "an unarmed click selects the piece")
	main.panel.remove_button.pressed.emit()
	check(not placed.board.pieces.has(placed.square), "removed")
	check_eq(Roster.bench(state.run, state.boards).size(), 1, "it went back to the bench")
	main.panel.bench_box.get_child(0).pressed.emit()
	main._on_square_selected(placed.square, placed.board)
	check(placed.board.pieces.has(placed.square), "an armed bench piece still deploys")

func test_win_and_lose_buttons_end_the_match_and_work_while_deploying_too() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	_debug(main)
	check(main.state.deployment.active and not main.state.current_match.active, "still deploying")
	main.panel.debug_win_button.pressed.emit()                            # no need to press Start Match first
	check(main.result_screen.visible and main.result_screen.title_label.text == "VICTORY", "forced win straight from deployment")
	check_eq(main.result_screen.reason_label.text, "Debug", "reason")
	check(main.state.run.currency > 0, "and it paid out")
	main.result_screen.continue_button.pressed.emit()
	check(main.state.deployment.active, "on to the next match's deployment")
	main.panel.debug_lose_button.pressed.emit()
	check(main.result_screen.visible and main.result_screen.title_label.text == "DEFEAT", "forced loss from deployment too")
	main.result_screen.continue_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	main.panel.debug_win_button.pressed.emit()
	check(main.result_screen.visible and main.result_screen.title_label.text == "VICTORY", "and mid-match as before")

func test_real_mouse_clicks_on_the_debug_buttons_work() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	await pump(3)
	await click_control(panel.debug_check)
	check(main.state.debug_mode, "toggled on by a real click")
	await click_control(panel.start_run_button)
	check(main.state.run.active and main.state.deployment.active, "a run started, deploying")
	await click_control(panel.debug_win_button)
	check(main.result_screen.visible, "Win Match responds to a real click while deploying")

func test_debug_buttons_that_cannot_act_say_why() -> void:
	var main = await load_main()
	_debug(main)
	main.panel.debug_win_button.pressed.emit()
	check(main.panel.match_status_label.text.begins_with("DEBUG: no match to end"), main.panel.match_status_label.text)
	main.panel.debug_pass_button.pressed.emit()
	check(main.panel.match_status_label.text.begins_with("DEBUG: no match in progress"), main.panel.match_status_label.text)
	main.panel.debug_moves_spin.value = 5
	check(main.panel.match_status_label.text.begins_with("DEBUG: no match in progress"), main.panel.match_status_label.text)
	check(not main.result_screen.visible, "and nothing else happened")

func test_the_status_line_never_claims_the_ai_is_thinking_in_debug() -> void:
	var main = await load_main()
	_setup_match(main)
	var board: Board = main.state.boards[0]
	_click_move(main, board, Vector2i(3, 3), Vector2i(3, 4))              # normal mode: the AI answers
	await pump(6)
	_debug(main)
	_click_move(main, board, Vector2i(3, 4), Vector2i(3, 5))
	check(main.panel.match_status_label.text.begins_with("Black to move (debug)"), main.panel.match_status_label.text)
	check(not main.panel.match_status_label.text.contains("AI thinking"), "no 'AI thinking' while you control black")
	var black_move := _any_move(main, BLACK)
	main._on_square_selected(black_move.square, black_move.board)
	main._on_square_selected(black_move.move.square, black_move.move.board)
	check(main.panel.match_status_label.text.begins_with("White to move (debug)"), main.panel.match_status_label.text)
	_debug(main, false)
	check(main.panel.match_status_label.text.begins_with("Your turn"), "back to the normal wording: %s" % main.panel.match_status_label.text)

func test_pass_turn_flips_the_turn_without_spending_a_move() -> void:
	var main = await load_main()
	_setup_match(main)
	_debug(main)
	var current: MatchState = main.state.current_match
	main.panel.debug_pass_button.pressed.emit()
	check_eq(current.turn_side, BLACK, "white passed")
	check_eq(current.moves_left, 10, "no move spent")
	main.panel.debug_pass_button.pressed.emit()
	check_eq(current.turn_side, WHITE, "black passed")
	current.moves_left = 0
	main.panel.debug_pass_button.pressed.emit()
	check(current.result == "loss" and current.result_reason == "Out of moves", "passing with no moves left loses, as usual")

func test_go_jumps_to_any_round_and_match_and_starts_a_run_if_needed() -> void:
	var main = await load_main()
	_debug(main)
	main.panel.debug_round_spin.value = 5
	main.panel.debug_match_spin.value = 3
	main.panel.debug_go_button.pressed.emit()
	var run: RunState = main.state.run
	check(run.active and run.round_number == 5 and run.match_number == 3, "started at 5-3")
	check(main.panel.run_status_label.text.contains("Round 5/12 - Match 3/3 - BOSS: Sir "), main.panel.run_status_label.text)
	check(main.state.deployment.active, "dealt and waiting for deployment")
	main._on_debug_goto(99, 9)
	check(run.round_number == RunConfig.ROUNDS + 1 and run.match_number == 1, "out-of-range values are clamped to Arthur")
	check_eq(run.boss_name(), "Arthur", "Arthur")

func test_go_inside_a_run_keeps_your_gold_and_roster() -> void:
	var main = await load_main()
	_debug(main)
	main._on_debug_goto(1, 1)
	main.state.run.currency = 42
	main.state.run.remove_from_roster(main.state.run.roster[0].id)
	main._on_debug_goto(7, 2)
	check_eq(main.state.run.currency, 42, "gold kept")
	check_eq(main.state.run.roster.size(), 5, "roster kept")
	check_eq(main.state.run.title(), "Round 7/12 - Match 2/3", "moved")

func test_gold_and_moves_can_be_set_and_the_row_shows_live_values() -> void:
	var main = await load_main()
	_debug(main)
	_begin_run(main)
	main.panel.debug_gold_spin.value = 77
	check_eq(main.state.run.currency, 77, "gold set")
	check_eq(main.panel.wallet_label.text, "Gold: 77", "wallet updated")
	main.panel.debug_moves_spin.value = 3
	check_eq(main.state.current_match.moves_left, 3, "moves set")
	check(main.panel.match_status_label.text.contains("Moves left: 3"), main.panel.match_status_label.text)
	main.state.current_match.moves_left = 8
	main._refresh_view()
	check_eq(int(main.panel.debug_moves_spin.value), 8, "the spin box follows the match")
	check_eq(int(main.panel.debug_round_spin.value), 1, "and the round")

func test_in_debug_black_can_promote_through_the_picker() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	for x in 8:
		board.zone_owner[Vector2i(x, 7)] = WHITE
	_setup_match(main)
	_debug(main)
	put(board, Vector2i(3, 6), PAWN, BLACK)
	main._on_square_selected(Vector2i(3, 6), board)
	main._on_square_selected(Vector2i(3, 7), board)
	var picker: PromotionPicker = main.promotion_picker
	check(picker.visible, "the picker opened for black's pawn")
	check(picker.buttons_row.get_child(0).text.contains(Piece.symbol(QUEEN, BLACK)), "with black glyphs")
	picker._buttons[KNIGHT].pressed.emit()
	check(board.pieces[Vector2i(3, 7)].type == KNIGHT and board.pieces[Vector2i(3, 7)].side == BLACK, "promoted")
	check_eq(main.state.current_match.turn_side, WHITE, "and the turn passed to white")
