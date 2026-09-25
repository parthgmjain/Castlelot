class_name GreedyAI
extends RefCounted

const KING_WORTH := 100000.0
const RISK_WEIGHT := 1.0
const APPROACH_WEIGHT := 2.0

## Picks `side`'s move: take the most valuable capture it can, but count what
## the opponent could take back next turn, and when nothing is worth taking
## close in on the enemy. Returns { board, square, move } or {} with no moves.
static func choose_move(state: GameState, side: Piece.Side) -> Dictionary:
	var enemy := Piece.opponent(side)
	var enemy_squares: Array = []
	for board in state.boards:
		for square in board.pieces:
			if board.pieces[square].side == enemy:
				enemy_squares.append({ "board": board, "square": square })
	var distance := BoardGraph.distance_field(state.boards, enemy_squares)

	var best: Dictionary = {}
	var best_value := -INF
	for board in state.boards:
		for square in board.pieces.keys():
			var piece: Dictionary = board.pieces[square]
			if piece.side != side:
				continue
			for move in Piece.get_legal_moves(piece.type, side, board, square):
				var value := _evaluate(state, side, board, square, piece, move, distance) + randf()
				if value > best_value:
					best_value = value
					best = { "board": board, "square": square, "move": move }
	return best

static func _evaluate(state: GameState, side: Piece.Side, from_board: Board, from_square: Vector2i, piece: Dictionary, move: Dictionary, distance: Dictionary) -> float:
	var victim = move.board.pieces.get(move.square)
	if victim != null and victim.type == Piece.Type.KING:
		return KING_WORTH * 10.0
	var gain := _worth(victim) if victim != null else 0.0

	# Try the move, see the best reply, then put everything back.
	from_board.pieces.erase(from_square)
	move.board.pieces[move.square] = piece
	var risk := _best_capture(state, Piece.opponent(side))
	move.board.pieces.erase(move.square)
	if victim != null:
		move.board.pieces[move.square] = victim
	from_board.pieces[from_square] = piece

	var value := gain - risk * RISK_WEIGHT
	if victim == null:
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
				var victim = move.board.pieces.get(move.square)
				if victim != null:
					best = max(best, _worth(victim))
	return best

static func _worth(piece: Dictionary) -> float:
	if piece.type == Piece.Type.KING:
		return KING_WORTH
	return float(Piece.value(piece.type) * Scoring.CHIPS_PER_VALUE)
