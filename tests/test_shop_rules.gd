extends "res://tests/TestCase.gd"
## The shop's economy: tiers, buying pawns, trading up, and the two upgrades.

func _run(gold: int = 100) -> RunState:
	var run := RunState.new()
	run.begin()
	run.currency = gold
	return run

func _ids_of(run: RunState, type: Piece.Type, count: int) -> Array:
	var ids := []
	for entry in run.roster:
		if entry.type == type and ids.size() < count:
			ids.append(entry.id)
	return ids

func _give(run: RunState, type: Piece.Type, count: int) -> Array:
	var ids := []
	for i in count:
		ids.append(run.add_to_roster(type))
	return ids

# ---- tiers ---------------------------------------------------------------------

func test_pieces_have_the_tiers_you_specified() -> void:
	check_eq(Piece.tier(PAWN), Piece.Tier.COMMON, "pawn")
	for type in [KNIGHT, BISHOP, ROOK]:
		check_eq(Piece.tier(type), Piece.Tier.UNCOMMON, Piece.Type.find_key(type))
	check_eq(Piece.tier(QUEEN), Piece.Tier.LEGENDARY, "queen")
	check_eq(Piece.types_in_tier(Piece.Tier.UNCOMMON).size(), 3, "three uncommon types")
	check_eq(Piece.types_in_tier(Piece.Tier.LEGENDARY), [QUEEN], "only the queen is legendary")

# ---- trading up ------------------------------------------------------------------

func test_five_pawns_trade_up_to_one_uncommon_piece() -> void:
	var run := _run()
	var pawns := _ids_of(run, PAWN, 3) + _give(run, PAWN, 2)
	check_eq(pawns.size(), 5, "five pawns")
	var check := Shop.check_trade_up(run, pawns)
	check(check.ok and check.from == Piece.Tier.COMMON and check.to == Piece.Tier.UNCOMMON, "a valid common -> uncommon trade")
	var before := run.roster.size()
	var result := Shop.trade_up(run, pawns)
	check(result.ok, "traded")
	check_eq(Piece.tier(result.gained), Piece.Tier.UNCOMMON, "got an uncommon piece")
	check_eq(run.roster.size(), before - 5 + 1, "five out, one in")
	for id in pawns:
		check(run.roster_entry(id).is_empty(), "the sacrificed pawn %d is gone" % id)

func test_five_uncommon_pieces_trade_up_to_a_queen() -> void:
	var run := _run()
	var ids := _ids_of(run, ROOK, 1) + _ids_of(run, KNIGHT, 1) + _ids_of(run, BISHOP, 1) + _give(run, KNIGHT, 1) + _give(run, BISHOP, 1)
	var result := Shop.trade_up(run, ids)
	check(result.ok, "traded")
	check_eq(result.gained, QUEEN, "the only legendary piece")
	check(run.roster.any(func(e): return e.type == QUEEN), "the queen is in the roster")

func test_a_trade_up_can_give_any_of_the_uncommon_pieces() -> void:
	var seen := {}
	for i in 60:
		var run := _run()
		var ids := _ids_of(run, PAWN, 3) + _give(run, PAWN, 2)
		seen[Shop.trade_up(run, ids).gained] = true
	check(seen.has(KNIGHT) and seen.has(BISHOP) and seen.has(ROOK), "all three turn up over many trades: %s" % str(seen.keys()))

func test_trade_up_needs_exactly_five_pieces_of_one_tier() -> void:
	var run := _run()
	var pawns := _ids_of(run, PAWN, 3) + _give(run, PAWN, 2)
	check(not Shop.check_trade_up(run, pawns.slice(0, 4)).ok, "four isn't enough")
	check(not Shop.check_trade_up(run, pawns + _give(run, PAWN, 1)).ok, "six isn't five")
	var mixed := pawns.slice(0, 4) + _ids_of(run, ROOK, 1)
	check(not Shop.check_trade_up(run, mixed).ok, "mixed tiers are refused")
	check_eq(Shop.check_trade_up(run, mixed).reason, "All five must be the same tier", "with a reason")
	check(not Shop.check_trade_up(run, [pawns[0], pawns[0], pawns[1], pawns[2], pawns[3]]).ok, "the same piece twice")
	check(not Shop.check_trade_up(run, [pawns[0], pawns[1], pawns[2], pawns[3], 9999]).ok, "a piece you don't own")
	var before := run.roster.size()
	var refused := Shop.trade_up(run, mixed)
	check(not refused.ok, "a refused trade reports failure")
	check_eq(run.roster.size(), before, "and changes nothing")

