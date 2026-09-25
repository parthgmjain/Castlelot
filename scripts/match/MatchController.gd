class_name MatchController
extends RefCounted

## Starts a match with `moves` player moves and a `target` score. Returns an
## error message, or "" when it started. Modifiers carry over from the last match.
static func start(state: GameState, moves: int, target: int) -> String:
	for side in [Piece.Side.WHITE, Piece.Side.BLACK]:
		if not _has_king(state.boards, side):
			return "Both sides need a king - generate zones first"

	var fresh := MatchState.new()
	fresh.active = true
	fresh.moves_left = moves
	fresh.target_score = target
	fresh.modifiers = state.current_match.modifiers
	state.current_match = fresh
	MoveEffects.mark_homes(state)
	MoveController.clear_selection(state)
	return ""

## Whether a click should reach normal selection/move handling. Outside a
## match everything is allowed; inside one only the player's own pieces (or a
## highlighted destination) on the player's turn.
static func accepts_click(state: GameState, board: Board, square: Vector2i) -> bool:
	var current := state.current_match
	if not current.active or state.debug_mode:
		return true
	if current.turn_side != current.player_side:
		return false
	for move in state.current_moves:
		if move.board == board and move.square == square:
			return true
	var piece = board.pieces.get(square)
	return piece != null and piece.side == current.player_side

## Scores a finished move and checks for a king capture or the target score.
## `result` is what MoveController.execute returned; a `free` move (a bonus
## move) doesn't use up one of the player's moves.
static func record_move(state: GameState, result: Dictionary, free: bool = false) -> void:
	var current := state.current_match
	if not current.active:
		return

	var mover: Piece.Side = result.piece.side
	var other := Piece.opponent(mover)
	current.last_mover = mover
	if mover == current.player_side and not free:
		current.moves_left -= 1

	for victim in result.victims:
		if victim.piece.type == Piece.Type.KING:
			current.last_event = "%s captured the king" % _who(current, mover)
			_finish(current, mover == current.player_side, "King captured")
			return
	for loss in result.losses:
		if loss.piece.type == Piece.Type.KING:
			current.last_event = "%s's king was destroyed" % _who(current, mover)
			_finish(current, mover != current.player_side, "King destroyed")
			return

	var gained := 0
	var names: Array = []
	for victim in result.victims:
		gained += Scoring.capture_score(current, result.piece, victim.piece, victim.board, victim.square)
		names.append(_name(victim.piece))
	current.scores[mover] += gained
	var retaliation := 0
	for loss in result.losses:
		retaliation += Scoring.capture_score(current, loss.by, loss.piece, loss.board, loss.square)
	current.scores[other] += retaliation

	if not names.is_empty():
		current.last_event = "%s took a %s with a %s (+%d)" % [_who(current, mover), " and a ".join(names), _name(result.piece), gained]
	elif not result.swapped.is_empty():
		current.last_event = "%s swapped a %s with a %s" % [_who(current, mover), _name(result.piece), _name(result.swapped.piece)]
	else:
		current.last_event = "%s moved a %s" % [_who(current, mover), _name(result.piece)]
	if retaliation > 0:
		current.last_event += " (+%d for the other side)" % retaliation
	for note in result.notes:
		current.last_event += " | %s" % note
	if current.scores[current.player_side] >= current.target_score:
		_finish(current, true, "Target score reached")

## Ends the current side's turn (call once the move, including any promotion,
## is fully resolved). The player loses if that was their last move.
static func end_turn(state: GameState) -> void:
	var current := state.current_match
	if not current.active:
		return

	if state.debug_mode:
		current.turn_side = current.last_mover      # anyone may move; the turn goes to the other side

	current.bonus = {}
	current.turns_taken[current.turn_side] += 1
	_tick_rest(state, current.turn_side)
	MoveEffects.tick_revivals(state, current.turn_side)
	if current.turn_side == current.player_side and current.moves_left <= 0:
		_finish(current, false, "Out of moves")
		return

	current.turn_side = Piece.opponent(current.turn_side)
	if current.turn_side == current.player_side and not has_legal_move(state, current.player_side):
		_finish(current, false, "No legal moves")

## A side's pieces recover one step from resting at the end of each of its own turns.
static func _tick_rest(state: GameState, side: Piece.Side) -> void:
	for board in state.boards:
		for piece in board.pieces.values():
			if piece.side == side and piece.get("rest", 0) > 0:
				piece["rest"] -= 1

static func has_legal_move(state: GameState, side: Piece.Side) -> bool:
	for board in state.boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == side and not Piece.get_legal_moves(piece.type, side, board, square).is_empty():
				return true
	return false

static func status_text(state: GameState) -> String:
	var current := state.current_match
	var score := "Score %d/%d" % [current.scores[current.player_side], current.target_score]
	if current.active:
		var turn := "Your turn" if current.turn_side == current.player_side else "AI thinking..."
		if state.debug_mode:
			turn = "%s to move (debug)" % ("White" if current.turn_side == Piece.Side.WHITE else "Black")
		var text := "%s | Moves left: %d | %s | %s" % [turn, current.moves_left, score, current.last_event]
		if state.current_moves.any(func(m): return m.get("special", false)):
			text += " | Right-click an orange ring to use a special attack or ability"
		if not current.bonus.is_empty():
			text += " | BONUS MOVE: %s (or skip it)" % current.bonus.label
		return text
	if current.result != "":
		return "%s: %s | %s | %s" % [current.result.to_upper(), current.result_reason, score, current.last_event]
	return ""

static func _finish(current: MatchState, won: bool, reason: String) -> void:
	current.active = false
	current.result = "win" if won else "loss"
	current.result_reason = reason

static func _has_king(boards: Array, side: Piece.Side) -> bool:
	for board in boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == side and piece.type == Piece.Type.KING:
				return true
	return false

static func _who(current: MatchState, side: Piece.Side) -> String:
	return "You" if side == current.player_side else "The AI"

static func _name(piece: Dictionary) -> String:
	return Piece.Type.find_key(piece.type).capitalize()
