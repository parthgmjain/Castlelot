extends "res://tests/TestCase.gd"
## The shop's economy: trading up (5 / 5 / 7) and the two upgrades.

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

func test_the_chess_pieces_sit_in_the_tiers_you_would_expect() -> void:
	check_eq(Piece.tier(PAWN), Piece.Tier.COMMON, "pawn")
	check_eq(Piece.tier(KNIGHT), Piece.Tier.UNCOMMON, "knight")
	check_eq(Piece.tier(BISHOP), Piece.Tier.UNCOMMON, "bishop")
	check_eq(Piece.tier(ROOK), Piece.Tier.RARE, "rook")
	check_eq(Piece.tier(QUEEN), Piece.Tier.LEGENDARY, "queen")
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]:
		for type in Piece.types_in_tier(tier):
			check_eq(Piece.tier(type), tier, "everything listed in a tier is in it: %s" % Piece.display_name(type))

# ---- trading up ------------------------------------------------------------------

func test_the_costs_are_five_five_and_seven() -> void:
	check_eq(Shop.trade_up_cost(Piece.Tier.COMMON), 5, "commons")
	check_eq(Shop.trade_up_cost(Piece.Tier.UNCOMMON), 5, "uncommons")
	check_eq(Shop.trade_up_cost(Piece.Tier.RARE), 7, "rares")
	check_eq(Shop.trade_up_cost(Piece.Tier.LEGENDARY), 0, "legendaries can't go higher")

func test_five_pawns_trade_up_and_offer_uncommon_cards() -> void:
	var run := _run()
	var pawns := _ids_of(run, PAWN, 3) + _give(run, PAWN, 2)
	check_eq(pawns.size(), 5, "five pawns")
	var check := Shop.check_trade_up(run, pawns)
	check(check.ok and check.from == Piece.Tier.COMMON and check.to == Piece.Tier.UNCOMMON and check.count == 5, "a valid common -> uncommon trade")
	var before := run.roster.size()
	var result := Shop.trade_up(run, pawns, RandomNumberGenerator.new())
	check(result.ok and result.to == Piece.Tier.UNCOMMON, "traded")
	check_eq(run.roster.size(), before - 5, "the five are gone and nothing is granted yet")
	check(run.pending.kind == "cards" and run.pending.tier == Piece.Tier.UNCOMMON and run.pending.source == "trade_up", "a choice of uncommon cards waits")
	for id in pawns:
		check(run.roster_entry(id).is_empty(), "the sacrificed pawn %d is gone" % id)
	Lottery.pick_card(run, 0)
	check_eq(run.roster.size(), before - 5 + 1, "one piece in return once you pick")

func test_five_uncommons_offer_rare_cards() -> void:
	var run := _run()
	var ids := _ids_of(run, KNIGHT, 1) + _ids_of(run, BISHOP, 1) + _give(run, KNIGHT, 2) + _give(run, Piece.Type.CAMEL, 1)
	var result := Shop.trade_up(run, ids)
	check(result.ok and result.to == Piece.Tier.RARE, "traded up to rare")
	check_eq(run.pending.tier, Piece.Tier.RARE, "rare cards")
	check(run.pending.cards.all(func(c): return Piece.tier(c.type) == Piece.Tier.RARE), "all rare")

func test_seven_rares_are_needed_for_a_legendary() -> void:
	var run := _run()
	var rares := _ids_of(run, ROOK, 1) + _give(run, ROOK, 4)
	check(not Shop.check_trade_up(run, rares).ok, "five rares aren't enough")
	check_eq(Shop.check_trade_up(run, rares).reason, "Select 7 rare pieces (5 selected)", "and it says why")
	rares += _give(run, ROOK, 1)
	check(not Shop.check_trade_up(run, rares).ok, "six isn't either")
	rares += _give(run, ROOK, 1)
	var check := Shop.check_trade_up(run, rares)
	check(check.ok and check.to == Piece.Tier.LEGENDARY and check.count == 7, "seven works")
	check(not Shop.check_trade_up(run, rares + _give(run, ROOK, 1)).ok, "eight doesn't")

