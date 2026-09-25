class_name MoveController
extends RefCounted

## A click while not editing zones: either completes a pending move onto a
## highlighted square, or selects the clicked square (and shows its piece's moves).
## Returns the finished move (see execute) or {} when it only selected.
static func click(state: GameState, board: Board, square: Vector2i) -> Dictionary:
	for move in state.current_moves:
		if move.board == board and move.square == square:
			return execute(state, move)

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
	state.current_moves = Piece.get_legal_moves(piece.type, piece.side, state.active_board, state.active_square)

	var grouped: Dictionary = {}
	for move in state.current_moves:
		if not grouped.has(move.board):
			grouped[move.board] = { "moves": [], "captures": [] }
		if move.capture:
			grouped[move.board].captures.append(move.square)
		else:
			grouped[move.board].moves.append(move.square)

	for b in grouped:
		b.set_move_markers(grouped[b].moves, grouped[b].captures)

## Moves the selected piece to `move.square` on `move.board` and deselects.
## Returns { piece, victim (or null), board, square, from_board, from_square }.
static func execute(state: GameState, move: Dictionary) -> Dictionary:
	var from_board: Board = state.active_board
	var from_square: Vector2i = state.active_square
	var piece: Dictionary = from_board.pieces[from_square]
	var victim = move.board.pieces.get(move.square)
	from_board.pieces.erase(from_square)
	move.board.pieces[move.square] = piece
	if PawnMovement.reached_promotion(piece, move.board, move.square):
		state.pending_promotion = { "piece": piece, "board": move.board, "square": move.square }
	from_board.queue_redraw()
	move.board.queue_redraw()

	for b in state.boards:
		b.clear_selection()
		b.clear_move_markers()
	state.clear_active()
	return { "piece": piece, "victim": victim, "board": move.board, "square": move.square, "from_board": from_board, "from_square": from_square }

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
	for b in state.boards:
		b.set_last_move_squares(squares.get(b, []))
