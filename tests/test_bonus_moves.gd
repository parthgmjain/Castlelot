extends "res://tests/TestCase.gd"
## Bonus moves: a Ninja's extra step and a Warlord's extra pawn move, through the real game.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# The real game with `pieces` = [[square, type, side], ...] on the first board (plus both kings) and a
# match started (6 moves). The AI is kept from replying on its own unless a test frees it.
func _game(pieces: Array, start_match: bool = true) -> Dictionary:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})                      # the world is generated with random seams; these tests want a closed board
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	for p in pieces:
		put(board, p[0], p[1], p[2])
	if start_match:
		main.run_flow.start_match(6, 9999)
	main.turn_flow.ai_delay = 5.0
	return { "main": main, "board": board, "state": main.state, "match": main.state.current_match }

func _click(g: Dictionary, square: Vector2i) -> void:
	g.main._on_square_selected(square, g.board)

# ---- Ninja ------------------------------------------------------------------------------

func test_ninja_moves_like_a_knight() -> void:
	var board := make_board(8, 8)
	put(board, V(3, 3), Piece.Type.NINJA, WHITE)
	var squares := Piece.get_legal_moves(Piece.Type.NINJA, WHITE, board, V(3, 3)).map(func(m): return m.square)
	check_eq(squares.size(), 8, "eight jumps")
	check(squares.has(V(4, 5)) and squares.has(V(1, 2)), "knight squares")

func test_a_ninja_capture_earns_a_free_optional_step() -> void:
	var g := await _game([[V(3, 3), Piece.Type.NINJA, WHITE], [V(4, 5), ROOK, BLACK], [V(5, 5), PAWN, BLACK]])
	var current: MatchState = g.match
	_click(g, V(3, 3))
	_click(g, V(4, 5))
	check_eq(current.bonus.get("kind"), "step", "a bonus step is on offer")
	check_eq(current.turn_side, WHITE, "the turn hasn't passed")
	check_eq(current.moves_left, 5, "the capture cost a move")
	check(g.main.panel.match_status_label.text.contains("BONUS MOVE"), g.main.panel.match_status_label.text)
	check(g.main.panel.skip_bonus_button.visible, "the skip button shows")

	_click(g, V(7, 7))
	check(g.state.current_moves.is_empty(), "no other piece can move during the bonus")
	_click(g, V(4, 5))
	check_eq(g.state.current_moves.size(), 8, "the ninja can take one step in any direction")
	check(not g.state.current_moves.any(func(m): return m.square == V(6, 4)), "no knight jumps now")
	check(g.state.current_moves.any(func(m): return m.square == V(5, 5) and m.capture), "and the step may capture")

	_click(g, V(5, 5))
	check(current.bonus.is_empty(), "the bonus is used up and doesn't chain")
	check_eq(current.moves_left, 5, "the bonus move was free")
	check_eq(current.turn_side, BLACK, "now the AI is up")
	check_eq(current.scores[WHITE], (Piece.value(ROOK) + Piece.value(PAWN)) * Scoring.CHIPS_PER_VALUE, "both captures scored")
	check(not g.main.panel.skip_bonus_button.visible, "and the button is gone")

func test_the_skip_button_gives_up_the_bonus_and_ends_the_turn() -> void:
	var g := await _game([[V(3, 3), Piece.Type.NINJA, WHITE], [V(4, 5), ROOK, BLACK]])
	_click(g, V(3, 3))
	_click(g, V(4, 5))
	check(not g.match.bonus.is_empty(), "offered")
	g.main.panel.skip_bonus_button.pressed.emit()
	check(g.match.bonus.is_empty(), "declined")
	check_eq(g.match.turn_side, BLACK, "the turn passed")
	check_eq(g.match.moves_left, 5, "at no extra cost")
	check(not g.main.panel.skip_bonus_button.visible, "the button hides")

func test_a_quiet_ninja_move_earns_nothing() -> void:
	var g := await _game([[V(3, 3), Piece.Type.NINJA, WHITE]])
	_click(g, V(3, 3))
	_click(g, V(4, 5))
	check(g.match.bonus.is_empty(), "no capture, no bonus")
	check_eq(g.match.turn_side, BLACK, "turn over")

func test_a_ninja_capturing_the_king_wins_without_a_bonus() -> void:
	var g := await _game([[V(3, 3), Piece.Type.NINJA, WHITE], [V(4, 5), KING, BLACK]])
	g.board.pieces.erase(V(0, 0))
	g.board.pieces[V(4, 5)] = { "type": KING, "side": BLACK }
	_click(g, V(3, 3))
	_click(g, V(4, 5))
	check_eq(g.match.result, "win", "won")
	check(g.match.bonus.is_empty(), "nothing left to bonus")

func test_a_bonus_nobody_can_use_is_not_offered() -> void:
	var g := await _game([
		[V(2, 6), Piece.Type.NINJA, WHITE], [V(0, 7), ROOK, BLACK],
		[V(1, 7), PAWN, WHITE], [V(0, 6), PAWN, WHITE], [V(1, 6), PAWN, WHITE],           # the ninja lands boxed in by friends
	])
	_click(g, V(2, 6))
	_click(g, V(0, 7))
	check(g.match.bonus.is_empty(), "no step is possible, so no bonus")
	check_eq(g.match.turn_side, BLACK, "the turn just passes")

