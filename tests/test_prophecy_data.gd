extends "res://tests/TestCase.gd"
## The fifty prophecy cards: the list itself, rarity and prices.

func test_there_are_fifty_cards_with_unique_ids_and_names() -> void:
	check_eq(ProphecyDefs.ids().size(), 50, "fifty cards")
	var names := {}
	for id in ProphecyDefs.ids():
		var name: String = ProphecyDefs.display_name(id)
		check(not names.has(name), "%s is used twice" % name)
		names[name] = true
		check(id == id.to_lower() and not id.contains(" "), "%s is a tidy id" % id)
		check(ProphecyDefs.text(id).length() >= 8, "%s has a description" % id)

func test_the_rarity_split_is_18_16_11_5() -> void:
	check_eq(ProphecyDefs.ids_of_rarity(Piece.Tier.COMMON).size(), 18, "common")
	check_eq(ProphecyDefs.ids_of_rarity(Piece.Tier.UNCOMMON).size(), 16, "uncommon")
	check_eq(ProphecyDefs.ids_of_rarity(Piece.Tier.RARE).size(), 11, "rare")
	check_eq(ProphecyDefs.ids_of_rarity(Piece.Tier.LEGENDARY).size(), 5, "legendary")

func test_every_card_is_played_in_a_known_way() -> void:
	for id in ProphecyDefs.ids():
		check(["match", "armed", "shop"].has(ProphecyDefs.timing(id)), "%s has a timing" % id)
		if ProphecyDefs.timing(id) == "armed":
			check(ProphecyDefs.text(id).begins_with("Arm before a match"), "%s says it is armed" % id)

func test_the_rarer_the_card_the_pricier_and_the_less_likely() -> void:
	var tiers := [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]
	for i in range(1, tiers.size()):
		check(RunConfig.PROPHECY_PRICES[tiers[i]] > RunConfig.PROPHECY_PRICES[tiers[i - 1]], "%s costs more than %s" % [Piece.TIER_NAMES[tiers[i]], Piece.TIER_NAMES[tiers[i - 1]]])
		check(RunConfig.PROPHECY_WEIGHTS[tiers[i]] < RunConfig.PROPHECY_WEIGHTS[tiers[i - 1]], "%s is rarer than %s" % [Piece.TIER_NAMES[tiers[i]], Piece.TIER_NAMES[tiers[i - 1]]])
	for id in ProphecyDefs.ids():
		check_eq(Prophecies.price(id), RunConfig.PROPHECY_PRICES[ProphecyDefs.rarity(id)], "%s costs what its rarity says" % id)

func test_stages_one_and_two_build_thirty_five_cards() -> void:
	var ready := ProphecyDefs.ready_ids()
	check_eq(ready.size(), 35, "scoring, economy, shop, time and position cards")
	for id in ["omen_of_plunder", "rising_tide", "blood_moon", "blessing_of_the_blade", "song_of_the_small", "giant_slayer", "final_blow", "chain_of_fate", "prophecy_of_ruin", "gilded_ledger",
			"purse_of_gold", "golden_tithe", "lucky_draw", "loaded_dice", "wider_net", "fair_trade", "hagglers_charm", "second_sight", "queens_favor", "unsealed_tomb", "merlins_bargain",
			"quickening", "borrowed_hour", "turning_tide", "frozen_moment", "second_chance", "twin_sun", "haste",
			"sanctuary", "stone_ward", "waypoint", "swap_fates", "broaden_the_realm", "reinforcements", "wings"]:
		check(ready.has(id), "%s is built" % id)
	check(not ProphecyDefs.is_ready("call_to_arms"), "the piece and enemy cards are still to come")

func test_the_shop_only_ever_offers_built_cards_and_never_the_same_twice() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value in 200:
		rng.seed = seed_value
		var offers := Prophecies.roll_offers(rng)
		check_eq(offers.size(), RunConfig.PROPHECY_OFFERS, "four offers")
		var unique := {}
		for id in offers:
			unique[id] = true
			check(ProphecyDefs.is_ready(id), "%s is built" % id)
		check_eq(unique.size(), offers.size(), "no card twice in one shop")
		if failures.size() > 3:
			break

func test_rarer_cards_turn_up_less_often() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts := { Piece.Tier.COMMON: 0, Piece.Tier.UNCOMMON: 0, Piece.Tier.RARE: 0, Piece.Tier.LEGENDARY: 0 }
	for i in 1500:
		for id in Prophecies.roll_offers(rng):
			counts[ProphecyDefs.rarity(id)] += 1
	check(counts[Piece.Tier.COMMON] > counts[Piece.Tier.UNCOMMON] and counts[Piece.Tier.UNCOMMON] > counts[Piece.Tier.RARE] and counts[Piece.Tier.RARE] > counts[Piece.Tier.LEGENDARY], "common > uncommon > rare > legendary: %s" % str(counts))
	check(counts[Piece.Tier.LEGENDARY] > 0, "legendaries do show up")
