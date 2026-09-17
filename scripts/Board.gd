extends Node2D

signal square_selected(square: Vector2i)

const SQUARE_SIZE := 32.0
const LIGHT_COLOR := Color(0.87, 0.87, 0.87)
const DARK_COLOR := Color(0.35, 0.35, 0.35)
const SELECT_COLOR := Color(0.95, 0.85, 0.2)
const CONNECTOR_COLOR := Color(0.2, 0.6, 0.95)
const PIECE_FONT_SIZE := 22
const PIECE_COLOR := Color(0.05, 0.05, 0.05)

var pieces: Dictionary = {}
var selected_square: Vector2i = Vector2i(-1, -1)
var connection_squares: Array = []

@export var grid_width: int = 8:
	set(value):
		grid_width = value
		pieces.clear()
		selected_square = Vector2i(-1, -1)
		queue_redraw()

@export var grid_height: int = 8:
	set(value):
		grid_height = value
		pieces.clear()
		selected_square = Vector2i(-1, -1)
		queue_redraw()

func pixel_size() -> Vector2:
	return Vector2(grid_width, grid_height) * SQUARE_SIZE

func local_square_center(square: Vector2i) -> Vector2:
	return Vector2(square.x + 0.5, square.y + 0.5) * SQUARE_SIZE

func set_connection_squares(squares: Array) -> void:
	connection_squares = squares
	queue_redraw()

func clear_selection() -> void:
	selected_square = Vector2i(-1, -1)
	queue_redraw()

func place_piece(square: Vector2i, type: Piece.Type, side: Piece.Side) -> void:
	if square.x < 0 or square.y < 0 or square.x >= grid_width or square.y >= grid_height:
		return
	pieces[square] = { "type": type, "side": side }
	queue_redraw()

func remove_piece(square: Vector2i) -> void:
	if pieces.has(square):
		pieces.erase(square)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rel: Vector2 = to_local(event.position)
		if rel.x < 0 or rel.y < 0:
			return
		var col := int(rel.x / SQUARE_SIZE)
		var row := int(rel.y / SQUARE_SIZE)
		if col < grid_width and row < grid_height:
			selected_square = Vector2i(col, row)
			queue_redraw()
			square_selected.emit(selected_square)

func _draw() -> void:
	for row in grid_height:
		for col in grid_width:
			var color := LIGHT_COLOR if (row + col) % 2 == 0 else DARK_COLOR
			var pos := Vector2(col, row) * SQUARE_SIZE
			draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), color)

	if selected_square.x >= 0 and selected_square.y >= 0:
		var pos := Vector2(selected_square.x, selected_square.y) * SQUARE_SIZE
		draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), SELECT_COLOR, false, 3.0)

	for square in connection_squares:
		draw_circle(local_square_center(square), SQUARE_SIZE * 0.18, CONNECTOR_COLOR)

	var font := ThemeDB.fallback_font
	for square in pieces:
		var piece: Dictionary = pieces[square]
		var symbol: String = Piece.symbol(piece.type, piece.side)
		var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE)
		var square_pos := Vector2(square.x, square.y) * SQUARE_SIZE
		var text_pos := square_pos + Vector2(SQUARE_SIZE - text_size.x, SQUARE_SIZE + text_size.y * 0.3) / 2.0
		draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE, PIECE_COLOR)
