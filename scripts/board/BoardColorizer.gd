class_name BoardColorizer
extends RefCounted

## Aligns each board's checkerboard parity to its parent's, using only the
## first cell pair of the connection between them, so touching squares
## always alternate colors correctly across the seam.
static func assign_colors(boards: Array, connections: Array) -> void:
	if boards.is_empty():
		return

	var parity: Array = []
	parity.resize(boards.size())
	parity[0] = 0
	boards[0].color_parity = 0

	for i in range(1, boards.size()):
		var conn: Dictionary = connections[i - 1]
		var parent_square: Vector2i = conn.a_squares[0]
		var child_square: Vector2i = conn.b_squares[0]
		var parent_parity: int = parity[conn.a_board]

		var parent_color: int = (parent_square.x + parent_square.y + parent_parity) % 2
		var child_base: int = (child_square.x + child_square.y) % 2
		var child_parity: int = ((1 - parent_color - child_base) % 2 + 2) % 2

		parity[i] = child_parity
		boards[i].color_parity = child_parity
