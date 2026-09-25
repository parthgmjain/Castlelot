extends "res://tests/TestCase.gd"
## Moving through the connecting squares (portals) between boards, including
## knights and diagonals.

# The original step_across, kept only to prove the diagonal bug it had.
func _old_step(board: Board, square: Vector2i, direction: Vector2i) -> Dictionary:
	var target: Vector2i = square + direction
	if board.is_in_bounds(target):
		return { "board": board, "square": target }
	for portal in board.portals.get(square, []):
		if portal.direction == direction:
			return { "board": portal.target_board, "square": portal.target_square }
	return {}

func test_rook_slides_through_a_portal_and_keeps_going() -> void:
	var rig := make_rig([1], 4)
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(0, 1), ROOK, WHITE)
	var moves := Piece.get_legal_moves(ROOK, WHITE, a, Vector2i(0, 1))
	for x in 4:
		check(has_move(moves, b, Vector2i(x, 1)), "reaches B(%d,1)" % x)

func test_rook_captures_just_past_the_portal_and_stops() -> void:
	var rig := make_rig([1], 4)
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(0, 1), ROOK, WHITE)
	put(b, Vector2i(1, 1), PAWN, BLACK)
	var moves := Piece.get_legal_moves(ROOK, WHITE, a, Vector2i(0, 1))
	check(has_move(moves, b, Vector2i(1, 1)), "captures the pawn on the far board")
	check(not has_move(moves, b, Vector2i(2, 1)), "cannot pass through it")

func test_king_steps_through_a_portal() -> void:
	var rig := make_rig([1], 4)
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(3, 1), KING, WHITE)
	check(has_move(Piece.get_legal_moves(KING, WHITE, a, Vector2i(3, 1)), b, Vector2i(0, 1)), "king crosses the seam")

func test_piece_next_to_a_wall_without_a_portal_cannot_cross() -> void:
	var rig := make_rig([1], 4)
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(0, 3), ROOK, WHITE)
	var moves := Piece.get_legal_moves(ROOK, WHITE, a, Vector2i(0, 3))
	check(moves_on(moves, b).is_empty(), "row 3 is not connected")

func test_knight_open_board_is_unchanged() -> void:
	var board := make_board()
	put(board, Vector2i(4, 4), KNIGHT, WHITE)
	var moves := Piece.get_legal_moves(KNIGHT, WHITE, board, Vector2i(4, 4))
	check_eq(moves.size(), 8, "eight moves")
	for m in moves:
		check(m.board == board, "stays on its board")

func test_knight_path_can_cross_a_portal_and_jumps_pieces() -> void:
	var rig := make_rig([0, 1, 2, 3], 4)
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(2, 1), KNIGHT, WHITE)
	# offset (2,1): two steps right (through the portal at A(3,1)) then one down -> B(0,2)
	check(has_move(Piece.get_legal_moves(KNIGHT, WHITE, a, Vector2i(2, 1)), b, Vector2i(0, 2)), "lands on board B")
	put(a, Vector2i(3, 1), PAWN, WHITE)   # sits on the traced path - a knight jumps over it
	check(has_move(Piece.get_legal_moves(KNIGHT, WHITE, a, Vector2i(2, 1)), b, Vector2i(0, 2)), "not blocked by a piece on the path")

# ---- diagonals (the reported bug) -------------------------------------------

func test_diagonal_crosses_when_the_square_beside_has_no_portal() -> void:
	var rig := make_rig([2])              # only row 2 connects
	var a: Board = rig[0]
	var b: Board = rig[1]
	var from := Vector2i(4, 3)            # right edge, row 3: nothing directly beside it
	check(_old_step(a, from, Vector2i(1, -1)).is_empty(), "the old logic was stuck here")
	var step := Piece.step_across(a, from, Vector2i(1, -1))
	check(step.get("board") == b and step.get("square") == Vector2i(0, 2), "now lands on the diagonal neighbour")
	put(a, from, BISHOP, WHITE)
	var moves := Piece.get_legal_moves(BISHOP, WHITE, a, from)
	check(has_move(moves, b, Vector2i(0, 2)) and has_move(moves, b, Vector2i(1, 1)) and has_move(moves, b, Vector2i(2, 0)), "bishop slides on across the seam")

