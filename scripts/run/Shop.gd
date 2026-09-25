class_name Shop
extends RefCounted

# ---- trading up: N pieces of one tier become a choice from the next tier ------

## How many pieces of `tier` it takes to trade up (0 when it can't be done).
static func trade_up_cost(tier: Piece.Tier) -> int:
	return RunConfig.TRADE_UP_COUNTS.get(tier, 0)

## Whether these roster ids can be sacrificed. Returns { ok, reason, count, from, to }
## (`from`/`to` are Piece.Tiers and `count` the number needed, once the first piece shows the tier).
static func check_trade_up(run: RunState, ids: Array) -> Dictionary:
	if ids.is_empty():
		return { "ok": false, "reason": "Select pieces of one tier to trade up", "count": RunConfig.TRADE_UP_COUNTS[Piece.Tier.COMMON] }

	var tier := -1
	var seen := {}
	for id in ids:
		var entry := run.roster_entry(id)
		if entry.is_empty() or seen.has(id):
			return { "ok": false, "reason": "Those pieces aren't all in your roster" }
		seen[id] = true
		var this_tier := Piece.tier(entry.type)
		if tier != -1 and this_tier != tier:
			return { "ok": false, "reason": "All the pieces must be the same tier" }
		tier = this_tier

	var count := trade_up_cost(tier)
	if count == 0:
		return { "ok": false, "reason": "Legendary pieces can't be traded up" }
	if ids.size() != count:
		return { "ok": false, "reason": "Select %d %s pieces (%d selected)" % [count, Piece.TIER_NAMES[tier].to_lower(), ids.size()], "count": count, "from": tier }
	if tier + 1 == Piece.Tier.LEGENDARY and Legendaries.available_upgrades(run).is_empty():
		return { "ok": false, "reason": "You hold every legendary you have unlocked", "count": count, "from": tier }
	return { "ok": true, "reason": "", "count": count, "from": tier, "to": tier + 1 }

## Sacrifices the pieces and starts the choice of what you get: cards from the next tier, or
## (for a legendary) which legendary you want. The choice waits in run.pending.
## Returns { ok, reason, to }.
static func trade_up(run: RunState, ids: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var check := check_trade_up(run, ids)
	if not check.ok:
		return check
	for id in ids:
		run.remove_from_roster(id)
	if check.to == Piece.Tier.LEGENDARY:
		run.pending = { "kind": "legendary_pick", "options": Legendaries.available_upgrades(run) }
	else:
		Lottery.begin_choice(run, check.to, "trade_up", rng)
	return { "ok": true, "reason": "", "to": check.to }

# ---- upgrades ------------------------------------------------------------------

static func points_upgrade_price(run: RunState) -> int:
	return RunConfig.POINTS_UPGRADE_PRICE_BASE + run.points_upgrades_bought * RunConfig.POINTS_UPGRADE_PRICE_STEP

static func can_buy_points(run: RunState) -> bool:
	return run.currency >= points_upgrade_price(run) and run.allocated_points < RunConfig.MAX_ALLOCATED_POINTS

static func buy_points(run: RunState) -> bool:
	if not can_buy_points(run):
		return false
	run.currency -= points_upgrade_price(run)
	run.points_upgrades_bought += 1
	run.allocated_points = mini(run.allocated_points + RunConfig.POINTS_UPGRADE_AMOUNT, RunConfig.MAX_ALLOCATED_POINTS)
	return true

static func zone_upgrade_price(run: RunState) -> int:
	return RunConfig.ZONE_UPGRADE_PRICE_BASE + run.zone_upgrades_bought * RunConfig.ZONE_UPGRADE_PRICE_STEP

static func can_buy_zone(run: RunState) -> bool:
	return run.currency >= zone_upgrade_price(run) and run.zone_tiles < RunConfig.MAX_ZONE_TILES

static func buy_zone(run: RunState) -> bool:
	if not can_buy_zone(run):
		return false
	run.currency -= zone_upgrade_price(run)
	run.zone_upgrades_bought += 1
	run.zone_tiles = mini(run.zone_tiles + RunConfig.ZONE_UPGRADE_AMOUNT, RunConfig.MAX_ZONE_TILES)
	return true
