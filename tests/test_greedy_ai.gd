extends "res://tests/TestCase.gd"
## The AI's move choice.

func test_it_takes_the_more_valuable_of_two_free_captures() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(0, 0), ROOK, BLACK], [Vector2i(0, 5), QUEEN, WHITE], [Vector2i(5, 0), PAWN, WHITE], [Vector2i(7, 7), KING, WHITE], [Vector2i(7, 4), KING, BLACK]])
	var took_queen := 0
	for i in 20:
		var choice := GreedyAI.choose_move(state, BLACK)
		if choice.move.square == Vector2i(0, 5) and choice.move.capture:
			took_queen += 1
	check_eq(took_queen, 20, "queen taken every time")

func test_it_always_takes_the_king_when_it_can() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(0, 0), ROOK, BLACK], [Vector2i(0, 5), QUEEN, WHITE], [Vector2i(5, 0), KING, WHITE], [Vector2i(7, 4), KING, BLACK]])
	for i in 20:
		check_eq(GreedyAI.choose_move(state, BLACK).move.square, Vector2i(5, 0), "the king, not the queen")

func test_it_declines_a_queen_for_a_defended_pawn() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(3, 3), QUEEN, BLACK], [Vector2i(3, 6), PAWN, WHITE], [Vector2i(3, 7), ROOK, WHITE], [Vector2i(7, 7), KING, WHITE], [Vector2i(0, 0), KING, BLACK]])
	var took_it := 0
	for i in 20:
		if GreedyAI.choose_move(state, BLACK).move.square == Vector2i(3, 6):
			took_it += 1
	check_eq(took_it, 0, "never trades the queen for a defended pawn")

func test_with_nothing_to_take_it_closes_the_distance() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(0, 0), ROOK, BLACK], [Vector2i(7, 7), KING, WHITE], [Vector2i(0, 7), KING, BLACK]])
	var field := BoardGraph.distance_field(state.boards, [{ "board": board, "square": Vector2i(7, 7) }])
	for i in 10:
		var choice := GreedyAI.choose_move(state, BLACK)
		if choice.square == Vector2i(0, 0):
			check(field[board][choice.move.square] < field[board][Vector2i(0, 0)], "the rook moves closer to the enemy king")

func test_thinking_leaves_the_position_untouched_and_no_pieces_means_no_move() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(0, 0), ROOK, BLACK], [Vector2i(0, 5), QUEEN, WHITE], [Vector2i(5, 0), PAWN, WHITE], [Vector2i(7, 7), KING, WHITE], [Vector2i(7, 4), KING, BLACK]])
	var before := board.pieces.duplicate(true)
	GreedyAI.choose_move(state, BLACK)
	check_eq(board.pieces.size(), before.size(), "same number of pieces")
	for square in before:
		check(board.pieces.has(square) and board.pieces[square].type == before[square].type and board.pieces[square].side == before[square].side, "piece at %s restored" % str(square))
	var lonely := make_state(make_board(), [[Vector2i(0, 0), KING, WHITE]])
	check(GreedyAI.choose_move(lonely, BLACK).is_empty(), "no black pieces, no move")

func test_it_uses_seams_between_boards_to_capture() -> void:
	var rig := make_rig([0, 1, 2, 3, 4])
	var a: Board = rig[0]
	var b: Board = rig[1]
	var state := GameState.new()
	state.boards = [a, b]
	put(a, Vector2i(0, 2), ROOK, BLACK)
	put(b, Vector2i(3, 2), QUEEN, WHITE)
	put(a, Vector2i(0, 0), KING, BLACK)
	put(b, Vector2i(4, 4), KING, WHITE)
	var choice := GreedyAI.choose_move(state, BLACK)
	check(choice.move.board == b and choice.move.square == Vector2i(3, 2), "the rook slides across the seam and takes the queen")

func test_thinking_is_fast_on_a_real_position() -> void:
	var main = await load_main()
	await new_world(main, 10, 10, true)
	var started := Time.get_ticks_usec()
	var choice := GreedyAI.choose_move(main.state, BLACK)
	var msec := (Time.get_ticks_usec() - started) / 1000.0
	check(not choice.is_empty(), "it found a move")
	check(msec < 250.0, "took %.1f ms" % msec)