func test_outside_a_match_a_ninja_capture_gives_no_bonus() -> void:
	var g := await _game([[V(3, 3), Piece.Type.NINJA, WHITE], [V(4, 5), ROOK, BLACK]], false)
	_click(g, V(3, 3))
	_click(g, V(4, 5))
	check(g.match.bonus.is_empty() and g.board.pieces[V(4, 5)].type == Piece.Type.NINJA, "the capture happened, no bonus")

# ---- Warlord ----------------------------------------------------------------------------

func test_warlord_moves_like_a_rook_and_a_knight() -> void:
	var board := make_board(8, 8)
	put(board, V(3, 3), Piece.Type.WARLORD, WHITE)
	var squares := Piece.get_legal_moves(Piece.Type.WARLORD, WHITE, board, V(3, 3)).map(func(m): return m.square)
	check_eq(squares.size(), 14 + 8, "fourteen rook squares and eight knight squares")
	check(squares.has(V(3, 0)) and squares.has(V(4, 5)) and not squares.has(V(4, 4)), "not diagonal")

func test_a_warlord_capture_earns_a_free_move_with_any_pawn() -> void:
	var g := await _game([
		[V(3, 3), Piece.Type.WARLORD, WHITE], [V(3, 0), PAWN, BLACK],
		[V(5, 5), PAWN, WHITE], [V(2, 6), PAWN, WHITE], [V(1, 4), ROOK, WHITE],
	])
	var current: MatchState = g.match
	_click(g, V(3, 3))
	_click(g, V(3, 0))
	check_eq(current.bonus.get("kind"), "pawn", "a pawn move is on offer")
	check_eq(current.turn_side, WHITE, "the turn hasn't passed")
	_click(g, V(3, 0))
	check(g.state.current_moves.is_empty(), "the warlord itself can't move now")
	_click(g, V(1, 4))
	check(g.state.current_moves.is_empty(), "nor can a rook")
	_click(g, V(5, 5))
	check(g.state.current_moves.any(func(m): return m.square == V(5, 4)), "but a pawn can")
	_click(g, V(5, 4))
	check(current.bonus.is_empty(), "the bonus is spent")
	check_eq(current.moves_left, 5, "and it was free")
	check_eq(current.turn_side, BLACK, "the turn passes")

func test_a_pawn_promoting_during_a_bonus_still_ends_the_turn_afterwards() -> void:
	var g := await _game([[V(3, 3), Piece.Type.WARLORD, WHITE], [V(3, 0), PAWN, BLACK], [V(5, 1), PAWN, WHITE]])
	for x in 8:
		g.board.zone_owner[V(x, 0)] = BLACK
	_click(g, V(3, 3))
	_click(g, V(3, 0))
	_click(g, V(5, 1))
	_click(g, V(5, 0))
	check(g.main.promotion_picker.visible, "the promotion picker opens")
	check_eq(g.match.turn_side, WHITE, "and the turn waits for the choice")
	g.main.promotion_picker.piece_chosen.emit(QUEEN)
	check(g.board.pieces[V(5, 0)].type == QUEEN, "promoted")
	check_eq(g.match.turn_side, BLACK, "then the turn passes")
	check(g.match.bonus.is_empty(), "with the bonus spent")

func test_a_warlord_capture_with_no_pawns_earns_nothing() -> void:
	var g := await _game([[V(3, 3), Piece.Type.WARLORD, WHITE], [V(3, 0), PAWN, BLACK]])
	_click(g, V(3, 3))
	_click(g, V(3, 0))
	check(g.match.bonus.is_empty(), "no pawns to move")
	check_eq(g.match.turn_side, BLACK, "the turn passes")

# ---- the AI -----------------------------------------------------------------------------

func test_the_ai_takes_a_worthwhile_bonus_step() -> void:
	var g := await _game([[V(3, 3), Piece.Type.NINJA, BLACK], [V(4, 5), ROOK, WHITE], [V(5, 6), BISHOP, WHITE]])     # the bishop is not aimed at black's king
	g.match.turn_side = BLACK
	g.main.turn_flow.ai_delay = 0.0
	g.main.turn_flow.run_ai_turn()
	await pump(10)
	var scores: Dictionary = g.match.scores
	check_eq(scores[BLACK], (Piece.value(ROOK) + Piece.value(BISHOP)) * Scoring.CHIPS_PER_VALUE, "the ninja took the rook and then the bishop: %s" % g.match.last_event)
	check(g.match.bonus.is_empty() and g.match.turn_side == WHITE, "and it's the player's turn again")
	check_eq(g.match.moves_left, 6, "the AI's moves never cost the player's")

func test_the_ai_never_leaves_a_bonus_hanging() -> void:
	var g := await _game([[V(3, 3), Piece.Type.WARLORD, BLACK], [V(3, 6), PAWN, WHITE], [V(6, 6), KNIGHT, WHITE]])
	g.match.turn_side = BLACK
	g.main.turn_flow.ai_delay = 0.0
	g.main.turn_flow.run_ai_turn()
	await pump(10)
	check(g.match.bonus.is_empty(), "the bonus was used or skipped")
	check_eq(g.match.turn_side, WHITE, "so the turn came back")
