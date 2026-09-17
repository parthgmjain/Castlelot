class_name Piece
extends RefCounted

enum Type { KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN }
enum Side { WHITE, BLACK }

const SYMBOLS := {
	Side.WHITE: {
		Type.KING: "♔",
		Type.QUEEN: "♕",
		Type.ROOK: "♖",
		Type.BISHOP: "♗",
		Type.KNIGHT: "♘",
		Type.PAWN: "♙",
	},
	Side.BLACK: {
		Type.KING: "♚",
		Type.QUEEN: "♛",
		Type.ROOK: "♜",
		Type.BISHOP: "♝",
		Type.KNIGHT: "♞",
		Type.PAWN: "♟",
	},
}

const KING_OFFSETS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const KNIGHT_OFFSETS := [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1),
]
const ROOK_DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const BISHOP_DIRECTIONS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func symbol(type: Piece.Type, side: Piece.Side) -> String:
	return SYMBOLS[side][type]

static func get_legal_moves(type: Piece.Type, side: Piece.Side, from: Vector2i, board: Board) -> Array:
	match type:
		Type.KING:
			return _step_moves(KING_OFFSETS, side, from, board)
		Type.KNIGHT:
			return _step_moves(KNIGHT_OFFSETS, side, from, board)
		Type.ROOK:
			return _slide_moves(ROOK_DIRECTIONS, side, from, board)
		Type.BISHOP:
			return _slide_moves(BISHOP_DIRECTIONS, side, from, board)
		Type.QUEEN:
			return _slide_moves(ROOK_DIRECTIONS + BISHOP_DIRECTIONS, side, from, board)
		Type.PAWN:
			return _pawn_moves(side, from, board)
	return []

static func _step_moves(offsets: Array, side: Piece.Side, from: Vector2i, board: Board) -> Array:
	var moves: Array = []
	for offset in offsets:
		var target: Vector2i = from + offset
		if not board.is_in_bounds(target):
			continue
		var occupant = board.pieces.get(target)
		if occupant == null or occupant.side != side:
			moves.append(target)
	return moves

static func _slide_moves(directions: Array, side: Piece.Side, from: Vector2i, board: Board) -> Array:
	var moves: Array = []
	for dir in directions:
		var target: Vector2i = from + dir
		while board.is_in_bounds(target):
			var occupant = board.pieces.get(target)
			if occupant == null:
				moves.append(target)
			else:
				if occupant.side != side:
					moves.append(target)
				break
			target += dir
	return moves

static func _pawn_moves(side: Piece.Side, from: Vector2i, board: Board) -> Array:
	var moves: Array = []
	var forward: int = -1 if side == Piece.Side.WHITE else 1
	var home_row: int = board.grid_height - 1 if side == Piece.Side.WHITE else 0

	var one_step: Vector2i = from + Vector2i(0, forward)
	if board.is_in_bounds(one_step) and not board.pieces.has(one_step):
		moves.append(one_step)
		var two_step: Vector2i = from + Vector2i(0, forward * 2)
		if from.y == home_row and board.is_in_bounds(two_step) and not board.pieces.has(two_step):
			moves.append(two_step)

	for dx in [-1, 1]:
		var capture: Vector2i = from + Vector2i(dx, forward)
		if board.is_in_bounds(capture):
			var occupant = board.pieces.get(capture)
			if occupant != null and occupant.side != side:
				moves.append(capture)

	return moves
