extends "res://tests/TestCase.gd"
## Effects that fire when a piece captures or is captured: Torchbearer, Lich, Phoenix, Hydra.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# Kings are placed in the far corners unless `others` already has them.
func _setup(others: Array) -> GameState:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE]])
	for other in others:
		put(board, other[0], other[1], other[2])
	return state

func _move(state: GameState, from: Vector2i, to: Vector2i, special: bool = false) -> Dictionary:
	state.active_board = state.boards[0]
	state.active_square = from
	MoveController.refresh(state)
	return MoveController.click(state, state.boards[0], to, special)

func _count(board: Board, type: Piece.Type, side: Piece.Side) -> int:
	return board.pieces.values().filter(func(p): return p.type == type and p.side == side).size()

func _in_match(state: GameState, player: Piece.Side = WHITE) -> void:
	MatchController.start(state, 50, 9999)
	state.current_match.player_side = player

# ---- Torchbearer -----------------------------------------------------------------------

func test_torchbearer_moves_like_a_pawn() -> void:
	var state := _setup([[V(3, 4), Piece.Type.TORCHBEARER, WHITE], [V(2, 3), PAWN, BLACK]])
	state.active_board = state.boards[0]
	state.active_square = V(3, 4)
	MoveController.refresh(state)
	check(state.current_moves.any(func(m): return m.square == V(3, 3) and not m.capture), "forward")
	check(state.current_moves.any(func(m): return m.square == V(2, 3) and m.capture), "diagonal capture")
	var home := _setup([[V(3, 7), Piece.Type.TORCHBEARER, WHITE]])
	check(Piece.get_legal_moves(Piece.Type.TORCHBEARER, WHITE, home.boards[0], V(3, 7)).any(func(m): return m.square == V(3, 5)), "and a double step from its home row")

func test_whoever_captures_a_torchbearer_is_destroyed_too() -> void:
	var state := _setup([[V(3, 4), Piece.Type.TORCHBEARER, WHITE], [V(3, 1), ROOK, BLACK]])
	var result := _move(state, V(3, 1), V(3, 4))
	var board: Board = state.boards[0]
	check(not board.pieces.has(V(3, 4)), "neither the torchbearer nor the rook is left")
	check(not board.pieces.has(V(3, 1)), "and the rook didn't stay behind either")
	check_eq(result.victims.size(), 1, "one victim")
	check_eq(result.losses.size(), 1, "and one loss for the capturer")
	check_eq(result.losses[0].piece.type, ROOK, "the rook")
	check(result.notes.size() == 1 and result.notes[0].contains("Torchbearer"), str(result.notes))

func test_the_torchbearers_side_scores_the_destroyed_attacker() -> void:
	var state := _setup([[V(3, 4), Piece.Type.TORCHBEARER, WHITE], [V(3, 1), ROOK, BLACK]])
	_in_match(state)
	state.current_match.turn_side = BLACK
	var result := _move(state, V(3, 1), V(3, 4))
	MatchController.record_move(state, result)
	var scores: Dictionary = state.current_match.scores
	check_eq(scores[BLACK], Piece.value(Piece.Type.TORCHBEARER) * Scoring.CHIPS_PER_VALUE, "black took the torchbearer")
	check_eq(scores[WHITE], Piece.value(ROOK) * Scoring.CHIPS_PER_VALUE, "white gets the rook it burnt")
	check(state.current_match.last_event.contains("for the other side"), state.current_match.last_event)

func test_a_king_that_takes_a_torchbearer_loses_the_match() -> void:
	var state := _setup([[V(3, 4), Piece.Type.TORCHBEARER, WHITE], [V(3, 3), KING, BLACK]])
	_in_match(state)
	var result := _move(state, V(3, 3), V(3, 4))
	MatchController.record_move(state, result)
	check_eq(state.current_match.result, "win", "white's torchbearer took the black king with it")
	check_eq(state.current_match.result_reason, "King destroyed", "and says why")
	var mirror := _setup([[V(3, 4), Piece.Type.TORCHBEARER, BLACK], [V(3, 5), KING, WHITE]])
	_in_match(mirror)
	var second := _move(mirror, V(3, 5), V(3, 4))
	MatchController.record_move(mirror, second)
	check_eq(mirror.current_match.result, "loss", "and the same for the player's own king")

func test_a_shot_at_a_torchbearer_destroys_the_shooter() -> void:
	var state := _setup([[V(3, 4), Piece.Type.ARCHER, BLACK], [V(3, 6), Piece.Type.TORCHBEARER, WHITE]])
	state.boards[0].pieces[V(3, 4)] = { "type": Piece.Type.ARCHER, "side": BLACK }
	# black faces down the screen, so its arrow flies toward larger y
	var result := _move(state, V(3, 4), V(3, 6), true)
	check(not state.boards[0].pieces.has(V(3, 4)) and not state.boards[0].pieces.has(V(3, 6)), "both gone, though the archer never moved")
	check_eq(result.losses.size(), 1, "recorded as a loss")

