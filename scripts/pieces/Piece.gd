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

## Standard chess values. King is 0 - it doesn't count against a point budget.
const VALUES := {
	Type.KING: 0,
	Type.QUEEN: 9,
	Type.ROOK: 5,
	Type.BISHOP: 3,
	Type.KNIGHT: 3,
	Type.PAWN: 1,
}

static func symbol(type: Piece.Type, side: Piece.Side) -> String:
	return SYMBOLS[side][type]

static func value(type: Piece.Type) -> int:
	return VALUES[type]

## Steps one square from `square` on `board` in `direction`. If that lands
## off the board, follows a portal at `square` whose direction matches, if
## one exists (a piece can only pass through a board edge at a connecting
## square). Returns {} when there's nowhere to go.
static func step_across(board: Board, square: Vector2i, direction: Vector2i) -> Dictionary:
	var target: Vector2i = square + direction
	if board.is_in_bounds(target):
		return { "board": board, "square": target }
	for portal in board.portals.get(square, []):
		if portal.direction == direction:
			return { "board": portal.target_board, "square": portal.target_square }
	return {}

## Every move is { board: Board, square: Vector2i, capture: bool }. `board`
## may differ from the piece's origin board when the move crosses a portal.
static func get_legal_moves(type: Piece.Type, side: Piece.Side, board: Board, from: Vector2i) -> Array:
	match type:
		Type.KING:
			return _step_moves(KING_OFFSETS, side, board, from)
		Type.KNIGHT:
			return _knight_moves(side, board, from)
		Type.ROOK:
			return _slide_moves(ROOK_DIRECTIONS, side, board, from)
		Type.BISHOP:
			return _slide_moves(BISHOP_DIRECTIONS, side, board, from)
		Type.QUEEN:
			return _slide_moves(ROOK_DIRECTIONS + BISHOP_DIRECTIONS, side, board, from)
		Type.PAWN:
			return PawnMovement.moves(side, board, from)
	return []

static func _step_moves(offsets: Array, side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves: Array = []
	for offset in offsets:
		var dest: Dictionary = step_across(board, from, offset)
		if dest.is_empty():
			continue
		var occupant = dest.board.pieces.get(dest.square)
		if occupant == null or occupant.side != side:
			moves.append({ "board": dest.board, "square": dest.square, "capture": occupant != null })
	return moves

## Traces a knight's L-shape as a sequence of unit steps (all of the x
## offset, then all of the y offset) so a jump that crosses a board edge
## mid-path can follow a portal, same as any other piece. Occupancy only
## matters at the final square - knights jump over pieces along the way.
static func _knight_moves(side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves: Array = []
	for offset in KNIGHT_OFFSETS:
		var dest: Dictionary = _trace_path(board, from, offset)
		if dest.is_empty():
			continue
		var occupant = dest.board.pieces.get(dest.square)
		if occupant == null or occupant.side != side:
			moves.append({ "board": dest.board, "square": dest.square, "capture": occupant != null })
	return moves

static func _trace_path(board: Board, from: Vector2i, offset: Vector2i) -> Dictionary:
	var steps: Array = []
	var step_x := Vector2i(1 if offset.x > 0 else -1, 0)
	var step_y := Vector2i(0, 1 if offset.y > 0 else -1)
	for i in abs(offset.x):
		steps.append(step_x)
	for i in abs(offset.y):
		steps.append(step_y)

	var current_board: Board = board
	var current_square: Vector2i = from
	for step in steps:
		var dest: Dictionary = step_across(current_board, current_square, step)
		if dest.is_empty():
			return {}
		current_board = dest.board
		current_square = dest.square
	return { "board": current_board, "square": current_square }

static func _slide_moves(directions: Array, side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves: Array = []
	for dir in directions:
		var current_board: Board = board
		var current_square: Vector2i = from
		while true:
			var dest: Dictionary = step_across(current_board, current_square, dir)
			if dest.is_empty():
				break
			var occupant = dest.board.pieces.get(dest.square)
			if occupant == null:
				moves.append({ "board": dest.board, "square": dest.square, "capture": false })
			else:
				if occupant.side != side:
					moves.append({ "board": dest.board, "square": dest.square, "capture": true })
				break
			current_board = dest.board
			current_square = dest.square
	return moves
