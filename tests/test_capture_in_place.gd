extends "res://tests/TestCase.gd"
## Attacks that don't move the piece (Archer, Catapult, Dragon), multi-captures (Titan),
## resting, and the right-click that triggers them.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# `others` = [[square, type, side], ...]. Returns the state with the piece at `from` selected.
func _setup(type: Piece.Type, from: Vector2i, others: Array = [], side: Piece.Side = WHITE) -> GameState:
	var board := make_board(8, 8)
	var state := make_state(board, [[from, type, side], [V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE]])
	for other in others:
		put(board, other[0], other[1], other[2])
	state.active_board = board
	state.active_square = from
	MoveController.refresh(state)
	return state

# Starting a match clears the selection, so pick the piece up again afterwards.
func _start_match_and_reselect(state: GameState, board: Board, square: Vector2i) -> void:
	MatchController.start(state, 20, 999)
	state.active_board = board
	state.active_square = square
	MoveController.refresh(state)

func _special(state: GameState) -> Array:
	return state.current_moves.filter(func(m): return m.get("special", false))

func _normal(state: GameState) -> Array:
	return state.current_moves.filter(func(m): return not m.get("special", false))

func _squares(moves: Array) -> Array:
	return moves.map(func(m): return m.square)

# ---- Archer ----------------------------------------------------------------------

func test_archer_steps_forward_and_shoots_two_squares_ahead() -> void:
	var state := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 2), PAWN, BLACK]])
	check_eq(_squares(_normal(state)), [V(3, 3)], "it walks one square forward")
	var shots := _special(state)
	check_eq(shots.size(), 1, "one shot")
	check(shots[0].square == V(3, 2) and shots[0].stay and shots[0].capture, "at the enemy two ahead, without moving")

func test_archer_needs_a_clear_line_and_cannot_hit_the_adjacent_square() -> void:
	var adjacent := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 3), PAWN, BLACK], [V(3, 2), PAWN, BLACK]])
	check(_special(adjacent).is_empty(), "an enemy in the way stops the arrow")
	check(_normal(adjacent).is_empty(), "and it can't walk into it or capture it")
	var friend := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 3), PAWN, WHITE], [V(3, 2), PAWN, BLACK]])
	check(_special(friend).is_empty(), "a friend in the way stops it too")
	var far := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 1), PAWN, BLACK]])
	check(_special(far).is_empty(), "three squares is too far")
	var own := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 2), PAWN, WHITE]])
	check(_special(own).is_empty(), "it doesn't shoot friends")

func test_an_archer_shot_removes_the_victim_and_the_archer_stays() -> void:
	var state := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 2), ROOK, BLACK]])
	var board: Board = state.active_board
	var result := MoveController.click(state, board, V(3, 2), true)
	check(not board.pieces.has(V(3, 2)), "the rook is gone")
	check(board.pieces.has(V(3, 4)) and board.pieces[V(3, 4)].type == Piece.Type.ARCHER, "the archer didn't move")
	check(not board.pieces.has(V(3, 3)), "nothing else moved")
	check_eq(result.victims.size(), 1, "one victim")
	check(result.board == board and result.square == V(3, 4), "the result says the archer is still at home")

func test_left_clicking_a_shot_target_also_fires_when_nothing_else_is_there() -> void:
	var state := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 2), PAWN, BLACK]])
	var result := MoveController.click(state, state.active_board, V(3, 2))
	check(not result.is_empty() and state.boards[0].pieces.has(V(3, 4)) and not state.boards[0].pieces.has(V(3, 2)), "a plain click on the only meaning of that square fires")

func test_a_right_click_does_nothing_without_a_special_move() -> void:
	var state := _setup(Piece.Type.ARCHER, V(3, 4))
	var board: Board = state.active_board
	check(MoveController.click(state, board, V(3, 3), true).is_empty(), "the walk isn't special")
	check(board.pieces.has(V(3, 4)) and not board.pieces.has(V(3, 3)), "and nothing happened")
	check(state.active_square == V(3, 4), "the archer is still selected")

func test_the_shot_is_marked_orange_and_moves_are_not() -> void:
	var state := _setup(Piece.Type.ARCHER, V(3, 4), [[V(3, 2), PAWN, BLACK]])
	var board: Board = state.active_board
	check_eq(board.special_squares, [V(3, 2)], "the orange ring")
	check_eq(board.move_squares, [V(3, 3)], "the green dot")
	check(board.capture_squares.is_empty(), "no red ring for a special-only target")

