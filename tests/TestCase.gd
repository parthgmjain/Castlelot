extends RefCounted
## Base class for every test file. A test file is `extends "res://tests/TestCase.gd"`
## and declares methods named `test_*`; the runner makes a fresh instance for each
## one, so tests can't leak state into each other. Test methods may `await`.

const BoardScene := preload("res://scenes/Board.tscn")
const MainScene := preload("res://scenes/Main.tscn")

const WHITE := Piece.Side.WHITE
const BLACK := Piece.Side.BLACK
const KING := Piece.Type.KING
const QUEEN := Piece.Type.QUEEN
const ROOK := Piece.Type.ROOK
const BISHOP := Piece.Type.BISHOP
const KNIGHT := Piece.Type.KNIGHT
const PAWN := Piece.Type.PAWN

var tree: SceneTree
var checks := 0
var failures: Array = []

var _tracked: Array = []

func check(condition: bool, message: String = "check failed") -> void:
	checks += 1
	if not condition:
		failures.append(message)

func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])

## Frees everything the test created. Called by the runner after each test.
func cleanup() -> void:
	for node in _tracked:
		if is_instance_valid(node):
			node.queue_free()
	_tracked.clear()
	await tree.process_frame

func track(node: Node) -> Node:
	_tracked.append(node)
	return node

func pump(frames: int = 1) -> void:
	for i in frames:
		await tree.process_frame

# ---- building blocks -------------------------------------------------------

func make_board(width: int = 8, height: int = 8) -> Board:
	var board: Board = BoardScene.instantiate()
	board.grid_width = width
	board.grid_height = height
	tree.root.add_child(board)
	track(board)
	return board

func put(board: Board, square: Vector2i, type: Piece.Type, side: Piece.Side) -> Dictionary:
	var piece := { "type": type, "side": side }
	board.pieces[square] = piece
	return piece

## A one-board GameState with `pieces` = [[square, type, side], ...].
func make_state(board: Board, pieces: Array = []) -> GameState:
	var state := GameState.new()
	state.boards = [board]
	for p in pieces:
		put(board, p[0], p[1], p[2])
	return state

## Two square boards, A on the left and B on the right, joined only along
## `rows` (A's right column <-> B's left column). Returns [a, b].
func make_rig(rows: Array, size: int = 5) -> Array:
	var a := make_board(size, size)
	var b := make_board(size, size)
	var to_b := {}
	var to_a := {}
	for r in rows:
		to_b[Vector2i(size - 1, r)] = [{ "direction": Vector2i(1, 0), "target_board": b, "target_square": Vector2i(0, r) }]
		to_a[Vector2i(0, r)] = [{ "direction": Vector2i(-1, 0), "target_board": a, "target_square": Vector2i(size - 1, r) }]
	a.set_portals(to_b)
	b.set_portals(to_a)
	return [a, b]

## The real Main scene, with the AI's pause removed. `await` it.
## Boards start at a fixed 8x8 so tests can use fixed squares; pass
## random_sizes = true (or change the board count) to get random ones.
func load_main(random_sizes: bool = false) -> Node:
	var main = MainScene.instantiate()
	tree.root.add_child(main)
	main.turn_flow.ai_delay = 0.0
	main.shop_screen.reveal_delay = 0.0
	track(main)
	await pump(2)
	if not random_sizes:
		var panel: ControlPanel = main.panel
		for box in panel._width_boxes + panel._height_boxes:
			box.value = 8
	return main

## Regenerates the boards (and optionally zones/armies) through the real buttons.
## Waits a frame first so boards queued for deletion are really gone - otherwise
## they'd still answer clicks.
func new_world(main: Node, white_tiles: int = 8, black_tiles: int = 8, armies: bool = false) -> void:
	var panel: ControlPanel = main.panel
	panel.refresh_button.pressed.emit()
	await pump()
	panel.white_zone_spin_box.value = white_tiles
	panel.black_zone_spin_box.value = black_tiles
	panel.generate_zones_button.pressed.emit()
	if armies:
		panel.auto_place_white_button.pressed.emit()
		panel.auto_place_black_button.pressed.emit()
	await pump()

# ---- helpers ---------------------------------------------------------------

func squares_of(moves: Array) -> Array:
	var out := []
	for m in moves:
		out.append(m.square)
	return out

func has_move(moves: Array, board: Board, square: Vector2i) -> bool:
	for m in moves:
		if m.board == board and m.square == square:
			return true
	return false

func moves_on(moves: Array, board: Board) -> Array:
	return moves.filter(func(m): return m.board == board).map(func(m): return m.square)

## Synthetic left click at viewport coordinates. Headless windows are tiny, so
## the event must be pushed with local coordinates or it lands off-screen.
func click_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	tree.root.push_input(event, true)

## A full mouse click on a control: buttons only fire on release, so this sends
## the press and the release (and lets a frame pass between them). `await` it.
func click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		tree.root.push_input(event, true)
		await tree.process_frame

func square_position(board: Board, square: Vector2i) -> Vector2:
	return board.get_global_transform() * board.local_square_center(square)

func king_alive(boards: Array, side: Piece.Side) -> bool:
	for board in boards:
		for square in board.pieces:
			if board.pieces[square].side == side and board.pieces[square].type == KING:
				return true
	return false

func count_zone(boards: Array, side: Piece.Side) -> int:
	var total := 0
	for board in boards:
		for square in board.zone_owner:
			if board.zone_owner[square] == side:
				total += 1
	return total

func pieces_of(boards: Array, side: Piece.Side, include_king: bool = true) -> Array:
	var out := []
	for board in boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == side and (include_king or piece.type != KING):
				out.append({ "board": board, "square": square, "piece": piece })
	return out

## Every board reachable from the first one through portals.
func boards_connected(boards: Array) -> bool:
	var visited := { boards[0]: true }
	var queue: Array = [boards[0]]
	while not queue.is_empty():
		var b: Board = queue.pop_front()
		for square in b.portals:
			for portal in b.portals[square]:
				if not visited.has(portal.target_board):
					visited[portal.target_board] = true
					queue.append(portal.target_board)
	return visited.size() == boards.size()

func any_overlap(boards: Array) -> bool:
	for i in boards.size():
		for j in boards.size():
			if i == j:
				continue
			var pi: Vector2 = boards[i].position
			var si: Vector2 = boards[i].pixel_size()
			var pj: Vector2 = boards[j].position
			var sj: Vector2 = boards[j].pixel_size()
			if pi.x < pj.x + sj.x and pi.x + si.x > pj.x and pi.y < pj.y + sj.y and pi.y + si.y > pj.y:
				return true
	return false
