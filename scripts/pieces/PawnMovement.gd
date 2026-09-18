class_name PawnMovement
extends RefCounted

const CARDINALS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

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
	var enemy: Piece.Side = Piece.Side.BLACK if side == Piece.Side.WHITE else Piece.Side.WHITE

	var reachable: Array = [board]
	var seen: Dictionary = { board: true }
	var index := 0
	while index < reachable.size():
		var b: Board = reachable[index]
		index += 1
		for square in b.portals:
			for portal in b.portals[square]:
				if not seen.has(portal.target_board):
					seen[portal.target_board] = true
					reachable.append(portal.target_board)

	var field: Dictionary = {}
	var queue: Array = []
	for b in reachable:
		field[b] = {}
		for square in b.zone_owner:
			if b.zone_owner[square] == enemy:
				field[b][square] = 0
				queue.append({ "board": b, "square": square })
	if queue.is_empty():
		return {}

	var head := 0
	while head < queue.size():
		var current: Dictionary = queue[head]
		head += 1
		var distance: int = field[current.board][current.square]
		for direction in CARDINALS:
			var next: Dictionary = Piece.step_across(current.board, current.square, direction)
			if next.is_empty() or field[next.board].has(next.square):
				continue
			field[next.board][next.square] = distance + 1
			queue.append(next)
	return field

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
			if forward == home_direction(side) and from.y == home_row and one_step.board == board \
				and heading(one_step.board, one_step.square, side) == forward:
				var two_step: Vector2i = from + forward * 2
				if board.is_in_bounds(two_step) and not board.pieces.has(two_step):
					moves.append({ "board": board, "square": two_step, "capture": false })

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
