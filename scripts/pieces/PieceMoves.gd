class_name PieceMoves
extends RefCounted
## Turns a PieceDefs rule list into legal moves, following portals across
## boards like every other piece. Moves are { board, square, capture }.

static func generate(type: Piece.Type, side: Piece.Side, board: Board, from: Vector2i) -> Array:
	var moves: Array = []
	var frame: Dictionary = {}
	for rule in PieceDefs.rules(type):
		if rule.get("local", false) and frame.is_empty():
			frame = _frame(board, from, side)
		var vectors := _vectors(rule, frame)
		var mode: String = rule.get("mode", "any")
		match rule.kind:
			"step":
				for offset in vectors:
					var dest: Dictionary = Piece.step_across(board, from, offset)
					if not dest.is_empty():
						_emit(moves, dest, side, mode)
			"leap":
				for offset in vectors:
					var dest: Dictionary = Piece.trace_path(board, from, offset)
					if not dest.is_empty():
						_emit(moves, dest, side, mode)
			"twin_leap":
				_twin_leaps(vectors, side, board, from, moves)
			"slide":
				_slide(vectors, rule, side, board, from, moves)
			"cannon":
				_cannon(vectors, side, board, from, moves)
			"grasshopper":
				_grasshopper(vectors, side, board, from, moves)
			"step_slide":
				_step_slide(vectors, rule, side, board, from, moves)
	return _without_duplicates(moves)

## Which way is "forward" (toward the enemy zone, like a pawn's heading) and
## which way is to the piece's right.
static func _frame(board: Board, from: Vector2i, side: Piece.Side) -> Dictionary:
	var forward := PawnMovement.heading(board, from, side)
	if forward == Vector2i.ZERO:
		forward = PawnMovement.home_direction(side)
	return { "forward": forward, "right": Vector2i(-forward.y, forward.x) }

## The rule's vectors in board terms. Local ones are (sideways, forward).
static func _vectors(rule: Dictionary, frame: Dictionary) -> Array:
	var raw: Array = rule.get("to", rule.get("dirs", []))
	if not rule.get("local", false):
		return raw
	return raw.map(func(v: Vector2i) -> Vector2i: return v.x * frame.right + v.y * frame.forward)

## Adds the move if `mode` allows what is on the square. Returns whether it was empty.
static func _emit(moves: Array, dest: Dictionary, side: Piece.Side, mode: String) -> bool:
	var occupant = dest.board.pieces.get(dest.square)
	if occupant == null:
		if mode != "capture":
			moves.append({ "board": dest.board, "square": dest.square, "capture": false })
		return true
	if occupant.side != side and mode != "move":
		moves.append({ "board": dest.board, "square": dest.square, "capture": true })
	return false

static func _twin_leaps(offsets: Array, side: Piece.Side, board: Board, from: Vector2i, moves: Array) -> void:
	for offset in offsets:
		var first: Dictionary = Piece.trace_path(board, from, offset)
		if first.is_empty():
			continue
		if not _emit(moves, first, side, "any"):
			continue           # something stands on the first landing square: no second jump
		var second: Dictionary = Piece.trace_path(first.board, first.square, offset)
		if not second.is_empty():
			_emit(moves, second, side, "any")

## Walks each direction. Options: min, max (0 = no limit), through (keep going
## over pieces, they just can't be landed on unless enemy), bounce (reflect off
## a board edge this many times), mode.
static func _slide(dirs: Array, options: Dictionary, side: Piece.Side, board: Board, from: Vector2i, moves: Array) -> void:
	var lowest: int = options.get("min", 1)
	var highest: int = options.get("max", 0)
	var through: bool = options.get("through", false)
	var mode: String = options.get("mode", "any")
	for direction in dirs:
		var heading: Vector2i = direction
		var current_board: Board = board
		var current_square: Vector2i = from
		var bounces_left: int = options.get("bounce", 0)
		var steps := 0
		while highest == 0 or steps < highest:
			var dest: Dictionary = Piece.step_across(current_board, current_square, heading)
			if dest.is_empty() and bounces_left > 0:
				var rebound := _rebound(current_board, current_square, heading)
				if not rebound.is_empty():
					heading = rebound.direction
					dest = rebound.dest
					bounces_left -= 1
			if dest.is_empty():
				break
			steps += 1
			var was_empty := true
			if steps >= lowest:
				was_empty = _emit(moves, dest, side, mode)
			else:
				was_empty = not dest.board.pieces.has(dest.square)
			if not was_empty and not through:
				break
			current_board = dest.board
			current_square = dest.square

## Reflects a diagonal off whichever edge it hit: flip x, else flip y.
static func _rebound(board: Board, square: Vector2i, direction: Vector2i) -> Dictionary:
	for flipped in [Vector2i(-direction.x, direction.y), Vector2i(direction.x, -direction.y)]:
		var dest: Dictionary = Piece.step_across(board, square, flipped)
		if not dest.is_empty():
			return { "direction": flipped, "dest": dest }
	return {}

## Rook-style moves onto empty squares; captures the first piece beyond exactly one screen.
static func _cannon(dirs: Array, side: Piece.Side, board: Board, from: Vector2i, moves: Array) -> void:
	for direction in dirs:
		var current_board: Board = board
		var current_square: Vector2i = from
		var screened := false
		while true:
			var dest: Dictionary = Piece.step_across(current_board, current_square, direction)
			if dest.is_empty():
				break
			var occupant = dest.board.pieces.get(dest.square)
			if not screened:
				if occupant == null:
					moves.append({ "board": dest.board, "square": dest.square, "capture": false })
				else:
					screened = true
			elif occupant != null:
				if occupant.side != side:
					moves.append({ "board": dest.board, "square": dest.square, "capture": true })
				break
			current_board = dest.board
			current_square = dest.square

## Travels to the first piece in each direction, then lands directly behind it.
static func _grasshopper(dirs: Array, side: Piece.Side, board: Board, from: Vector2i, moves: Array) -> void:
	for direction in dirs:
		var current_board: Board = board
		var current_square: Vector2i = from
		while true:
			var dest: Dictionary = Piece.step_across(current_board, current_square, direction)
			if dest.is_empty():
				break
			if dest.board.pieces.has(dest.square):
				var landing: Dictionary = Piece.step_across(dest.board, dest.square, direction)
				if not landing.is_empty():
					_emit(moves, landing, side, "any")
				break
			current_board = dest.board
			current_square = dest.square

## One diagonal step, then a straight run outward along either of its axes.
static func _step_slide(dirs: Array, options: Dictionary, side: Piece.Side, board: Board, from: Vector2i, moves: Array) -> void:
	for diagonal in dirs:
		var first: Dictionary = Piece.step_across(board, from, diagonal)
		if first.is_empty():
			continue
		if not _emit(moves, first, side, "any"):
			continue
		var outward := [Vector2i(diagonal.x, 0), Vector2i(0, diagonal.y)]
		_slide(outward, { "max": options.get("then_max", 0) }, side, first.board, first.square, moves)

static func _without_duplicates(moves: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for move in moves:
		var key := [move.board.get_instance_id(), move.square]
		if not seen.has(key):
			seen[key] = true
			out.append(move)
	return out
