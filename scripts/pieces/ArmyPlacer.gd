class_name ArmyPlacer
extends RefCounted

## Total value of a side's pieces across every board (King counts as 0).
static func points_used(boards: Array, side: Piece.Side) -> int:
	var total := 0
	for b in boards:
		for square in b.pieces:
			var piece: Dictionary = b.pieces[square]
			if piece.side == side:
				total += Piece.points(piece)
	return total

## Places `type` for the current side on the selected square, unless it
## would push that side past `allocated` points (King is always free).
## Debug mode ignores both the budget and the zones.
static func place(state: GameState, type: Piece.Type, allocated: int) -> void:
	if state.active_board == null:
		return
	if type != Piece.Type.KING and not state.debug_mode:
		if points_used(state.boards, state.current_side) + Piece.value(type) > allocated:
			return
	state.active_board.place_piece(state.active_square, type, state.current_side, state.debug_mode)

static func remove(state: GameState) -> void:
	if state.active_board == null:
		return
	state.active_board.remove_piece(state.active_square)

## Rebuilds a side's army from scratch (kings stay): buys pieces with its
## allocated points and drops them on random free squares of its zone. The
## allocation is a hard cap, so the round type's budget multiplier is not applied.
## `reserved` pieces (a boss's own piece) are placed first and come on top of the
## allocation: the army is still bought with the full allocation. `round_number` gates which
## extra pieces (beyond the six chess ones) can be bought - see PieceSelector.EXTRA_TIER_UNLOCK;
## -1 (the sandbox's Auto Place buttons) means chess pieces only.
## Returns a status message for the UI.
static func auto_place(boards: Array, side: Piece.Side, allocated: int, round_type: String, reserved: Array = [], round_number: int = -1) -> String:
	for b in boards:
		for square in b.pieces.keys():
			var piece: Dictionary = b.pieces[square]
			if piece.side == side and piece.type != Piece.Type.KING:
				b.remove_piece(square)

	var free_squares: Array = []
	for b in boards:
		for square in b.zone_owner:
			if b.zone_owner[square] == side and not b.pieces.has(square):
				free_squares.append({ "board": b, "square": square })

	if free_squares.is_empty():
		return "No free zone squares - generate zones first"

	var total_free := free_squares.size()
	free_squares.shuffle()
	var spent := 0
	var placed := 0
	for type in reserved:
		if free_squares.is_empty():
			break
		var slot: Dictionary = free_squares.pop_back()
		slot.board.place_piece(slot.square, type, side)
		placed += 1

	var picks: Array = PieceSelector.pick_pieces(
		allocated,
		PieceSelector.working_weights(round_type, round_number),
		PieceSelector.working_decays(round_type, round_number),
		PieceSelector.working_supply(round_number),
		RandomNumberGenerator.new(),
		free_squares.size(),
	)
	for i in picks.size():
		free_squares[i].board.place_piece(free_squares[i].square, picks[i], side)
		spent += Piece.value(picks[i])
	placed += picks.size()
	return "Placed %d pieces (%d pts) in %d free squares" % [placed, spent, total_free]
