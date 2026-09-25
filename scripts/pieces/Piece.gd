class_name Piece
extends RefCounted

enum Type {
	KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN,
	# data-driven pieces (see PieceDefs)
	SCOUT, SERF, MILITIA, CRAB,
	CAMEL, ZEBRA, TWIN_RIDER, HAWK, CANNON, CHARGER, RANGER, LANCER, MIRROR, MONK,
	FERZ_GUARD, GRASSHOPPER, GHOST, SPEARMAN, GRIFFON,
	ARCHER, CATAPULT, TITAN, DRAGON,
	SHIELDBEARER, TORTOISE, GOLEM, BARD, WRAITH,
	PILGRIM, ALCHEMIST, TORCHBEARER, NINJA, SQUIRE, DRUMMER, LICH, WARLORD, PHOENIX, HYDRA,
}
enum Side { WHITE, BLACK }
enum Tier { COMMON, UNCOMMON, LEGENDARY }

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

const TIERS := {
	Type.PAWN: Tier.COMMON,
	Type.KNIGHT: Tier.UNCOMMON,
	Type.BISHOP: Tier.UNCOMMON,
	Type.ROOK: Tier.UNCOMMON,
	Type.QUEEN: Tier.LEGENDARY,
}
const TIER_NAMES := { Tier.COMMON: "Common", Tier.UNCOMMON: "Uncommon", Tier.LEGENDARY: "Legendary" }

## Standard chess values. King is 0 - it doesn't count against a point budget.
const VALUES := {
	Type.KING: 0,
	Type.QUEEN: 9,
	Type.ROOK: 5,
	Type.BISHOP: 3,
	Type.KNIGHT: 3,
	Type.PAWN: 1,
}

## Text symbol for buttons and messages. Data-driven pieces have no chess glyph;
## the board draws them as a labelled disc instead.
static func symbol(type: Piece.Type, side: Piece.Side) -> String:
	if PieceDefs.has(type):
		return "◇" if side == Side.WHITE else "◆"
	return SYMBOLS[side][type]

static func tier(type: Piece.Type) -> Piece.Tier:
	if PieceDefs.has(type):
		return PieceDefs.tier(type)
	return TIERS.get(type, Piece.Tier.COMMON)

static func types_in_tier(tier_value: Piece.Tier) -> Array:
	var types: Array = TIERS.keys().filter(func(t): return TIERS[t] == tier_value)
	types.append_array(PieceDefs.types().filter(func(t): return PieceDefs.tier(t) == tier_value))
	return types

## Boss rewards: earned by beating a knight, never drawn from the lottery or a trade-up.
static func is_reward_only(type: Piece.Type) -> bool:
	return PieceDefs.has(type) and PieceDefs.is_reward_only(type)

static func opponent(side: Piece.Side) -> Piece.Side:
	return Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE

static func value(type: Piece.Type) -> int:
	if PieceDefs.has(type):
		return PieceDefs.value(type)
	return VALUES[type]

## What a placed piece counts against its side's points: its standard value,
## unless it carries an override (a promoted pawn keeps counting as a pawn).
static func points(piece: Dictionary) -> int:
	return piece.get("points", value(piece.type))

## Whether any of the 8 squares around `square` (across seams too) holds a piece `test` accepts.
static func has_adjacent(board: Board, square: Vector2i, test: Callable) -> bool:
	for offset in KING_OFFSETS:
		var next: Dictionary = step_across(board, square, offset)
		if next.is_empty():
			continue
		var piece = next.board.pieces.get(next.square)
		if piece != null and test.call(piece):
			return true
	return false

## Steps one square from `square` on `board` in `direction`. If that lands
## off the board, follows a portal at `square` whose direction matches, if
## one exists (a piece can only pass through a board edge at a connecting
## square). A diagonal step that leaves the board is made as two straight
## steps, so it can cross a seam even when the square beside the piece has no
## portal but the one above or below it does. Returns {} when there's nowhere to go.
static func step_across(board: Board, square: Vector2i, direction: Vector2i) -> Dictionary:
	var target: Vector2i = square + direction
	if board.is_in_bounds(target):
		return { "board": board, "square": target }
	if direction.x != 0 and direction.y != 0:
		return _step_diagonally_across(board, square, direction)
	for portal in board.portals.get(square, []):
		if portal.direction == direction:
			return { "board": portal.target_board, "square": portal.target_square }
	return {}

static func _step_diagonally_across(board: Board, square: Vector2i, direction: Vector2i) -> Dictionary:
	var horizontal := Vector2i(direction.x, 0)
	var vertical := Vector2i(0, direction.y)
	for order in [[horizontal, vertical], [vertical, horizontal]]:
		var first: Dictionary = step_across(board, square, order[0])
		if first.is_empty():
			continue
		var second: Dictionary = step_across(first.board, first.square, order[1])
		if not second.is_empty():
			return second
	return {}

## Every move is { board: Board, square: Vector2i, capture: bool }. `board`
## may differ from the piece's origin board when the move crosses a portal.
static func get_legal_moves(type: Piece.Type, side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves := _generate_moves(type, side, board, from)
	return CaptureRules.filter(moves, { "type": type, "side": side, "board": board, "square": from })

static func _generate_moves(type: Piece.Type, side: Piece.Side, board: Board, from: Vector2i) -> Array:
	if PieceDefs.has(type):
		return PieceMoves.generate(type, side, board, from)
	match type:
		Type.KING:
			return step_moves(KING_OFFSETS, side, board, from)
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

static func step_moves(offsets: Array, side: Piece.Side, board: Board, from: Vector2i) -> Array:
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
		var dest: Dictionary = trace_path(board, from, offset)
		if dest.is_empty():
			continue
		var occupant = dest.board.pieces.get(dest.square)
		if occupant == null or occupant.side != side:
			moves.append({ "board": dest.board, "square": dest.square, "capture": occupant != null })
	return moves

static func trace_path(board: Board, from: Vector2i, offset: Vector2i) -> Dictionary:
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