func test_an_archer_shoots_across_a_portal() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	var state := GameState.new()
	state.boards = [a, b]
	put(a, V(3, 2), Piece.Type.ARCHER, WHITE)
	put(b, V(0, 2), PAWN, BLACK)                   # forward is right: one step to (4,2), the next crosses the seam
	for row in 5:
		b.zone_owner[V(4, row)] = BLACK
	var moves := Piece.get_legal_moves(Piece.Type.ARCHER, WHITE, a, V(3, 2))
	check(moves.any(func(m): return m.get("special", false) and m.board == b and m.square == V(0, 2)), "the shot lands on board B")

# ---- Catapult ----------------------------------------------------------------------

func test_catapult_never_moves_and_hits_exactly_three_away_over_blockers() -> void:
	var state := _setup(Piece.Type.CATAPULT, V(3, 3), [
		[V(3, 4), PAWN, WHITE], [V(3, 5), PAWN, BLACK], [V(3, 6), ROOK, BLACK],     # down: blockers, an enemy at 2, an enemy at 3
		[V(5, 3), PAWN, BLACK],                                                     # right: only at 2
		[V(0, 3), PAWN, WHITE],                                                     # left: a friend at 3
		[V(3, 0), QUEEN, BLACK],                                                    # up: an enemy at 3, nothing in the way
	])
	check(_normal(state).is_empty(), "it has no ordinary moves")
	check_eq(_squares(_special(state)).size(), 2, "two targets")
	check(_squares(_special(state)).has(V(3, 6)) and _squares(_special(state)).has(V(3, 0)), "the rook and queen three squares away")

func test_catapult_fires_and_stays() -> void:
	var state := _setup(Piece.Type.CATAPULT, V(3, 3), [[V(3, 6), ROOK, BLACK]])
	var board: Board = state.active_board
	MoveController.click(state, board, V(3, 6), true)
	check(board.pieces.has(V(3, 3)) and not board.pieces.has(V(3, 6)), "it stays and the target falls")

func test_a_catapult_alone_counts_as_having_a_move_only_with_a_target() -> void:
	var idle := _setup(Piece.Type.CATAPULT, V(3, 3))
	check(idle.current_moves.is_empty(), "no target, no moves")
	var armed := _setup(Piece.Type.CATAPULT, V(3, 3), [[V(3, 6), ROOK, BLACK]])
	check(MatchController.has_legal_move(armed, WHITE), "a target counts as a legal move for the no-moves-left rule")

# ---- Titan ----------------------------------------------------------------------------

func test_titan_moves_like_a_rook_and_can_take_two_pieces_in_one_move() -> void:
	var state := _setup(Piece.Type.TITAN, V(3, 5), [[V(3, 3), PAWN, BLACK], [V(3, 1), ROOK, BLACK]])
	var board: Board = state.active_board
	var double := state.current_moves.filter(func(m): return m.square == V(3, 1))
	check_eq(double.size(), 1, "the far piece can be reached")
	check_eq(double[0].hits.size(), 1, "taking the near one on the way")
	check(state.current_moves.any(func(m): return m.square == V(3, 3) and m.capture and not m.has("hits")), "the ordinary single capture is still there")
	check(state.current_moves.any(func(m): return m.square == V(3, 4) and not m.capture), "and ordinary rook moves")
	var result := MoveController.click(state, board, V(3, 1))
	check(not board.pieces.has(V(3, 3)) and board.pieces.has(V(3, 1)) and board.pieces[V(3, 1)].type == Piece.Type.TITAN, "both are gone and the titan is on the far square")
	check_eq(result.victims.size(), 2, "two victims")
	check(not board.pieces.has(V(3, 5)), "it left its start")

func test_titan_cannot_take_a_second_piece_through_a_friend_or_a_third() -> void:
	var blocked := _setup(Piece.Type.TITAN, V(3, 5), [[V(3, 3), PAWN, BLACK], [V(3, 2), PAWN, WHITE], [V(3, 1), ROOK, BLACK]])
	check(not _squares(blocked.current_moves).has(V(3, 1)), "a friend behind the first victim blocks it")
	var three := _setup(Piece.Type.TITAN, V(3, 5), [[V(3, 3), PAWN, BLACK], [V(3, 2), PAWN, BLACK], [V(3, 1), ROOK, BLACK]])
	check(_squares(three.current_moves).has(V(3, 2)), "it can take the first two")
	check(not _squares(three.current_moves).has(V(3, 1)), "but never a third")

