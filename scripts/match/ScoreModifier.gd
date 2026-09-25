class_name ScoreModifier
extends RefCounted

## Base class for anything that changes what a capture is worth (planet
## cards, jokers, abilities). Override on_capture and edit the context:
## { chips, mult, attacker, victim, board, square, side }.
func on_capture(_context: Dictionary) -> void:
	pass
