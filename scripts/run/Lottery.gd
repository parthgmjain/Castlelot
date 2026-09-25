class_name Lottery
extends RefCounted

## The piece lottery. A pull happens in two steps so the tier can be shown
## first: start_pull pays and finds out the tier, finish_pull draws a piece from it.
## Pools come from Piece.TIERS, so a piece added there joins its tier's pool.

static func price(run: RunState) -> int:
	return RunConfig.PULL_PRICE_BASE + run.pulls_made * RunConfig.PULL_PRICE_STEP

## Weight of each tier for this run's next pull. This is the one place to plug
## in rubber-banding or meta bonuses later.
static func tier_weights(_run: RunState) -> Dictionary:
	return usable_weights(RunConfig.TIER_WEIGHTS)

## Drops tiers that can't be drawn: zero weight, or no pieces in them.
static func usable_weights(weights: Dictionary) -> Dictionary:
	var out := {}
	for tier in weights:
		if weights[tier] > 0.0 and not Piece.types_in_tier(tier).is_empty():
			out[tier] = weights[tier]
	return out

## Each tier's chance (0-1) on the next pull.
static func odds(run: RunState) -> Dictionary:
	var weights := tier_weights(run)
	var total := 0.0
	for tier in weights:
		total += weights[tier]
	var out := {}
	for tier in weights:
		out[tier] = weights[tier] / total
	return out

static func roll_tier(weights: Dictionary, rng: RandomNumberGenerator = null) -> Piece.Tier:
	rng = rng if rng != null else RandomNumberGenerator.new()
	var usable := usable_weights(weights)
	var total := 0.0
	for tier in usable:
		total += usable[tier]
	var roll := rng.randf() * total
	var last: Piece.Tier = usable.keys()[0]
	for tier in usable:
		last = tier
		roll -= usable[tier]
		if roll < 0.0:
			return tier
	return last

## Every piece that can be drawn from `tier`.
static func pool(tier: Piece.Tier) -> Array:
	return Piece.types_in_tier(tier)

static func roll_piece(tier: Piece.Tier, rng: RandomNumberGenerator = null) -> Piece.Type:
	rng = rng if rng != null else RandomNumberGenerator.new()
	var options := pool(tier)
	return options[rng.randi_range(0, options.size() - 1)]

## Step 1: pays for a pull and finds out which tier it landed in.
## Returns { ok, reason, tier }.
static func start_pull(run: RunState, rng: RandomNumberGenerator = null) -> Dictionary:
	var cost := price(run)
	if run.currency < cost:
		return { "ok": false, "reason": "Not enough gold (a pull costs %d)." % cost }
	run.currency -= cost
	run.pulls_made += 1
	return { "ok": true, "reason": "", "tier": roll_tier(tier_weights(run), rng) }

## Step 2: draws the piece from the tier and puts it in your roster.
static func finish_pull(run: RunState, tier: Piece.Tier, rng: RandomNumberGenerator = null) -> Piece.Type:
	var type := roll_piece(tier, rng)
	run.add_to_roster(type)
	return type
