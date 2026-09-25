extends "res://tests/TestCase.gd"
## Pieces that can't be captured by certain attackers: Shieldbearer, Tortoise, Golem,
## Bard (an aura for its neighbours) and Wraith.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# An 8x8 board with `pieces` = [[square, type, side], ...] (White heads up the screen, Black down).
func _board(pieces: Array) -> Board:
	var board := make_board(8, 8)
	for p in pieces:
		put(board, p[0], p[1], p[2])
	return board

func _can_take(board: Board, from: Vector2i, target: Vector2i) -> bool:
	var piece: Dictionary = board.pieces[from]
	var moves := Piece.get_legal_moves(piece.type, piece.side, board, from)
	return moves.any(func(m): return m.capture and m.square == target)

# ---- Shieldbearer ---------------------------------------------------------------------

func test_shieldbearer_cannot_be_captured_by_the_piece_directly_in_front() -> void:
	var board := _board([[V(3, 4), Piece.Type.SHIELDBEARER, WHITE], [V(3, 3), QUEEN, BLACK]])
	check(not _can_take(board, V(3, 3), V(3, 4)), "the queen right in front can't take it")
	board.pieces[V(3, 3)] = { "type": ROOK, "side": BLACK }
	check(not _can_take(board, V(3, 3), V(3, 4)), "nor can a rook")

func test_shieldbearer_can_be_captured_from_anywhere_else() -> void:
	var board := _board([[V(3, 4), Piece.Type.SHIELDBEARER, WHITE], [V(3, 1), ROOK, BLACK], [V(3, 7), QUEEN, BLACK], [V(2, 3), QUEEN, BLACK], [V(0, 4), ROOK, BLACK]])
	check(_can_take(board, V(3, 1), V(3, 4)), "a rook further up the same file can")
	check(_can_take(board, V(3, 7), V(3, 4)), "from behind")
	check(_can_take(board, V(2, 3), V(3, 4)), "from the front diagonal")
	check(_can_take(board, V(0, 4), V(3, 4)), "from the side")

func test_shieldbearer_faces_its_heading_not_the_screen() -> void:
	var board := _board([[V(3, 4), Piece.Type.SHIELDBEARER, WHITE], [V(4, 4), ROOK, BLACK], [V(3, 3), ROOK, BLACK]])
	for row in 8:
		board.zone_owner[V(7, row)] = BLACK                 # the enemy zone is on the right, so it faces right
	check(not _can_take(board, V(4, 4), V(3, 4)), "the rook on its right is in front")
	check(_can_take(board, V(3, 3), V(3, 4)), "the rook above it is now beside it")

func test_shieldbearer_moves_like_a_pawn_that_cannot_walk_into_a_capture() -> void:
	var board := _board([[V(3, 4), Piece.Type.SHIELDBEARER, WHITE], [V(2, 3), PAWN, BLACK], [V(3, 3), PAWN, BLACK]])
	var moves := Piece.get_legal_moves(Piece.Type.SHIELDBEARER, WHITE, board, V(3, 4))
	check_eq(moves.map(func(m): return m.square), [V(2, 3)], "captures diagonally forward only; blocked ahead")

# ---- Tortoise -------------------------------------------------------------------------

func test_tortoise_can_only_be_captured_from_behind_or_the_sides() -> void:
	var board := _board([
		[V(3, 4), Piece.Type.TORTOISE, WHITE],
		[V(3, 1), ROOK, BLACK], [V(5, 2), Piece.Type.BISHOP, BLACK],          # in front, straight and diagonal
		[V(0, 4), ROOK, BLACK],                                                # beside it
		[V(3, 7), ROOK, BLACK], [V(5, 6), Piece.Type.BISHOP, BLACK],           # behind, straight and diagonal
	])
	check(not _can_take(board, V(3, 1), V(3, 4)), "not from the front")
	check(not _can_take(board, V(5, 2), V(3, 4)), "not from the front diagonal")
	check(_can_take(board, V(0, 4), V(3, 4)), "from the side")
	check(_can_take(board, V(3, 7), V(3, 4)), "from behind")
	check(_can_take(board, V(5, 6), V(3, 4)), "from behind, diagonally")