func test_torchbearer_effect_works_in_the_sandbox_too() -> void:
	var state := _setup([[V(3, 4), Piece.Type.TORCHBEARER, WHITE], [V(3, 1), ROOK, BLACK]])
	_move(state, V(3, 1), V(3, 4))
	check(not state.boards[0].pieces.has(V(3, 4)), "no match needed")

func test_a_pawn_that_takes_a_torchbearer_does_not_get_to_promote() -> void:
	var white := _setup([[V(3, 3), Piece.Type.TORCHBEARER, BLACK], [V(2, 4), PAWN, WHITE]])
	white.boards[0].zone_owner[V(3, 3)] = BLACK      # the enemy zone for white
	_move(white, V(2, 4), V(3, 3))
	check(white.pending_promotion.is_empty(), "the pawn died in the flames before it could promote")

func test_the_ai_does_not_trade_a_queen_for_a_torchbearer() -> void:
	var state := _setup([[V(3, 3), QUEEN, BLACK], [V(3, 4), Piece.Type.TORCHBEARER, WHITE]])
	for i in 8:
		var choice := GreedyAI.choose_move(state, BLACK)
		check(not (choice.move.capture and choice.move.square == V(3, 4)), "the queen leaves the torchbearer alone")
	var board: Board = state.boards[0]
	check(board.pieces.has(V(3, 3)) and board.pieces.has(V(3, 4)), "and thinking about it moved nothing")

# ---- Lich ------------------------------------------------------------------------------

func test_lich_moves_like_a_king_or_leaps_two() -> void:
	var state := _setup([[V(3, 3), Piece.Type.LICH, WHITE]])
	var squares := Piece.get_legal_moves(Piece.Type.LICH, WHITE, state.boards[0], V(3, 3)).map(func(m): return m.square)
	check_eq(squares.size(), 16, "eight steps and eight leaps")
	for target in [V(3, 5), V(1, 3), V(5, 5), V(1, 1), V(4, 4), V(2, 2)]:
		check(squares.has(target), "reaches %s" % str(target))
	check(not squares.has(V(5, 4)), "but not a knight square")

func test_a_lich_capture_raises_a_pawn_on_the_back_rank_of_your_zone() -> void:
	var state := _setup([[V(3, 3), Piece.Type.LICH, WHITE], [V(4, 4), ROOK, BLACK]])
	var board: Board = state.boards[0]
	for x in 8:
		board.zone_owner[V(x, 7)] = WHITE
		board.zone_owner[V(x, 6)] = WHITE
		board.zone_owner[V(x, 0)] = BLACK
		board.zone_owner[V(x, 1)] = BLACK
	var result := _move(state, V(3, 3), V(4, 4))
	var pawns := board.pieces.keys().filter(func(s): return board.pieces[s].type == PAWN and board.pieces[s].side == WHITE)
	check_eq(pawns.size(), 1, "one pawn appeared")
	check(pawns[0].y == 7, "on the far row of white's zone: %s" % str(pawns))
	check(board.pieces[pawns[0]].get("spawned", false) and not board.pieces[pawns[0]].has("roster_id"), "a temporary pawn, not a roster piece")
	check(result.notes.any(func(n): return n.contains("pawn")), str(result.notes))

func test_a_lich_without_zones_raises_its_pawn_on_the_home_row() -> void:
	var state := _setup([[V(3, 3), Piece.Type.LICH, WHITE], [V(4, 4), ROOK, BLACK]])
	_move(state, V(3, 3), V(4, 4))
	var board: Board = state.boards[0]
	check(board.pieces.keys().any(func(s): return s.y == 7 and board.pieces[s].type == PAWN and board.pieces[s].side == WHITE), "white's home row is the bottom")
	var black := _setup([[V(3, 3), Piece.Type.LICH, BLACK], [V(4, 4), ROOK, WHITE]])
	_move(black, V(3, 3), V(4, 4))
	check(black.boards[0].pieces.keys().any(func(s): return s.y == 0 and black.boards[0].pieces[s].type == PAWN and black.boards[0].pieces[s].side == BLACK), "and black's the top")

func test_a_quiet_lich_move_raises_nothing() -> void:
	var state := _setup([[V(3, 3), Piece.Type.LICH, WHITE]])
	_move(state, V(3, 3), V(3, 2))
	check_eq(_count(state.boards[0], PAWN, WHITE), 0, "no capture, no pawn")

