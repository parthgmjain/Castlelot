class_name Shop
extends RefCounted

# ---- trading up: N pieces of one tier become one of the next tier -------------

## Whether these roster ids can be sacrificed. Returns { ok, reason, from, to }
## (`from`/`to` are Piece.Tiers, only set when the pieces themselves are valid).
static func check_trade_up(run: RunState, ids: Array) -> Dictionary:
	var count := RunConfig.TRADE_UP_COUNT
	if ids.size() != count:
		return { "ok": false, "reason": "Select %d pieces (%d selected)" % [count, ids.size()] }

	var tier := -1
	var seen := {}
	for id in ids:
		var entry := run.roster_entry(id)
		if entry.is_empty() or seen.has(id):
			return { "ok": false, "reason": "Those pieces aren't all in your roster" }
		seen[id] = true
		var this_tier := Piece.tier(entry.type)
		if tier != -1 and this_tier != tier:
			return { "ok": false, "reason": "All five must be the same tier" }
		tier = this_tier

	if tier == Piece.Tier.LEGENDARY:
		return { "ok": false, "reason": "Legendary pieces can't be traded up" }
	return { "ok": true, "reason": "", "from": tier, "to": tier + 1 }

## Sacrifices the pieces for a random piece of the next tier up.
## Returns { ok, reason, gained (the Piece.Type) }.
static func trade_up(run: RunState, ids: Array) -> Dictionary:
	var check := check_trade_up(run, ids)
	if not check.ok:
		return check
	for id in ids:
		run.remove_from_roster(id)
	var gained: Piece.Type = Lottery.roll_piece(check.to)
	run.add_to_roster(gained)
	return { "ok": true, "reason": "", "gained": gained }

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