# ---- Dragon -----------------------------------------------------------------------------

func test_dragon_fire_burns_every_enemy_within_three_in_a_line() -> void:
	var state := _setup(Piece.Type.DRAGON, V(3, 3), [
		[V(3, 4), PAWN, BLACK], [V(3, 5), PAWN, WHITE], [V(3, 6), ROOK, BLACK],        # down: enemy, friend (passed over), enemy at 3
		[V(3, 7), PAWN, BLACK],                                                          # down: too far (4)
		[V(6, 3), PAWN, BLACK],                                                          # right: one enemy at 3
	])
	var fire := _special(state)
	var down := fire.filter(func(m): return m.hits.size() == 2)
	check_eq(down.size(), 2, "each burnt square is a target for the two-victim line")
	check(_squares(down).has(V(3, 4)) and _squares(down).has(V(3, 6)), "the two enemies in range")
	check(not fire.any(func(m): return m.square == V(3, 5)), "the friend is not a target")
	check(fire.any(func(m): return m.square == V(6, 3) and m.hits.size() == 1), "the lone enemy to the right")
	check(not fire.any(func(m): return m.square == V(3, 7)), "nothing beyond three squares")

func test_dragon_fire_kills_the_line_and_the_dragon_stays() -> void:
	var state := _setup(Piece.Type.DRAGON, V(3, 3), [[V(3, 4), PAWN, BLACK], [V(3, 5), PAWN, WHITE], [V(3, 6), ROOK, BLACK]])
	var board: Board = state.active_board
	var result := MoveController.click(state, board, V(3, 4), true)
	check(not board.pieces.has(V(3, 4)) and not board.pieces.has(V(3, 6)), "both enemies burn")
	check(board.pieces.has(V(3, 5)) and board.pieces[V(3, 5)].side == WHITE, "the friend is untouched")
	check(board.pieces.has(V(3, 3)) and board.pieces[V(3, 3)].type == Piece.Type.DRAGON, "the dragon is where it was")
	check_eq(result.victims.size(), 2, "two victims")

func test_left_and_right_click_on_the_same_square_do_different_things() -> void:
	var walk := _setup(Piece.Type.DRAGON, V(3, 3), [[V(3, 4), PAWN, BLACK], [V(3, 6), ROOK, BLACK]])
	var b1: Board = walk.active_board
	check_eq(b1.capture_squares.has(V(3, 4)) and b1.special_squares.has(V(3, 4)), true, "both rings show on the adjacent enemy")
	MoveController.click(walk, b1, V(3, 4))
	check(b1.pieces.has(V(3, 4)) and b1.pieces[V(3, 4)].type == Piece.Type.DRAGON and not b1.pieces.has(V(3, 3)), "a left click is the ordinary rook capture")
	check(b1.pieces.has(V(3, 6)), "and burns nothing else")

func test_dragon_rests_for_one_of_its_sides_turns_after_firing() -> void:
	var state := _setup(Piece.Type.DRAGON, V(3, 3), [[V(3, 4), PAWN, BLACK]])
	var board: Board = state.active_board
	_start_match_and_reselect(state, board, V(3, 3))
	var result := MoveController.click(state, board, V(3, 4), true)
	MatchController.record_move(state, result)
	MatchController.end_turn(state)                               # white's turn ends
	check_eq(state.current_match.turn_side, BLACK, "black's turn")
	MatchController.end_turn(state)                               # black's turn ends
	check_eq(state.current_match.turn_side, WHITE, "white again")
	check(Piece.get_legal_moves(Piece.Type.DRAGON, WHITE, board, V(3, 3)).is_empty(), "the dragon rests through this turn")
	MatchController.end_turn(state)                               # white's turn ends without the dragon
	MatchController.end_turn(state)                               # black's turn ends
	check(not Piece.get_legal_moves(Piece.Type.DRAGON, WHITE, board, V(3, 3)).is_empty(), "and can act the turn after")

func test_a_dragon_in_the_sandbox_never_gets_stuck_resting() -> void:
	var state := _setup(Piece.Type.DRAGON, V(3, 3), [[V(3, 4), PAWN, BLACK]])
	var board: Board = state.active_board
	MoveController.click(state, board, V(3, 4), true)
	check_eq(board.pieces[V(3, 3)].get("rest", 0), 0, "no match means no rest")

# ---- scoring and the AI ---------------------------------------------------------------

