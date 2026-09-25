class_name MoveEffects
extends RefCounted
## What a move sets off beyond the move itself, driven by the `on_capture` /
## `on_captured` lists in PieceDefs, plus the bonus moves some captures grant.
##
## on_captured (the victim's effects):  destroy_attacker, rebirth { turns }, split { alone, crowded }
## on_capture  (the capturer's effects): raise_pawn, bonus_step, bonus_pawn
## on_move     (any move it makes):      double_turn { every }
## actions     (instead of moving):      undo

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
static func bonus_after(state: GameState, result: Dictionary, was_bonus: bool) -> Dictionary:
	if was_bonus or not result.losses.is_empty():
		return {}
	var mover: Piece.Side = result.piece.side
	for effect in _effects(result.piece, "on_move"):
		if effect.kind == "double_turn" and (state.current_match.turns_taken[mover] + 1) % effect.every == 0:
			return { "kind": "repeat", "side": mover, "board": result.board, "square": result.square,
				"label": "it's the %s's double turn, so it may move again" % _name(result.piece) }
	if result.victims.is_empty():
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
		return Piece.get_legal_moves(piece.type, piece.side, board, square) + action_moves(state, piece)
	if piece.side != bonus.side:
		return []
	match bonus.kind:
		"repeat":
			if board == bonus.board and square == bonus.square:
				return Piece.get_legal_moves(piece.type, piece.side, board, square)
		"step":
			if board != bonus.board or square != bonus.square:
				return []
			var steps := Piece.step_moves(Piece.KING_OFFSETS, piece.side, board, square)
			return CaptureRules.filter(steps, { "type": piece.type, "side": piece.side, "board": board, "square": square })
		"pawn":
			if piece.type == Piece.Type.PAWN:
				return Piece.get_legal_moves(piece.type, piece.side, board, square)
		"any":
			return Piece.get_legal_moves(piece.type, piece.side, board, square)
	return []

## Actions a piece can take instead of moving. The Chronomancer's rewind is offered on the
## square where the opponent's last move ended; make it with a right-click (it is free, and
## you then move as usual). Once per match per Chronomancer, and only right after the opponent moved.
static func action_moves(state: GameState, piece: Dictionary) -> Array:
	var current := state.current_match
	if not PieceDefs.has(piece.type) or not current.active:
		return []
	for action in PieceDefs.effects(piece.type, "actions"):
		if action.kind == "undo" and not piece.get("undo_used", false) and not current.history.is_empty():
			var last: Dictionary = current.history.back()
			if last.side != piece.side and last.has("end") and is_instance_valid(last.end.board):
				return [{ "board": last.end.board, "square": last.end.square, "capture": false, "stay": true, "special": true, "undo": true }]
	return []

## What the boards, scores and waiting revivals look like right now, before `side` moves.
static func take_snapshot(state: GameState, side: Piece.Side) -> Dictionary:
	var current := state.current_match
	var boards: Array = []
	for board in state.boards:
		boards.append({ "board": board, "pieces": board.pieces.duplicate(true) })
	return { "side": side, "boards": boards, "scores": current.scores.duplicate(),
		"revivals": current.revivals.map(func(r): return r.duplicate()), "last_event": current.last_event }

## Puts everything back the way the newest snapshot recorded it, and marks the Chronomancer at
## `square` as spent (when given one - the Turning Tide card rewinds with no piece of its own).
## Returns a note for the event line.
static func rewind(state: GameState, board: Board = null, square: Vector2i = Vector2i(-1, -1)) -> String:
	var current := state.current_match
	var snapshot: Dictionary = current.history.pop_back()
	for saved in snapshot.boards:
		saved.board.pieces = saved.pieces.duplicate(true)
		saved.board.queue_redraw()
	current.scores = snapshot.scores.duplicate()
	current.revivals = snapshot.revivals.map(func(r): return r.duplicate())
	current.bonus = {}
	state.pending_promotion = {}
	var chronomancer = board.pieces.get(square) if board != null else null
	if chronomancer != null:
		chronomancer["undo_used"] = true
	current.last_event = "%s turned back time: the last move never happened" % ("You" if snapshot.side != current.player_side else "The AI")
	return current.last_event

## Notes every piece's starting square when a match begins: a Phoenix (or Mantle of the
## Phoenix) needs it to know where to return, and Rite of Rebirth needs it for any piece.
static func mark_homes(state: GameState) -> void:
	for board in state.boards:
		for square in board.pieces:
			board.pieces[square]["home"] = { "board": board, "square": square }

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
		spawn(empty[i].board, empty[i].square, Piece.Type.KNIGHT, victim.piece.side)
	result.notes.append("the %s split into %d knight%s" % [_name(victim.piece), count, "" if count == 1 else "s"])

static func _raise_pawn(state: GameState, attacker: Dictionary, result: Dictionary) -> void:
	var slot := back_rank_square(state, attacker.side)
	if slot.is_empty():
		result.notes.append("no room to raise a pawn")
		return
	spawn(slot.board, slot.square, Piece.Type.PAWN, attacker.side)
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

## A temporary piece (Hydra's knights, a raised pawn, Call to Arms, Echo of Steel): no roster_id,
## so it's never counted as lost and simply disappears when the boards are next regenerated.
static func spawn(board: Board, square: Vector2i, type: Piece.Type, side: Piece.Side) -> void:
	board.pieces[square] = { "type": type, "side": side, "spawned": true }
	board.queue_redraw()

## `key`'s effects for this piece: its type's own (PieceDefs) plus any granted just to this one
## instance for the match (Mantle of the Phoenix uses "extra_on_captured").
static func _effects(piece: Dictionary, key: String) -> Array:
	var base: Array = PieceDefs.effects(piece.type, key) if PieceDefs.has(piece.type) else []
	return base + piece.get("extra_" + key, [])

static func _name(piece: Dictionary) -> String:
	return Piece.Type.find_key(piece.type).capitalize()