func test_a_lich_with_no_room_says_so() -> void:
	var state := _setup([[V(3, 3), Piece.Type.LICH, WHITE], [V(4, 4), ROOK, BLACK]])
	var board: Board = state.boards[0]
	for x in 8:
		board.zone_owner[V(x, 7)] = WHITE
		if V(x, 7) != V(7, 7):
			put(board, V(x, 7), ROOK, WHITE)              # white's whole zone is full
	var result := _move(state, V(3, 3), V(4, 4))
	check_eq(_count(board, PAWN, WHITE), 0, "no pawn")
	check(result.notes.any(func(n): return n.contains("no room")), str(result.notes))

# ---- Phoenix ---------------------------------------------------------------------------

func _phoenix_state(extra: Array = []) -> GameState:
	var state := _setup([[V(3, 3), Piece.Type.PHOENIX, WHITE], [V(3, 0), ROOK, BLACK], [V(6, 6), PAWN, WHITE]] + extra)
	_in_match(state)
	state.current_match.turn_side = BLACK
	return state

# One turn of each side ends: black's, then white's (the phoenix owner's).
func _end_round(state: GameState) -> void:
	MatchController.end_turn(state)          # black's turn ends
	MatchController.end_turn(state)          # white's turn ends

func test_a_captured_phoenix_returns_three_of_its_own_turns_later() -> void:
	var state := _phoenix_state()
	var board: Board = state.boards[0]
	var result := _move(state, V(3, 0), V(3, 3))
	MatchController.record_move(state, result)
	check(not (board.pieces.has(V(3, 3)) and board.pieces[V(3, 3)].type == Piece.Type.PHOENIX), "the phoenix is gone for now")
	check_eq(state.current_match.revivals.size(), 1, "waiting to return")
	check(result.notes.any(func(n): return n.contains("return in 3 turns")), str(result.notes))
	board.pieces.erase(V(3, 3))                        # the black rook moves on
	MatchController.end_turn(state)                    # black's turn ends
	MatchController.end_turn(state)                    # white turn 1 ends
	MatchController.end_turn(state)                    # black
	MatchController.end_turn(state)                    # white turn 2 ends
	check(not board.pieces.has(V(3, 3)), "still away after two turns")
	MatchController.end_turn(state)                    # black
	MatchController.end_turn(state)                    # white turn 3 ends
	check(board.pieces.has(V(3, 3)) and board.pieces[V(3, 3)].type == Piece.Type.PHOENIX, "back on its starting square")
	check(board.pieces[V(3, 3)].get("reborn", false), "and marked as reborn")
	check(state.current_match.revivals.is_empty(), "nothing left waiting")

func test_a_phoenix_only_returns_once() -> void:
	var state := _phoenix_state()
	var board: Board = state.boards[0]
	MatchController.record_move(state, _move(state, V(3, 0), V(3, 3)))
	board.pieces.erase(V(3, 3))
	for i in 3:
		_end_round(state)
	check(board.pieces.has(V(3, 3)) and board.pieces[V(3, 3)].type == Piece.Type.PHOENIX, "reborn")
	state.current_match.turn_side = BLACK
	put(board, V(3, 1), ROOK, BLACK)
	var second := _move(state, V(3, 1), V(3, 3))
	MatchController.record_move(state, second)
	check(state.current_match.revivals.is_empty(), "the second death is final")
	check(second.notes.is_empty(), "with no promise of return")

func test_a_phoenix_waits_while_its_square_is_taken() -> void:
	var state := _phoenix_state()
	var board: Board = state.boards[0]
	MatchController.record_move(state, _move(state, V(3, 0), V(3, 3)))          # the rook now sits on the phoenix's square
	for i in 3:
		_end_round(state)
	check(board.pieces[V(3, 3)].type == ROOK, "the rook is still there, so no phoenix")
	check_eq(state.current_match.revivals.size(), 1, "still waiting")
	board.pieces.erase(V(3, 3))
	_end_round(state)
	check(board.pieces.has(V(3, 3)) and board.pieces[V(3, 3)].type == Piece.Type.PHOENIX, "it returns as soon as the square is free")

func test_a_phoenix_outside_a_match_is_just_captured() -> void:
	var state := _setup([[V(3, 3), Piece.Type.PHOENIX, WHITE], [V(3, 0), ROOK, BLACK]])
	var result := _move(state, V(3, 0), V(3, 3))
	check(result.notes.is_empty(), "no match, no rebirth")

