extends "res://tests/TestCase.gd"
## The real Main scene end to end: panel signals reaching the game.

func test_startup_state() -> void:
	var main = await load_main()
	check_eq(main.panel.points_status_label.text, "White: 0/20   Black: 0/20", "points label")
	check_eq(main.panel.round_option.item_count, 2, "normal and boss round types")
	check_eq(main.panel.round_type(), "normal", "defaults to normal")

func test_clicking_a_piece_then_a_highlighted_square_moves_it() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	put(board, Vector2i(1, 0), KNIGHT, WHITE)
	main._on_square_selected(Vector2i(1, 0), board)
	check(not main.state.current_moves.is_empty(), "moves are highlighted")
	var target: Dictionary = main.state.current_moves[0]
	main._on_square_selected(target.square, target.board)
	check(target.board.pieces.has(target.square) and not board.pieces.has(Vector2i(1, 0)), "the knight moved")
	check(main.state.active_board == null, "selection cleared")

func test_a_rook_on_a_connecting_square_gets_moves_on_the_next_board() -> void:
	var main = await load_main()
	var conn: Dictionary = main.state.connections[0]
	var a: Board = main.state.boards[conn.a_board]
	var b: Board = main.state.boards[conn.b_board]
	put(a, conn.a_squares[0], ROOK, WHITE)
	main._on_square_selected(conn.a_squares[0], a)
	check(main.state.current_moves.any(func(m): return m.board == b), "moves on the neighbouring board")
	check(not moves_on(main.state.current_moves, b).is_empty(), "and markers there")

func test_the_side_toggle_decides_whose_pieces_the_palette_places() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	main._on_square_selected(Vector2i(0, 0), board)
	main.panel.side_check_button.button_pressed = true
	main.panel.pawn_button.pressed.emit()
	check_eq(board.pieces[Vector2i(0, 0)].side, BLACK, "black piece")
	check_eq(main.state.current_side, BLACK, "state follows the toggle")

func test_generate_zones_then_auto_place_reports_what_it_did() -> void:
	var main = await load_main()
	await new_world(main, 8, 8)
	main.panel.auto_place_white_button.pressed.emit()
	check(main.panel.auto_place_status_label.text.begins_with("Placed"), main.panel.auto_place_status_label.text)
	check(main.panel.points_status_label.text.begins_with("White: "), main.panel.points_status_label.text)

func test_changing_the_points_allocation_updates_the_label() -> void:
	var main = await load_main()
	main.panel.white_points_spin_box.value = 7
	check(main.panel.points_status_label.text.begins_with("White: 0/7"), main.panel.points_status_label.text)
