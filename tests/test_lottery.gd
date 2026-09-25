extends "res://tests/TestCase.gd"
## The piece lottery: pay, learn the tier, then choose one of five cards from that tier.

const CARDS := RunConfig.CARDS_OFFERED

func _run(gold: int = 100) -> RunState:
	var run := RunState.new()
	run.begin()
	run.currency = gold
	return run

func _rng(seed_value: int = 4242) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _give(run: RunState, type: Piece.Type, count: int = 1) -> void:
	for i in count:
		run.add_to_roster(type)

func _kinds(cards: Array, kind: String) -> Array:
	return cards.filter(func(c): return c.kind == kind)

func _types(cards: Array) -> Array:
	return cards.map(func(c): return c.type)

# A run whose common tier is full: pawn x3 plus four other types.
func _full_commons() -> RunState:
	var run := _run()
	for type in [Piece.Type.SCOUT, Piece.Type.SERF, Piece.Type.CRAB, Piece.Type.DRUMMER]:
		_give(run, type)
	return run

# ---- paying and the tier ---------------------------------------------------------------------

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

func test_the_tier_is_learned_first_and_no_piece_is_given_yet() -> void:
	var run := _run(100)
	var roster_before := run.roster.size()
	var started := Lottery.start_pull(run, _rng())
	check(started.ok and [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE].has(started.tier), "step 1 reveals a tier")
	check_eq(run.roster.size(), roster_before, "no piece yet")
	check(run.pending.is_empty(), "and no offer yet either")

func test_legendaries_can_never_be_drawn() -> void:
	var run := _run()
	var rng := _rng(99)
	check(not Lottery.odds(run).has(Piece.Tier.LEGENDARY), "no legendary odds")
	for i in 3000:
		check(Lottery.roll_tier(Lottery.tier_weights(run), rng) != Piece.Tier.LEGENDARY, "a roll landed on legendary")
		if failures.size() > 3:
			break
	check(Lottery.pool(Piece.Tier.LEGENDARY).is_empty(), "the legendary pool is empty")

func test_tier_odds_follow_the_weights() -> void:
	var run := _run()
	var rng := _rng(7)
	var counts := { Piece.Tier.COMMON: 0, Piece.Tier.UNCOMMON: 0, Piece.Tier.RARE: 0 }
	var rolls := 6000
	for i in rolls:
		counts[Lottery.roll_tier(Lottery.tier_weights(run), rng)] += 1
	var odds := Lottery.odds(run)
	for tier in counts:
		var observed := float(counts[tier]) / rolls
		check(absf(observed - odds[tier]) < 0.025, "%s: observed %.3f vs expected %.3f" % [Piece.TIER_NAMES[tier], observed, odds[tier]])
	check(counts[Piece.Tier.COMMON] > counts[Piece.Tier.UNCOMMON] and counts[Piece.Tier.UNCOMMON] > counts[Piece.Tier.RARE] and counts[Piece.Tier.RARE] > 0, "common > uncommon > rare, and rares do happen")

func test_the_odds_add_up_to_one() -> void:
	var total := 0.0
	for p in Lottery.odds(_run()).values():
		total += p
	check(absf(total - 1.0) < 0.0001, "sum %f" % total)

func test_tiers_with_no_pieces_or_no_weight_are_never_drawn() -> void:
	var weights := { Piece.Tier.COMMON: 1.0, 99: 5.0, Piece.Tier.UNCOMMON: 0.0, Piece.Tier.LEGENDARY: 4.0 }
	check_eq(Lottery.usable_weights(weights), { Piece.Tier.COMMON: 1.0 }, "only common has both pieces and weight")
	var rng := _rng(3)
	for i in 100:
		check_eq(Lottery.roll_tier(weights, rng), Piece.Tier.COMMON, "always common")

# ---- the offer ---------------------------------------------------------------------------------