func test_tortoise_moves_up_to_two_orthogonally_and_captures_normally() -> void:
	var board := _board([[V(3, 4), Piece.Type.TORTOISE, WHITE], [V(3, 2), PAWN, BLACK]])
	var moves := Piece.get_legal_moves(Piece.Type.TORTOISE, WHITE, board, V(3, 4))
	var squares := moves.map(func(m): return m.square)
	for expected in [V(3, 3), V(3, 5), V(3, 6), V(2, 4), V(1, 4), V(4, 4), V(5, 4), V(3, 2)]:
		check(squares.has(expected), "can reach %s" % str(expected))
	check_eq(squares.size(), 8, "and nothing else")

func test_tortoise_front_is_measured_across_board_seams() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	b.position = Vector2(5 * Board.SQUARE_SIZE, 0)          # B sits to the right of A, like the real layout
	for row in 5:
		b.zone_owner[Vector2i(4, row)] = BLACK              # the enemy zone is on B, so the tortoise faces right
	put(a, V(2, 2), Piece.Type.TORTOISE, WHITE)
	put(b, V(0, 2), ROOK, BLACK)                            # in front of it, on the other board
	put(a, V(0, 2), ROOK, BLACK)                            # behind it
	check(not Piece.get_legal_moves(ROOK, BLACK, b, V(0, 2)).any(func(m): return m.capture and m.board == a and m.square == V(2, 2)), "the rook on B is in front, and can't")
	check(Piece.get_legal_moves(ROOK, BLACK, a, V(0, 2)).any(func(m): return m.capture and m.board == a and m.square == V(2, 2)), "the rook behind it on A can")

# ---- Golem ----------------------------------------------------------------------------

func test_golem_cannot_be_captured_by_pawns_or_knights() -> void:
	var board := _board([[V(3, 4), Piece.Type.GOLEM, WHITE], [V(2, 3), PAWN, BLACK], [V(1, 3), KNIGHT, BLACK]])
	check(not _can_take(board, V(2, 3), V(3, 4)), "not by a pawn")
	check(not _can_take(board, V(1, 3), V(3, 4)), "not by a knight")

func test_golem_can_be_captured_by_everything_else() -> void:
	var board := _board([[V(3, 4), Piece.Type.GOLEM, WHITE], [V(3, 1), ROOK, BLACK], [V(6, 1), BISHOP, BLACK], [V(3, 7), QUEEN, BLACK], [V(0, 3), Piece.Type.CAMEL, BLACK]])
	for from in [V(3, 1), V(6, 1), V(3, 7), V(0, 3)]:
		check(_can_take(board, from, V(3, 4)), "%s can" % Piece.Type.find_key(board.pieces[from].type))

func test_golem_itself_captures_pawns_and_knights_one_step_orthogonally() -> void:
	var board := _board([[V(3, 4), Piece.Type.GOLEM, WHITE], [V(3, 3), PAWN, BLACK], [V(4, 4), KNIGHT, BLACK], [V(2, 3), PAWN, BLACK]])
	var squares := Piece.get_legal_moves(Piece.Type.GOLEM, WHITE, board, V(3, 4)).map(func(m): return m.square)
	check(squares.has(V(3, 3)) and squares.has(V(4, 4)) and not squares.has(V(2, 3)), "orthogonal only")

# ---- Bard -----------------------------------------------------------------------------

func test_bard_protects_neighbours_from_pawns_but_not_from_others() -> void:
	var board := _board([
		[V(3, 3), Piece.Type.BARD, WHITE], [V(4, 3), ROOK, WHITE],       # a rook beside the bard
		[V(5, 2), PAWN, BLACK],                                            # a pawn that attacks (4,3)
		[V(6, 4), KNIGHT, BLACK],                                          # (6,4) -> (4,3) is a knight move
	])
	check(not _can_take(board, V(5, 2), V(4, 3)), "a pawn can't take the rook beside the bard")
	check(_can_take(board, V(6, 4), V(4, 3)), "a knight still can")
	board.pieces.erase(V(3, 3))
	check(_can_take(board, V(5, 2), V(4, 3)), "without the bard the pawn can")

