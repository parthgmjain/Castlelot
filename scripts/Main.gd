extends Node2D

const BOARD_SCENE := preload("res://scenes/Board.tscn")
const SQUARE_SIZE := 32.0
const MIN_DIM := 2
const MAX_DIM := 10
const DIRECTIONS := ["RIGHT", "LEFT", "UP", "DOWN"]
const DIR_VECTORS := { "RIGHT": Vector2i(1, 0), "LEFT": Vector2i(-1, 0), "UP": Vector2i(0, -1), "DOWN": Vector2i(0, 1) }
const PLAY_AREA := Vector2(1200.0, 500.0)
const BASE_POSITION := Vector2(40.0, 250.0)

@onready var boards_container: Node2D = $BoardsContainer
@onready var count_spin_box: SpinBox = $UI/VBox/CountRow/CountSpinBox
@onready var refresh_button: Button = $UI/VBox/CountRow/RefreshButton
@onready var sizes_row: HBoxContainer = $UI/VBox/SizesRow
@onready var white_zone_spin_box: SpinBox = $UI/VBox/ZoneRow/WhiteZoneSpinBox
@onready var black_zone_spin_box: SpinBox = $UI/VBox/ZoneRow/BlackZoneSpinBox
@onready var generate_zones_button: Button = $UI/VBox/ZoneRow/GenerateZonesButton
@onready var side_check_button: CheckButton = $UI/VBox/PieceRow/SideCheckButton
@onready var zone_edit_button: CheckButton = $UI/VBox/PieceRow/ZoneEditButton
@onready var king_button: Button = $UI/VBox/PieceRow/KingButton
@onready var queen_button: Button = $UI/VBox/PieceRow/QueenButton
@onready var rook_button: Button = $UI/VBox/PieceRow/RookButton
@onready var bishop_button: Button = $UI/VBox/PieceRow/BishopButton
@onready var knight_button: Button = $UI/VBox/PieceRow/KnightButton
@onready var pawn_button: Button = $UI/VBox/PieceRow/PawnButton
@onready var remove_button: Button = $UI/VBox/PieceRow/RemoveButton

var current_side: Piece.Side = Piece.Side.WHITE
var boards: Array = []
var attach_info: Array = []
var connections: Array = []
var board_width_boxes: Array = []
var board_height_boxes: Array = []
var active_board: Board = null
var active_square: Vector2i = Vector2i(-1, -1)
var current_moves: Array = []
var zone_edit_mode: bool = false

func _ready() -> void:
	count_spin_box.value_changed.connect(_on_count_changed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	side_check_button.toggled.connect(_on_side_toggled)
	zone_edit_button.toggled.connect(_on_zone_edit_toggled)
	generate_zones_button.pressed.connect(_on_generate_zones_pressed)
	king_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KING))
	queen_button.pressed.connect(_on_place_pressed.bind(Piece.Type.QUEEN))
	rook_button.pressed.connect(_on_place_pressed.bind(Piece.Type.ROOK))
	bishop_button.pressed.connect(_on_place_pressed.bind(Piece.Type.BISHOP))
	knight_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KNIGHT))
	pawn_button.pressed.connect(_on_place_pressed.bind(Piece.Type.PAWN))
	remove_button.pressed.connect(_on_remove_pressed)

	_rebuild_size_controls(int(count_spin_box.value))
	_generate_boards()

func _on_count_changed(value: float) -> void:
	_rebuild_size_controls(int(value))

func _on_refresh_pressed() -> void:
	_generate_boards()

func _rebuild_size_controls(count: int) -> void:
	for child in sizes_row.get_children():
		child.queue_free()
	board_width_boxes.clear()
	board_height_boxes.clear()

	for i in count:
		var label := Label.new()
		label.text = "Board %d:" % (i + 1)
		sizes_row.add_child(label)

		var width_box := SpinBox.new()
		width_box.min_value = MIN_DIM
		width_box.max_value = MAX_DIM
		width_box.value = randi_range(MIN_DIM, MAX_DIM)
		width_box.custom_minimum_size = Vector2(60, 0)
		width_box.value_changed.connect(_on_board_size_changed.bind(i, true))
		sizes_row.add_child(width_box)

		var height_box := SpinBox.new()
		height_box.min_value = MIN_DIM
		height_box.max_value = MAX_DIM
		height_box.value = randi_range(MIN_DIM, MAX_DIM)
		height_box.custom_minimum_size = Vector2(60, 0)
		height_box.value_changed.connect(_on_board_size_changed.bind(i, false))
		sizes_row.add_child(height_box)

		board_width_boxes.append(width_box)
		board_height_boxes.append(height_box)

