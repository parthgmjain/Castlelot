extends Node2D

const BOUND_SIZE := Vector2(640.0, 640.0)
const LIGHT_COLOR := Color(0.87, 0.87, 0.87)
const DARK_COLOR := Color(0.35, 0.35, 0.35)

@export var grid_width: int = 8:
	set(value):
		grid_width = value
		queue_redraw()

@export var grid_height: int = 8:
	set(value):
		grid_height = value
		queue_redraw()

func _draw() -> void:
	var square_size: float = min(BOUND_SIZE.x / grid_width, BOUND_SIZE.y / grid_height)
	var board_size := Vector2(grid_width, grid_height) * square_size
	var offset := (BOUND_SIZE - board_size) / 2.0
	for row in grid_height:
		for col in grid_width:
			var color := LIGHT_COLOR if (row + col) % 2 == 0 else DARK_COLOR
			var pos := offset + Vector2(col * square_size, row * square_size)
			draw_rect(Rect2(pos, Vector2(square_size, square_size)), color)
