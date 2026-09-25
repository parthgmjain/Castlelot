class_name Roster
extends RefCounted

const PLAYER_SIDE := Piece.Side.WHITE

## Roster id -> { board, square } for every roster piece currently on a board.
static func on_field(boards: Array) -> Dictionary:
	var out := {}
	for board in boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == PLAYER_SIDE and piece.has("roster_id"):
				out[piece.roster_id] = { "board": board, "square": square }
	return out

static func field_ids(boards: Array) -> Array:
	return on_field(boards).keys()

## Roster entries not currently on a board.
static func bench(run: RunState, boards: Array) -> Array:
	var placed := on_field(boards)
	return run.roster.filter(func(entry): return not placed.has(entry.id))

## Empty squares in `side`'s zone, as [{ board, square }].
static func free_squares(boards: Array, side: Piece.Side) -> Array:
	var out: Array = []
	for board in boards:
		for square in board.zone_owner:
			if board.zone_owner[square] == side and not board.pieces.has(square):
				out.append({ "board": board, "square": square })
	return out

## Puts a bench piece on an empty square of your zone. Returns whether it worked.
static func deploy(run: RunState, boards: Array, id: int, board: Board, square: Vector2i) -> bool:
	var entry := run.roster_entry(id)
	if entry.is_empty() or on_field(boards).has(id):
		return false
	if not board.is_in_bounds(square) or board.zone_owner.get(square) != PLAYER_SIDE or board.pieces.has(square):
		return false
	board.pieces[square] = { "type": entry.type, "side": PLAYER_SIDE, "roster_id": id }
	board.queue_redraw()
	return true

## Takes a deployed roster piece back to the bench.
static func withdraw(board: Board, square: Vector2i) -> bool:
	var piece = board.pieces.get(square)
	if piece == null or piece.side != PLAYER_SIDE or not piece.has("roster_id"):
		return false
	board.pieces.erase(square)
	board.queue_redraw()
	return true

## Fills free zone squares with bench pieces at random; returns how many were placed.
static func auto_deploy(run: RunState, boards: Array) -> int:
	var free := free_squares(boards, PLAYER_SIDE)
	free.shuffle()
	var placed := 0
	for entry in bench(run, boards):
		if free.is_empty():
			break
		var slot: Dictionary = free.pop_back()
		if deploy(run, boards, entry.id, slot.board, slot.square):
			placed += 1
	return placed

## After a match: any piece that was deployed but is no longer on a board was
## captured, so it leaves the roster for good. Returns those entries.
static func settle(run: RunState, boards: Array, deployed_ids: Array) -> Array:
	var alive := on_field(boards)
	var lost: Array = []
	for id in deployed_ids:
		if not alive.has(id):
			var entry := run.roster_entry(id)
			if not entry.is_empty():
				lost.append(entry.duplicate())
				run.remove_from_roster(id)
	return lost
