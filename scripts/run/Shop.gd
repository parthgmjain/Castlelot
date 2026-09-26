class_name Shop
extends RefCounted

# ---- trading up: N pieces of one tier become a choice from the next tier ------

## How many pieces of `tier` it takes to trade up (0 when it can't be done). With a `run`,
## Fair Trade (-2 for the next trade-up) and Queen's Favor (-2 on the rare -> legendary one) count.
static func trade_up_cost(tier: Piece.Tier, run: RunState = null) -> int:
	var cost: int = RunConfig.TRADE_UP_COUNTS.get(tier, 0)
	if cost == 0 or run == null:
		return cost
	if run.shop_effects.has("fair_trade"):
		cost -= run.shop_effects.fair_trade
	if tier == Piece.Tier.RARE and run.shop_effects.get("queens_favor", false):
		cost -= 2
	return maxi(cost, 1)

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

	var count := trade_up_cost(tier, run)
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
	run.shop_effects.erase("fair_trade")
	if check.from == Piece.Tier.RARE:
		run.shop_effects.erase("queens_favor")
	if check.to == Piece.Tier.LEGENDARY:
		run.pending = { "kind": "legendary_pick", "options": Legendaries.available_upgrades(run) }
	else:
		Lottery.begin_choice(run, check.to, "trade_up", rng)
	return { "ok": true, "reason": "", "to": check.to }

# ---- upgrades ------------------------------------------------------------------

static func points_upgrade_price(run: RunState) -> int:
	return _haggled(run, RunConfig.POINTS_UPGRADE_PRICE_BASE + run.points_upgrades_bought * RunConfig.POINTS_UPGRADE_PRICE_STEP)

## Haggler's Charm halves upgrade prices (rounding up) for this shop visit.
static func _haggled(run: RunState, price: int) -> int:
	return int(ceil(price / 2.0)) if run.shop_effects.get("haggle", false) else price

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
	return _haggled(run, RunConfig.ZONE_UPGRADE_PRICE_BASE + run.zone_upgrades_bought * RunConfig.ZONE_UPGRADE_PRICE_STEP)

static func can_buy_zone(run: RunState) -> bool:
	return run.currency >= zone_upgrade_price(run) and run.zone_tiles < RunConfig.MAX_ZONE_TILES

static func buy_zone(run: RunState) -> bool:
	if not can_buy_zone(run):
		return false
	run.currency -= zone_upgrade_price(run)
	run.zone_upgrades_bought += 1
	run.zone_tiles = mini(run.zone_tiles + RunConfig.ZONE_UPGRADE_AMOUNT, RunConfig.MAX_ZONE_TILES)
	return true

static func moves_upgrade_price(run: RunState) -> int:
	return _haggled(run, RunConfig.MOVES_UPGRADE_PRICE_BASE + run.moves_upgrades_bought * RunConfig.MOVES_UPGRADE_PRICE_STEP)

static func can_buy_moves(run: RunState) -> bool:
	return run.currency >= moves_upgrade_price(run) and run.bonus_moves < RunConfig.MAX_BONUS_MOVES

## Adds RunConfig.MOVES_UPGRADE_AMOUNT moves to every match for the rest of the run.
static func buy_moves(run: RunState) -> bool:
	if not can_buy_moves(run):
		return false
	run.currency -= moves_upgrade_price(run)
	run.moves_upgrades_bought += 1
	run.bonus_moves = mini(run.bonus_moves + RunConfig.MOVES_UPGRADE_AMOUNT, RunConfig.MAX_BONUS_MOVES)
	return true
