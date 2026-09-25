class_name BoardLayout
extends RefCounted

const SQUARE_SIZE := Board.SQUARE_SIZE
const DIRECTIONS := ["RIGHT", "LEFT", "UP", "DOWN"]
const DIR_VECTORS := { "RIGHT": Vector2i(1, 0), "LEFT": Vector2i(-1, 0), "UP": Vector2i(0, -1), "DOWN": Vector2i(0, 1) }
const PLAY_AREA := Vector2(1200.0, 500.0)
const BASE_POSITION := Vector2(40.0, 410.0)

## Which earlier board (and side of it) board `index` should attach to.
## The root board has no parent.
static func random_attach(index: int) -> Variant:
	if index == 0:
		return null
	return {
		"parent": randi_range(0, index - 1),
		"direction": DIRECTIONS[randi_range(0, DIRECTIONS.size() - 1)],
	}

## Places each board touching its parent (retrying other directions, then
## falling back to the right of the whole cluster), then scales and centers
## the cluster inside `container`. May rewrite attach_info entries to match
## where a board actually ended up. Returns { positions, sizes } in the
## un-normalized layout space that BoardConnections expects.
static func arrange(boards: Array, attach_info: Array, container: Node2D) -> Dictionary:
	var positions: Array = [Vector2.ZERO]
	var sizes: Array = [boards[0].pixel_size()]

	for i in range(1, boards.size()):
		var info: Dictionary = attach_info[i]
		var my_size: Vector2 = boards[i].pixel_size()
		sizes.append(my_size)
		var placed := false

		for attempt in 30:
			var parent_index: int = info.parent
			var direction: String = info.direction
			var parent_pos: Vector2 = positions[parent_index]
			var parent_size: Vector2 = sizes[parent_index]
			var candidate := Vector2.ZERO

			match direction:
				"RIGHT":
					candidate = Vector2(parent_pos.x + parent_size.x, _random_overlap_offset(parent_pos.y, parent_size.y, my_size.y))
				"LEFT":
					candidate = Vector2(parent_pos.x - my_size.x, _random_overlap_offset(parent_pos.y, parent_size.y, my_size.y))
				"DOWN":
					candidate = Vector2(_random_overlap_offset(parent_pos.x, parent_size.x, my_size.x), parent_pos.y + parent_size.y)
				"UP":
					candidate = Vector2(_random_overlap_offset(parent_pos.x, parent_size.x, my_size.x), parent_pos.y - my_size.y)

			if not _overlaps_any(candidate, my_size, positions, sizes, i):
				positions.append(candidate)
				placed = true
				break

			info.direction = DIRECTIONS[randi_range(0, DIRECTIONS.size() - 1)]

		if not placed:
			# Nothing else can occupy x >= max_x, so placing touching it here
			# is always collision-free - and touching is required for a portal
			# to make sense between the two boards.
			var fallback_parent := 0
			var max_x := 0.0
			for j in i:
				var edge: float = positions[j].x + sizes[j].x
				if edge > max_x:
					max_x = edge
					fallback_parent = j
			positions.append(Vector2(max_x, positions[fallback_parent].y))
			info.parent = fallback_parent
			info.direction = "RIGHT"

	var min_pos: Vector2 = positions[0]
	var max_pos: Vector2 = positions[0] + sizes[0]
	for i in boards.size():
		min_pos.x = min(min_pos.x, positions[i].x)
		min_pos.y = min(min_pos.y, positions[i].y)
		max_pos.x = max(max_pos.x, positions[i].x + sizes[i].x)
		max_pos.y = max(max_pos.y, positions[i].y + sizes[i].y)

	var cluster_size: Vector2 = max_pos - min_pos
	var fit_scale: float = min(1.0, min(PLAY_AREA.x / cluster_size.x, PLAY_AREA.y / cluster_size.y))

	for i in boards.size():
		boards[i].position = positions[i] - min_pos

	container.scale = Vector2(fit_scale, fit_scale)
	container.position = BASE_POSITION + Vector2(
		max(0.0, (PLAY_AREA.x - cluster_size.x * fit_scale) / 2.0),
		max(0.0, (PLAY_AREA.y - cluster_size.y * fit_scale) / 2.0)
	)

	return { "positions": positions, "sizes": sizes }

static func _random_overlap_offset(parent_origin: float, parent_len: float, my_len: float) -> float:
	var min_offset: float = parent_origin - my_len + SQUARE_SIZE
	var max_offset: float = parent_origin + parent_len - SQUARE_SIZE
	var steps: int = int(round((max_offset - min_offset) / SQUARE_SIZE))
	if steps <= 0:
		return min(min_offset, max_offset)
	return min_offset + randi_range(0, steps) * SQUARE_SIZE

static func _overlaps_any(candidate: Vector2, size: Vector2, positions: Array, sizes: Array, count: int) -> bool:
	for j in count:
		var other_pos: Vector2 = positions[j]
		var other_size: Vector2 = sizes[j]
		if candidate.x < other_pos.x + other_size.x and candidate.x + size.x > other_pos.x \
			and candidate.y < other_pos.y + other_size.y and candidate.y + size.y > other_pos.y:
			return true
	return false
