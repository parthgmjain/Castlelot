extends "res://tests/TestCase.gd"
## Pilgrim and Alchemist swaps, the Drummer's boost to pawns, and the Squire's knight jumps.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

func _setup(type: Piece.Type, from: Vector2i, others: Array = [], side: Piece.Side = WHITE) -> GameState:
	var board := make_board(8, 8)
	var state := make_state(board, [[from, type, side], [V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE]])
	for other in others:
		put(board, other[0], other[1], other[2])
	state.active_board = board
	state.active_square = from
	MoveController.refresh(state)
	return state

func _swaps(state: GameState) -> Array:
	return state.current_moves.filter(func(m): return m.get("swap", false)).map(func(m): return m.square)

func _plain(state: GameState) -> Array:
	return state.current_moves.filter(func(m): return not m.get("swap", false) and not m.capture).map(func(m): return m.square)

func _same(actual: Array, expected: Array, message: String) -> void:
	var missing := expected.filter(func(s): return not actual.has(s))
	var extra := actual.filter(func(s): return not expected.has(s))
	check(missing.is_empty() and extra.is_empty(), "%s: missing %s, unexpected %s" % [message, str(missing), str(extra)])

# ---- Pilgrim ---------------------------------------------------------------------------

func test_pilgrim_steps_forward_or_back_and_swaps_with_adjacent_friends() -> void:
	var state := _setup(Piece.Type.PILGRIM, V(3, 4), [
		[V(2, 4), ROOK, WHITE], [V(4, 3), PAWN, WHITE],      # adjacent friends (beside, diagonal)
		[V(3, 5), PAWN, BLACK],                                # an enemy behind it blocks the step back
		[V(5, 4), BISHOP, WHITE],                              # two away: too far
	])
	_same(_plain(state), [V(3, 3)], "walks forward; back is blocked by an enemy; no sideways step")
	_same(_swaps(state), [V(2, 4), V(4, 3)], "trades with the friends next to it")
	check(state.current_moves.all(func(m): return not m.capture), "never captures")

func test_swapping_exchanges_the_two_pieces() -> void:
	var state := _setup(Piece.Type.PILGRIM, V(3, 4), [[V(2, 4), ROOK, WHITE]])
	var board: Board = state.active_board
	check_eq(board.swap_squares, [V(2, 4)], "the friend is marked")
	var result := MoveController.click(state, board, V(2, 4))
	check(board.pieces[V(2, 4)].type == Piece.Type.PILGRIM and board.pieces[V(3, 4)].type == ROOK, "they traded places")
	check_eq(result.swapped.piece.type, ROOK, "the result names the friend")
	check(result.victims.is_empty() and result.from_square == V(3, 4) and result.square == V(2, 4), "no victim; from and to are the pilgrim's")

func test_a_swap_crosses_a_seam() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, V(4, 2), Piece.Type.PILGRIM, WHITE)
	put(b, V(0, 2), ROOK, WHITE)
	var state := GameState.new()
	state.boards = [a, b]
	state.active_board = a
	state.active_square = V(4, 2)
	MoveController.refresh(state)
	check(state.current_moves.any(func(m): return m.get("swap", false) and m.board == b and m.square == V(0, 2)), "the rook next door is a swap target")
	MoveController.click(state, b, V(0, 2))
	check(b.pieces[V(0, 2)].type == Piece.Type.PILGRIM and a.pieces[V(4, 2)].type == ROOK, "and they traded across the seam")

func test_a_pawn_swapped_into_the_enemy_zone_promotes() -> void:
	var state := _setup(Piece.Type.PILGRIM, V(3, 3), [[V(3, 4), PAWN, WHITE]])
	state.active_board.zone_owner[V(3, 3)] = BLACK
	var pawn: Dictionary = state.active_board.pieces[V(3, 4)]
	MoveController.click(state, state.active_board, V(3, 4))
	check(state.pending_promotion.get("piece") == pawn, "the pawn now stands on the pilgrim's old square, in the enemy zone")

func test_a_swap_is_reported_as_a_swap() -> void:
	var state := _setup(Piece.Type.PILGRIM, V(3, 4), [[V(2, 4), ROOK, WHITE]])
	MatchController.start(state, 10, 999)
	state.active_board = state.boards[0]
	state.active_square = V(3, 4)
	MoveController.refresh(state)
	var result := MoveController.click(state, state.boards[0], V(2, 4))
	MatchController.record_move(state, result)
	check(state.current_match.last_event.contains("swapped a Pilgrim with a Rook"), state.current_match.last_event)
	check_eq(state.current_match.moves_left, 9, "it costs a move")

# ---- Alchemist -------------------------------------------------------------------------

func test_alchemist_moves_like_a_king_and_swaps_with_any_friend_within_two() -> void:
	var state := _setup(Piece.Type.ALCHEMIST, V(3, 3), [
		[V(5, 3), ROOK, WHITE], [V(1, 2), PAWN, WHITE], [V(4, 4), PAWN, WHITE], [V(3, 5), KNIGHT, WHITE],   # within 2
		[V(4, 3), PAWN, BLACK],                                                                               # an enemy in the way doesn't stop a swap over it
		[V(6, 3), ROOK, WHITE], [V(3, 0), ROOK, WHITE],                                                       # three away: too far
		[V(2, 2), PAWN, BLACK],                                                                               # captured like a king would
	])
	_same(_swaps(state), [V(5, 3), V(1, 2), V(4, 4), V(3, 5)], "friends within two squares, whatever is between")
	check(state.current_moves.any(func(m): return m.capture and m.square == V(2, 2)), "and the king step captures")
	check(state.current_moves.any(func(m): return m.square == V(3, 2) and not m.capture), "and walks")

