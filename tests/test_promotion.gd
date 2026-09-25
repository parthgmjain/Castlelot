extends "res://tests/TestCase.gd"
## Pawn promotion: the rule, its point accounting, and the picker UI.

# Puts a lone pawn in `side`'s zone and clicks it along its whole route until
# it steps into the enemy zone. Returns { board, square } where it ended.
func _march(main: Node, side: Piece.Side) -> Dictionary:
	var state: GameState = main.state
	for board in state.boards:
		board.pieces.clear()
	var start_board: Board = null
	var square := Vector2i(-1, -1)
	for board in state.boards:
		for sq in board.zone_owner:
			if board.zone_owner[sq] == side and start_board == null:
				start_board = board
				square = sq
	put(start_board, square, PAWN, side)
	var board := start_board
	for step in 80:
		main._on_square_selected(square, board)
		var next = null
		for m in state.current_moves:
			if not m.capture:
				next = m
				break
		if next == null:
			return {}
		main._on_square_selected(next.square, next.board)
		board = next.board
		square = next.square
		if not state.pending_promotion.is_empty():
			return { "board": board, "square": square }
	return {}

func test_only_a_pawn_landing_in_the_enemy_zone_promotes() -> void:
	var board := make_board()
	board.zone_owner[Vector2i(0, 0)] = BLACK
	board.zone_owner[Vector2i(1, 0)] = WHITE
	var white_pawn := { "type": PAWN, "side": WHITE }
	check(PawnMovement.reached_promotion(white_pawn, board, Vector2i(0, 0)), "white pawn in the black zone")
	check(not PawnMovement.reached_promotion(white_pawn, board, Vector2i(1, 0)), "not in its own zone")
	check(not PawnMovement.reached_promotion(white_pawn, board, Vector2i(5, 5)), "not on a neutral square")
	check(PawnMovement.reached_promotion({ "type": PAWN, "side": BLACK }, board, Vector2i(1, 0)), "black pawn in the white zone")
	check(not PawnMovement.reached_promotion({ "type": KNIGHT, "side": WHITE }, board, Vector2i(0, 0)), "only pawns promote")

func test_a_promoted_pawn_keeps_counting_as_a_pawn() -> void:
	var pawn := { "type": PAWN, "side": WHITE }
	PawnMovement.promote(pawn, QUEEN)
	check_eq(pawn.type, QUEEN, "becomes the chosen piece")
	check_eq(Piece.points(pawn), 1, "still worth 1 against the budget")
	check_eq(Piece.points({ "type": QUEEN, "side": WHITE }), 9, "an ordinary queen still costs 9")

func test_promotion_through_the_move_flow_leaves_points_unchanged() -> void:
	var board := make_board()
	var state := make_state(board)
	for x in 8:
		board.zone_owner[Vector2i(x, 0)] = BLACK
	put(board, Vector2i(3, 1), PAWN, WHITE)
	put(board, Vector2i(6, 6), KNIGHT, WHITE)
	check_eq(ArmyPlacer.points_used(state.boards, WHITE), 4, "pawn 1 + knight 3")
	MoveController.click(state, board, Vector2i(3, 1))
	check_eq(state.current_moves.size(), 1, "one step forward")
	MoveController.click(state, board, Vector2i(3, 0))
	check(not state.pending_promotion.is_empty(), "promotion is pending after the step")
	PawnMovement.promote(state.pending_promotion.piece, QUEEN)
	check_eq(ArmyPlacer.points_used(state.boards, WHITE), 4, "not 12")
	MoveController.click(state, board, Vector2i(3, 0))
	check(state.current_moves.size() > 10, "it now moves like a queen")

func test_promoted_piece_counts_one_for_placement_and_refunds_one() -> void:
	var board := make_board()
	var state := make_state(board)
	put(board, Vector2i(3, 0), PAWN, WHITE)
	put(board, Vector2i(6, 6), KNIGHT, WHITE)
	PawnMovement.promote(board.pieces[Vector2i(3, 0)], QUEEN)
	state.active_board = board
	state.active_square = Vector2i(2, 5)
	ArmyPlacer.place(state, PAWN, 4)
	check(not board.pieces.has(Vector2i(2, 5)), "4 + 1 exceeds a 4 budget")
	state.active_square = Vector2i(3, 0)
	ArmyPlacer.remove(state)
	check_eq(ArmyPlacer.points_used(state.boards, WHITE), 3, "removing the promoted queen refunds 1, not 9")

func test_capturing_into_the_zone_promotes_and_black_promotes_in_the_white_zone() -> void:
	var board := make_board()
	var state := make_state(board)
	for x in 8:
		board.zone_owner[Vector2i(x, 0)] = BLACK
		board.zone_owner[Vector2i(x, 7)] = WHITE
	put(board, Vector2i(3, 1), PAWN, WHITE)
	put(board, Vector2i(4, 0), ROOK, BLACK)
	put(board, Vector2i(3, 6), PAWN, BLACK)
	MoveController.click(state, board, Vector2i(3, 1))
	MoveController.click(state, board, Vector2i(4, 0))
	check(state.pending_promotion.get("piece") == board.pieces[Vector2i(4, 0)], "capturing into the zone is pending promotion")
	state.pending_promotion = {}
	MoveController.click(state, board, Vector2i(3, 6))
	MoveController.click(state, board, Vector2i(3, 7))
	check(state.pending_promotion.get("piece") == board.pieces[Vector2i(3, 7)], "black pawn in the white zone")

