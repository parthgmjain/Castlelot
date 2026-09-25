extends "res://tests/TestCase.gd"
## Empress, Paladin, Storm Witch, Oracle and Chronomancer.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

func _board(pieces: Array) -> Board:
	var board := make_board(8, 8)
	for p in pieces:
		put(board, p[0], p[1], p[2])
	return board

func _moves(board: Board, from: Vector2i) -> Array:
	var piece: Dictionary = board.pieces[from]
	return Piece.get_legal_moves(piece.type, piece.side, board, from)

func _squares(moves: Array) -> Array:
	return moves.map(func(m): return m.square)

func _can_take(board: Board, from: Vector2i, target: Vector2i) -> bool:
	return _moves(board, from).any(func(m): return m.capture and m.square == target)

func _teleports(moves: Array) -> Array:
	return moves.filter(func(m): return m.get("teleport", false))

# ---- Empress ---------------------------------------------------------------------------

func test_empress_moves_like_a_queen_and_a_knight() -> void:
	var board := _board([[V(3, 3), Piece.Type.EMPRESS, WHITE]])
	var moves := _moves(board, V(3, 3))
	check_eq(moves.size(), 27 + 8, "a queen's 27 squares and a knight's 8")
	var squares := _squares(moves)
	check(squares.has(V(7, 7)) and squares.has(V(3, 0)) and squares.has(V(4, 5)) and squares.has(V(1, 2)), "lines and jumps")

# ---- Paladin ---------------------------------------------------------------------------

func test_paladin_moves_like_a_bishop_and_a_knight() -> void:
	var board := _board([[V(3, 3), Piece.Type.PALADIN, WHITE]])
	var moves := _moves(board, V(3, 3))
	check_eq(moves.size(), 13 + 8, "a bishop's 13 squares and a knight's 8")
	check(not _squares(moves).has(V(3, 2)), "nothing orthogonal")

func test_paladins_neighbours_cannot_be_captured_by_anything() -> void:
	var board := _board([
		[V(3, 3), Piece.Type.PALADIN, WHITE], [V(4, 3), ROOK, WHITE],
		[V(4, 7), ROOK, BLACK], [V(6, 4), KNIGHT, BLACK], [V(5, 0), QUEEN, BLACK], [V(5, 2), PAWN, BLACK],
	])
	for from in [V(4, 7), V(6, 4), V(5, 0), V(5, 2)]:
		check(not _can_take(board, from, V(4, 3)), "%s can't take the rook beside the paladin" % Piece.Type.find_key(board.pieces[from].type))
	board.pieces.erase(V(3, 3))
	check(_can_take(board, V(4, 7), V(4, 3)), "without the paladin the rook can")

func test_the_paladin_itself_and_distant_friends_are_not_covered() -> void:
	var board := _board([[V(3, 3), Piece.Type.PALADIN, WHITE], [V(6, 3), ROOK, WHITE], [V(3, 0), ROOK, BLACK], [V(6, 7), ROOK, BLACK]])
	check(_can_take(board, V(3, 0), V(3, 3)), "the paladin can be taken")
	check(_can_take(board, V(6, 7), V(6, 3)), "so can a friend two squares away")

func test_the_paladins_shield_works_across_a_seam() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, V(4, 2), Piece.Type.PALADIN, WHITE)
	put(b, V(0, 2), ROOK, WHITE)
	put(b, V(3, 2), ROOK, BLACK)
	check(not _can_take(b, V(3, 2), V(0, 2)), "the rook beside the paladin through the seam is safe")

# A white king in the corner, a black rook that can capture it, and a paladin elsewhere.
func _attacked_king_board(extra: Array = []) -> Board:
	return _board([[V(7, 7), KING, WHITE], [V(0, 0), KING, BLACK], [V(7, 0), ROOK, BLACK], [V(2, 4), Piece.Type.PALADIN, WHITE]] + extra)

func test_a_paladin_can_teleport_beside_its_king_when_the_king_is_attacked() -> void:
	var board := _attacked_king_board()
	var teleports := _teleports(_moves(board, V(2, 4)))
	check_eq(_squares(teleports).size(), 3, "the three free squares around a corner king")
	for square in [V(6, 7), V(6, 6), V(7, 6)]:
		check(_squares(teleports).has(square), "can land on %s" % str(square))
	check(teleports.all(func(m): return not m.capture), "a teleport is never a capture")

func test_a_paladin_does_not_teleport_while_its_king_is_safe() -> void:
	var board := _attacked_king_board()
	board.pieces.erase(V(7, 0))
	check(_teleports(_moves(board, V(2, 4))).is_empty(), "no attacker, no teleport")

