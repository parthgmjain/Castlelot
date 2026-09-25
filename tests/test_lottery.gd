extends "res://tests/TestCase.gd"
## The piece lottery: tier first, then a piece from that tier.

func _run(gold: int = 100) -> RunState:
	var run := RunState.new()
	run.begin()
	run.currency = gold
	return run

func _rng(seed_value: int = 4242) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_a_pull_costs_gold_and_each_pull_costs_more() -> void:
	var run := _run(100)
	var first := Lottery.price(run)
	check_eq(first, RunConfig.PULL_PRICE_BASE, "the first pull")
	check(Lottery.start_pull(run, _rng()).ok, "paid")
	check_eq(run.currency, 100 - first, "gold spent")
	check_eq(Lottery.price(run), first + RunConfig.PULL_PRICE_STEP, "the next pull is dearer")

func test_a_pull_without_the_gold_is_refused_and_costs_nothing() -> void:
	var run := _run(RunConfig.PULL_PRICE_BASE - 1)
	var result := Lottery.start_pull(run, _rng())
	check(not result.ok, "refused")
	check(result.reason.begins_with("Not enough gold"), result.reason)
	check_eq(run.currency, RunConfig.PULL_PRICE_BASE - 1, "nothing spent")
	check_eq(run.pulls_made, 0, "and it doesn't count as a pull")

func test_the_tier_is_learned_first_and_the_piece_second() -> void:
	var run := _run(100)
	var roster_before := run.roster.size()
	var started := Lottery.start_pull(run, _rng())
	check(started.ok and Piece.TIERS.values().has(started.tier), "step 1 reveals a tier")
	check_eq(run.roster.size(), roster_before, "no piece yet")
	var type := Lottery.finish_pull(run, started.tier, _rng())
	check_eq(Piece.tier(type), started.tier, "step 2 draws from that very tier")
	check_eq(run.roster.size(), roster_before + 1, "and the piece joins your roster")
	check_eq(run.roster.back().type, type, "the right one")

func test_tier_odds_follow_the_weights() -> void:
	var run := _run()
	var rng := _rng(7)
	var counts := { Piece.Tier.COMMON: 0, Piece.Tier.UNCOMMON: 0, Piece.Tier.LEGENDARY: 0 }
	var rolls := 6000
	for i in rolls:
		counts[Lottery.roll_tier(Lottery.tier_weights(run), rng)] += 1
	var odds := Lottery.odds(run)
	for tier in counts:
		var observed := float(counts[tier]) / rolls
		check(absf(observed - odds[tier]) < 0.025, "%s: observed %.3f vs expected %.3f" % [Piece.TIER_NAMES[tier], observed, odds[tier]])
	check(counts[Piece.Tier.LEGENDARY] > 0, "legendary pulls do happen")
	check(counts[Piece.Tier.COMMON] > counts[Piece.Tier.UNCOMMON] and counts[Piece.Tier.UNCOMMON] > counts[Piece.Tier.LEGENDARY], "common > uncommon > legendary")

func test_the_odds_add_up_to_one() -> void:
	var total := 0.0
	for p in Lottery.odds(_run()).values():
		total += p
	check(absf(total - 1.0) < 0.0001, "sum %f" % total)

func test_every_piece_in_a_tier_can_be_drawn() -> void:
	var rng := _rng(11)
	var seen := {}
	for i in 400:
		seen[Lottery.roll_piece(Piece.Tier.UNCOMMON, rng)] = true
	check(seen.has(KNIGHT) and seen.has(BISHOP) and seen.has(ROOK), "all three uncommon pieces turn up: %s" % str(seen.keys()))
	check_eq(Lottery.roll_piece(Piece.Tier.COMMON, rng), PAWN, "the common pool is the pawn")
	check_eq(Lottery.roll_piece(Piece.Tier.LEGENDARY, rng), QUEEN, "the legendary pool is the queen")

func test_tiers_with_no_pieces_or_no_weight_are_never_drawn() -> void:
	var weights := { Piece.Tier.COMMON: 1.0, 99: 5.0, Piece.Tier.UNCOMMON: 0.0 }
	check_eq(Lottery.usable_weights(weights), { Piece.Tier.COMMON: 1.0 }, "only the tier that has pieces and weight")
	var rng := _rng(3)
	for i in 100:
		check_eq(Lottery.roll_tier(weights, rng), Piece.Tier.COMMON, "always common")

func test_pools_come_from_the_tier_table_so_new_pieces_join_automatically() -> void:
	var union := []
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.LEGENDARY]:
		check_eq(Lottery.pool(tier), Piece.types_in_tier(tier), "pool for %s" % Piece.TIER_NAMES[tier])
		check(not Lottery.pool(tier).is_empty(), "%s isn't empty" % Piece.TIER_NAMES[tier])
		union.append_array(Lottery.pool(tier))
	union.sort()
	var table_keys := Piece.TIERS.keys()
	table_keys.sort()
	check_eq(union, table_keys, "every piece in the tier table is in exactly one pool")

func test_trade_ups_draw_from_the_same_pools() -> void:
	var run := _run()
	var ids := []
	for i in 5:
		ids.append(run.add_to_roster(PAWN))
	var result := Shop.trade_up(run, ids)
	check(Lottery.pool(Piece.Tier.UNCOMMON).has(result.gained), "the uncommon pool")