func test_a_full_tier_is_offered_three_pieces_you_hold_and_two_new_ones() -> void:
	var run := _full_commons()
	check_eq(run.held_types(Piece.Tier.COMMON).size(), 5, "the common slots are full")
	var cards := Lottery.offer(run, Piece.Tier.COMMON, _rng())
	check_eq(cards.size(), CARDS, "five cards")
	check_eq(_kinds(cards, "add").size(), 3, "three you hold")
	check_eq(_kinds(cards, "new").size(), 2, "two replacements")
	for card in _kinds(cards, "add"):
		check(run.held_types(Piece.Tier.COMMON).has(card.type), "%s is one you hold" % Piece.display_name(card.type))
	for card in _kinds(cards, "new"):
		check(not run.held_types(Piece.Tier.COMMON).has(card.type), "%s is new to you" % Piece.display_name(card.type))
		check_eq(Piece.tier(card.type), Piece.Tier.COMMON, "from the same tier")

func test_cards_are_all_different_and_never_boss_or_legendary_pieces() -> void:
	var run := _full_commons()
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE]:
		for seed_value in 20:
			var cards := Lottery.offer(run, tier, _rng(seed_value))
			var unique := {}
			for card in cards:
				unique[card.type] = true
				check(not Piece.is_reward_only(card.type) and Piece.tier(card.type) == tier, "%s belongs in %s" % [Piece.display_name(card.type), Piece.TIER_NAMES[tier]])
			check_eq(unique.size(), cards.size(), "no card twice")

func test_a_tier_with_free_slots_fills_out_with_new_cards() -> void:
	var run := _run()                                   # starts with pawn (common), knight+bishop (uncommon), rook (rare)
	var common := Lottery.offer(run, Piece.Tier.COMMON, _rng())
	check_eq(_kinds(common, "add").size(), 1, "one common type held")
	check_eq(_kinds(common, "new").size(), 4, "so four new ones")
	var uncommon := Lottery.offer(run, Piece.Tier.UNCOMMON, _rng())
	check_eq(_kinds(uncommon, "add").size(), 2, "two uncommon types held")
	check_eq(_kinds(uncommon, "new").size(), 3, "three new")
	var rare := Lottery.offer(run, Piece.Tier.RARE, _rng())
	check_eq(_kinds(rare, "add").size(), 1, "the rook")
	check_eq(_kinds(rare, "new").size(), 4, "four new")
	var empty := RunState.new()
	empty.begin()
	empty.roster.clear()
	check_eq(_kinds(Lottery.offer(empty, Piece.Tier.RARE, _rng()), "new").size(), CARDS, "nothing held: five new cards")

func test_the_offer_is_repeatable_with_a_seed_and_varies_between_seeds() -> void:
	var run := _full_commons()
	check_eq(_types(Lottery.offer(run, Piece.Tier.COMMON, _rng(5))), _types(Lottery.offer(run, Piece.Tier.COMMON, _rng(5))), "same seed, same cards")
	var seen := {}
	for seed_value in 30:
		seen[str(_types(Lottery.offer(run, Piece.Tier.COMMON, _rng(seed_value))))] = true
	check(seen.size() > 5, "different seeds give different offers")

func test_begin_choice_lays_the_offer_out_and_waits() -> void:
	var run := _full_commons()
	check(Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng()), "an offer was made")
	check_eq(run.pending.kind, "cards", "waiting for you")
	check(run.pending.tier == Piece.Tier.COMMON and run.pending.source == "pull" and run.pending.stage == "pick" and run.pending.cards.size() == CARDS, "the details")

# ---- picking ------------------------------------------------------------------------------------

func test_picking_a_piece_you_hold_adds_a_copy() -> void:
	var run := _full_commons()
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	var index: int = run.pending.cards.find_custom(func(c): return c.kind == "add")
	var type: Piece.Type = run.pending.cards[index].type
	var count_before := run.count_of(type)
	var roster_before := run.roster.size()
	var result := Lottery.pick_card(run, index)
	check(result.ok and result.stage == "done" and result.gained == type, "picked")
	check_eq(run.count_of(type), count_before + 1, "one more copy")
	check_eq(run.roster.size(), roster_before + 1, "and nothing else changed")
	check_eq(run.held_types(Piece.Tier.COMMON).size(), 5, "still five types")
	check(run.pending.is_empty(), "the offer is spent")

