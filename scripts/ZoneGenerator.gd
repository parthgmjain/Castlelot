class_name ZoneGenerator
extends RefCounted

## Generates `count` grid offsets (starting with Vector2i.ZERO) walking an
## outward square spiral: right, down, left, up, with each leg's length
## increasing by 1 every two turns. This is the classic square-spiral fill
## pattern, so a zone grows outward from its seed square in rings that stay
## square-shaped as they complete.
static func spiral_offsets(count: int) -> Array:
	var offsets: Array = []
	if count <= 0:
		return offsets
	offsets.append(Vector2i.ZERO)
	if count == 1:
		return offsets

	var directions := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var x := 0
	var y := 0
	var dir_index := 0
	var leg_length := 1

	while offsets.size() < count:
		for repeat in 2:
			var dir: Vector2i = directions[dir_index % 4]
			for step in leg_length:
				x += dir.x
				y += dir.y
				offsets.append(Vector2i(x, y))
				if offsets.size() >= count:
					return offsets
			dir_index += 1
		leg_length += 1

	return offsets
