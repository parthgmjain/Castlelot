extends Node2D

const GRID_SIZE := 8
const SQUARE_SIZE := 80
const LIGHT_COLOR := Color(0.87, 0.87, 0.87)
const DARK_COLOR := Color(0.35, 0.35, 0.35)

func _draw() -> void:
	for row in GRID_SIZE:
		for col in GRID_SIZE:
			var color := LIGHT_COLOR if (row + col) % 2 == 0 else DARK_COLOR
			var pos := Vector2(col * SQUARE_SIZE, row * SQUARE_SIZE)
			draw_rect(Rect2(pos, Vector2(SQUARE_SIZE, SQUARE_SIZE)), color)