func test_a_teleport_lands_on_the_chosen_square() -> void:
	var board := _attacked_king_board()
	var state := make_state(board)
	state.active_board = board
	state.active_square = V(2, 4)
	MoveController.refresh(state)
	MoveController.click(state, board, V(6, 6))
	check(board.pieces.has(V(6, 6)) and board.pieces[V(6, 6)].type == Piece.Type.PALADIN and not board.pieces.has(V(2, 4)), "moved across the board in one go")

func test_a_paladin_next_to_its_king_makes_the_king_safe_so_no_teleport_is_needed() -> void:
	var board := _attacked_king_board([[V(6, 7), Piece.Type.PALADIN, WHITE]])
	check(_teleports(_moves(board, V(2, 4))).is_empty(), "the aura already protects the king")
	check(not _can_take(board, V(7, 0), V(7, 7)), "and the rook can't take it")

func test_two_paladins_asking_about_each_others_kings_do_not_recurse_forever() -> void:
	var board := _board([
		[V(7, 7), KING, WHITE], [V(0, 0), KING, BLACK],
		[V(7, 0), ROOK, BLACK], [V(0, 7), ROOK, WHITE],
		[V(2, 2), Piece.Type.PALADIN, WHITE], [V(5, 5), Piece.Type.PALADIN, BLACK],
	])
	check(not _teleports(_moves(board, V(2, 2))).is_empty(), "white's paladin can teleport")
	check(not _teleports(_moves(board, V(5, 5))).is_empty(), "and so can black's")
	check(not PieceMoves.threat_check, "the threat check switched itself off again")

# ---- Storm Witch -----------------------------------------------------------------------

func test_storm_witch_moves_like_a_queen() -> void:
	var board := _board([[V(3, 3), Piece.Type.STORM_WITCH, WHITE]])
	check_eq(_moves(board, V(3, 3)).size(), 27, "a queen's squares when there is nobody to teleport to")

func test_storm_witch_can_teleport_beside_any_enemy() -> void:
	var board := _board([[V(3, 3), Piece.Type.STORM_WITCH, WHITE], [V(6, 6), PAWN, BLACK]])
	var witch := _squares(_moves(board, V(3, 3)))
	var queen_board := _board([[V(3, 3), QUEEN, WHITE], [V(6, 6), PAWN, BLACK]])
	var expected := _squares(_moves(queen_board, V(3, 3)))
	for offset in Piece.KING_OFFSETS:
		if not expected.has(V(6, 6) + offset):
			expected.append(V(6, 6) + offset)                 # the eight squares around the pawn
	for square in expected:
		check(witch.has(square), "the witch can reach %s" % str(square))
	check_eq(witch.size(), expected.size(), "and nowhere else: a queen's moves plus the squares around the pawn")
	check(_teleports(_moves(board, V(3, 3))).all(func(m): return not m.capture), "a teleport is never a capture")

func test_teleport_squares_are_shared_occupied_squares_skipped() -> void:
	var board := _board([[V(3, 3), Piece.Type.STORM_WITCH, WHITE], [V(5, 5), PAWN, BLACK], [V(6, 5), PAWN, BLACK], [V(4, 4), PAWN, WHITE]])
	var teleports := _teleports(_moves(board, V(3, 3)))
	var squares := _squares(teleports)
	check(not squares.has(V(5, 5)) and not squares.has(V(6, 5)) and not squares.has(V(4, 4)), "occupied squares are excluded")
	check_eq(squares.size(), 9, "12 squares around the two pawns, minus the pawns and the white pawn")
	var unique := {}
	for s in squares:
		unique[s] = true
	check_eq(unique.size(), squares.size(), "each square once")

func test_storm_witch_teleports_to_enemies_on_other_boards() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, V(1, 1), Piece.Type.STORM_WITCH, WHITE)
	put(b, V(2, 2), PAWN, BLACK)
	var teleports := _teleports(Piece.get_legal_moves(Piece.Type.STORM_WITCH, WHITE, a, V(1, 1)))
	check(teleports.any(func(m): return m.board == b and m.square == V(1, 1)), "onto board B, beside the pawn")
	check(teleports.size() >= 8, "all around it")

