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
			return _step_moves(KNIGHT_OFFSETS, side, board, from)
		Type.ROOK:
			return _slide_moves(ROOK_DIRECTIONS, side, board, from)
		Type.BISHOP:
			return _slide_moves(BISHOP_DIRECTIONS, side, board, from)
		Type.QUEEN:
			return _slide_moves(ROOK_DIRECTIONS + BISHOP_DIRECTIONS, side, board, from)
		Type.PAWN:
			return _pawn_moves(side, board, from)
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

static func _pawn_moves(side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves: Array = []
	var forward: int = -1 if side == Piece.Side.WHITE else 1
	var home_row: int = board.grid_height - 1 if side == Piece.Side.WHITE else 0

	var one_step: Dictionary = step_across(board, from, Vector2i(0, forward))
	if not one_step.is_empty() and not one_step.board.pieces.has(one_step.square):
		moves.append({ "board": one_step.board, "square": one_step.square, "capture": false })

		if from.y == home_row and one_step.board == board:
			var two_step: Vector2i = from + Vector2i(0, forward * 2)
			if board.is_in_bounds(two_step) and not board.pieces.has(two_step):
				moves.append({ "board": board, "square": two_step, "capture": false })

	for dx in [-1, 1]:
		var capture: Dictionary = step_across(board, from, Vector2i(dx, forward))
		if capture.is_empty():
			continue
		var occupant = capture.board.pieces.get(capture.square)
		if occupant != null and occupant.side != side:
			moves.append({ "board": capture.board, "square": capture.square, "capture": true })

	return moves
