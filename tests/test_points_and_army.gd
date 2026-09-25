extends "res://tests/TestCase.gd"
## Point budgets for placing pieces, and the auto-place buttons.

# Selects a square cleanly (a piece left selected would treat the click as a move).
func _pick(main: Node, square: Vector2i, board: Board) -> void:
	MoveController.clear_selection(main.state)
	main._on_square_selected(square, board)

func test_king_is_free_and_over_budget_pieces_are_refused() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	var board: Board = main.state.boards[0]
	panel.white_points_spin_box.value = 4
	_pick(main, Vector2i(0, 0), board)
	panel.king_button.pressed.emit()
	check(board.pieces.has(Vector2i(0, 0)), "king placed")
	check_eq(ArmyPlacer.points_used(main.state.boards, WHITE), 0, "king costs nothing")
	_pick(main, Vector2i(1, 0), board)
	panel.rook_button.pressed.emit()
	check(not board.pieces.has(Vector2i(1, 0)), "rook (5) refused against 4 points")
	panel.knight_button.pressed.emit()
	check(board.pieces.has(Vector2i(1, 0)), "knight (3) fits")
	check(panel.points_status_label.text.begins_with("White: 3/4"), "label shows 3/4: %s" % panel.points_status_label.text)

func test_budget_is_enforced_down_to_the_last_point_and_removal_refunds() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	var board: Board = main.state.boards[0]
	panel.white_points_spin_box.value = 4
	_pick(main, Vector2i(1, 0), board)
	panel.knight_button.pressed.emit()                     # 3
	_pick(main, Vector2i(2, 0), board)
	panel.knight_button.pressed.emit()                     # would be 6
	check(not board.pieces.has(Vector2i(2, 0)), "second knight refused")
	panel.pawn_button.pressed.emit()                       # 3 + 1 = 4
	check(board.pieces.has(Vector2i(2, 0)), "the last point buys a pawn")
	check_eq(ArmyPlacer.points_used(main.state.boards, WHITE), 4, "used 4")
	panel.remove_button.pressed.emit()
	check_eq(ArmyPlacer.points_used(main.state.boards, WHITE), 3, "removal refunds")

func test_white_and_black_budgets_are_independent() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	var board: Board = main.state.boards[0]
	panel.white_points_spin_box.value = 4
	panel.black_points_spin_box.value = 9
	_pick(main, Vector2i(0, 0), board)
	panel.knight_button.pressed.emit()
	panel.side_check_button.button_pressed = true
	_pick(main, Vector2i(1, 0), board)
	panel.queen_button.pressed.emit()
	check(board.pieces.has(Vector2i(1, 0)), "black's queen fits its own 9")
	check_eq(ArmyPlacer.points_used(main.state.boards, WHITE), 3, "white unaffected")
	check_eq(ArmyPlacer.points_used(main.state.boards, BLACK), 9, "black spent 9")

func test_auto_place_needs_zones_first() -> void:
	var main = await load_main()
	main.panel.auto_place_black_button.pressed.emit()
	check_eq(main.panel.auto_place_status_label.text, "No free zone squares - generate zones first", "message")
	check(pieces_of(main.state.boards, BLACK).is_empty(), "nothing placed")

func test_auto_place_stays_in_zone_budget_and_supply_for_both_round_types() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel.white_zone_spin_box.value = 6
	panel.black_zone_spin_box.value = 12
	panel.white_points_spin_box.value = 20
	panel.black_points_spin_box.value = 25
	panel.generate_zones_button.pressed.emit()
	var boards: Array = main.state.boards
	var free := { WHITE: 5, BLACK: 11 }      # zone tiles minus the king's square
	for round_index in [0, 1]:
		panel.round_option.select(round_index)
		for side in [WHITE, BLACK]:
			for i in 20:
				main._on_auto_place(side)
				var army := pieces_of(boards, side, false)
				check(army.size() <= free[side], "at most the free zone squares")
				check(main.panel.points_allocated(side) >= ArmyPlacer.points_used(boards, side), "within budget")
				var counts := {}
				for entry in army:
					check_eq(entry.board.zone_owner.get(entry.square), side, "inside its own zone")
					counts[entry.piece.type] = counts.get(entry.piece.type, 0) + 1
				for type in counts:
					check(counts[type] <= PieceSelector.SUPPLY_LIMITS[type], "supply limit for %s" % Piece.Type.find_key(type))

func test_auto_place_keeps_kings_leaves_the_other_side_and_replaces() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel.white_points_spin_box.value = 20
	panel.black_points_spin_box.value = 25
	await new_world(main, 8, 8, true)
	var boards: Array = main.state.boards
	var white_before := pieces_of(boards, WHITE).size()
	for i in 10:
		main._on_auto_place(BLACK)
		check(ArmyPlacer.points_used(boards, BLACK) <= 25, "re-running replaces instead of piling up")
	check_eq(pieces_of(boards, WHITE).size(), white_before, "white untouched")
	check(king_alive(boards, WHITE) and king_alive(boards, BLACK), "kings stay")
	check(panel.auto_place_status_label.text.begins_with("Placed"), "status message")