func test_bard_does_not_protect_far_pieces_or_itself() -> void:
	var board := _board([
		[V(3, 3), Piece.Type.BARD, WHITE], [V(6, 3), ROOK, WHITE], [V(5, 2), PAWN, BLACK], [V(2, 2), PAWN, BLACK],
	])
	check(_can_take(board, V(5, 2), V(6, 3)), "a rook two squares away is not protected")
	check(_can_take(board, V(2, 2), V(3, 3)), "the bard itself can be taken by a pawn")

func test_bard_does_not_protect_enemies_of_its_side() -> void:
	var board := _board([[V(3, 3), Piece.Type.BARD, WHITE], [V(4, 3), ROOK, BLACK], [V(5, 4), PAWN, WHITE]])
	check(_can_take(board, V(5, 4), V(4, 3)), "the white pawn takes the black rook beside a white bard")

func test_bard_moves_like_a_king_but_cannot_capture() -> void:
	var board := _board([[V(3, 3), Piece.Type.BARD, WHITE], [V(4, 3), PAWN, BLACK]])
	var moves := Piece.get_legal_moves(Piece.Type.BARD, WHITE, board, V(3, 3))
	check_eq(moves.size(), 7, "seven free neighbours")
	check(not moves.any(func(m): return m.capture), "no captures")

func test_bard_protects_across_a_seam() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, V(4, 2), Piece.Type.BARD, WHITE)
	put(b, V(0, 2), ROOK, WHITE)                                # adjacent to the bard through the portal
	put(b, V(1, 1), PAWN, BLACK)                                # a black pawn heading down: it attacks (0,2) diagonally
	check(not Piece.get_legal_moves(PAWN, BLACK, b, V(1, 1)).any(func(m): return m.capture and m.square == V(0, 2)), "the pawn can't take a rook shielded through the seam")
	a.pieces.erase(V(4, 2))
	check(Piece.get_legal_moves(PAWN, BLACK, b, V(1, 1)).any(func(m): return m.capture and m.square == V(0, 2)), "and can once the bard is gone")

# ---- Wraith ---------------------------------------------------------------------------

func test_wraith_moves_like_a_queen_through_pieces() -> void:
	var board := _board([[V(3, 3), Piece.Type.WRAITH, WHITE], [V(3, 2), PAWN, WHITE], [V(3, 5), PAWN, BLACK]])
	var moves := Piece.get_legal_moves(Piece.Type.WRAITH, WHITE, board, V(3, 3))
	var squares := moves.map(func(m): return m.square)
	check(not squares.has(V(3, 2)), "can't stop on a friend")
	check(squares.has(V(3, 1)) and squares.has(V(3, 0)), "but passes over it")
	check(moves.any(func(m): return m.capture and m.square == V(3, 5)), "captures an enemy")
	check(squares.has(V(3, 6)) and squares.has(V(3, 7)), "and keeps going past it")

func test_wraith_can_only_be_captured_by_pawns_and_legendaries() -> void:
	var board := _board([
		[V(3, 3), Piece.Type.WRAITH, WHITE],
		[V(3, 0), ROOK, BLACK], [V(0, 0), BISHOP, BLACK], [V(1, 2), KNIGHT, BLACK], [V(6, 3), Piece.Type.CANNON, BLACK],
		[V(4, 2), PAWN, BLACK],                                                     # a black pawn attacks (3,3) from (4,2)
		[V(3, 7), QUEEN, BLACK],
	])
	for from in [V(3, 0), V(0, 0), V(1, 2), V(6, 3)]:
		check(not _can_take(board, from, V(3, 3)), "%s can't" % Piece.Type.find_key(board.pieces[from].type))
	check(_can_take(board, V(4, 2), V(3, 3)), "a pawn can")
	check(_can_take(board, V(3, 7), V(3, 3)), "a queen (a legendary) can")
	var open := _board([[V(3, 3), Piece.Type.WRAITH, WHITE], [V(7, 3), Piece.Type.DRAGON, BLACK], [V(3, 0), Piece.Type.TITAN, BLACK]])
	check(_can_take(open, V(7, 3), V(3, 3)), "a dragon can too")
	check(_can_take(open, V(3, 0), V(3, 3)), "and a titan")