func test_no_zones_means_no_promotion() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(3, 1), PAWN, WHITE]])
	MoveController.click(state, board, Vector2i(3, 1))
	MoveController.click(state, board, Vector2i(3, 0))
	check(state.pending_promotion.is_empty(), "nothing pending")
	check_eq(board.pieces[Vector2i(3, 0)].type, PAWN, "still a pawn on the far edge")

# ---- the picker ---------------------------------------------------------------

func test_picker_starts_hidden_with_four_choices_and_a_full_screen_backdrop() -> void:
	var main = await load_main()
	var picker: PromotionPicker = main.promotion_picker
	check(not picker.visible, "hidden at start")
	check_eq(picker.buttons_row.get_child_count(), 4, "queen, rook, bishop, knight")
	check_eq(picker.mouse_filter, Control.MOUSE_FILTER_STOP, "swallows clicks")
	check(picker.size.is_equal_approx(Vector2(main.get_tree().root.get_visible_rect().size)), "covers the whole viewport")

func test_entering_the_zone_opens_the_picker_and_the_pawn_waits_as_a_pawn() -> void:
	var main = await load_main()
	await new_world(main)
	var spot := _march(main, WHITE)
	var picker: PromotionPicker = main.promotion_picker
	check(picker.visible, "picker is open")
	check(not spot.is_empty(), "the pawn reached the zone")
	check_eq(spot.board.pieces[spot.square].type, PAWN, "still a pawn until you choose")
	var texts := picker.buttons_row.get_children().map(func(c): return c.text)
	check(texts[0].contains(Piece.symbol(QUEEN, WHITE)) and texts[3].contains(Piece.symbol(KNIGHT, WHITE)), "white glyphs: %s" % str(texts))

func test_open_picker_blocks_clicks_and_closed_picker_does_not() -> void:
	var main = await load_main()
	await new_world(main)
	var picker: PromotionPicker = main.promotion_picker
	var board: Board = main.state.boards[0]
	var square := Vector2i(board.grid_width - 1, board.grid_height - 1)
	var position := square_position(board, square)
	picker.show()
	board.selected_square = Vector2i(-1, -1)
	click_at(position)
	check_eq(board.selected_square, Vector2i(-1, -1), "blocked while open")
	picker.hide()
	click_at(position)
	check_eq(board.selected_square, square, "the same click works once closed")

func test_each_choice_promotes_closes_the_picker_and_keeps_one_point() -> void:
	var main = await load_main()
	var picker: PromotionPicker = main.promotion_picker
	for type in PawnMovement.PROMOTION_CHOICES:
		await new_world(main)
		var spot := _march(main, WHITE)
		check(picker.visible, "picker open for %s" % Piece.Type.find_key(type))
		picker._buttons[type].pressed.emit()
		var promoted: Dictionary = spot.board.pieces[spot.square]
		check(promoted.type == type and promoted.side == WHITE, "promoted to the chosen piece")
		check(not picker.visible and main.state.pending_promotion.is_empty(), "picker closed")
		check_eq(Piece.points(promoted), 1, "still 1 point")
		check(main.panel.points_status_label.text.begins_with("White: 1/"), "label shows 1")
		main._on_square_selected(spot.square, spot.board)
		check_eq(main.state.current_moves.size(), Piece.get_legal_moves(type, WHITE, spot.board, spot.square).size(), "moves like a %s" % Piece.Type.find_key(type))

func test_black_promotion_shows_black_glyphs() -> void:
	var main = await load_main()
	await new_world(main)
	var spot := _march(main, BLACK)
	var picker: PromotionPicker = main.promotion_picker
	check(picker.visible, "picker open")
	check(picker.buttons_row.get_child(0).text.contains(Piece.symbol(QUEEN, BLACK)), "black queen glyph")
	picker._buttons[ROOK].pressed.emit()
	check(spot.board.pieces[spot.square].type == ROOK and spot.board.pieces[spot.square].side == BLACK, "black rook")

func test_refreshing_boards_clears_a_pending_promotion() -> void:
	var main = await load_main()
	await new_world(main)
	_march(main, WHITE)
	check(main.promotion_picker.visible, "pending")
	main.panel.refresh_button.pressed.emit()
	check(not main.promotion_picker.visible and main.state.pending_promotion.is_empty(), "cleared and hidden")

func test_without_zones_no_picker_appears() -> void:
	var main = await load_main()
	main.panel.refresh_button.pressed.emit()
	await pump()
	var board: Board = main.state.boards[0]
	put(board, Vector2i(0, 1), PAWN, WHITE)
	main._on_square_selected(Vector2i(0, 1), board)
	main._on_square_selected(Vector2i(0, 0), board)
	check(not main.promotion_picker.visible, "no picker")
	check_eq(board.pieces[Vector2i(0, 0)].type, PAWN, "stays a pawn")
