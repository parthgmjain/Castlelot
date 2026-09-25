class_name MoveEffects
extends RefCounted
## What a move sets off beyond the move itself, driven by the `on_capture` /
## `on_captured` lists in PieceDefs, plus the bonus moves some captures grant.
##
## on_captured (the victim's effects):  destroy_attacker, rebirth { turns }, split { alone, crowded }
## on_capture  (the capturer's effects): raise_pawn, bonus_step, bonus_pawn

## Applies the effects of a move that was just carried out. `result` is the
## MoveController result; this adds `losses` (the mover's pieces it destroyed:
## [{ piece, board, square, by }]) and `notes` (short sentences for the event line).
static func apply(state: GameState, result: Dictionary) -> void:
	var attacker: Dictionary = result.piece
	var alive := true
	for victim in result.victims:
		for effect in _effects(victim.piece, "on_captured"):
			match effect.kind:
				"destroy_attacker":
					if alive:
						alive = false
						result.board.pieces.erase(result.square)
						result.losses.append({ "piece": attacker, "board": result.board, "square": result.square, "by": victim.piece })
						result.notes.append("the %s's fire destroyed the %s" % [_name(victim.piece), _name(attacker)])
						if state.pending_promotion.get("piece") == attacker:
							state.pending_promotion = {}
				"rebirth":
					_queue_rebirth(state, victim, effect, result)
				"split":
					_split(state, victim, effect, result)
	if not alive:
		return
	for effect in _effects(attacker, "on_capture"):
		if effect.kind == "raise_pawn":
			for victim in result.victims:
				_raise_pawn(state, attacker, result)

## The bonus move a finished move earns, or {} (a bonus move never earns another).
static func bonus_after(result: Dictionary, was_bonus: bool) -> Dictionary:
	if was_bonus or result.victims.is_empty() or not result.losses.is_empty():
		return {}
	for effect in _effects(result.piece, "on_capture"):
		match effect.kind:
			"bonus_step":
				return { "kind": "step", "side": result.piece.side, "board": result.board, "square": result.square,
					"label": "the %s may move one more square" % _name(result.piece) }
			"bonus_pawn":
				return { "kind": "pawn", "side": result.piece.side, "label": "move any one pawn" }
	return {}

## Whether anyone can actually take the pending bonus move.
static func bonus_playable(state: GameState) -> bool:
	for board in state.boards:
		for square in board.pieces:
			if not moves_for(state, board.pieces[square], board, square).is_empty():
				return true
	return false

## The moves `piece` may make right now: its ordinary moves, or during a bonus
## only what the bonus allows.
static func moves_for(state: GameState, piece: Dictionary, board: Board, square: Vector2i) -> Array:
	var bonus: Dictionary = state.current_match.bonus
	if bonus.is_empty():
		return Piece.get_legal_moves(piece.type, piece.side, board, square)
	if piece.side != bonus.side:
		return []
	match bonus.kind:
		"step":
			if board != bonus.board or square != bonus.square:
				return []
			var steps := Piece.step_moves(Piece.KING_OFFSETS, piece.side, board, square)
			return CaptureRules.filter(steps, { "type": piece.type, "side": piece.side, "board": board, "square": square })
		"pawn":
			if piece.type == Piece.Type.PAWN:
				return Piece.get_legal_moves(piece.type, piece.side, board, square)
	return []

## Notes a piece's `home` when a match starts, so a Phoenix knows where to return.
static func mark_homes(state: GameState) -> void:
	for board in state.boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			for effect in _effects(piece, "on_captured"):
				if effect.kind == "rebirth":
					piece["home"] = { "board": board, "square": square }