# ---- special attacks respect protection ---------------------------------------------------

func test_a_catapult_shot_at_a_protected_piece_is_not_offered() -> void:
	var board := _board([[V(3, 3), Piece.Type.CATAPULT, BLACK], [V(3, 6), Piece.Type.WRAITH, WHITE], [V(0, 3), ROOK, WHITE]])
	var moves := Piece.get_legal_moves(Piece.Type.CATAPULT, BLACK, board, V(3, 3))
	check_eq(moves.map(func(m): return m.square), [V(0, 3)], "only the rook, not the wraith")

func test_dragon_fire_skips_protected_pieces_but_still_burns_the_rest() -> void:
	var board := _board([
		[V(3, 3), Piece.Type.DRAGON, BLACK],
		[V(3, 4), Piece.Type.TORTOISE, WHITE],                # the dragon is in front of it: protected from it
		[V(3, 5), PAWN, WHITE],
	])
	var moves := Piece.get_legal_moves(Piece.Type.DRAGON, BLACK, board, V(3, 3))
	var fire := moves.filter(func(m): return m.get("special", false))
	check_eq(fire.size(), 1, "only the pawn is a target")
	check(fire[0].square == V(3, 5) and fire[0].hits.size() == 1, "and the flame reaches just that one")
	check(not moves.any(func(m): return m.square == V(3, 4) and m.capture), "no normal capture of the tortoise either")

func test_dragon_fire_keeps_hitting_the_unprotected_in_a_mixed_line() -> void:
	var board := _board([
		[V(3, 3), Piece.Type.DRAGON, BLACK],
		[V(3, 4), PAWN, WHITE],
		[V(3, 5), Piece.Type.GOLEM, WHITE],                   # a dragon isn't a pawn or a knight, so the golem burns
	])
	var fire := Piece.get_legal_moves(Piece.Type.DRAGON, BLACK, board, V(3, 3)).filter(func(m): return m.get("special", false))
	check_eq(fire.size(), 2, "both squares are targets")
	check_eq(fire[0].hits.size(), 2, "and both burn")

func test_titan_cannot_double_capture_through_a_protected_piece() -> void:
	var board := _board([[V(3, 1), Piece.Type.TITAN, BLACK], [V(3, 3), Piece.Type.TORTOISE, WHITE], [V(3, 5), ROOK, WHITE]])
	var moves := Piece.get_legal_moves(Piece.Type.TITAN, BLACK, board, V(3, 1))
	check(not moves.any(func(m): return m.capture), "the tortoise faces the titan, so no capture, and no double capture past it")

# ---- through the game ---------------------------------------------------------------------

func test_the_ai_never_takes_a_protected_piece() -> void:
	var board := _board([[V(7, 7), KING, BLACK], [V(0, 0), KING, WHITE], [V(2, 3), PAWN, BLACK], [V(3, 4), Piece.Type.GOLEM, WHITE]])
	var state := make_state(board)
	for i in 10:
		var choice := GreedyAI.choose_move(state, BLACK)
		check(not choice.is_empty() and not (choice.move.capture and choice.move.square == V(3, 4)), "the pawn doesn't try to take the golem")

func test_a_protected_target_is_not_marked_on_the_board() -> void:
	var board := _board([[V(3, 3), ROOK, BLACK], [V(3, 6), Piece.Type.WRAITH, WHITE], [V(0, 3), PAWN, WHITE]])
	var state := make_state(board)
	state.active_board = board
	state.active_square = V(3, 3)
	MoveController.refresh(state)
	check(not board.capture_squares.has(V(3, 6)), "no red ring on the wraith")
	check(board.capture_squares.has(V(0, 3)), "but the pawn is still a target")

func test_a_side_with_only_protected_targets_still_has_moves_elsewhere() -> void:
	var board := _board([[V(3, 3), ROOK, BLACK], [V(3, 6), Piece.Type.WRAITH, WHITE]])
	check(MatchController.has_legal_move(make_state(board), BLACK), "the rook can still walk around")