func test_a_boxed_in_enemy_offers_no_teleports() -> void:
	var pieces: Array = [[V(0, 0), Piece.Type.STORM_WITCH, WHITE], [V(5, 5), PAWN, BLACK]]
	for offset in Piece.KING_OFFSETS:
		pieces.append([V(5, 5) + offset, PAWN, BLACK])
	var board := _board(pieces)
	var to_the_middle := _teleports(_moves(board, V(0, 0))).filter(func(m): return m.square.x >= 4 and m.square.x <= 6 and m.square.y >= 4 and m.square.y <= 6)
	check(to_the_middle.is_empty(), "no empty square touches the pawn in the middle")

func test_the_ai_thinking_about_teleports_moves_nothing() -> void:
	var board := _board([[V(7, 7), KING, BLACK], [V(0, 0), KING, WHITE], [V(4, 4), Piece.Type.STORM_WITCH, BLACK], [V(2, 5), ROOK, WHITE]])
	var state := make_state(board)
	var before := board.pieces.duplicate(true)
	for i in 4:
		var choice := GreedyAI.choose_move(state, BLACK)
		check(not choice.is_empty(), "it has a move")
	check_eq(board.pieces.size(), before.size(), "same pieces")
	for square in before:
		check(board.pieces.has(square) and board.pieces[square].type == before[square].type, "untouched: %s" % str(square))

# ---- Oracle -----------------------------------------------------------------------------

func test_oracle_moves_up_to_three_squares_in_any_direction() -> void:
	var board := _board([[V(3, 3), Piece.Type.ORACLE, WHITE]])
	check_eq(_moves(board, V(3, 3)).size(), 24, "eight directions, three squares each")
	var blocked := _board([[V(3, 3), Piece.Type.ORACLE, WHITE], [V(3, 2), PAWN, WHITE]])
	check_eq(_moves(blocked, V(3, 3)).size(), 21, "a friend blocks that line")

func _oracle_game(other: Array = []) -> Dictionary:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	put(board, V(3, 3), Piece.Type.ORACLE, WHITE)
	for p in other:
		put(board, p[0], p[1], p[2])
	main.run_flow.start_match(6, 9999)
	main.turn_flow.ai_delay = 5.0
	return { "main": main, "board": board, "state": main.state, "match": main.state.current_match }

func test_turns_are_counted_per_side() -> void:
	var g := await _oracle_game()
	check_eq(g.match.turns_taken[WHITE], 0, "none yet")
	g.main._on_square_selected(V(3, 3), g.board)
	g.main._on_square_selected(V(3, 2), g.board)
	check_eq(g.match.turns_taken[WHITE], 1, "white finished one turn")
	check_eq(g.match.turns_taken[BLACK], 0, "black none")

func test_the_oracles_first_turn_is_an_ordinary_one() -> void:
	var g := await _oracle_game()
	g.main._on_square_selected(V(3, 3), g.board)
	g.main._on_square_selected(V(3, 1), g.board)
	check(g.match.bonus.is_empty(), "no double turn yet")
	check_eq(g.match.turn_side, BLACK, "the turn passes")

func test_on_every_second_turn_the_oracle_moves_twice() -> void:
	var g := await _oracle_game([[V(6, 6), ROOK, WHITE]])
	g.match.turns_taken[WHITE] = 1                      # this is white's second turn
	g.main._on_square_selected(V(3, 3), g.board)
	g.main._on_square_selected(V(3, 1), g.board)
	check_eq(g.match.bonus.get("kind"), "repeat", "the oracle may move again")
	check_eq(g.match.turn_side, WHITE, "the turn hasn't passed")
	check(g.main.panel.match_status_label.text.contains("double turn"), g.main.panel.match_status_label.text)
	g.main._on_square_selected(V(6, 6), g.board)
	check(g.state.current_moves.is_empty(), "nobody else can move")
	g.main._on_square_selected(V(3, 1), g.board)
	check_eq(g.state.current_moves.size(), 18, "the oracle has its full range from (3,1): up to three squares each way, cut short by the top edge")
	g.main._on_square_selected(V(6, 1), g.board)
	check(g.match.bonus.is_empty(), "the second move ends the double turn")
	check_eq(g.match.moves_left, 5, "and the pair cost a single move")
	check_eq(g.match.turn_side, BLACK, "then the turn passes")
	check(g.board.pieces.has(V(6, 1)) and g.board.pieces[V(6, 1)].type == Piece.Type.ORACLE, "the oracle ended up two moves away from where it began")

func test_moving_another_piece_on_the_second_turn_earns_nothing() -> void:
	var g := await _oracle_game([[V(6, 6), ROOK, WHITE]])
	g.match.turns_taken[WHITE] = 1
	g.main._on_square_selected(V(6, 6), g.board)
	g.main._on_square_selected(V(6, 5), g.board)
	check(g.match.bonus.is_empty(), "only the oracle's own moves double up")

