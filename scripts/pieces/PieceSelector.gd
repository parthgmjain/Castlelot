class_name PieceSelector
extends RefCounted

## Independent, separately tunable config tables. Keys are Piece.Type (no King).
const BASE_WEIGHTS := {
	Piece.Type.QUEEN: 5.0,
	Piece.Type.ROOK: 10.0,
	Piece.Type.BISHOP: 20.0,
	Piece.Type.KNIGHT: 20.0,
	Piece.Type.PAWN: 45.0,
}

## Multiplied into a piece's weight each time it's picked (0-1).
const DECAY_FACTORS := {
	Piece.Type.QUEEN: 0.4,
	Piece.Type.ROOK: 0.5,
	Piece.Type.BISHOP: 0.6,
	Piece.Type.KNIGHT: 0.6,
	Piece.Type.PAWN: 0.85,
}

## Per-round-type multipliers on BASE_WEIGHTS.
const ROUND_MODIFIERS := {
	"normal": {
		Piece.Type.QUEEN: 1.0,
		Piece.Type.ROOK: 1.0,
		Piece.Type.BISHOP: 1.0,
		Piece.Type.KNIGHT: 1.0,
		Piece.Type.PAWN: 1.0,
	},
	"boss": {
		Piece.Type.QUEEN: 2.5,
		Piece.Type.ROOK: 2.0,
		Piece.Type.BISHOP: 1.0,
		Piece.Type.KNIGHT: 1.0,
		Piece.Type.PAWN: 0.5,
	},
}

## Per-round-type overrides on DECAY_FACTORS (only the pieces listed).
const ROUND_DECAY_OVERRIDES := {
	"normal": {},
	"boss": { Piece.Type.QUEEN: 0.75 },
}

## Per-round-type scaling of the point budget itself.
const ROUND_BUDGET_MULTIPLIERS := {
	"normal": 1.0,
	"boss": 1.5,
}

## How hard pieces cheaper than the points-per-remaining-slot target are
## penalised (the ratio is raised to this power). 0 disables the bias.
const SLOT_PRESSURE_STRENGTH := 2.0

const SUPPLY_LIMITS := {
	Piece.Type.QUEEN: 1,
	Piece.Type.ROOK: 2,
	Piece.Type.BISHOP: 2,
	Piece.Type.KNIGHT: 2,
	Piece.Type.PAWN: 8,
}

## This game's starting weights: BASE_WEIGHTS * the round type's modifiers.
## Always a fresh copy, so decay never leaks into shared config or other games.
static func working_weights(round_type: String) -> Dictionary:
	var weights: Dictionary = {}
	var modifiers: Dictionary = ROUND_MODIFIERS[round_type]
	for type in BASE_WEIGHTS:
		weights[type] = BASE_WEIGHTS[type] * modifiers[type]
	return weights

static func working_decays(round_type: String) -> Dictionary:
	var decays: Dictionary = DECAY_FACTORS.duplicate()
	decays.merge(ROUND_DECAY_OVERRIDES[round_type], true)
	return decays

## Probabilities over just `keys`, renormalized so they sum to 1.
static func normalized(weights: Dictionary, keys: Array) -> Dictionary:
	var total := 0.0
	for type in keys:
		total += weights[type]
	var probabilities: Dictionary = {}
	for type in keys:
		probabilities[type] = weights[type] / total
	return probabilities

## Buys pieces for `budget` points (scaled by the round type's budget
## multiplier). Returns the picked Piece.Types in purchase order.
## `max_pieces` is the number of free squares in the side's zone (zone tiles
## minus the king's square); -1 means no limit.
static func select_army(budget: int, round_type: String = "normal", rng: RandomNumberGenerator = null, respect_supply: bool = true, max_pieces: int = -1) -> Array:
	var effective_budget: int = int(round(budget * ROUND_BUDGET_MULTIPLIERS[round_type]))
	return pick_pieces(
		effective_budget,
		working_weights(round_type),
		working_decays(round_type),
		SUPPLY_LIMITS if respect_supply else {},
		rng if rng != null else RandomNumberGenerator.new(),
		max_pieces,
	)

## Core loop. `weights` is mutated (decayed) in place - pass a per-game copy.
## An empty `supply_limits` means unlimited duplicates. With `max_pieces` >= 0
## the loop also stops once that many pieces are picked, and as slots run out
## pieces too cheap to spend the remaining budget in the remaining slots are
## penalised (on a throwaway copy - the decaying weights stay untouched).
static func pick_pieces(budget: int, weights: Dictionary, decays: Dictionary, supply_limits: Dictionary, rng: RandomNumberGenerator, max_pieces: int = -1, pressure_strength: float = SLOT_PRESSURE_STRENGTH) -> Array:
	var picks: Array = []
	var counts: Dictionary = {}
	var remaining := budget

	while true:
		var slots_left := max_pieces - picks.size()
		if max_pieces >= 0 and slots_left <= 0:
			break

		var affordable: Array = []
		for type in weights:
			if Piece.value(type) > remaining or weights[type] <= 0.0:
				continue
			if counts.get(type, 0) >= supply_limits.get(type, 1 << 30):
				continue
			affordable.append(type)
		if affordable.is_empty():
			break

		var effective: Dictionary = weights
		if max_pieces >= 0:
			effective = _apply_slot_pressure(weights, affordable, float(remaining) / slots_left, pressure_strength)

		var choice: Piece.Type = _weighted_pick(normalized(effective, affordable), rng)
		picks.append(choice)
		remaining -= Piece.value(choice)
		counts[choice] = counts.get(choice, 0) + 1
		weights[choice] *= decays[choice]

	return picks

static func _apply_slot_pressure(weights: Dictionary, keys: Array, target: float, strength: float) -> Dictionary:
	var adjusted: Dictionary = weights.duplicate()
	for type in keys:
		var cost := float(Piece.value(type))
		if cost < target:
			adjusted[type] = weights[type] * pow(cost / target, strength)
	return adjusted

static func _weighted_pick(probabilities: Dictionary, rng: RandomNumberGenerator) -> Piece.Type:
	var roll := rng.randf()
	var cumulative := 0.0
	var last: Piece.Type = probabilities.keys()[0]
	for type in probabilities:
		cumulative += probabilities[type]
		last = type
		if roll < cumulative:
			return type
	return last
