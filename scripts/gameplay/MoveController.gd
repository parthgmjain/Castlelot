class_name MoveController
extends RefCounted

## A click while not editing zones: either completes a pending move onto a
## highlighted square, or selects the clicked square (and shows its piece's moves).
static func click(state: GameState, board: Board, square: Vector2i) -> void:
	for move in state.current_moves:
		if move.board == board and move.square == square:
			execute(state, move)
			return

	for b in state.boards:
		if b != board:
			b.clear_selection()

	state.active_board = board
	state.active_square = square
	refresh(state)

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
static func execute(state: GameState, move: Dictionary) -> void:
	var piece: Dictionary = state.active_board.pieces[state.active_square]
	state.active_board.pieces.erase(state.active_square)
	move.board.pieces[move.square] = piece
	state.active_board.queue_redraw()
	move.board.queue_redraw()

	for b in state.boards:
		b.clear_selection()
		b.clear_move_markers()
	state.clear_active()

static func clear_selection(state: GameState) -> void:
	state.clear_active()
	for b in state.boards:
		b.clear_selection()
	refresh(state)