func test_the_double_turn_can_be_skipped_and_repeats_every_second_turn() -> void:
	var g := await _oracle_game()
	g.match.turns_taken[WHITE] = 1
	g.main._on_square_selected(V(3, 3), g.board)
	g.main._on_square_selected(V(3, 1), g.board)
	g.main.panel.skip_bonus_button.pressed.emit()
	check(g.match.bonus.is_empty() and g.match.turn_side == BLACK, "skipped")
	var result := { "piece": { "type": Piece.Type.ORACLE, "side": WHITE }, "board": g.board, "square": V(3, 1), "victims": [], "losses": [] }
	for taken in [0, 1, 2, 3, 4, 5]:
		g.match.turns_taken[WHITE] = taken
		var earns := not MoveEffects.bonus_after(g.state, result, false).is_empty()
		check_eq(earns, taken % 2 == 1, "turn %d" % (taken + 1))
	check(MoveEffects.bonus_after(g.state, result, true).is_empty(), "a bonus move never earns another")

# ---- Chronomancer ---------------------------------------------------------------------------

func test_chronomancer_moves_like_a_bishop() -> void:
	var board := _board([[V(3, 3), Piece.Type.CHRONOMANCER, WHITE]])
	check_eq(_moves(board, V(3, 3)).size(), 13, "a bishop's squares")

# A game where black has just captured white's rook: white to move with a Chronomancer.
func _time_game() -> Dictionary:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	put(board, V(1, 6), Piece.Type.CHRONOMANCER, WHITE)
	put(board, V(6, 6), PAWN, WHITE)
	put(board, V(4, 7), ROOK, WHITE)["roster_id"] = 7
	put(board, V(4, 0), ROOK, BLACK)
	main.run_flow.start_match(6, 9999)
	main.turn_flow.ai_delay = 5.0
	var g := { "main": main, "board": board, "state": main.state, "match": main.state.current_match }
	main._on_square_selected(V(6, 6), board)                  # white moves a pawn
	main._on_square_selected(V(6, 5), board)
	g.state.active_board = board                               # black's rook takes white's rook
	g.state.active_square = V(4, 0)
	MoveController.refresh(g.state)
	main.turn_flow.after_move(MoveController.click(g.state, board, V(4, 7)))
	return g

func test_a_chronomancer_can_rewind_the_opponents_last_move() -> void:
	var g := await _time_game()
	var board: Board = g.board
	var current: MatchState = g.match
	check_eq(current.scores[BLACK], Piece.value(ROOK) * Scoring.CHIPS_PER_VALUE, "black took the rook")
	check_eq(current.turn_side, WHITE, "white's turn")
	g.main._on_square_selected(V(1, 6), board)
	check(board.special_squares.has(V(4, 7)), "the rewind is offered on the black rook that just moved")
	check(g.main.panel.match_status_label.text.contains("Right-click"), "and the status line says how")
	var moves_before: int = current.moves_left
	g.main._on_square_right_clicked(V(4, 7), board)
	check(board.pieces[V(4, 7)].type == ROOK and board.pieces[V(4, 7)].side == WHITE, "white's rook is back")
	check(board.pieces[V(4, 0)].type == ROOK and board.pieces[V(4, 0)].side == BLACK, "and black's rook is back where it started")
	check_eq(board.pieces[V(4, 7)].get("roster_id"), 7, "it is still the same roster piece")
	check(board.pieces.has(V(6, 5)) and not board.pieces.has(V(6, 6)), "white's own earlier pawn move stands")
	check_eq(current.scores[BLACK], 0, "black's score from that capture is gone")
	check_eq(current.turn_side, WHITE, "it is still white's turn")
	check_eq(current.moves_left, moves_before, "and rewinding was free")
	check(current.last_event.contains("turned back time"), current.last_event)
	check(board.pieces[V(1, 6)].get("undo_used", false), "the chronomancer is spent")

func test_the_rewind_is_once_only_and_the_turn_carries_on() -> void:
	var g := await _time_game()
	var board: Board = g.board
	g.main._on_square_selected(V(1, 6), board)
	g.main._on_square_right_clicked(V(4, 7), board)
	g.main._on_square_selected(V(1, 6), board)
	check(g.state.current_moves.all(func(m): return not m.get("undo", false)), "no second rewind")
	check(board.special_squares.is_empty(), "no orange ring either")
	g.main._on_square_selected(V(4, 7), board)                 # and white can play on: rook takes rook
	g.main._on_square_selected(V(4, 0), board)
	check(board.pieces[V(4, 0)].side == WHITE, "the game goes on normally")
	check_eq(g.match.turn_side, BLACK, "and the turn passes after a real move")