func test_legendary_pieces_cannot_be_traded_up() -> void:
	var run := _run()
	var queens := _give(run, QUEEN, 5)
	var check := Shop.check_trade_up(run, queens)
	check(not check.ok, "refused")
	check_eq(check.reason, "Legendary pieces can't be traded up", "reason")

func test_you_choose_which_pieces_to_sacrifice() -> void:
	var run := _run()
	var rook: int = _ids_of(run, ROOK, 1)[0]
	var extra := _give(run, KNIGHT, 4)
	var result := Shop.trade_up(run, extra + _ids_of(run, KNIGHT, 1))     # keep the rook, give up five knights
	check(result.ok, "traded")
	check(not run.roster_entry(rook).is_empty(), "the rook you didn't pick is still yours")

# ---- upgrades ----------------------------------------------------------------------

func test_a_new_run_starts_with_the_points_and_zone_that_fit_the_starting_roster() -> void:
	var run := _run()
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START, "points")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES, "zone")
	var value := 0
	for entry in run.roster:
		value += Piece.value(entry.type)
	check_eq(value, run.allocated_points, "the starting roster costs exactly the starting points")

func test_upgrading_allocated_points() -> void:
	var run := _run(100)
	var price := Shop.points_upgrade_price(run)
	check_eq(price, RunConfig.POINTS_UPGRADE_PRICE_BASE, "first price")
	check(Shop.buy_points(run), "bought")
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START + RunConfig.POINTS_UPGRADE_AMOUNT, "more points")
	check_eq(run.currency, 100 - price, "gold spent")
	check_eq(Shop.points_upgrade_price(run), price + RunConfig.POINTS_UPGRADE_PRICE_STEP, "the next costs more")

func test_upgrading_zone_size() -> void:
	var run := _run(100)
	var price := Shop.zone_upgrade_price(run)
	check(Shop.buy_zone(run), "bought")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES + RunConfig.ZONE_UPGRADE_AMOUNT, "a bigger zone")
	check_eq(run.currency, 100 - price, "gold spent")
	check_eq(Shop.zone_upgrade_price(run), price + RunConfig.ZONE_UPGRADE_PRICE_STEP, "the next costs more")

func test_upgrades_need_gold_and_respect_their_caps() -> void:
	var poor := _run(1)
	check(not Shop.buy_points(poor) and not Shop.buy_zone(poor), "no gold, no upgrades")
	check_eq(poor.currency, 1, "nothing spent")
	var rich := _run(100000)
	rich.zone_tiles = RunConfig.MAX_ZONE_TILES
	rich.allocated_points = RunConfig.MAX_ALLOCATED_POINTS
	check(not Shop.buy_zone(rich) and not Shop.buy_points(rich), "capped upgrades are refused")
	check_eq(rich.currency, 100000, "and cost nothing")

func test_a_new_run_resets_purchases_and_prices() -> void:
	var run := _run(500)
	Lottery.start_pull(run)
	Shop.buy_points(run)
	Shop.buy_zone(run)
	run.begin()
	check_eq(Lottery.price(run), RunConfig.PULL_PRICE_BASE, "pull price reset")
	check_eq(Shop.points_upgrade_price(run), RunConfig.POINTS_UPGRADE_PRICE_BASE, "points price reset")
	check_eq(Shop.zone_upgrade_price(run), RunConfig.ZONE_UPGRADE_PRICE_BASE, "zone price reset")
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START, "points reset")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES, "zone reset")