func test_all_four_diagonal_approaches_work_both_ways() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	check_eq(Piece.step_across(a, Vector2i(4, 1), Vector2i(1, 1)).get("square"), Vector2i(0, 2), "down-right from A")
	check_eq(Piece.step_across(a, Vector2i(4, 3), Vector2i(1, -1)).get("square"), Vector2i(0, 2), "up-right from A")
	check_eq(Piece.step_across(b, Vector2i(0, 1), Vector2i(-1, 1)).get("square"), Vector2i(4, 2), "down-left from B")
	check_eq(Piece.step_across(b, Vector2i(0, 3), Vector2i(-1, -1)).get("square"), Vector2i(4, 2), "up-left from B")

func test_diagonals_with_nothing_across_still_stop() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	check(Piece.step_across(a, Vector2i(4, 4), Vector2i(1, 1)).is_empty(), "off a corner")
	check(Piece.step_across(a, Vector2i(4, 0), Vector2i(1, -1)).is_empty(), "off the top corner")
	check(Piece.step_across(a, Vector2i(4, 4), Vector2i(1, -1)).is_empty(), "toward an unconnected row")

func test_queen_crosses_diagonally_and_stops_at_blockers() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(4, 3), QUEEN, WHITE)
	put(b, Vector2i(1, 1), PAWN, BLACK)
	var moves := Piece.get_legal_moves(QUEEN, WHITE, a, Vector2i(4, 3))
	check(has_move(moves, b, Vector2i(0, 2)), "crosses")
	check(has_move(moves, b, Vector2i(1, 1)), "captures the pawn")
	check(not has_move(moves, b, Vector2i(2, 0)), "cannot pass through it")

func test_king_and_pawn_captures_cross_diagonally_too() -> void:
	var rig := make_rig([0, 1, 2, 3, 4])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, Vector2i(4, 2), KING, WHITE)
	var king_moves := Piece.get_legal_moves(KING, WHITE, a, Vector2i(4, 2))
	check(has_move(king_moves, b, Vector2i(0, 1)) and has_move(king_moves, b, Vector2i(0, 3)), "king's diagonals")
	a.pieces.clear()
	put(a, Vector2i(4, 2), PAWN, WHITE)
	put(b, Vector2i(0, 1), ROOK, BLACK)
	var pawn_moves := Piece.get_legal_moves(PAWN, WHITE, a, Vector2i(4, 2))
	check(pawn_moves.any(func(m): return m.board == b and m.square == Vector2i(0, 1) and m.capture), "pawn captures diagonally onto the next board")

func test_every_step_in_random_worlds_lands_on_the_physically_adjacent_square() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel.count_spin_box.value = 5
	await pump()
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var seam_steps := 0
	var diagonal_seam_steps := 0
	var newly_possible := 0
	for world in 30:
		panel.refresh_button.pressed.emit()
		await pump()
		for board in main.state.boards:
			for x in board.grid_width:
				for y in board.grid_height:
					var square := Vector2i(x, y)
					for d in directions:
						var result := Piece.step_across(board, square, d)
						if result.is_empty() or result.board == board:
							continue
						seam_steps += 1
						var from_world: Vector2 = board.position + Vector2(square) * Board.SQUARE_SIZE
						var to_world: Vector2 = result.board.position + Vector2(result.square) * Board.SQUARE_SIZE
						if not (to_world - from_world).is_equal_approx(Vector2(d) * Board.SQUARE_SIZE):
							check(false, "step %s from %s is not physically adjacent" % [d, square])
						var back := Piece.step_across(result.board, result.square, -d)
						if back.is_empty() or back.board != board or back.square != square:
							check(false, "step %s from %s does not reverse" % [d, square])
						if d.x != 0 and d.y != 0:
							diagonal_seam_steps += 1
							if _old_step(board, square, d).is_empty():
								newly_possible += 1
	check(seam_steps > 0 and diagonal_seam_steps > 0, "worlds produced seam crossings")
	check(newly_possible > 0, "diagonal crossings that were impossible before exist")
	check(true, "%d seam steps, %d diagonal (%d newly possible) all adjacent and reversible" % [seam_steps, diagonal_seam_steps, newly_possible])
