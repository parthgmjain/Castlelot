extends "res://tests/TestCase.gd"
## Turns, the move counter, scoring, and the win/loss conditions.

class DoubleKnights extends ScoreModifier:
	func on_capture(context: Dictionary) -> void:
		if context.attacker.type == Piece.Type.KNIGHT:
			context.mult *= 2.0

class FlatBonus extends ScoreModifier:
	func on_capture(context: Dictionary) -> void:
		context.chips += 5

# One full player move (select, then move) followed by the bookkeeping Main does.
func _play(state: GameState, from: Vector2i, to: Vector2i) -> void:
	var board: Board = state.boards[0]
	check(MatchController.accepts_click(state, board, from), "can select %s" % str(from))
	MoveController.click(state, board, from)
	check(MatchController.accepts_click(state, board, to), "can move to %s" % str(to))
	var result := MoveController.click(state, board, to)
	check(not result.is_empty(), "the move happened")
	MatchController.record_move(state, result)
	MatchController.end_turn(state)

func test_a_match_needs_both_kings() -> void:
	var state := make_state(make_board(), [[Vector2i(0, 7), KING, WHITE]])
	check(MatchController.start(state, 5, 30) != "", "refuses to start")
	check(not state.current_match.active, "not active")

func test_capture_values_and_modifiers() -> void:
	var board := make_board()
	var match_state := MatchState.new()
	var rook := { "type": ROOK, "side": WHITE }
	for pair in [[PAWN, 10], [KNIGHT, 30], [BISHOP, 30], [ROOK, 50], [QUEEN, 90]]:
		check_eq(Scoring.capture_score(match_state, rook, { "type": pair[0], "side": BLACK }, board, Vector2i.ZERO), pair[1], "value of %s" % Piece.Type.find_key(pair[0]))
	var promoted := { "type": PAWN, "side": BLACK }
	PawnMovement.promote(promoted, QUEEN)
	check_eq(Scoring.capture_score(match_state, rook, promoted, board, Vector2i.ZERO), 90, "a promoted pawn scores as its new type")
	match_state.modifiers = [DoubleKnights.new(), FlatBonus.new()]
	var knight := { "type": KNIGHT, "side": WHITE }
	check_eq(Scoring.capture_score(match_state, knight, { "type": ROOK, "side": BLACK }, board, Vector2i.ZERO), 110, "(50 + 5) x 2")
	check_eq(Scoring.capture_score(match_state, rook, { "type": ROOK, "side": BLACK }, board, Vector2i.ZERO), 55, "rook attacker isn't doubled")

func test_turns_the_move_counter_and_player_only_selection() -> void:
	var state := make_state(make_board(), [
		[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK],
		[Vector2i(3, 3), ROOK, WHITE], [Vector2i(3, 0), PAWN, BLACK], [Vector2i(6, 6), PAWN, BLACK],
	])
	check_eq(MatchController.start(state, 3, 60), "", "starts")
	var current := state.current_match
	var board: Board = state.boards[0]
	check(current.active and current.turn_side == WHITE and current.moves_left == 3, "white to move with 3 moves")
	check(not MatchController.accepts_click(state, board, Vector2i(3, 0)), "an enemy piece can't be selected")
	check(not MatchController.accepts_click(state, board, Vector2i(5, 5)), "neither can an empty square")
	_play(state, Vector2i(3, 3), Vector2i(3, 0))
	check_eq(current.scores[WHITE], 10, "pawn scored")
	check_eq(current.moves_left, 2, "one move spent")
	check_eq(current.turn_side, BLACK, "turn passes")
	check(not MatchController.accepts_click(state, board, Vector2i(3, 0)) and not MatchController.accepts_click(state, board, Vector2i(0, 7)), "the player is locked out on the AI's turn")
	MatchController.end_turn(state)
	check(current.turn_side == WHITE and current.moves_left == 2, "the AI's turn ending costs the player nothing")
	check(current.last_event.begins_with("You took a Pawn"), current.last_event)

