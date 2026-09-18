class_name ZoneController
extends RefCounted

## Wipes every board's pieces and zones, puts White's king in the root
## board's top-left corner and Black's in the bottom-right corner of the
## farthest board, then grows each side's zone outward from its king.
static func generate(boards: Array, white_tiles: int, black_tiles: int) -> void:
	if boards.is_empty():
		return

	for b in boards:
		b.pieces.clear()
		b.zone_owner.clear()

	var white_board: Board = boards[0]
	var white_square := Vector2i(0, 0)
	var black_board: Board = _farthest_board(boards, white_board)
	var black_square := Vector2i(black_board.grid_width - 1, black_board.grid_height - 1)

	white_board.place_piece(white_square, Piece.Type.KING, Piece.Side.WHITE)
	black_board.place_piece(black_square, Piece.Type.KING, Piece.Side.BLACK)

	_grow_zone(white_board, white_square, Piece.Side.WHITE, white_tiles)
	_grow_zone(black_board, black_square, Piece.Side.BLACK, black_tiles)

	for b in boards:
		b.queue_redraw()

static func _farthest_board(boards: Array, from: Board) -> Board:
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
static func _grow_zone(king_board: Board, king_square: Vector2i, side: Piece.Side, tile_count: int) -> void:
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
