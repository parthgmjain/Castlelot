class_name Scoring
extends RefCounted

## Chips a victim is worth per point of standard chess value (pawn 10, queen 90).
const CHIPS_PER_VALUE := 10

## What capturing `victim` with `attacker` scores: (chips + modifier bonuses)
## x multiplier. A victim counts as whatever it currently is, so a promoted
## queen is worth a queen.
static func capture_score(current_match: MatchState, attacker: Dictionary, victim: Dictionary, board: Board, square: Vector2i) -> int:
	var context := {
		"chips": float(Piece.value(victim.type) * CHIPS_PER_VALUE),
		"mult": 1.0,
		"attacker": attacker,
		"victim": victim,
		"board": board,
		"square": square,
		"side": attacker.side,
	}
	for modifier in current_match.modifiers:
		modifier.on_capture(context)
	return int(round(context.chips * context.mult))
