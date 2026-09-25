extends "res://tests/TestCase.gd"
## Standard chess movement for every piece on a single board.

func test_rook_slides_blocks_and_captures() -> void:
	var board := make_board()
	put(board, Vector2i(3, 3), ROOK, WHITE)
	put(board, Vector2i(3, 5), PAWN, WHITE)   # own piece: blocks
	put(board, Vector2i(6, 3), PAWN, BLACK)   # enemy: capturable, ends the slide
	var moves := Piece.get_legal_moves(ROOK, WHITE, board, Vector2i(3, 3))
	var squares := squares_of(moves)
	check(squares.has(Vector2i(3, 4)), "can step up to its own blocker")
	check(not squares.has(Vector2i(3, 5)), "cannot land on its own piece")
	check(not squares.has(Vector2i(3, 6)), "cannot slide past its own piece")
	check(squares.has(Vector2i(6, 3)), "can capture the enemy")
	check(not squares.has(Vector2i(7, 3)), "cannot slide past a capture")

func test_bishop_slides_diagonals_only() -> void:
	var board := make_board()
	put(board, Vector2i(0, 0), BISHOP, WHITE)
	var squares := squares_of(Piece.get_legal_moves(BISHOP, WHITE, board, Vector2i(0, 0)))
	check(squares.has(Vector2i(7, 7)), "reaches the far corner")
	check(not squares.has(Vector2i(1, 0)), "does not move straight")
	check_eq(squares.size(), 7, "one diagonal from a corner")

func test_knight_has_eight_moves_in_the_open() -> void:
	var board := make_board()
	put(board, Vector2i(4, 4), KNIGHT, WHITE)
	check_eq(Piece.get_legal_moves(KNIGHT, WHITE, board, Vector2i(4, 4)).size(), 8, "open-board knight moves")

func test_knight_jumps_over_pieces() -> void:
	var board := make_board()
	put(board, Vector2i(4, 4), KNIGHT, WHITE)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		put(board, Vector2i(4, 4) + offset, PAWN, WHITE)
	check_eq(Piece.get_legal_moves(KNIGHT, WHITE, board, Vector2i(4, 4)).size(), 8, "surrounded knight still has all moves")

func test_king_steps_one_square() -> void:
	var board := make_board()
	put(board, Vector2i(0, 0), KING, WHITE)
	check_eq(Piece.get_legal_moves(KING, WHITE, board, Vector2i(0, 0)).size(), 3, "king in a corner")
	board.pieces.clear()
	put(board, Vector2i(4, 4), KING, WHITE)
	check_eq(Piece.get_legal_moves(KING, WHITE, board, Vector2i(4, 4)).size(), 8, "king in the open")

func test_queen_combines_rook_and_bishop() -> void:
	var board := make_board()
	put(board, Vector2i(3, 3), QUEEN, WHITE)
	check_eq(Piece.get_legal_moves(QUEEN, WHITE, board, Vector2i(3, 3)).size(), 27, "14 straight + 13 diagonal")

func test_pieces_capture_enemies_but_not_friends() -> void:
	var board := make_board()
	put(board, Vector2i(3, 3), QUEEN, WHITE)
	put(board, Vector2i(3, 0), ROOK, BLACK)
	put(board, Vector2i(0, 3), ROOK, WHITE)
	var moves := Piece.get_legal_moves(QUEEN, WHITE, board, Vector2i(3, 3))
	var capture: Array = moves.filter(func(m): return m.square == Vector2i(3, 0))
	check(capture.size() == 1 and capture[0].capture, "enemy rook is a capture")
	check(not squares_of(moves).has(Vector2i(0, 3)), "friendly rook is not a target")