func test_trade_up_needs_exactly_the_right_number_of_one_tier() -> void:
	var run := _run()
	var pawns := _ids_of(run, PAWN, 3) + _give(run, PAWN, 2)
	check(not Shop.check_trade_up(run, pawns.slice(0, 4)).ok, "four isn't enough")
	check(not Shop.check_trade_up(run, pawns + _give(run, PAWN, 1)).ok, "six isn't five")
	check(not Shop.check_trade_up(run, []).ok, "nothing selected")
	var mixed := pawns.slice(0, 4) + _ids_of(run, KNIGHT, 1)
	check(not Shop.check_trade_up(run, mixed).ok, "mixed tiers are refused")
	check_eq(Shop.check_trade_up(run, mixed).reason, "All the pieces must be the same tier", "with a reason")
	check(not Shop.check_trade_up(run, [pawns[0], pawns[0], pawns[1], pawns[2], pawns[3]]).ok, "the same piece twice")
	check(not Shop.check_trade_up(run, [pawns[0], pawns[1], pawns[2], pawns[3], 9999]).ok, "a piece you don't own")
	var before := run.roster.size()
	var refused := Shop.trade_up(run, mixed)
	check(not refused.ok, "a refused trade reports failure")
	check_eq(run.roster.size(), before, "and changes nothing")
	check(run.pending.is_empty(), "and offers nothing")

func test_legendary_pieces_cannot_be_traded_up() -> void:
	var run := _run()
	var queens := _give(run, QUEEN, 2)
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

func test_sacrificing_a_whole_type_frees_its_slot_for_the_offer() -> void:
	var run := _run()
	for type in [Piece.Type.SCOUT, Piece.Type.SERF, Piece.Type.CRAB, Piece.Type.DRUMMER]:
		_give(run, type, 1)
	check_eq(run.free_slots(Piece.Tier.COMMON), 0, "common is full")
	var ids := _ids_of(run, Piece.Type.SCOUT, 1) + _ids_of(run, Piece.Type.SERF, 1) + _ids_of(run, Piece.Type.CRAB, 1) + _ids_of(run, Piece.Type.DRUMMER, 1) + _ids_of(run, PAWN, 1)
	Shop.trade_up(run, ids)
	check_eq(run.free_slots(Piece.Tier.COMMON), 4, "four common slots are open again")

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

func test_upgrading_moves() -> void:
	var run := _run(100)
	check_eq(run.bonus_moves, 0, "no bonus yet")
	var price := Shop.moves_upgrade_price(run)
	check_eq(price, RunConfig.MOVES_UPGRADE_PRICE_BASE, "first price")
	check(Shop.buy_moves(run), "bought")
	check_eq(run.bonus_moves, RunConfig.MOVES_UPGRADE_AMOUNT, "more moves banked")
	check_eq(run.currency, 100 - price, "gold spent")
	check_eq(Shop.moves_upgrade_price(run), price + RunConfig.MOVES_UPGRADE_PRICE_STEP, "the next costs more")

func test_the_bonus_moves_carry_into_every_matchs_setup() -> void:
	var run := _run(100)
	var before: int = RunConfig.match_setup(run).moves
	Shop.buy_moves(run)
	check_eq(RunConfig.match_setup(run).moves, before + RunConfig.MOVES_UPGRADE_AMOUNT, "the next match gets the bonus")
	Shop.buy_moves(run)
	check_eq(RunConfig.match_setup(run).moves, before + RunConfig.MOVES_UPGRADE_AMOUNT * 2, "and stacks with a second purchase")

func test_moves_upgrade_needs_gold_and_respects_its_cap() -> void:
	var poor := _run(1)
	check(not Shop.buy_moves(poor), "no gold, no upgrade")
	check_eq(poor.currency, 1, "nothing spent")
	var rich := _run(100000)
	rich.bonus_moves = RunConfig.MAX_BONUS_MOVES
	check(not Shop.buy_moves(rich), "capped")
	check_eq(rich.currency, 100000, "and costs nothing")

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
	Shop.buy_moves(run)
	run.begin()
	check_eq(Lottery.price(run), RunConfig.PULL_PRICE_BASE, "pull price reset")
	check_eq(Shop.points_upgrade_price(run), RunConfig.POINTS_UPGRADE_PRICE_BASE, "points price reset")
	check_eq(Shop.zone_upgrade_price(run), RunConfig.ZONE_UPGRADE_PRICE_BASE, "zone price reset")
	check_eq(Shop.moves_upgrade_price(run), RunConfig.MOVES_UPGRADE_PRICE_BASE, "moves price reset")
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START, "points reset")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES, "zone reset")
	check_eq(run.bonus_moves, 0, "bonus moves reset")
