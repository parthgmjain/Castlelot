class_name GreedyAI
extends RefCounted

const KING_WORTH := 100000.0
const RISK_WEIGHT := 1.0
const APPROACH_WEIGHT := 2.0

## Picks `side`'s move: take the most valuable capture it can, but count what
## the opponent could take back next turn, and when nothing is worth taking
## close in on the enemy. Returns { board, square, move } or {} with no moves.
static func choose_move(state: GameState, side: Piece.Side) -> Dictionary:
	return _best_move(state, side, -INF)

## The same for a bonus move, which is optional: {} unless it is worth making.
static func choose_bonus_move(state: GameState, side: Piece.Side) -> Dictionary:
	return _best_move(state, side, 0.0)

static func _best_move(state: GameState, side: Piece.Side, minimum: float) -> Dictionary:
	var enemy := Piece.opponent(side)
	var enemy_squares: Array = []
	for board in state.boards:
		for square in board.pieces:
			if board.pieces[square].side == enemy:
				enemy_squares.append({ "board": board, "square": square })
	var distance := BoardGraph.distance_field(state.boards, enemy_squares)

	var best: Dictionary = {}
	var best_value := minimum
	for board in state.boards:
		for square in board.pieces.keys():
			var piece: Dictionary = board.pieces[square]
			if piece.side != side:
				continue
			for move in MoveEffects.moves_for(state, piece, board, square):
				var value := _evaluate(state, side, board, square, piece, move, distance) + randf()
				if value > best_value:
					best_value = value
					best = { "board": board, "square": square, "move": move }
	return best

static func _evaluate(state: GameState, side: Piece.Side, from_board: Board, from_square: Vector2i, piece: Dictionary, move: Dictionary, distance: Dictionary) -> float:
	var victims := MoveController.victims_of(move)
	var gain := 0.0
	var dies := false                       # a Torchbearer takes its attacker with it
	for victim in victims:
		if victim.piece.type == Piece.Type.KING:
			return KING_WORTH * 10.0
		gain += _worth(victim.piece)
		if PieceDefs.has(victim.piece.type) and PieceDefs.effects(victim.piece.type, "on_captured").any(func(e): return e.kind == "destroy_attacker"):
			dies = true
	if dies:
		gain -= _worth(piece)

	# Try the move, see the best reply, then put everything back exactly as it was.
	var stays: bool = move.get("stay", false)
	var touched: Array = [{ "board": from_board, "square": from_square }, { "board": move.board, "square": move.square }]
	touched.append_array(victims)
	var saved: Array = touched.map(func(t): return { "board": t.board, "square": t.square, "piece": t.board.pieces.get(t.square) })
	var friend = move.board.pieces.get(move.square) if move.get("swap", false) else null
	for victim in victims:
		victim.board.pieces.erase(victim.square)
	if dies or not stays:
		from_board.pieces.erase(from_square)
	if not stays and not dies:
		move.board.pieces[move.square] = piece
		if friend != null:
			from_board.pieces[from_square] = friend
	var risk := _best_capture(state, Piece.opponent(side))
	for entry in saved:
		if entry.piece == null:
			entry.board.pieces.erase(entry.square)
		else:
			entry.board.pieces[entry.square] = entry.piece

	var value := gain - risk * RISK_WEIGHT
	if victims.is_empty():
		var before: int = distance[from_board].get(from_square, 99)
		var after: int = distance[move.board].get(move.square, 99)
		value += (before - after) * APPROACH_WEIGHT
	return value

## The most valuable capture `side` could make right now.
static func _best_capture(state: GameState, side: Piece.Side) -> float:
	var best := 0.0
	for board in state.boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side != side:
				continue
			for move in Piece.get_legal_moves(piece.type, side, board, square):
				var worth := 0.0
				for victim in MoveController.victims_of(move):
					worth += _worth(victim.piece)
				best = max(best, worth)
	return best

static func _worth(piece: Dictionary) -> float:
	if piece.type == Piece.Type.KING:
		return KING_WORTH
	return float(Piece.value(piece.type) * Scoring.CHIPS_PER_VALUE)
