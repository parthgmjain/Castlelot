class_name Lottery
extends RefCounted

## The piece lottery. A pull first pays and reveals the TIER (start_pull); then you are
## offered cards from that tier (begin_choice) and pick one (pick_card).
##
## A card is { type, kind }. "add" cards are types you already hold: taking one gives you
## another copy. "new" cards are types you don't hold: taking one fills a free slot in the
## tier, or - when the tier is full - replaces one of your types, keeping its number of pieces.
## Legendaries are never drawn (see Legendaries). Pools come from Piece.TIERS and PieceDefs,
## so a piece added there joins its tier's pool.
##
## The offer waits in run.pending so it survives leaving and reopening the shop screen:
##   { kind: "cards", tier, cards, source, stage: "pick" | "replace", card (in "replace") }

static func price(run: RunState) -> int:
	return RunConfig.PULL_PRICE_BASE + run.pulls_made * RunConfig.PULL_PRICE_STEP

## Weight of each tier for this run's next pull. This is the one place to plug
## in rubber-banding or meta bonuses later.
static func tier_weights(_run: RunState) -> Dictionary:
	return usable_weights(RunConfig.TIER_WEIGHTS)

## Drops tiers that can't be drawn: zero weight, or nothing to draw from them.
static func usable_weights(weights: Dictionary) -> Dictionary:
	var out := {}
	for tier in weights:
		if weights[tier] > 0.0 and not pool(tier).is_empty():
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

## Every piece that can be offered from `tier`: boss rewards are never for sale and
## legendaries are only ever upgraded into.
static func pool(tier: Piece.Tier) -> Array:
	if tier == Piece.Tier.LEGENDARY:
		return []
	return Piece.types_in_tier(tier).filter(func(t): return not Piece.is_reward_only(t))

## Step 1: pays for a pull and finds out which tier it landed in.
## Returns { ok, reason, tier }.
static func start_pull(run: RunState, rng: RandomNumberGenerator = null) -> Dictionary:
	var cost := price(run)
	if run.currency < cost:
		return { "ok": false, "reason": "Not enough gold (a pull costs %d)." % cost }
	run.currency -= cost
	run.pulls_made += 1
	return { "ok": true, "reason": "", "tier": roll_tier(tier_weights(run), rng) }

## The cards for a `tier` offer: up to OWNED_CARDS types you hold (each adds a copy) and new
## types for the rest, RunConfig.CARDS_OFFERED in all where the pool allows.
static func offer(run: RunState, tier: Piece.Tier, rng: RandomNumberGenerator = null) -> Array:
	rng = rng if rng != null else RandomNumberGenerator.new()
	var owned: Array = run.held_types(tier).filter(func(t): return pool(tier).has(t))
	var fresh: Array = pool(tier).filter(func(t): return not owned.has(t))
	_shuffle(owned, rng)
	_shuffle(fresh, rng)
	var adds: Array = owned.slice(0, RunConfig.OWNED_CARDS)
	var news: Array = fresh.slice(0, RunConfig.CARDS_OFFERED - adds.size())
	if adds.size() + news.size() < RunConfig.CARDS_OFFERED:
		adds.append_array(owned.slice(adds.size(), adds.size() + RunConfig.CARDS_OFFERED - adds.size() - news.size()))
	var cards: Array = []
	for type in adds:
		cards.append({ "type": type, "kind": "add" })
	for type in news:
		cards.append({ "type": type, "kind": "new" })
	return cards

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap

## Step 2: lays out the cards for the player to choose from (waits in run.pending).
## `source` is "pull" or "trade_up". Returns false when there is nothing to offer.
static func begin_choice(run: RunState, tier: Piece.Tier, source: String, rng: RandomNumberGenerator = null) -> bool:
	var cards := offer(run, tier, rng)
	if cards.is_empty():
		return false
	run.pending = { "kind": "cards", "tier": tier, "cards": cards, "source": source, "stage": "pick" }
	return true

## Takes card number `index` of the pending offer. Returns { ok, reason, stage, gained }: stage is
## "replace" when a new type needs a slot to replace (call pick_replacement next), else "done".
static func pick_card(run: RunState, index: int) -> Dictionary:
	if run.pending.get("kind") != "cards" or run.pending.stage != "pick" or index < 0 or index >= run.pending.cards.size():
		return { "ok": false, "reason": "There is no card to pick." }
	var card: Dictionary = run.pending.cards[index]
	var tier: Piece.Tier = run.pending.tier
	if card.kind == "new" and run.free_slots(tier) == 0:
		run.pending.stage = "replace"
		run.pending.card = card
		return { "ok": true, "reason": "", "stage": "replace", "gained": card.type }
	run.add_to_roster(card.type)
	run.pending = {}
	return { "ok": true, "reason": "", "stage": "done", "gained": card.type }

## When the tier is full: the new type takes over the slot of `replaced` (one of your held
## types in the tier). All your pieces of that type become the new type, so the number is kept.
static func pick_replacement(run: RunState, replaced: Piece.Type) -> Dictionary:
	if run.pending.get("kind") != "cards" or run.pending.stage != "replace":
		return { "ok": false, "reason": "Nothing to replace right now." }
	var tier: Piece.Tier = run.pending.tier
	if not run.held_types(tier).has(replaced):
		return { "ok": false, "reason": "You don't hold that piece." }
	var incoming: Piece.Type = run.pending.card.type
	run.retype(replaced, incoming)
	run.pending = {}
	return { "ok": true, "reason": "", "stage": "done", "gained": incoming, "replaced": replaced }