func _on_board_size_changed(value: float, index: int, is_width: bool) -> void:
	if index >= boards.size():
		return
	var board = boards[index]
	if is_width:
		board.grid_width = int(value)
	else:
		board.grid_height = int(value)
	_relayout()

func _generate_boards() -> void:
	for board in boards:
		board.queue_free()
	boards.clear()
	attach_info.clear()
	connections.clear()
	active_board = null
	active_square = Vector2i(-1, -1)

	var count := int(count_spin_box.value)
	for i in count:
		var board = BOARD_SCENE.instantiate()
		boards_container.add_child(board)
		board.grid_width = int(board_width_boxes[i].value)
		board.grid_height = int(board_height_boxes[i].value)
		board.square_selected.connect(_on_square_selected.bind(board))
		board.square_right_clicked.connect(_on_square_right_clicked.bind(board))
		boards.append(board)

		if i == 0:
			attach_info.append(null)
		else:
			attach_info.append({
				"parent": randi_range(0, i - 1),
				"direction": DIRECTIONS[randi_range(0, DIRECTIONS.size() - 1)],
			})

	_relayout()

func _random_overlap_offset(parent_origin: float, parent_len: float, my_len: float) -> float:
	var min_offset: float = parent_origin - my_len + SQUARE_SIZE
	var max_offset: float = parent_origin + parent_len - SQUARE_SIZE
	var steps: int = int(round((max_offset - min_offset) / SQUARE_SIZE))
	if steps <= 0:
		return min(min_offset, max_offset)
	return min_offset + randi_range(0, steps) * SQUARE_SIZE

func _overlaps_any(candidate: Vector2, size: Vector2, positions: Array, sizes: Array, count: int) -> bool:
	for j in count:
		var other_pos: Vector2 = positions[j]
		var other_size: Vector2 = sizes[j]
		if candidate.x < other_pos.x + other_size.x and candidate.x + size.x > other_pos.x \
			and candidate.y < other_pos.y + other_size.y and candidate.y + size.y > other_pos.y:
			return true
	return false

func _relayout() -> void:
	if boards.is_empty():
		return

	var positions: Array = [Vector2.ZERO]
	var sizes: Array = [boards[0].pixel_size()]

	for i in range(1, boards.size()):
		var info: Dictionary = attach_info[i]
		var my_size: Vector2 = boards[i].pixel_size()
		sizes.append(my_size)
		var placed := false

		for attempt in 30:
			var parent_index: int = info.parent
			var direction: String = info.direction
			var parent_pos: Vector2 = positions[parent_index]
			var parent_size: Vector2 = sizes[parent_index]
			var candidate := Vector2.ZERO

			match direction:
				"RIGHT":
					candidate = Vector2(parent_pos.x + parent_size.x, _random_overlap_offset(parent_pos.y, parent_size.y, my_size.y))
				"LEFT":
					candidate = Vector2(parent_pos.x - my_size.x, _random_overlap_offset(parent_pos.y, parent_size.y, my_size.y))
				"DOWN":
					candidate = Vector2(_random_overlap_offset(parent_pos.x, parent_size.x, my_size.x), parent_pos.y + parent_size.y)
				"UP":
					candidate = Vector2(_random_overlap_offset(parent_pos.x, parent_size.x, my_size.x), parent_pos.y - my_size.y)

			if not _overlaps_any(candidate, my_size, positions, sizes, i):
				positions.append(candidate)
				placed = true
				break

			info.direction = DIRECTIONS[randi_range(0, DIRECTIONS.size() - 1)]

		if not placed:
			var max_x := 0.0
			for j in i:
				max_x = max(max_x, positions[j].x + sizes[j].x)
			positions.append(Vector2(max_x + SQUARE_SIZE, 0))
			info.parent = 0
			info.direction = "RIGHT"

	var min_pos: Vector2 = positions[0]
	var max_pos: Vector2 = positions[0] + sizes[0]
	for i in boards.size():
		min_pos.x = min(min_pos.x, positions[i].x)
		min_pos.y = min(min_pos.y, positions[i].y)
		max_pos.x = max(max_pos.x, positions[i].x + sizes[i].x)
		max_pos.y = max(max_pos.y, positions[i].y + sizes[i].y)

	var cluster_size: Vector2 = max_pos - min_pos
	var fit_scale: float = min(1.0, min(PLAY_AREA.x / cluster_size.x, PLAY_AREA.y / cluster_size.y))

	for i in boards.size():
		boards[i].position = positions[i] - min_pos

	boards_container.scale = Vector2(fit_scale, fit_scale)
	boards_container.position = BASE_POSITION + Vector2(
		max(0.0, (PLAY_AREA.x - cluster_size.x * fit_scale) / 2.0),
		max(0.0, (PLAY_AREA.y - cluster_size.y * fit_scale) / 2.0)
	)

	_compute_connections(positions, sizes)
	BoardColorizer.assign_colors(boards, connections)
	_build_portals()
	_refresh_moves()