func test_alchemist_does_not_swap_with_enemies_or_itself() -> void:
	var state := _setup(Piece.Type.ALCHEMIST, V(3, 3), [[V(5, 3), ROOK, BLACK]])
	check(_swaps(state).is_empty(), "no friends, no swaps")

# ---- the AI ------------------------------------------------------------------------------

func test_the_ai_thinking_about_swaps_leaves_every_piece_where_it_was() -> void:
	var state := _setup(Piece.Type.ALCHEMIST, V(3, 3), [[V(4, 5), ROOK, BLACK], [V(5, 5), PAWN, WHITE]], BLACK)
	var board: Board = state.active_board
	var before := board.pieces.duplicate(true)
	for i in 5:
		var choice := GreedyAI.choose_move(state, BLACK)
		check(not choice.is_empty(), "it has a move")
	check_eq(board.pieces.size(), before.size(), "same number of pieces")
	for square in before:
		check(board.pieces.has(square) and board.pieces[square].type == before[square].type and board.pieces[square].side == before[square].side, "untouched: %s" % str(square))

# ---- Drummer ---------------------------------------------------------------------------

func test_a_pawn_next_to_a_drummer_can_advance_two_from_anywhere() -> void:
	var state := _setup(PAWN, V(3, 4), [[V(4, 4), Piece.Type.DRUMMER, WHITE]])
	_same(_plain(state), [V(3, 3), V(3, 2)], "one or two forward")
	var diagonal := _setup(PAWN, V(3, 4), [[V(4, 5), Piece.Type.DRUMMER, WHITE]])
	_same(_plain(diagonal), [V(3, 3), V(3, 2)], "a diagonal neighbour counts")
	var alone := _setup(PAWN, V(3, 4))
	_same(_plain(alone), [V(3, 3)], "without the drummer, just one")
	var far := _setup(PAWN, V(3, 4), [[V(5, 4), Piece.Type.DRUMMER, WHITE]])
	_same(_plain(far), [V(3, 3)], "two squares away is too far")

func test_the_drummer_boost_is_for_friendly_real_pawns_and_needs_a_clear_path() -> void:
	var enemy := _setup(PAWN, V(3, 4), [[V(4, 4), Piece.Type.DRUMMER, BLACK]])
	_same(_plain(enemy), [V(3, 3)], "an enemy drummer doesn't help")
	var scout := _setup(Piece.Type.SCOUT, V(3, 4), [[V(4, 4), Piece.Type.DRUMMER, WHITE]])
	check(not _plain(scout).has(V(3, 2)), "only pawns are drummed")
	var blocked := _setup(PAWN, V(3, 4), [[V(4, 4), Piece.Type.DRUMMER, WHITE], [V(3, 2), PAWN, BLACK]])
	_same(_plain(blocked), [V(3, 3)], "it can't jump a piece on the second square")
	var jammed := _setup(PAWN, V(3, 4), [[V(4, 4), Piece.Type.DRUMMER, WHITE], [V(3, 3), PAWN, BLACK]])
	check(_plain(jammed).is_empty(), "or through one on the first")

func test_a_drummed_pawn_on_its_home_row_gets_no_duplicate_move() -> void:
	var state := _setup(PAWN, V(3, 7), [[V(4, 7), Piece.Type.DRUMMER, WHITE]])
	check_eq(state.current_moves.size(), 2, "one step and two steps, each once")

func test_the_drummer_walks_forward_and_never_captures() -> void:
	var state := _setup(Piece.Type.DRUMMER, V(3, 4), [[V(3, 3), PAWN, BLACK], [V(2, 3), PAWN, BLACK]])
	check(state.current_moves.is_empty(), "blocked ahead, and diagonal enemies can't be taken")
	var open := _setup(Piece.Type.DRUMMER, V(3, 4))
	check_eq(open.current_moves.size(), 1, "one square forward")

# ---- Squire ----------------------------------------------------------------------------

func test_squire_moves_like_a_pawn() -> void:
	var state := _setup(Piece.Type.SQUIRE, V(3, 4), [[V(2, 3), PAWN, BLACK]])
	check(state.current_moves.any(func(m): return m.square == V(3, 3) and not m.capture), "forward")
	check(state.current_moves.any(func(m): return m.square == V(2, 3) and m.capture), "diagonal capture")
	check_eq(state.current_moves.size(), 2, "and nothing else")

func test_squire_next_to_a_friendly_knight_can_jump_like_one() -> void:
	var state := _setup(Piece.Type.SQUIRE, V(3, 4), [[V(4, 4), KNIGHT, WHITE], [V(4, 2), PAWN, BLACK]])
	for jump in [V(5, 5), V(1, 3), V(4, 6), V(2, 6), V(5, 3), V(2, 2), V(1, 5)]:
		check(state.current_moves.any(func(m): return m.square == jump), "jumps to %s" % str(jump))
	check(state.current_moves.any(func(m): return m.square == V(4, 2) and m.capture), "and a jump can capture")
	var alone := _setup(Piece.Type.SQUIRE, V(3, 4), [[V(5, 4), KNIGHT, WHITE]])
	check_eq(alone.current_moves.size(), 1, "a knight two squares away doesn't count")
	var enemy := _setup(Piece.Type.SQUIRE, V(3, 4), [[V(4, 4), KNIGHT, BLACK]])
	check_eq(enemy.current_moves.size(), 1, "an enemy knight doesn't count")
	var bishop := _setup(Piece.Type.SQUIRE, V(3, 4), [[V(4, 4), BISHOP, WHITE]])
	check_eq(bishop.current_moves.size(), 1, "and neither does a friendly bishop")
