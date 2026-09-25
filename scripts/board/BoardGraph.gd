class_name BoardGraph
extends RefCounted

const CARDINALS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

## `start` plus every board reachable from it through portals.
static func reachable_boards(start: Board) -> Array:
	var reachable: Array = [start]
	var seen: Dictionary = { start: true }
	var index := 0
	while index < reachable.size():
		var b: Board = reachable[index]
		index += 1
		for square in b.portals:
			for portal in b.portals[square]:
				if not seen.has(portal.target_board):
					seen[portal.target_board] = true
					reachable.append(portal.target_board)
	return reachable

## Steps (through portals) from every square to the nearest of `sources`
## ({ board, square } dictionaries): { Board: { Vector2i: int } }.
## Pieces are ignored - this is distance over the boards themselves.
static func distance_field(boards: Array, sources: Array) -> Dictionary:
	var field: Dictionary = {}
	for b in boards:
		field[b] = {}

	var queue: Array = []
	for source in sources:
		field[source.board][source.square] = 0
		queue.append(source)

	var head := 0
	while head < queue.size():
		var current: Dictionary = queue[head]
		head += 1
		var distance: int = field[current.board][current.square]
		for direction in CARDINALS:
			var next: Dictionary = Piece.step_across(current.board, current.square, direction)
			if next.is_empty() or field[next.board].has(next.square):
				continue
			field[next.board][next.square] = distance + 1
			queue.append(next)
	return field
