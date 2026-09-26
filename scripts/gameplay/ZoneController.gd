class_name ZoneController
extends RefCounted

## Wipes every board's pieces and zones, puts White's king in the root board's top-left corner
## and Black's king at a random board corner that's at least this round's minimum separation away
## (through the portal graph, not just how the boards happen to be laid out) - see
## RunConfig.ZONE_MIN_DISTANCE_START/CAP - then grows each side's zone outward from its king.
## `round_number` (-1 for the sandbox) sets how far along that guarantee has grown; see
## RunConfig.board_growth.
static func generate(boards: Array, white_tiles: int, black_tiles: int, round_number: int = -1, rng: RandomNumberGenerator = null) -> void:
	if boards.is_empty():
		return

	for b in boards:
		b.pieces.clear()
		b.zone_owner.clear()

	var white_board: Board = boards[0]
	var white_square := Vector2i(0, 0)
	white_board.place_piece(white_square, Piece.Type.KING, Piece.Side.WHITE)

	var min_distance := int(round(lerp(
		float(RunConfig.ZONE_MIN_DISTANCE_START), float(RunConfig.ZONE_MIN_DISTANCE_CAP), RunConfig.board_growth(round_number))))
	var black_spot := _pick_black_king(boards, white_board, white_square, min_distance, rng)
	black_spot.board.place_piece(black_spot.square, Piece.Type.KING, Piece.Side.BLACK)

	_grow_zone(white_board, white_square, Piece.Side.WHITE, white_tiles)
	_grow_zone(black_spot.board, black_spot.square, Piece.Side.BLACK, black_tiles)

	for b in boards:
		b.queue_redraw()

## Picks a random board corner that's at least `min_distance` steps from White's king through the
## portal graph, so the guarantee holds without every match placing Black in the exact same spot.
## If nothing reaches the minimum (a very small or oddly-connected world), a random corner among
## those tied for the farthest available is used instead.
static func _pick_black_king(boards: Array, white_board: Board, white_square: Vector2i, min_distance: int, rng: RandomNumberGenerator = null) -> Dictionary:
	rng = rng if rng != null else RandomNumberGenerator.new()
	var field := BoardGraph.distance_field(boards, [{ "board": white_board, "square": white_square }])
	var candidates: Array = []
	var farthest := -1
	for b in boards:
		for corner in [Vector2i(0, 0), Vector2i(b.grid_width - 1, 0), Vector2i(0, b.grid_height - 1), Vector2i(b.grid_width - 1, b.grid_height - 1)]:
			if b == white_board and corner == white_square:
				continue
			var distance: int = field.get(b, {}).get(corner, -1)
			if distance >= 0:
				candidates.append({ "board": b, "square": corner, "distance": distance })
				farthest = maxi(farthest, distance)
	if candidates.is_empty():
		return { "board": white_board, "square": white_square }
	var qualifying: Array = candidates.filter(func(c): return c.distance >= min_distance)
	var pool: Array = qualifying if not qualifying.is_empty() else candidates.filter(func(c): return c.distance == farthest)
	return pool[rng.randi_range(0, pool.size() - 1)]

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