func _build_connection(p: int, c: int, direction: String, positions: Array, sizes: Array) -> Dictionary:
	var p_pos: Vector2 = positions[p]
	var c_pos: Vector2 = positions[c]
	var p_size: Vector2 = sizes[p]
	var c_size: Vector2 = sizes[c]
	var a_squares: Array = []
	var b_squares: Array = []

	if direction == "RIGHT" or direction == "LEFT":
		var top: float = max(p_pos.y, c_pos.y)
		var bottom: float = min(p_pos.y + p_size.y, c_pos.y + c_size.y)
		var rows: int = int(round((bottom - top) / SQUARE_SIZE))
		var p_col: int = boards[p].grid_width - 1 if direction == "RIGHT" else 0
		var c_col: int = 0 if direction == "RIGHT" else boards[c].grid_width - 1
		for k in rows:
			var y: float = top + k * SQUARE_SIZE
			a_squares.append(Vector2i(p_col, int(round((y - p_pos.y) / SQUARE_SIZE))))
			b_squares.append(Vector2i(c_col, int(round((y - c_pos.y) / SQUARE_SIZE))))
	else:
		var left: float = max(p_pos.x, c_pos.x)
		var right: float = min(p_pos.x + p_size.x, c_pos.x + c_size.x)
		var cols: int = int(round((right - left) / SQUARE_SIZE))
		var p_row: int = boards[p].grid_height - 1 if direction == "DOWN" else 0
		var c_row: int = 0 if direction == "DOWN" else boards[c].grid_height - 1
		for k in cols:
			var x: float = left + k * SQUARE_SIZE
			a_squares.append(Vector2i(int(round((x - p_pos.x) / SQUARE_SIZE)), p_row))
			b_squares.append(Vector2i(int(round((x - c_pos.x) / SQUARE_SIZE)), c_row))

	return { "a_board": p, "a_squares": a_squares, "b_board": c, "b_squares": b_squares }

func _compute_connections(positions: Array, sizes: Array) -> void:
	connections.clear()
	for i in range(1, boards.size()):
		var info: Dictionary = attach_info[i]
		connections.append(_build_connection(info.parent, i, info.direction, positions, sizes))
	_apply_connection_squares()

func _apply_connection_squares() -> void:
	for i in boards.size():
		var squares: Array = []
		for conn in connections:
			if conn.a_board == i:
				squares.append_array(conn.a_squares)
			if conn.b_board == i:
				squares.append_array(conn.b_squares)
		boards[i].set_connection_squares(squares)

func _build_portals() -> void:
	var board_portals: Dictionary = {}
	for b in boards:
		board_portals[b] = {}

	for i in range(1, boards.size()):
		var info: Dictionary = attach_info[i]
		var conn: Dictionary = connections[i - 1]
		var direction: Vector2i = DIR_VECTORS[info.direction]
		var board_a: Board = boards[conn.a_board]
		var board_b: Board = boards[conn.b_board]

		for k in conn.a_squares.size():
			var sa: Vector2i = conn.a_squares[k]
			var sb: Vector2i = conn.b_squares[k]

			if not board_portals[board_a].has(sa):
				board_portals[board_a][sa] = []
			board_portals[board_a][sa].append({ "direction": direction, "target_board": board_b, "target_square": sb })

			if not board_portals[board_b].has(sb):
				board_portals[board_b][sb] = []
			board_portals[board_b][sb].append({ "direction": -direction, "target_board": board_a, "target_square": sa })

	for b in boards:
		b.set_portals(board_portals[b])

func _refresh_moves() -> void:
	for b in boards:
		b.clear_move_markers()
	current_moves = []

	if active_board == null or not active_board.pieces.has(active_square):
		return

	var piece: Dictionary = active_board.pieces[active_square]
	current_moves = Piece.get_legal_moves(piece.type, piece.side, active_board, active_square)

	var grouped: Dictionary = {}
	for move in current_moves:
		if not grouped.has(move.board):
			grouped[move.board] = { "moves": [], "captures": [] }
		if move.capture:
			grouped[move.board].captures.append(move.square)
		else:
			grouped[move.board].moves.append(move.square)

	for b in grouped:
		b.set_move_markers(grouped[b].moves, grouped[b].captures)

