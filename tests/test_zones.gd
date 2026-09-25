extends "res://tests/TestCase.gd"
## Zones: spiral growth, generation, spilling across boards, manual editing.

func test_spiral_offsets_form_complete_squares() -> void:
	check_eq(ZoneGenerator.spiral_offsets(1), [Vector2i(0, 0)], "one tile")
	check_eq(ZoneGenerator.spiral_offsets(0).size(), 0, "no tiles")
	for pair in [[9, 1], [25, 2]]:
		var offsets := ZoneGenerator.spiral_offsets(pair[0])
		check_eq(offsets.size(), pair[0], "count %d" % pair[0])
		for o in offsets:
			check(absi(o.x) <= pair[1] and absi(o.y) <= pair[1], "%s inside the %dx%d square" % [str(o), pair[1] * 2 + 1, pair[1] * 2 + 1])
		var unique := {}
		for o in offsets:
			unique[o] = true
		check_eq(unique.size(), pair[0], "no repeated tiles")

func test_generating_zones_places_kings_and_the_requested_sizes() -> void:
	var main = await load_main()
	main.panel.white_zone_spin_box.value = 6
	main.panel.black_zone_spin_box.value = 12
	main.panel.generate_zones_button.pressed.emit()
	var boards: Array = main.state.boards
	check_eq(count_zone(boards, WHITE), 6, "white tiles")
	check_eq(count_zone(boards, BLACK), 12, "black tiles")
	check(king_alive(boards, WHITE) and king_alive(boards, BLACK), "both kings placed")
	var white_king: Dictionary = pieces_of(boards, WHITE)[0]
	check_eq(white_king.board.zone_owner.get(white_king.square), WHITE, "white king sits in white's zone")

func test_white_and_black_zone_sizes_are_independent() -> void:
	var main = await load_main()
	main.panel.white_zone_spin_box.value = 3
	main.panel.black_zone_spin_box.value = 15
	main.panel.generate_zones_button.pressed.emit()
	check_eq(count_zone(main.state.boards, WHITE), 3, "white")
	check_eq(count_zone(main.state.boards, BLACK), 15, "black")

func test_a_zone_fills_its_board_then_spills_across_a_portal() -> void:
	var a := make_board(2, 2)
	var b := make_board(4, 4)
	a.set_portals({
		Vector2i(1, 0): [{ "direction": Vector2i(1, 0), "target_board": b, "target_square": Vector2i(0, 0) }],
		Vector2i(1, 1): [{ "direction": Vector2i(1, 0), "target_board": b, "target_square": Vector2i(0, 1) }],
	})
	b.set_portals({
		Vector2i(0, 0): [{ "direction": Vector2i(-1, 0), "target_board": a, "target_square": Vector2i(1, 0) }],
		Vector2i(0, 1): [{ "direction": Vector2i(-1, 0), "target_board": a, "target_square": Vector2i(1, 1) }],
	})
	ZoneController._grow_zone(a, Vector2i(0, 0), WHITE, 10)
	check_eq(a.zone_owner.size(), 4, "board A completely filled first")
	check_eq(b.zone_owner.size(), 6, "the remaining six spill onto board B")

func test_asking_for_more_tiles_than_exist_caps_out_quietly() -> void:
	var board := make_board(2, 2)
	ZoneController._grow_zone(board, Vector2i(0, 0), WHITE, 20)
	check_eq(board.zone_owner.size(), 4, "only the four squares that exist")

func test_a_zone_never_takes_squares_the_other_side_owns() -> void:
	var board := make_board(3, 3)
	board.zone_owner[Vector2i(1, 1)] = BLACK
	ZoneController._grow_zone(board, Vector2i(0, 0), WHITE, 9)
	check_eq(board.zone_owner[Vector2i(1, 1)], BLACK, "black's square is untouched")
	check_eq(count_zone([board], WHITE), 8, "white takes every other square")

func test_zone_rules_for_placing_pieces() -> void:
	var board := make_board()
	board.place_piece(Vector2i(0, 0), PAWN, WHITE)
	check(board.pieces.has(Vector2i(0, 0)), "unzoned squares are open to anyone")
	board.remove_piece(Vector2i(0, 0))
	board.set_zone(Vector2i(1, 1), WHITE)
	check(board.is_zone_allowed(Vector2i(1, 1), WHITE) and not board.is_zone_allowed(Vector2i(1, 1), BLACK), "a zoned square belongs to its side")
	board.place_piece(Vector2i(1, 1), PAWN, BLACK)
	check(not board.pieces.has(Vector2i(1, 1)), "black can't place in white's zone")
	board.place_piece(Vector2i(1, 1), PAWN, WHITE)
	check(board.pieces.has(Vector2i(1, 1)), "white can")
	board.clear_zone(Vector2i(1, 1))
	board.remove_piece(Vector2i(1, 1))
	board.place_piece(Vector2i(1, 1), PAWN, BLACK)
	check(board.pieces.has(Vector2i(1, 1)), "open to everyone again once cleared")

func test_resizing_a_board_wipes_its_zones_and_pieces() -> void:
	var board := make_board()
	board.zone_owner[Vector2i(0, 0)] = WHITE
	put(board, Vector2i(1, 1), PAWN, WHITE)
	board.grid_width = 5
	check(board.zone_owner.is_empty() and board.pieces.is_empty(), "cleared")

func test_zone_edit_mode_paints_and_erases_and_suspends_selection() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	main.panel.zone_edit_button.button_pressed = true
	check(main.state.zone_edit_mode, "edit mode on")
	main._on_square_selected(Vector2i(1, 1), board)
	check_eq(board.zone_owner.get(Vector2i(1, 1)), WHITE, "left click paints the current side")
	main.panel.side_check_button.button_pressed = true
	main._on_square_selected(Vector2i(2, 1), board)
	check_eq(board.zone_owner.get(Vector2i(2, 1)), BLACK, "the side toggle picks whose zone")
	main._on_square_right_clicked(Vector2i(1, 1), board)
	check(not board.zone_owner.has(Vector2i(1, 1)), "right click erases")
	check(main.state.active_board == null, "painting doesn't select")
	main.panel.zone_edit_button.button_pressed = false
	check(not main.state.zone_edit_mode, "edit mode off")
	main._on_square_selected(Vector2i(0, 0), board)
	check(main.state.active_board == board, "normal selection is back")
