class_name Board
extends Node2D

signal square_selected(square: Vector2i)

const SQUARE_SIZE := 32.0
const LIGHT_COLOR := Color(0.87, 0.87, 0.87)
const DARK_COLOR := Color(0.35, 0.35, 0.35)
const SELECT_COLOR := Color(0.95, 0.85, 0.2)
const CONNECTOR_COLOR := Color(0.2, 0.6, 0.95)
const MOVE_COLOR := Color(0.2, 0.85, 0.3)
const CAPTURE_COLOR := Color(0.9, 0.25, 0.25)
const PIECE_FONT_SIZE := 22
const PIECE_COLOR := Color(0.05, 0.05, 0.05)

var pieces: Dictionary = {}
var selected_square: Vector2i = Vector2i(-1, -1)
var connection_squares: Array = []
var move_origin: Vector2i = Vector2i(-1, -1)
var legal_moves: Array = []

var color_parity: int = 0:
	set(value):
		color_parity = value
		queue_redraw()

@export var grid_width: int = 8:
	set(value):
		grid_width = value
		pieces.clear()
		selected_square = Vector2i(-1, -1)
		move_origin = Vector2i(-1, -1)
		legal_moves = []
		queue_redraw()

@export var grid_height: int = 8:
	set(value):
		grid_height = value
		pieces.clear()
		selected_square = Vector2i(-1, -1)
		move_origin = Vector2i(-1, -1)
		legal_moves = []
		queue_redraw()

func pixel_size() -> Vector2:
	return Vector2(grid_width, grid_height) * SQUARE_SIZE

func local_square_center(square: Vector2i) -> Vector2:
	return Vector2(square.x + 0.5, square.y + 0.5) * SQUARE_SIZE

func is_in_bounds(square: Vector2i) -> bool:
	return square.x >= 0 and square.y >= 0 and square.x < grid_width and square.y < grid_height

func set_connection_squares(squares: Array) -> void:
	connection_squares = squares
	queue_redraw()

func clear_selection() -> void:
	selected_square = Vector2i(-1, -1)
	move_origin = Vector2i(-1, -1)
	legal_moves = []
	queue_redraw()

func place_piece(square: Vector2i, type: Piece.Type, side: Piece.Side) -> void:
	if not is_in_bounds(square):
		return
	pieces[square] = { "type": type, "side": side }
	if square == selected_square:
		_update_legal_moves()
	queue_redraw()

func remove_piece(square: Vector2i) -> void:
	if pieces.has(square):
		pieces.erase(square)
		if square == selected_square:
			_update_legal_moves()
		queue_redraw()

func _update_legal_moves() -> void:
	move_origin = Vector2i(-1, -1)
	legal_moves = []
	if pieces.has(selected_square):
		var piece: Dictionary = pieces[selected_square]
		legal_moves = Piece.get_legal_moves(piece.type, piece.side, selected_square, self)
		move_origin = selected_square

func _move_piece(from: Vector2i, to: Vector2i) -> void:
	if not pieces.has(from):
		return
	pieces[to] = pieces[from]
	pieces.erase(from)
	selected_square = Vector2i(-1, -1)
	move_origin = Vector2i(-1, -1)
	legal_moves = []
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rel: Vector2 = to_local(event.position)
		if rel.x < 0 or rel.y < 0:
			return
		var col := int(rel.x / SQUARE_SIZE)
		var row := int(rel.y / SQUARE_SIZE)
		if col < grid_width and row < grid_height:
			var clicked := Vector2i(col, row)
			if move_origin.x >= 0 and legal_moves.has(clicked):
				_move_piece(move_origin, clicked)
			else:
				selected_square = clicked
				_update_legal_moves()
			queue_redraw()
			square_selected.emit(selected_square)

func _draw() -> void:
	for row in grid_height:
		for col in grid_width:
			var color := LIGHT_COLOR if (row + col + color_parity) % 2 == 0 else DARK_COLOR
			var pos := Vector2(col, row) * SQUARE_SIZE
			draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), color)

	if selected_square.x >= 0 and selected_square.y >= 0:
		var pos := Vector2(selected_square.x, selected_square.y) * SQUARE_SIZE
		draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), SELECT_COLOR, false, 3.0)

	for square in connection_squares:
		draw_circle(local_square_center(square), SQUARE_SIZE * 0.18, CONNECTOR_COLOR)

	for square in legal_moves:
		var center := local_square_center(square)
		if pieces.has(square):
			draw_arc(center, SQUARE_SIZE * 0.35, 0, TAU, 24, CAPTURE_COLOR, 3.0)
		else:
			draw_circle(center, SQUARE_SIZE * 0.12, MOVE_COLOR)

	var font := ThemeDB.fallback_font
	for square in pieces:
		var piece: Dictionary = pieces[square]
		var symbol: String = Piece.symbol(piece.type, piece.side)
		var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE)
		var square_pos := Vector2(square.x, square.y) * SQUARE_SIZE
		var text_pos := square_pos + Vector2(SQUARE_SIZE - text_size.x, SQUARE_SIZE + text_size.y * 0.3) / 2.0
		draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, PIECE_FONT_SIZE, PIECE_COLOR)
