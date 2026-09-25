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

## The AI's armies start as classic chess pieces only (round 1) and gradually pick up the extra
## pieces as a run goes on: a tier's weight is 0 before `start`, ramps linearly to full strength
## by `full`, and stays there after. Legendaries never appear here - they're earned, not bought
## (a boss still fields its own, separately, via ArmyPlacer.auto_place's `reserved`).
const EXTRA_TIER_UNLOCK := {
	Piece.Tier.COMMON: { "start": 2, "full": 5 },
	Piece.Tier.UNCOMMON: { "start": 4, "full": 8 },
	Piece.Tier.RARE: { "start": 7, "full": 12 },
}
## An extra piece's weight/decay/supply once fully unlocked, by tier (placeholders, kept modest
## next to a pawn's 45 so early exotic pieces are a sprinkle, not a takeover).
const EXTRA_TIER_WEIGHTS := { Piece.Tier.COMMON: 4.0, Piece.Tier.UNCOMMON: 5.0, Piece.Tier.RARE: 4.0 }
const EXTRA_TIER_DECAYS := { Piece.Tier.COMMON: 0.8, Piece.Tier.UNCOMMON: 0.6, Piece.Tier.RARE: 0.5 }
const EXTRA_TIER_SUPPLY := { Piece.Tier.COMMON: 3, Piece.Tier.UNCOMMON: 2, Piece.Tier.RARE: 1 }

## Every data-driven type that can turn up in a random AI army: not a boss-only legendary.
static func _extra_types() -> Array:
	return PieceDefs.types().filter(func(t): return not Piece.is_reward_only(t) and PieceDefs.tier(t) != Piece.Tier.LEGENDARY)

## How unlocked `tier` is on `round_number`: 0 before "start", already a little unlocked
## right on "start", ramping up to fully unlocked (1) by "full" and staying there.
## `round_number` < 0 means no run context (the sandbox), so nothing is unlocked.
static func extras_factor(tier: Piece.Tier, round_number: int) -> float:
	if round_number < 0 or not EXTRA_TIER_UNLOCK.has(tier):
		return 0.0
	var range: Dictionary = EXTRA_TIER_UNLOCK[tier]
	if round_number < range.start:
		return 0.0
	return clampf(float(round_number - range.start + 1) / float(range.full - range.start + 1), 0.0, 1.0)

## This game's starting weights: BASE_WEIGHTS * the round type's modifiers, plus whichever
## extra pieces `round_number` has unlocked so far (see EXTRA_TIER_UNLOCK). Always a fresh
## copy, so decay never leaks into shared config or other games.
static func working_weights(round_type: String, round_number: int = -1) -> Dictionary:
	var weights: Dictionary = {}
	var modifiers: Dictionary = ROUND_MODIFIERS[round_type]
	for type in BASE_WEIGHTS:
		weights[type] = BASE_WEIGHTS[type] * modifiers[type]
	for type in _extra_types():
		var factor := extras_factor(PieceDefs.tier(type), round_number)
		if factor > 0.0:
			weights[type] = EXTRA_TIER_WEIGHTS[PieceDefs.tier(type)] * factor
	return weights

static func working_decays(round_type: String, round_number: int = -1) -> Dictionary:
	var decays: Dictionary = DECAY_FACTORS.duplicate()
	decays.merge(ROUND_DECAY_OVERRIDES[round_type], true)
	for type in _extra_types():
		decays[type] = EXTRA_TIER_DECAYS[PieceDefs.tier(type)]
	return decays

## SUPPLY_LIMITS plus caps for whatever extra pieces are unlocked (unlimited copies otherwise
## isn't right once they're in the weight table too).
static func working_supply(round_number: int = -1) -> Dictionary:
	var supply: Dictionary = SUPPLY_LIMITS.duplicate()
	for type in _extra_types():
		supply[type] = EXTRA_TIER_SUPPLY[PieceDefs.tier(type)]
	return supply

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
static func select_army(budget: int, round_type: String = "normal", rng: RandomNumberGenerator = null, respect_supply: bool = true, max_pieces: int = -1, round_number: int = -1) -> Array:
	var effective_budget: int = int(round(budget * ROUND_BUDGET_MULTIPLIERS[round_type]))
	return pick_pieces(
		effective_budget,
		working_weights(round_type, round_number),
		working_decays(round_type, round_number),
		working_supply(round_number) if respect_supply else {},
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