func test_capturing_the_king_wins_instantly() -> void:
	var state := make_state(make_board(), [[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK], [Vector2i(3, 0), ROOK, WHITE]])
	MatchController.start(state, 5, 999)
	_play(state, Vector2i(3, 0), Vector2i(7, 0))
	check(not state.current_match.active and state.current_match.result == "win" and state.current_match.result_reason == "King captured", "instant win")

func test_a_winning_move_counts_as_a_spent_move() -> void:
	var state := make_state(make_board(), [[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK], [Vector2i(3, 0), ROOK, WHITE]])
	MatchController.start(state, 10, 999)
	_play(state, Vector2i(3, 0), Vector2i(7, 0))
	check_eq(state.current_match.moves_left, 9, "one of ten moves was used to win")

func test_reaching_the_target_score_wins_at_once() -> void:
	var state := make_state(make_board(), [[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK], [Vector2i(2, 2), KNIGHT, WHITE], [Vector2i(4, 3), ROOK, BLACK]])
	MatchController.start(state, 5, 50)
	_play(state, Vector2i(2, 2), Vector2i(4, 3))
	check(state.current_match.result == "win" and state.current_match.result_reason == "Target score reached", "win on target")

func test_using_the_last_move_without_the_target_loses() -> void:
	var state := make_state(make_board(), [[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK], [Vector2i(1, 1), ROOK, WHITE]])
	MatchController.start(state, 2, 100)
	_play(state, Vector2i(1, 1), Vector2i(1, 2))
	check(state.current_match.active and state.current_match.moves_left == 1, "still going")
	MatchController.end_turn(state)
	_play(state, Vector2i(1, 2), Vector2i(1, 3))
	check(state.current_match.result == "loss" and state.current_match.result_reason == "Out of moves", "out of moves")

func test_the_ai_taking_your_king_loses() -> void:
	var board := make_board()
	var state := make_state(board, [[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK], [Vector2i(0, 0), ROOK, BLACK]])
	MatchController.start(state, 5, 100)
	MatchController.end_turn(state)
	check_eq(state.current_match.turn_side, BLACK, "the AI's turn")
	state.active_board = board
	state.active_square = Vector2i(0, 0)
	var result := MoveController.execute(state, { "board": board, "square": Vector2i(0, 7), "capture": true })
	MatchController.record_move(state, result)
	check(state.current_match.result == "loss" and state.current_match.result_reason == "King captured", "loss")

func test_a_player_with_no_legal_moves_loses_instead_of_deadlocking() -> void:
	var a := make_board(1, 1)
	var b := make_board(1, 1)
	var state := GameState.new()
	state.boards = [a, b]
	put(a, Vector2i(0, 0), KING, WHITE)
	put(b, Vector2i(0, 0), KING, BLACK)
	check_eq(MatchController.start(state, 5, 100), "", "starts")
	check(not MatchController.has_legal_move(state, WHITE), "white's king is boxed in")
	state.current_match.turn_side = BLACK
	MatchController.end_turn(state)
	check(state.current_match.result == "loss" and state.current_match.result_reason == "No legal moves", "loss")

func test_status_text_describes_each_phase() -> void:
	var state := make_state(make_board(), [[Vector2i(0, 7), KING, WHITE], [Vector2i(7, 0), KING, BLACK], [Vector2i(3, 0), ROOK, WHITE]])
	check_eq(MatchController.status_text(state), "", "blank before any match")
	MatchController.start(state, 5, 60)
	check(MatchController.status_text(state).begins_with("Your turn | Moves left: 5 | Score 0/60"), MatchController.status_text(state))
	_play(state, Vector2i(3, 0), Vector2i(7, 0))
	check(MatchController.status_text(state).begins_with("WIN: King captured"), MatchController.status_text(state))
