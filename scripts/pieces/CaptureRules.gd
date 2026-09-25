class_name CaptureRules
extends RefCounted
## Who may not capture whom. A piece's own `protection` rules (PieceDefs) and the
## `aura` rules of friendly pieces standing next to it are checked against every
## capture a piece could make; protected victims simply drop out of its moves.
##
## Rule kinds (see PieceDefs):
##   front_adjacent  the attacker stands on the square directly in front of the victim
##   from_front      the attacker stands anywhere in front of the victim (its heading)
##   attacker_types  attackers of these types (`types`) may not capture
##   only_attackers  only attackers of these types (`types`) or tiers (`tiers`) may capture

## `attacker` is { type, side, board, square } - the piece about to move, where it stands now.
## Returns `moves` without the captures the victims are protected from.
static func filter(moves: Array, attacker: Dictionary) -> Array:
	var kept: Array = []
	for move in moves:
		if not move.capture and not move.has("hits"):
			kept.append(move)
		elif move.get("stay", false):
			var survivors := _unprotected(move.hits, attacker)
			if survivors.size() == move.hits.size():
				kept.append(move)
			elif survivors.any(func(h): return h.board == move.board and h.square == move.square):
				var reduced: Dictionary = move.duplicate()
				reduced["hits"] = survivors                   # the flame skips whoever is protected
				kept.append(reduced)
		elif MoveController.victims_of(move).all(func(v): return can_capture(attacker, v)):
			kept.append(move)
	return kept

## `victims` is [{ board, square }] (extra keys are ignored); returns the ones that may be captured.
static func _unprotected(victims: Array, attacker: Dictionary) -> Array:
	return victims.filter(func(v): return can_capture(attacker, { "piece": v.board.pieces[v.square], "board": v.board, "square": v.square }))

## Whether `attacker` may capture `victim` ({ piece, board, square }).
static func can_capture(attacker: Dictionary, victim: Dictionary) -> bool:
	var type: Piece.Type = victim.piece.type
	if PieceDefs.has(type):
		for rule in PieceDefs.protection(type):
			if _forbids(rule, attacker, victim):
				return false
	for offset in Piece.KING_OFFSETS:
		var neighbour: Dictionary = Piece.step_across(victim.board, victim.square, offset)
		if neighbour.is_empty():
			continue
		var friend = neighbour.board.pieces.get(neighbour.square)
		if friend != null and friend.side == victim.piece.side and PieceDefs.has(friend.type):
			for rule in PieceDefs.aura(friend.type):
				if _forbids(rule, attacker, victim):
					return false
	return true

static func _forbids(rule: Dictionary, attacker: Dictionary, victim: Dictionary) -> bool:
	match rule.kind:
		"front_adjacent":
			var front: Dictionary = Piece.step_across(victim.board, victim.square, PieceMoves.frame(victim.board, victim.square, victim.piece.side).forward)
			return not front.is_empty() and front.board == attacker.board and front.square == attacker.square
		"from_front":
			var forward: Vector2i = PieceMoves.frame(victim.board, victim.square, victim.piece.side).forward
			var offset := world_square(attacker.board, attacker.square) - world_square(victim.board, victim.square)
			return offset.x * forward.x + offset.y * forward.y > 0
		"attacker_types":
			return rule.types.has(attacker.type)
		"only_attackers":
			return not (rule.types.has(attacker.type) or rule.get("tiers", []).has(Piece.tier(attacker.type)))
	return false

## A square's position in the shared world, so "in front of" still makes sense across boards.
static func world_square(board: Board, square: Vector2i) -> Vector2i:
	return square + Vector2i((board.position / Board.SQUARE_SIZE).round())