## At the end of `side`'s turn: revivals count down and return once due (and the square is free).
static func tick_revivals(state: GameState, side: Piece.Side) -> void:
	var current := state.current_match
	for revival in current.revivals.duplicate():
		if revival.side != side:
			continue
		revival.turns = maxi(revival.turns - 1, 0)
		if revival.turns == 0 and is_instance_valid(revival.board) and not revival.board.pieces.has(revival.square):
			revival.piece["reborn"] = true
			revival.board.pieces[revival.square] = revival.piece
			revival.board.queue_redraw()
			current.revivals.erase(revival)
			current.last_event += " | the %s rises again" % _name(revival.piece)

# ---- effects ------------------------------------------------------------------------------

static func _queue_rebirth(state: GameState, victim: Dictionary, effect: Dictionary, result: Dictionary) -> void:
	var piece: Dictionary = victim.piece
	if not state.current_match.active or piece.get("reborn", false) or not piece.has("home"):
		return
	state.current_match.revivals.append({ "piece": piece, "board": piece.home.board, "square": piece.home.square, "turns": effect.turns, "side": piece.side })
	result.notes.append("the %s will return in %d turns" % [_name(piece), effect.turns])

## The victim's square and neighbours: it splits into knights on the empty ones.
static func _split(state: GameState, victim: Dictionary, effect: Dictionary, result: Dictionary) -> void:
	var neighbours := _neighbours(victim.board, victim.square)
	var empty := neighbours.filter(func(n): return not n.board.pieces.has(n.square))
	var crowded := empty.size() < neighbours.size()
	var count := mini(effect.crowded if crowded else effect.alone, empty.size())
	for i in count:
		_spawn(empty[i].board, empty[i].square, Piece.Type.KNIGHT, victim.piece.side)
	result.notes.append("the %s split into %d knight%s" % [_name(victim.piece), count, "" if count == 1 else "s"])

static func _raise_pawn(state: GameState, attacker: Dictionary, result: Dictionary) -> void:
	var slot := back_rank_square(state, attacker.side)
	if slot.is_empty():
		result.notes.append("no room to raise a pawn")
		return
	_spawn(slot.board, slot.square, Piece.Type.PAWN, attacker.side)
	result.notes.append("a pawn rises on your back rank")

## Where a pawn raised for `side` appears: the empty square of its own zone farthest
## from the enemy zone (or, with no zones, the far end of a board's home row).
static func back_rank_square(state: GameState, side: Piece.Side) -> Dictionary:
	var options: Array = []
	for board in state.boards:
		for square in board.zone_owner:
			if board.zone_owner[square] == side and not board.pieces.has(square):
				options.append({ "board": board, "square": square })
	if options.is_empty():
		for board in state.boards:
			var row: int = board.grid_height - 1 if side == Piece.Side.WHITE else 0
			for x in board.grid_width:
				if not board.pieces.has(Vector2i(x, row)):
					options.append({ "board": board, "square": Vector2i(x, row) })
	if options.is_empty():
		return {}
	var field := PawnMovement.distance_field(state.boards[0], side)
	var best: Dictionary = options[0]
	var best_distance := -1
	for option in options:
		var distance: int = field[option.board].get(option.square, 0) if not field.is_empty() and field.has(option.board) else 0
		if distance > best_distance:
			best = option
			best_distance = distance
	return best

static func _neighbours(board: Board, square: Vector2i) -> Array:
	var found: Array = []
	for offset in Piece.KING_OFFSETS:
		var next: Dictionary = Piece.step_across(board, square, offset)
		if not next.is_empty() and not found.any(func(n): return n.board == next.board and n.square == next.square):
			found.append(next)
	return found

static func _spawn(board: Board, square: Vector2i, type: Piece.Type, side: Piece.Side) -> void:
	board.pieces[square] = { "type": type, "side": side, "spawned": true }
	board.queue_redraw()

static func _effects(piece: Dictionary, key: String) -> Array:
	return PieceDefs.effects(piece.type, key) if PieceDefs.has(piece.type) else []

static func _name(piece: Dictionary) -> String:
	return Piece.Type.find_key(piece.type).capitalize()
