class_name MoveController
extends RefCounted

## A click while not editing zones: either completes a pending move onto a
## highlighted square, or selects the clicked square (and shows its piece's moves).
## Returns the finished move (see execute) or {} when it only selected.
## `special` (a right-click) makes the "attack without moving" version of a
## move; it never selects, and does nothing where there is no special move.
static func click(state: GameState, board: Board, square: Vector2i, special: bool = false) -> Dictionary:
	var chosen := _move_at(state.current_moves, board, square, special)
	if not chosen.is_empty():
		return execute(state, chosen)
	if special:
		return {}

	for b in state.boards:
		if b != board:
			b.clear_selection()

	state.active_board = board
	state.active_square = square
	refresh(state)
	return {}

## Recomputes the selected piece's legal moves (possibly across boards) and
## puts the markers on whichever boards they land on.
static func refresh(state: GameState) -> void:
	for b in state.boards:
		b.clear_move_markers()
	state.current_moves = []

	if state.active_board == null or not state.active_board.pieces.has(state.active_square):
		return

	var piece: Dictionary = state.active_board.pieces[state.active_square]
	state.current_moves = MoveEffects.moves_for(state, piece, state.active_board, state.active_square)

	var grouped: Dictionary = {}
	for move in state.current_moves:
		if not grouped.has(move.board):
			grouped[move.board] = { "moves": [], "captures": [], "specials": [], "swaps": [] }
		if move.get("special", false):
			grouped[move.board].specials.append(move.square)
		elif move.get("swap", false):
			grouped[move.board].swaps.append(move.square)
		elif move.capture:
			grouped[move.board].captures.append(move.square)
		else:
			grouped[move.board].moves.append(move.square)

	for b in grouped:
		b.set_move_markers(grouped[b].moves, grouped[b].captures, grouped[b].specials, grouped[b].swaps)

## The move a click on `square` means: a normal move first (or the special one
## when `special` is asked for, or when it's the only one there).
static func _move_at(moves: Array, board: Board, square: Vector2i, special: bool) -> Dictionary:
	var fallback := {}
	for move in moves:
		if move.board != board or move.square != square:
			continue
		if move.get("special", false) == special:
			return move
		if fallback.is_empty() and not special:
			fallback = move
	return fallback

## Everything a move destroys: [{ piece, board, square }]. The piece on the
## destination (if any) comes first, then any extra `hits`. A "stay" move only
## destroys its hits, and a swap (whose destination holds a friend) destroys nothing.
static func victims_of(move: Dictionary) -> Array:
	var targets: Array = move.get("hits", [])
	if not move.get("stay", false) and not move.get("swap", false):
		targets = [{ "board": move.board, "square": move.square }] + targets
	var found: Array = []
	for target in targets:
		var piece = target.board.pieces.get(target.square)
		if piece != null:
			found.append({ "piece": piece, "board": target.board, "square": target.square })
	return found

## How many past moves are kept for a Chronomancer to rewind.
const HISTORY_LIMIT := 6

## The Chronomancer's rewind: it doesn't move and costs nothing (see MoveEffects.rewind).
static func _rewind(state: GameState, board: Board, square: Vector2i) -> Dictionary:
	var note := MoveEffects.rewind(state, board, square)
	for b in state.boards:
		b.clear_selection()
		b.clear_move_markers()
	state.clear_active()
	return { "piece": board.pieces[square], "victim": null, "victims": [], "board": board, "square": square,
		"from_board": board, "from_square": square, "swapped": {}, "losses": [], "notes": [note], "undo": true }

## Carries out the selected piece's move and deselects. Returns
## { piece, victim (the first victim or null), victims, board, square, from_board,
## from_square, swapped, losses, notes } where board/square is where the piece
## ended up, `swapped` the friend it traded places with (or {}), `losses` its own
## pieces that effects destroyed and `notes` short sentences about what was set off.
static func execute(state: GameState, move: Dictionary) -> Dictionary:
	var from_board: Board = state.active_board
	var from_square: Vector2i = state.active_square
	if move.get("undo", false):
		return _rewind(state, from_board, from_square)
	var piece: Dictionary = from_board.pieces[from_square]
	var snapshot := MoveEffects.take_snapshot(state, piece.side) if state.current_match.active else {}
	var victims := victims_of(move)
	for victim in victims:
		victim.board.pieces.erase(victim.square)
	var end_board: Board = from_board
	var end_square: Vector2i = from_square
	var swapped := {}
	if not move.get("stay", false):
		var friend = move.board.pieces.get(move.square) if move.get("swap", false) else null
		from_board.pieces.erase(from_square)
		move.board.pieces[move.square] = piece
		end_board = move.board
		end_square = move.square
		if PawnMovement.reached_promotion(piece, move.board, move.square):
			state.pending_promotion = { "piece": piece, "board": move.board, "square": move.square }
		if friend != null:
			from_board.pieces[from_square] = friend
			swapped = { "piece": friend, "board": from_board, "square": from_square }
			if PawnMovement.reached_promotion(friend, from_board, from_square):
				state.pending_promotion = { "piece": friend, "board": from_board, "square": from_square }
	if move.get("rest", 0) > 0 and state.current_match.active:
		piece["rest"] = move.rest

	var result := {
		"piece": piece, "victim": victims[0].piece if not victims.is_empty() else null, "victims": victims,
		"board": end_board, "square": end_square, "from_board": from_board, "from_square": from_square,
		"swapped": swapped, "losses": [], "notes": [],
	}
	MoveEffects.apply(state, result)
	if not snapshot.is_empty():
		snapshot["end"] = { "board": end_board, "square": end_square }
		state.current_match.history.append(snapshot)
		if state.current_match.history.size() > HISTORY_LIMIT:
			state.current_match.history.pop_front()
	for b in state.boards:
		b.queue_redraw()
		b.clear_selection()
		b.clear_move_markers()
	state.clear_active()
	return result

static func clear_selection(state: GameState) -> void:
	state.clear_active()
	for b in state.boards:
		b.clear_selection()
	refresh(state)

## Highlights the squares of the latest move (pass {} to clear the highlight).
static func mark_last_move(state: GameState, result: Dictionary) -> void:
	var squares: Dictionary = {}
	if not result.is_empty():
		squares[result.from_board] = [result.from_square]
		if not squares.has(result.board):
			squares[result.board] = []
		squares[result.board].append(result.square)
		if result.board == result.from_board and result.square == result.from_square:
			for victim in result.victims:              # it didn't move: show what it hit
				if not squares.has(victim.board):
					squares[victim.board] = []
				squares[victim.board].append(victim.square)
	for b in state.boards:
		b.set_last_move_squares(squares.get(b, []))
