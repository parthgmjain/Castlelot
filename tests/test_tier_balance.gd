extends "res://tests/TestCase.gd"
## The tier table: which piece sits where, what it costs, and how many kinds you can hold.

func _types(tier: Piece.Tier) -> Array:
	return Piece.types_in_tier(tier)

func _values(tier: Piece.Tier) -> Array:
	return _types(tier).map(func(t): return Piece.value(t))

func _average(numbers: Array) -> float:
	var total := 0.0
	for n in numbers:
		total += n
	return total / numbers.size()

func test_four_tiers_with_the_slot_limits_you_set() -> void:
	check_eq(RunConfig.SLOTS_PER_TIER[Piece.Tier.COMMON], 5, "common types")
	check_eq(RunConfig.SLOTS_PER_TIER[Piece.Tier.UNCOMMON], 5, "uncommon types")
	check_eq(RunConfig.SLOTS_PER_TIER[Piece.Tier.RARE], 3, "rare types")
	check_eq(RunConfig.SLOTS_PER_TIER[Piece.Tier.LEGENDARY], 2, "legendary types")
	check_eq(Piece.TIER_NAMES.size(), 4, "four tier names")

func test_every_piece_but_the_king_is_in_exactly_one_tier() -> void:
	var everyone := []
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]:
		everyone.append_array(_types(tier))
	check_eq(everyone.size(), 48, "35 ordinary pieces and 13 legendaries")
	var unique := {}
	for type in everyone:
		unique[type] = true
	check_eq(unique.size(), everyone.size(), "nobody is listed twice")
	check(not unique.has(KING), "the king isn't a card")

func test_tier_sizes() -> void:
	check_eq(_types(Piece.Tier.COMMON).size(), 11, "common: the pawn and the ten pawn-tier pieces")
	check_eq(_types(Piece.Tier.UNCOMMON).size(), 13, "uncommon")
	check_eq(_types(Piece.Tier.RARE).size(), 11, "rare")
	check_eq(_types(Piece.Tier.LEGENDARY).size(), 13, "legendary: the queen and the twelve boss pieces")

func test_each_buyable_tier_has_more_kinds_than_slots_so_there_are_replacements_to_offer() -> void:
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE]:
		check(Lottery.pool(tier).size() >= RunConfig.SLOTS_PER_TIER[tier] + 2, "%s has room for 2 replacement cards" % Piece.TIER_NAMES[tier])

func test_the_placements_you_will_notice() -> void:
	var expected := {
		PAWN: Piece.Tier.COMMON, Piece.Type.SCOUT: Piece.Tier.COMMON, Piece.Type.ARCHER: Piece.Tier.COMMON, Piece.Type.SQUIRE: Piece.Tier.COMMON,
		KNIGHT: Piece.Tier.UNCOMMON, BISHOP: Piece.Tier.UNCOMMON, Piece.Type.CAMEL: Piece.Tier.UNCOMMON, Piece.Type.GOLEM: Piece.Tier.UNCOMMON, Piece.Type.BARD: Piece.Tier.UNCOMMON,
		ROOK: Piece.Tier.RARE, Piece.Type.CANNON: Piece.Tier.RARE, Piece.Type.GHOST: Piece.Tier.RARE, Piece.Type.NINJA: Piece.Tier.RARE, Piece.Type.ALCHEMIST: Piece.Tier.RARE,
		QUEEN: Piece.Tier.LEGENDARY, Piece.Type.DRAGON: Piece.Tier.LEGENDARY,
	}
	for type in expected:
		check_eq(Piece.tier(type), expected[type], Piece.display_name(type))

func test_points_rise_with_the_tier() -> void:
	var commons := _values(Piece.Tier.COMMON)
	var uncommons := _values(Piece.Tier.UNCOMMON)
	var rares := _values(Piece.Tier.RARE)
	var legendaries := _values(Piece.Tier.LEGENDARY)
	check(commons.max() <= 2 and commons.min() >= 1, "commons cost 1-2: %s" % str(commons))
	check(uncommons.max() <= 3 and uncommons.min() >= 2, "uncommons cost 2-3: %s" % str(uncommons))
	check(rares.max() <= 5 and rares.min() >= 4, "rares cost 4-5: %s" % str(rares))
	check(legendaries.min() >= 9, "legendaries cost 9+: %s" % str(legendaries))
	check(_average(commons) < _average(uncommons) and _average(uncommons) < _average(rares) and _average(rares) < _average(legendaries), "each tier costs more on average than the last")
	check(commons.max() <= rares.min() and uncommons.max() <= rares.min() and rares.max() < legendaries.min(), "no rare is cheaper than a common or uncommon, no legendary cheaper than a rare")

func test_the_starting_roster_fits_the_slots_and_costs_the_starting_points() -> void:
	var run := RunState.new()
	run.begin()
	var cost := 0
	for entry in run.roster:
		cost += Piece.value(entry.type)
	check_eq(cost, RunConfig.PLAYER_POINTS_START, "14 points")
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]:
		check(run.held_types(tier).size() <= RunConfig.SLOTS_PER_TIER[tier], "%s stays within its slots" % Piece.TIER_NAMES[tier])
