class_name Board
extends Node2D

signal square_selected(square: Vector2i)
signal square_right_clicked(square: Vector2i)

const SQUARE_SIZE := 32.0
const LIGHT_COLOR := Color(0.87, 0.87, 0.87)
const DARK_COLOR := Color(0.35, 0.35, 0.35)
const SELECT_COLOR := Color(0.95, 0.85, 0.2)
const CONNECTOR_COLOR := Color(0.2, 0.6, 0.95)
const MOVE_COLOR := Color(0.2, 0.85, 0.3)
const CAPTURE_COLOR := Color(0.9, 0.25, 0.25)
const LAST_MOVE_COLOR := Color(1.0, 0.9, 0.3, 0.32)
const PIECE_FONT_SIZE := 22
const PIECE_COLOR := Color(0.05, 0.05, 0.05)
const ZONE_COLORS := {
	Piece.Side.WHITE: Color(0.2, 0.5, 0.95, 0.28),
	Piece.Side.BLACK: Color(0.85, 0.2, 0.2, 0.28),
}

var pieces: Dictionary = {}
var selected_square: Vector2i = Vector2i(-1, -1)
var connection_squares: Array = []
var last_move_squares: Array = []
var move_squares: Array = []
var capture_squares: Array = []
var zone_owner: Dictionary = {}

# Populated by Main: Vector2i -> Array[{ direction: Vector2i, target_board: Board, target_square: Vector2i }]
var portals: Dictionary = {}

var color_parity: int = 0:
	set(value):
		color_parity = value
		queue_redraw()

@export var grid_width: int = 8:
	set(value):
		grid_width = value
		pieces.clear()
		selected_square = Vector2i(-1, -1)
		move_squares = []
		capture_squares = []
		zone_owner.clear()
		queue_redraw()

@export var grid_height: int = 8:
	set(value):
		grid_height = value
		pieces.clear()
		selected_square = Vector2i(-1, -1)
		move_squares = []
		capture_squares = []
		zone_owner.clear()
		queue_redraw()

func pixel_size() -> Vector2:
	return Vector2(grid_width, grid_height) * SQUARE_SIZE

func local_square_center(square: Vector2i) -> Vector2:
	return Vector2(square.x + 0.5, square.y + 0.5) * SQUARE_SIZE

func is_in_bounds(square: Vector2i) -> bool:
	return square.x >= 0 and square.y >= 0 and square.x < grid_width and square.y < grid_height

func set_last_move_squares(squares: Array) -> void:
	last_move_squares = squares
	queue_redraw()

func set_connection_squares(squares: Array) -> void:
	connection_squares = squares
	queue_redraw()

func set_portals(new_portals: Dictionary) -> void:
	portals = new_portals

func set_move_markers(moves: Array, captures: Array) -> void:
	move_squares = moves
	capture_squares = captures
	queue_redraw()

func clear_move_markers() -> void:
	move_squares = []
	capture_squares = []
	queue_redraw()

func clear_selection() -> void:
	selected_square = Vector2i(-1, -1)
	queue_redraw()

func set_zone(square: Vector2i, side: Piece.Side) -> void:
	if not is_in_bounds(square):
		return
	zone_owner[square] = side
	queue_redraw()

func clear_zone(square: Vector2i) -> void:
	if zone_owner.has(square):
		zone_owner.erase(square)
		queue_redraw()

func is_zone_allowed(square: Vector2i, side: Piece.Side) -> bool:
	return not zone_owner.has(square) or zone_owner[square] == side

func place_piece(square: Vector2i, type: Piece.Type, side: Piece.Side) -> void:
	if not is_in_bounds(square) or not is_zone_allowed(square, side):
		return
	pieces[square] = { "type": type, "side": side }
	queue_redraw()

func remove_piece(square: Vector2i) -> void:
	if pieces.has(square):
		pieces.erase(square)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
		and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		var rel: Vector2 = to_local(event.position)
		if rel.x < 0 or rel.y < 0:
			return
		var col := int(rel.x / SQUARE_SIZE)
		var row := int(rel.y / SQUARE_SIZE)
		if col >= grid_width or row >= grid_height:
			return
		var square := Vector2i(col, row)
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected_square = square
			queue_redraw()
			square_selected.emit(square)
		else:
			square_right_clicked.emit(square)

func _draw() -> void:
	for row in grid_height:
		for col in grid_width:
			var color := LIGHT_COLOR if (row + col + color_parity) % 2 == 0 else DARK_COLOR
			var pos := Vector2(col, row) * SQUARE_SIZE
			draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), color)

	for square in zone_owner:
		var pos := Vector2(square.x, square.y) * SQUARE_SIZE
		draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), ZONE_COLORS[zone_owner[square]])

	for square in last_move_squares:
		draw_rect(Rect2(Vector2(square.x, square.y) * SQUARE_SIZE, Vector2(SQUARE_SIZE, SQUARE_SIZE)), LAST_MOVE_COLOR)

	if selected_square.x >= 0 and selected_square.y >= 0:
		var pos := Vector2(selected_square.x, selected_square.y) * SQUARE_SIZE
		draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), SELECT_COLOR, false, 3.0)

	for square in connection_squares:
		draw_circle(local_square_center(square), SQUARE_SIZE * 0.18, CONNECTOR_COLOR)

	for square in move_squares:
		draw_circle(local_square_center(square), SQUARE_SIZE * 0.12, MOVE_COLOR)

	for square in capture_squares:
		draw_arc(local_square_center(square), SQUARE_SIZE * 0.35, 0, TAU, 24, CAPTURE_COLOR, 3.0)

	var font := ThemeDB.fallback_font
	for square in pieces:
		var piece: Dictionary = pieces[square]
		var symbol: String = Piece.symbol(piece.type, piece.side)
		var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE)
		var square_pos := Vector2(square.x, square.y) * SQUARE_SIZE
		var text_pos := square_pos + Vector2(SQUARE_SIZE - text_size.x, SQUARE_SIZE + text_size.y * 0.3) / 2.0
		draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE, PIECE_COLOR)