func test_every_victim_of_a_multi_capture_scores() -> void:
	var state := _setup(Piece.Type.TITAN, V(3, 5), [[V(3, 3), PAWN, BLACK], [V(3, 1), ROOK, BLACK]])
	_start_match_and_reselect(state, state.active_board, V(3, 5))
	var result := MoveController.click(state, state.active_board, V(3, 1))
	MatchController.record_move(state, result)
	check_eq(state.current_match.scores[WHITE], (Piece.value(PAWN) + Piece.value(ROOK)) * Scoring.CHIPS_PER_VALUE, "pawn and rook")
	check(state.current_match.last_event.contains("Pawn") and state.current_match.last_event.contains("Rook") and state.current_match.last_event.contains(" and a "), state.current_match.last_event)

func test_burning_a_king_wins_the_match() -> void:
	var state := _setup(Piece.Type.DRAGON, V(3, 3), [[V(3, 4), PAWN, BLACK], [V(3, 5), KING, BLACK]])
	_start_match_and_reselect(state, state.active_board, V(3, 3))
	var result := MoveController.click(state, state.active_board, V(3, 4), true)
	MatchController.record_move(state, result)
	check_eq(state.current_match.result, "win", "the king was in the flames")

func test_the_ai_uses_fire_and_leaves_the_board_consistent_when_it_thinks() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [
		[V(7, 7), KING, BLACK], [V(0, 0), KING, WHITE],
		[V(3, 3), Piece.Type.DRAGON, BLACK],
		[V(3, 4), PAWN, WHITE], [V(3, 5), ROOK, WHITE], [V(3, 6), QUEEN, WHITE],
	])
	var before := board.pieces.duplicate(true)
	var choice := GreedyAI.choose_move(state, BLACK)
	check_eq(board.pieces.size(), before.size(), "thinking leaves every piece where it was")
	for square in before:
		check(board.pieces.has(square) and board.pieces[square].type == before[square].type, "still there: %s" % str(square))
	check(choice.move.get("special", false) and choice.move.hits.size() == 3, "the AI breathes fire on all three")
	var result := MoveController.execute(state, choice.move) if _select(state, choice) else {}
	check_eq(result.victims.size(), 3, "and it works")

func _select(state: GameState, choice: Dictionary) -> bool:
	state.active_board = choice.board
	state.active_square = choice.square
	return true

func test_the_ai_takes_two_pieces_with_a_titan_when_it_can() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [
		[V(7, 7), KING, BLACK], [V(0, 0), KING, WHITE],
		[V(3, 1), Piece.Type.TITAN, BLACK], [V(3, 3), QUEEN, WHITE], [V(3, 6), ROOK, WHITE],
	])
	var choice := GreedyAI.choose_move(state, BLACK)
	check(choice.move.square == V(3, 6) and choice.move.hits.size() == 1, "queen and rook in one move")

# ---- through the real game --------------------------------------------------------------

func test_a_right_click_attack_costs_a_move_and_passes_the_turn() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	board.pieces.clear()
	put(board, V(3, 4), Piece.Type.ARCHER, WHITE)
	put(board, V(3, 2), PAWN, BLACK)
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	main.run_flow.start_match(5, 999)
	main.turn_flow.ai_delay = 5.0                     # keep the AI from replying during the check
	main._on_square_selected(V(3, 4), board)
	check(board.special_squares.has(V(3, 2)), "the shot is offered")
	check(main.panel.match_status_label.text.contains("Right-click"), "and the status line says how to use it: %s" % main.panel.match_status_label.text)
	main._on_square_right_clicked(V(3, 2), board)
	check(not board.pieces.has(V(3, 2)) and board.pieces.has(V(3, 4)), "the pawn fell and the archer stayed")
	check_eq(main.state.current_match.moves_left, 4, "it used a move")
	check_eq(main.state.current_match.turn_side, BLACK, "and the AI is up")
	check_eq(main.state.current_match.scores[WHITE], Piece.value(PAWN) * Scoring.CHIPS_PER_VALUE, "and scored")

func test_boss_rewards_are_not_for_sale() -> void:
	for type in [Piece.Type.TITAN, Piece.Type.DRAGON]:
		check(Piece.is_reward_only(type) and Piece.tier(type) == Piece.Tier.LEGENDARY, "%s is a legendary reward" % Piece.Type.find_key(type))
		check(not Lottery.pool(Piece.Tier.LEGENDARY).has(type), "not in the lottery")
	check(not Piece.is_reward_only(Piece.Type.ARCHER) and not Piece.is_reward_only(QUEEN), "the others are ordinary")
