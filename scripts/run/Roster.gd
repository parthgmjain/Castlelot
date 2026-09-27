class_name Roster
extends RefCounted

## Default when a caller doesn't care which side is "yours" (sandbox mode, and
## most tests). A real run passes Banners.player_side(run) instead, so White
## Banner/Black Banner actually decide which side you field.
const PLAYER_SIDE := Piece.Side.WHITE

## Roster id -> { board, square } for every roster piece currently on a board.
static func on_field(boards: Array, side: Piece.Side = PLAYER_SIDE) -> Dictionary:
	var out := {}
	for board in boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == side and piece.has("roster_id"):
				out[piece.roster_id] = { "board": board, "square": square }
	return out

static func field_ids(boards: Array, side: Piece.Side = PLAYER_SIDE) -> Array:
	return on_field(boards, side).keys()

## Roster entries not currently on a board.
static func bench(run: RunState, boards: Array, side: Piece.Side = PLAYER_SIDE) -> Array:
	var placed := on_field(boards, side)
	return run.roster.filter(func(entry): return not placed.has(entry.id))

## Total value of the roster pieces on the boards (by what they are in the roster,
## so a promoted pawn still counts as a pawn). The king is free.
static func points_used(run: RunState, boards: Array, side: Piece.Side = PLAYER_SIDE) -> int:
	var total := 0
	for id in on_field(boards, side):
		var entry := run.roster_entry(id)
		if not entry.is_empty():
			total += Piece.value(entry.type)
	return total

## Empty squares in `side`'s zone, as [{ board, square }].
static func free_squares(boards: Array, side: Piece.Side) -> Array:
	var out: Array = []
	for board in boards:
		for square in board.zone_owner:
			if board.zone_owner[square] == side and not board.pieces.has(square):
				out.append({ "board": board, "square": square })
	return out

## Puts a bench piece on an empty square of your zone, if it fits in your
## allocated points (unless `ignore_budget`). Returns whether it worked.
static func deploy(run: RunState, boards: Array, id: int, board: Board, square: Vector2i, ignore_budget: bool = false, side: Piece.Side = PLAYER_SIDE) -> bool:
	var entry := run.roster_entry(id)
	if entry.is_empty() or on_field(boards, side).has(id):
		return false
	if not ignore_budget and points_used(run, boards, side) + Piece.value(entry.type) > run.effective_points():
		return false
	if not board.is_in_bounds(square) or board.zone_owner.get(square) != side or board.pieces.has(square):
		return false
	board.pieces[square] = { "type": entry.type, "side": side, "roster_id": id }
	board.queue_redraw()
	return true

## Takes a deployed roster piece back to the bench.
static func withdraw(board: Board, square: Vector2i, side: Piece.Side = PLAYER_SIDE) -> bool:
	var piece = board.pieces.get(square)
	if piece == null or piece.side != side or not piece.has("roster_id"):
		return false
	board.pieces.erase(square)
	board.queue_redraw()
	return true

## Fills free zone squares with bench pieces, most valuable first, on random
## squares, as far as your points allow; returns how many were placed.
static func auto_deploy(run: RunState, boards: Array, ignore_budget: bool = false, side: Piece.Side = PLAYER_SIDE) -> int:
	var free := free_squares(boards, side)
	free.shuffle()
	var candidates := bench(run, boards, side)
	candidates.sort_custom(func(a, b): return Piece.value(a.type) > Piece.value(b.type))
	var placed := 0
	for entry in candidates:
		if free.is_empty():
			break
		var slot: Dictionary = free.back()
		if deploy(run, boards, entry.id, slot.board, slot.square, ignore_budget, side):
			free.pop_back()
			placed += 1
	return placed

## After a match: any piece that was deployed but is no longer on a board was
## captured, so it leaves the roster for good. Returns those entries.
static func settle(run: RunState, boards: Array, deployed_ids: Array, waiting_ids: Array = []) -> Array:
	var alive := on_field(boards)
	for id in waiting_ids:
		alive[id] = true                      # a piece waiting to come back (a Phoenix) is not lost
	var lost: Array = []
	for id in deployed_ids:
		if not alive.has(id):
			var entry := run.roster_entry(id)
			if not entry.is_empty():
				lost.append(entry.duplicate())
				run.remove_from_roster(id)
	return lost