func _execute_move(move: Dictionary) -> void:
	var piece: Dictionary = active_board.pieces[active_square]
	active_board.pieces.erase(active_square)
	move.board.pieces[move.square] = piece
	active_board.queue_redraw()
	move.board.queue_redraw()

	for b in boards:
		b.clear_selection()
		b.clear_move_markers()

	active_board = null
	active_square = Vector2i(-1, -1)
	current_moves = []

func _on_square_selected(square: Vector2i, board: Board) -> void:
	if zone_edit_mode:
		board.set_zone(square, current_side)
		return

	for move in current_moves:
		if move.board == board and move.square == square:
			_execute_move(move)
			return

	for b in boards:
		if b != board:
			b.clear_selection()

	active_board = board
	active_square = square
	_refresh_moves()

func _on_square_right_clicked(square: Vector2i, board: Board) -> void:
	if zone_edit_mode:
		board.clear_zone(square)

func _on_generate_zones_pressed() -> void:
	if boards.is_empty():
		return

	for b in boards:
		b.pieces.clear()
		b.zone_owner.clear()
		b.clear_selection()
		b.clear_move_markers()
	active_board = null
	active_square = Vector2i(-1, -1)
	current_moves = []

	var white_board: Board = boards[0]
	var white_square := Vector2i(0, 0)
	var black_board: Board = _farthest_board(white_board)
	var black_square := Vector2i(black_board.grid_width - 1, black_board.grid_height - 1)

	white_board.place_piece(white_square, Piece.Type.KING, Piece.Side.WHITE)
	black_board.place_piece(black_square, Piece.Type.KING, Piece.Side.BLACK)

	_grow_zone(white_board, white_square, Piece.Side.WHITE, int(white_zone_spin_box.value))
	_grow_zone(black_board, black_square, Piece.Side.BLACK, int(black_zone_spin_box.value))

	for b in boards:
		b.queue_redraw()

func _farthest_board(from: Board) -> Board:
	var farthest: Board = from
	var farthest_dist: float = -1.0
	for b in boards:
		var dist: float = from.position.distance_to(b.position)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = b
	return farthest

## Fills the king's board completely (in spiral order from the king square)
## before spilling through any of that board's portals into unvisited
## neighboring boards, each filled the same way from its entry square.
func _grow_zone(king_board: Board, king_square: Vector2i, side: Piece.Side, tile_count: int) -> void:
	var visited: Dictionary = {}
	var queue: Array = [{ "board": king_board, "seed": king_square }]

	var assigned := 0
	while assigned < tile_count and not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var board: Board = entry.board
		var seed: Vector2i = entry.seed

		if visited.has(board):
			continue
		visited[board] = true

		# A spiral with this radius, centered anywhere inside the board, is
		# guaranteed to reach every square on it regardless of aspect ratio.
		var radius: int = max(board.grid_width, board.grid_height)
		var offsets: Array = ZoneGenerator.spiral_offsets((2 * radius + 1) * (2 * radius + 1))

		for offset in offsets:
			if assigned >= tile_count:
				break
			var square: Vector2i = seed + offset
			if not board.is_in_bounds(square):
				continue
			if board.zone_owner.has(square) and board.zone_owner[square] != side:
				continue
			if board.zone_owner.get(square) == side:
				continue
			board.set_zone(square, side)
			assigned += 1

		if assigned >= tile_count:
			return

		# Board is as full as it'll get for this side - spill through any of
		# its portals that landed inside this side's zone, into whichever
		# neighboring boards haven't been visited yet.
		var next_seeds: Dictionary = {}
		for square in board.portals:
			if board.zone_owner.get(square) != side:
				continue
			for portal in board.portals[square]:
				if not visited.has(portal.target_board) and not next_seeds.has(portal.target_board):
					next_seeds[portal.target_board] = portal.target_square

		for target_board in next_seeds:
			queue.append({ "board": target_board, "seed": next_seeds[target_board] })

func _on_side_toggled(pressed: bool) -> void:
	current_side = Piece.Side.BLACK if pressed else Piece.Side.WHITE

func _on_zone_edit_toggled(pressed: bool) -> void:
	zone_edit_mode = pressed
	active_board = null
	active_square = Vector2i(-1, -1)
	_refresh_moves()
	for b in boards:
		b.clear_selection()

func _on_place_pressed(type: Piece.Type) -> void:
	if active_board == null:
		return
	active_board.place_piece(active_square, type, current_side)
	_refresh_moves()

func _on_remove_pressed() -> void:
	if active_board == null:
		return
	active_board.remove_piece(active_square)
	_refresh_moves()