func test_a_rewind_undoes_every_effect_of_the_move() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.pieces.clear()
	for p in [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE], [V(1, 6), Piece.Type.CHRONOMANCER, WHITE],
			[V(4, 7), Piece.Type.TORCHBEARER, WHITE], [V(4, 0), ROOK, BLACK], [V(6, 6), PAWN, WHITE]]:
		put(board, p[0], p[1], p[2])
	main.run_flow.start_match(6, 9999)
	main.turn_flow.ai_delay = 5.0
	main._on_square_selected(V(6, 6), board)
	main._on_square_selected(V(6, 5), board)
	main.state.active_board = board
	main.state.active_square = V(4, 0)
	MoveController.refresh(main.state)
	main.turn_flow.after_move(MoveController.click(main.state, board, V(4, 7)))
	check(not board.pieces.has(V(4, 7)) and not board.pieces.has(V(4, 0)), "the torchbearer's flame took both pieces")
	check_eq(main.state.current_match.scores[WHITE], Piece.value(ROOK) * Scoring.CHIPS_PER_VALUE, "and white scored for it")
	main._on_square_selected(V(1, 6), board)
	check(main.state.current_moves.any(func(m): return m.get("undo", false)), "the rewind is offered even though the black rook is gone")
	main._on_square_right_clicked(main.state.current_moves.filter(func(m): return m.get("undo", false))[0].square, board)
	check(board.pieces.has(V(4, 7)) and board.pieces.has(V(4, 0)), "both pieces are back")
	check_eq(main.state.current_match.scores[WHITE], 0, "and the score with them")

func test_no_rewind_without_a_match_or_right_after_your_own_move() -> void:
	var board := _board([[V(1, 6), Piece.Type.CHRONOMANCER, WHITE], [V(7, 7), KING, WHITE], [V(0, 0), KING, BLACK], [V(4, 0), ROOK, BLACK]])
	var state := make_state(board)
	check(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).is_empty(), "no match, no history")
	MatchController.start(state, 10, 999)
	check(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).is_empty(), "nothing has been played yet")
	state.current_match.history.append({ "side": WHITE, "end": { "board": board, "square": V(4, 4) }, "boards": [], "scores": {}, "revivals": [], "last_event": "" })
	check(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).is_empty(), "the last move was white's own")
	state.current_match.history.append({ "side": BLACK, "end": { "board": board, "square": V(4, 4) }, "boards": [], "scores": {}, "revivals": [], "last_event": "" })
	check_eq(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).size(), 1, "black moved last, so it's offered")

func test_the_ai_never_uses_the_rewind() -> void:
	var board := _board([[V(1, 6), Piece.Type.CHRONOMANCER, BLACK], [V(7, 7), KING, WHITE], [V(0, 0), KING, BLACK]])
	var state := make_state(board)
	MatchController.start(state, 10, 999)
	# the "rewind" target sits right beside the white king, which would look very tempting to a greedy AI that could use it
	state.current_match.history.append({ "side": WHITE, "end": { "board": board, "square": V(6, 7) }, "boards": [], "scores": {}, "revivals": [], "last_event": "" })
	check_eq(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).size(), 1, "the option exists for it")
	for i in 10:
		var choice := GreedyAI.choose_move(state, BLACK)
		check(not choice.move.get("undo", false), "the AI never picks it")

func test_a_chronomancer_that_has_rewound_once_cannot_do_it_again_even_if_black_moved_twice() -> void:
	var board := _board([[V(1, 6), Piece.Type.CHRONOMANCER, WHITE], [V(7, 7), KING, WHITE], [V(0, 0), KING, BLACK], [V(4, 0), ROOK, BLACK]])
	var state := make_state(board)
	MatchController.start(state, 10, 999)
	for i in 2:                                        # two black moves in a row (a bonus move, say)
		var entry := MoveEffects.take_snapshot(state, BLACK)
		entry["end"] = { "board": board, "square": V(4, 4) }
		state.current_match.history.append(entry)
	check_eq(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).size(), 1, "available at first")
	MoveEffects.rewind(state, board, V(1, 6))
	check_eq(state.current_match.history.size(), 1, "one entry is left, and it is black's too")
	check(MoveEffects.action_moves(state, board.pieces[V(1, 6)]).is_empty(), "but the chronomancer has used its one rewind")

