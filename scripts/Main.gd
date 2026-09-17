extends Node2D

const BOARD_SCENE := preload("res://scenes/Board.tscn")
const SQUARE_SIZE := 32.0
const MIN_DIM := 2
const MAX_DIM := 10
const DIRECTIONS := ["RIGHT", "LEFT", "UP", "DOWN"]
const PLAY_AREA := Vector2(1200.0, 500.0)
const BASE_POSITION := Vector2(40.0, 210.0)

@onready var boards_container: Node2D = $BoardsContainer
@onready var count_spin_box: SpinBox = $UI/VBox/CountRow/CountSpinBox
@onready var refresh_button: Button = $UI/VBox/CountRow/RefreshButton
@onready var sizes_row: HBoxContainer = $UI/VBox/SizesRow
@onready var side_check_button: CheckButton = $UI/VBox/PieceRow/SideCheckButton
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
var active_board: Node2D = null
var active_square: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	count_spin_box.value_changed.connect(_on_count_changed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	side_check_button.toggled.connect(_on_side_toggled)
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

func _on_square_selected(square: Vector2i, board: Node2D) -> void:
	for b in boards:
		if b != board:
			b.clear_selection()
	active_board = board
	active_square = square

func _on_side_toggled(pressed: bool) -> void:
	current_side = Piece.Side.BLACK if pressed else Piece.Side.WHITE

func _on_place_pressed(type: Piece.Type) -> void:
	if active_board == null:
		return
	active_board.place_piece(active_square, type, current_side)

func _on_remove_pressed() -> void:
	if active_board == null:
		return
	active_board.remove_piece(active_square)
