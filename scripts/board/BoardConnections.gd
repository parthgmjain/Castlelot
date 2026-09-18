class_name BoardConnections
extends RefCounted

const SQUARE_SIZE := Board.SQUARE_SIZE

## One entry per non-root board, pairing the touching squares between it and
## its parent. Also marks those squares on the boards. `positions`/`sizes`
## come from BoardLayout.arrange.
static func build(boards: Array, attach_info: Array, positions: Array, sizes: Array) -> Array:
	var connections: Array = []
	for i in range(1, boards.size()):
		var info: Dictionary = attach_info[i]
		connections.append(_build_connection(boards, info.parent, i, info.direction, positions, sizes))
	_apply_connection_squares(boards, connections)
	return connections

## Gives every board a lookup of square -> portals through which a piece can
## step onto the neighboring board.
static func build_portals(boards: Array, attach_info: Array, connections: Array) -> void:
	var board_portals: Dictionary = {}
	for b in boards:
		board_portals[b] = {}

	for i in range(1, boards.size()):
		var info: Dictionary = attach_info[i]
		var conn: Dictionary = connections[i - 1]
		var direction: Vector2i = BoardLayout.DIR_VECTORS[info.direction]
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

static func _build_connection(boards: Array, p: int, c: int, direction: String, positions: Array, sizes: Array) -> Dictionary:
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

static func _apply_connection_squares(boards: Array, connections: Array) -> void:
	for i in boards.size():
		var squares: Array = []
		for conn in connections:
			if conn.a_board == i:
				squares.append_array(conn.a_squares)
			if conn.b_board == i:
				squares.append_array(conn.b_squares)
		boards[i].set_connection_squares(squares)
