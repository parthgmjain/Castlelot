class_name PawnMovement
extends RefCounted

const PROMOTION_CHOICES := [Piece.Type.QUEEN, Piece.Type.ROOK, Piece.Type.BISHOP, Piece.Type.KNIGHT]

## The way a pawn faces by default: White up, Black down.
static func home_direction(side: Piece.Side) -> Vector2i:
	return Vector2i(0, -1) if side == Piece.Side.WHITE else Vector2i(0, 1)

## When several directions all bring the pawn closer to the enemy zone it
## takes the first of these, so it keeps to one direction for as long as that
## direction still makes progress, then turns.
static func _preference(side: Piece.Side) -> Array:
	var forward := home_direction(side)
	return [forward, -forward, Vector2i(1, 0), Vector2i(-1, 0)]

## Steps (through portals, across every board) from each square to the
## nearest enemy-zone square: { Board: { Vector2i: int } }. Empty when the
## enemy has no zone. Pieces are ignored - they block, they don't reroute.
static func distance_field(board: Board, side: Piece.Side) -> Dictionary:
	var enemy: Piece.Side = Piece.opponent(side)
	var boards := BoardGraph.reachable_boards(board)
	var sources: Array = []
	for b in boards:
		for square in b.zone_owner:
			if b.zone_owner[square] == enemy:
				sources.append({ "board": b, "square": square })
	if sources.is_empty():
		return {}
	return BoardGraph.distance_field(boards, sources)

## The direction this pawn is currently heading. With no enemy zone to head
## for it falls back to its home direction; Vector2i.ZERO means it is already
## inside the enemy zone (or has no way in) and has no forward move.
static func heading(board: Board, square: Vector2i, side: Piece.Side) -> Vector2i:
	var field := distance_field(board, side)
	if field.is_empty():
		return home_direction(side)

	var here: int = field[board].get(square, -1)
	if here < 0:
		return home_direction(side)
	if here == 0:
		return Vector2i.ZERO

	for direction in _preference(side):
		var next: Dictionary = Piece.step_across(board, square, direction)
		if not next.is_empty() and field[next.board].get(next.square, -1) == here - 1:
			return direction
	return Vector2i.ZERO

## One step along its heading onto an empty square (or two from its home row
## while that stays on the path), plus captures on the two forward diagonals
## of that heading.
static func moves(side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves: Array = []
	var forward := heading(board, from, side)

	if forward != Vector2i.ZERO:
		var one_step: Dictionary = Piece.step_across(board, from, forward)
		if not one_step.is_empty() and not one_step.board.pieces.has(one_step.square):
			moves.append({ "board": one_step.board, "square": one_step.square, "capture": false })

			var home_row: int = board.grid_height - 1 if side == Piece.Side.WHITE else 0
			var two_step_added := false
			if forward == home_direction(side) and from.y == home_row and one_step.board == board \
				and heading(one_step.board, one_step.square, side) == forward:
				var two_step: Vector2i = from + forward * 2
				if board.is_in_bounds(two_step) and not board.pieces.has(two_step):
					moves.append({ "board": board, "square": two_step, "capture": false })
					two_step_added = true
			if not two_step_added and _is_drummed(board, from, side) and heading(one_step.board, one_step.square, side) == forward:
				var second: Dictionary = Piece.step_across(one_step.board, one_step.square, forward)
				if not second.is_empty() and not second.board.pieces.has(second.square):
					moves.append({ "board": second.board, "square": second.square, "capture": false })

	var facing := forward if forward != Vector2i.ZERO else home_direction(side)
	var sideways := Vector2i(facing.y, facing.x)
	for diagonal in [facing + sideways, facing - sideways]:
		var capture: Dictionary = Piece.step_across(board, from, diagonal)
		if capture.is_empty():
			continue
		var occupant = capture.board.pieces.get(capture.square)
		if occupant != null and occupant.side != side:
			moves.append({ "board": capture.board, "square": capture.square, "capture": true })

	return moves

## A real pawn next to a friendly Drummer may advance two squares from anywhere.
static func _is_drummed(board: Board, from: Vector2i, side: Piece.Side) -> bool:
	var me = board.pieces.get(from)
	if me == null or me.type != Piece.Type.PAWN:
		return false
	return Piece.has_adjacent(board, from, func(p): return p.side == side and PieceDefs.has(p.type) and PieceDefs.boosts(p.type).has("pawn_double_step"))

## True for a pawn standing inside the enemy zone.
static func reached_promotion(piece: Dictionary, board: Board, square: Vector2i) -> bool:
	if piece.type != Piece.Type.PAWN:
		return false
	var enemy: Piece.Side = Piece.Side.BLACK if piece.side == Piece.Side.WHITE else Piece.Side.WHITE
	return board.zone_owner.get(square) == enemy

## Turns the pawn into `type` in place. It keeps counting as a pawn against
## its side's points, so promotion is free.
static func promote(piece: Dictionary, type: Piece.Type) -> void:
	piece.points = Piece.points(piece)
	piece.type = type