func test_a_phoenix_waiting_to_return_is_not_lost_from_the_roster() -> void:
	var run := RunState.new()
	run.begin()
	var id: int = run.add_to_roster(Piece.Type.PHOENIX)
	var lost := Roster.settle(run, [], [id], [])
	check_eq(lost.size(), 1, "an unaccounted-for piece is lost")
	var run2 := RunState.new()
	run2.begin()
	var id2: int = run2.add_to_roster(Piece.Type.PHOENIX)
	check_eq(Roster.settle(run2, [], [id2], [id2]).size(), 0, "one waiting to be reborn survives")
	check(not run2.roster_entry(id2).is_empty(), "and stays in the roster")

# ---- Hydra -----------------------------------------------------------------------------

func test_hydra_moves_up_to_two_squares_in_any_direction() -> void:
	var state := _setup([[V(3, 3), Piece.Type.HYDRA, WHITE]])
	check_eq(Piece.get_legal_moves(Piece.Type.HYDRA, WHITE, state.boards[0], V(3, 3)).size(), 16, "sixteen squares")
	var blocked := _setup([[V(3, 3), Piece.Type.HYDRA, WHITE], [V(3, 2), PAWN, WHITE]])
	check_eq(Piece.get_legal_moves(Piece.Type.HYDRA, WHITE, blocked.boards[0], V(3, 3)).size(), 14, "a friend next to it blocks that square and the one behind it")

func _capture_hydra(hydra_at: Vector2i, attacker_at: Vector2i, others: Array = [], attacker: Piece.Type = ROOK) -> Dictionary:
	var state := _setup([[hydra_at, Piece.Type.HYDRA, WHITE], [attacker_at, attacker, BLACK]] + others)
	var result := _move(state, attacker_at, hydra_at)
	return { "state": state, "board": state.boards[0], "result": result }

func test_a_lonely_hydra_splits_into_four_knights() -> void:
	var out := _capture_hydra(V(3, 3), V(3, 0))
	var board: Board = out.board
	check_eq(_count(board, KNIGHT, WHITE), 4, "four knights")
	for square in [V(4, 3), V(2, 3), V(3, 4), V(3, 2)]:
		check(board.pieces.has(square) and board.pieces[square].type == KNIGHT and board.pieces[square].side == WHITE, "a white knight at %s" % str(square))
	check(board.pieces[V(3, 3)].type == ROOK and board.pieces[V(3, 3)].side == BLACK, "the rook that took it is on the hydra's square")
	check(board.pieces[V(4, 3)].get("spawned", false), "temporary pieces")
	check(out.result.notes.any(func(n): return n.contains("4 knights")), str(out.result.notes))

func test_a_hydra_with_any_piece_beside_it_splits_into_two() -> void:
	var out := _capture_hydra(V(3, 3), V(3, 0), [[V(4, 4), PAWN, BLACK]])
	check_eq(_count(out.board, KNIGHT, WHITE), 2, "two knights")
	var friend := _capture_hydra(V(3, 3), V(3, 0), [[V(2, 2), PAWN, WHITE]])
	check_eq(_count(friend.board, KNIGHT, WHITE), 2, "a friend beside it counts too")

func test_hydra_knights_never_outnumber_the_free_squares() -> void:
	var corner := _capture_hydra(V(0, 3), V(2, 4), [], KNIGHT)      # an edge: five neighbours, all free
	check_eq(_count(corner.board, KNIGHT, WHITE), 4, "four on an edge")
	var tight := _capture_hydra(V(0, 3), V(2, 4), [[V(1, 3), PAWN, BLACK], [V(1, 4), PAWN, BLACK], [V(0, 4), PAWN, BLACK], [V(0, 2), PAWN, BLACK]], KNIGHT)
	check_eq(_count(tight.board, KNIGHT, WHITE), 1, "only one free square is left (1,2), so one knight")
	var boxed_in := _capture_hydra(V(0, 3), V(2, 4), [[V(1, 3), PAWN, BLACK], [V(1, 4), PAWN, BLACK], [V(0, 4), PAWN, BLACK], [V(0, 2), PAWN, BLACK], [V(1, 2), PAWN, BLACK]], KNIGHT)
	check_eq(_count(boxed_in.board, KNIGHT, WHITE), 0, "and none when it is boxed in")
	check(boxed_in.result.notes.any(func(n): return n.contains("0 knights")), str(boxed_in.result.notes))

func test_a_black_hydra_splits_into_black_knights() -> void:
	var state := _setup([[V(3, 3), Piece.Type.HYDRA, BLACK], [V(3, 0), ROOK, WHITE]])
	_move(state, V(3, 0), V(3, 3))
	check_eq(_count(state.boards[0], KNIGHT, BLACK), 4, "the knights belong to the hydra's side")

func test_hydra_knights_are_real_pieces_that_can_move() -> void:
	var out := _capture_hydra(V(3, 3), V(3, 0))
	var moves := Piece.get_legal_moves(KNIGHT, WHITE, out.board, V(4, 3))
	check(not moves.is_empty(), "they can play")