func test_a_new_piece_takes_a_free_slot() -> void:
	var run := _run()
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	var index: int = run.pending.cards.find_custom(func(c): return c.kind == "new")
	var type: Piece.Type = run.pending.cards[index].type
	var result := Lottery.pick_card(run, index)
	check(result.ok and result.stage == "done", "no replacement needed")
	check_eq(run.count_of(type), 1, "one of the new type")
	check_eq(run.held_types(Piece.Tier.COMMON).size(), 2, "two common types now")
	check_eq(run.count_of(PAWN), 3, "the pawns are untouched")

func test_a_new_piece_in_a_full_tier_must_replace_a_slot_and_keeps_the_number() -> void:
	var run := _full_commons()
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	var index: int = run.pending.cards.find_custom(func(c): return c.kind == "new")
	var incoming: Piece.Type = run.pending.cards[index].type
	var roster_before := run.roster.size()
	var pawn_ids := run.roster.filter(func(e): return e.type == PAWN).map(func(e): return e.id)
	var result := Lottery.pick_card(run, index)
	check(result.ok and result.stage == "replace", "you are asked which slot to give up")
	check_eq(run.roster.size(), roster_before, "nothing has changed yet")
	check_eq(run.pending.stage, "replace", "still pending")
	var replaced := Lottery.pick_replacement(run, PAWN)
	check(replaced.ok and replaced.gained == incoming and replaced.replaced == PAWN, "the pawns are swapped out")
	check_eq(run.count_of(PAWN), 0, "no pawns left")
	check_eq(run.count_of(incoming), 3, "the same number of the new type")
	check_eq(run.roster.size(), roster_before, "the same number of pieces overall")
	for id in pawn_ids:
		check_eq(run.roster_entry(id).type, incoming, "piece %d kept its id and became the new type" % id)
	check_eq(run.held_types(Piece.Tier.COMMON).size(), 5, "still five types")
	check(run.pending.is_empty(), "the offer is spent")

func test_you_can_only_replace_a_type_you_hold() -> void:
	var run := _full_commons()
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	Lottery.pick_card(run, run.pending.cards.find_custom(func(c): return c.kind == "new"))
	var refused := Lottery.pick_replacement(run, Piece.Type.CAMEL)
	check(not refused.ok, "a piece you don't hold can't be swapped out")
	check_eq(run.pending.stage, "replace", "and the choice stays open")

func test_bad_picks_are_refused() -> void:
	var run := _full_commons()
	check(not Lottery.pick_card(run, 0).ok, "no offer, no pick")
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	check(not Lottery.pick_card(run, 9).ok and not Lottery.pick_card(run, -1).ok, "an index outside the offer")
	check(not Lottery.pick_replacement(run, PAWN).ok, "no replacement is due yet")
	check_eq(run.pending.stage, "pick", "the offer is untouched")

func test_the_tier_pools_hold_every_buyable_piece_exactly_once() -> void:
	var union := []
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE]:
		check_eq(Lottery.pool(tier), Piece.types_in_tier(tier).filter(func(t): return not Piece.is_reward_only(t)), "pool for %s" % Piece.TIER_NAMES[tier])
		union.append_array(Lottery.pool(tier))
	union.sort()
	var expected := (Piece.TIERS.keys() + PieceDefs.types()).filter(func(t): return Piece.tier(t) != Piece.Tier.LEGENDARY)
	expected.sort()
	check_eq(union, expected, "every non-legendary piece is in exactly one pool")

func test_a_new_run_starts_with_a_clean_slate() -> void:
	var run := _run()
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	run.unlocked_legendaries.append(Piece.Type.DRAGON)
	run.begin()
	check(run.pending.is_empty() and run.unlocked_legendaries.is_empty(), "nothing carries over")
