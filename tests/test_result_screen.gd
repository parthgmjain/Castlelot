extends "res://tests/TestCase.gd"
## The end-of-match result screen, payout, and the gold that carries between matches.

# Kings in opposite corners and a white rook on the top row, ready to take the black king in one move.
func _setup_match(main: Node, moves: int = 10, target: int = 999) -> Board:
	var board: Board = main.state.boards[0]
	board.pieces.clear()
	put(board, Vector2i(0, 7), KING, WHITE)
	put(board, Vector2i(0, 0), KING, BLACK)
	put(board, Vector2i(5, 0), ROOK, WHITE)
	main.panel.moves_spin_box.value = moves
	main.panel.target_spin_box.value = target
	main.panel.start_match_button.pressed.emit()
	return board

func _click_move(main: Node, board: Board, from: Vector2i, to: Vector2i) -> void:
	main._on_square_selected(from, board)
	main._on_square_selected(to, board)

func _win(main: Node, moves: int = 10) -> Board:
	var board := _setup_match(main, moves)
	_click_move(main, board, Vector2i(5, 0), Vector2i(0, 0))     # rook takes the king
	return board

func test_a_win_pays_out_and_shows_the_breakdown() -> void:
	var main = await load_main()
	_win(main, 10)
	var screen: ResultScreen = main.result_screen
	check(screen.visible, "result screen is open")
	check_eq(screen.title_label.text, "VICTORY", "title")
	check_eq(screen.reason_label.text, "King captured", "reason")
	var expected := Payout.BASE + 9 * Payout.PER_LEFTOVER_MOVE      # one of ten moves was used
	check(screen.details_label.text.contains("Moves left (9): +%d" % (9 * Payout.PER_LEFTOVER_MOVE)), screen.details_label.text)
	check(screen.details_label.text.contains("Total: +%d" % expected), screen.details_label.text)
	check_eq(main.state.run.currency, expected, "gold added to the wallet")
	check_eq(screen.wallet_label.text, "Gold: %d" % expected, "screen shows the new total")
	check_eq(main.panel.wallet_label.text, "Gold: %d" % expected, "panel shows it too")
	check_eq(screen.continue_button.text, "Continue", "button")

func test_reaching_the_target_score_also_pays() -> void:
	var main = await load_main()
	var board := _setup_match(main, 10, 10)
	put(board, Vector2i(5, 3), PAWN, BLACK)
	_click_move(main, board, Vector2i(5, 0), Vector2i(5, 3))          # takes the pawn: 10 points = the target
	check_eq(main.state.current_match.result_reason, "Target score reached", "reason")
	check(main.result_screen.visible, "screen open")
	check_eq(main.state.run.currency, Payout.BASE + 9 * Payout.PER_LEFTOVER_MOVE, "paid")

func test_continue_closes_the_screen_and_keeps_the_gold() -> void:
	var main = await load_main()
	_win(main)
	var gold: int = main.state.run.currency
	main.result_screen.continue_button.pressed.emit()
	check(not main.result_screen.visible, "closed")
	check_eq(main.state.run.currency, gold, "gold kept")
	check(not main.panel.refresh_button.disabled, "setup is available again")

func test_gold_carries_into_the_next_match_and_earns_interest() -> void:
	var main = await load_main()
	_win(main, 10)
	var after_first: int = main.state.run.currency
	main.result_screen.continue_pressed.emit()
	main.panel.refresh_button.pressed.emit()          # a new world; the run carries on
	await pump()
	check_eq(main.state.run.currency, after_first, "a new world doesn't touch the wallet")
	_win(main, 10)
	var interest: int = mini(after_first / Payout.INTEREST_STEP, Payout.INTEREST_CAP)
	check(interest > 0, "there is interest to earn (%d held)" % after_first)
	check_eq(main.state.run.currency, after_first + Payout.BASE + 9 * Payout.PER_LEFTOVER_MOVE + interest, "second payout includes interest on the first")
	check(main.result_screen.details_label.text.contains("Interest (%d held): +%d" % [after_first, interest]), main.result_screen.details_label.text)

func test_a_result_is_paid_only_once() -> void:
	var main = await load_main()
	_win(main)
	var gold: int = main.state.run.currency
	for i in 5:
		main._refresh_view()
	check_eq(main.state.run.currency, gold, "repeated refreshes don't pay again")

func test_a_loss_shows_defeat_and_restarting_wipes_the_gold() -> void:
	var main = await load_main()
	main.state.run.currency = 20
	var board := _setup_match(main, 1)
	_click_move(main, board, Vector2i(5, 0), Vector2i(5, 1))          # a quiet move: that was the only move
	var screen: ResultScreen = main.result_screen
	check(screen.visible, "screen open")
	check_eq(screen.title_label.text, "DEFEAT", "title")
	check_eq(screen.reason_label.text, "Out of moves", "reason")
	check(screen.details_label.text.contains("Your run is over."), screen.details_label.text)
	check_eq(screen.wallet_label.text, "Gold lost: 20", "shows what was lost")
	check_eq(main.state.run.currency, 20, "nothing paid, nothing taken until you restart")
	check_eq(screen.continue_button.text, "Restart Run", "button")
	screen.continue_button.pressed.emit()
	check_eq(main.state.run.currency, 0, "restart wipes the wallet")
	check_eq(main.panel.wallet_label.text, "Gold: 0", "panel shows 0")
	check(not screen.visible, "closed")

func test_the_screen_blocks_clicks_until_you_continue() -> void:
	var main = await load_main()
	var board := _win(main)
	var square := Vector2i(7, 7)
	var position := square_position(board, square)
	board.selected_square = Vector2i(-1, -1)
	click_at(position)
	check_eq(board.selected_square, Vector2i(-1, -1), "blocked while the result is showing")
	main.result_screen.continue_button.pressed.emit()
	click_at(position)
	check_eq(board.selected_square, square, "clicks work again afterwards")

func test_regenerating_the_boards_hides_the_screen_but_keeps_the_run() -> void:
	var main = await load_main()
	_win(main)
	var gold: int = main.state.run.currency
	main.panel.refresh_button.pressed.emit()
	await pump()
	check(not main.result_screen.visible, "hidden")
	check_eq(main.state.run.currency, gold, "gold kept")
	check(not main.state.current_match.active and main.state.current_match.result == "", "a fresh, idle match")

func test_the_ai_taking_your_king_is_a_loss_with_no_payout() -> void:
	var main = await load_main()
	main.state.run.currency = 8
	var board := _setup_match(main, 10)
	board.pieces.erase(Vector2i(5, 0))
	put(board, Vector2i(0, 5), ROOK, BLACK)              # lined up on the white king at (0,7)
	put(board, Vector2i(7, 3), ROOK, WHITE)
	_click_move(main, board, Vector2i(7, 3), Vector2i(7, 4))          # a quiet white move that ignores the threat
	await pump(4)
	var current: MatchState = main.state.current_match
	check_eq(current.result, "loss", "the AI took the king")
	check_eq(current.result_reason, "King captured", "reason")
	check(main.result_screen.visible and main.result_screen.title_label.text == "DEFEAT", "defeat screen")
	check_eq(main.state.run.currency, 8, "no payout on a loss")
