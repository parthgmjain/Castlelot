extends Node2D

const BOUND_SIZE := Vector2(640.0, 640.0)
const LIGHT_COLOR := Color(0.87, 0.87, 0.87)
const DARK_COLOR := Color(0.35, 0.35, 0.35)
const SELECT_COLOR := Color(0.95, 0.85, 0.2)
const PIECE_FONT_SIZE := 40
const PIECE_COLOR := Color(0.05, 0.05, 0.05)

var pieces: Dictionary = {}
var selected_square: Vector2i = Vector2i(-1, -1)

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

func _get_square_size() -> float:
	return min(BOUND_SIZE.x / grid_width, BOUND_SIZE.y / grid_height)

func _get_board_offset() -> Vector2:
	var square_size := _get_square_size()
	var board_size := Vector2(grid_width, grid_height) * square_size
	return (BOUND_SIZE - board_size) / 2.0

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
		var square_size := _get_square_size()
		var offset := _get_board_offset()
		var rel: Vector2 = to_local(event.position) - offset
		if rel.x < 0 or rel.y < 0:
			return
		var col := int(rel.x / square_size)
		var row := int(rel.y / square_size)
		if col < grid_width and row < grid_height:
			selected_square = Vector2i(col, row)
			queue_redraw()

func _draw() -> void:
	var square_size := _get_square_size()
	var offset := _get_board_offset()

	for row in grid_height:
		for col in grid_width:
			var color := LIGHT_COLOR if (row + col) % 2 == 0 else DARK_COLOR
			var pos := offset + Vector2(col * square_size, row * square_size)
			draw_rect(Rect2(pos, Vector2(square_size, square_size)), color)

	if selected_square.x >= 0 and selected_square.y >= 0:
		var pos := offset + Vector2(selected_square.x * square_size, selected_square.y * square_size)
		draw_rect(Rect2(pos, Vector2(square_size, square_size)), SELECT_COLOR, false, 4.0)

	var font := ThemeDB.fallback_font
	for square in pieces:
		var piece: Dictionary = pieces[square]
		var symbol: String = Piece.symbol(piece.type, piece.side)
		var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE)
		var square_pos := offset + Vector2(square.x * square_size, square.y * square_size)
		var text_pos := square_pos + Vector2(square_size - text_size.x, square_size + text_size.y * 0.3) / 2.0
		draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE, PIECE_COLOR)
