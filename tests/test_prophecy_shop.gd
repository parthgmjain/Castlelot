extends "res://tests/TestCase.gd"
## The shop prophecies: what each one does to the lottery, trade-ups and upgrades.

func _run(gold: int = 100) -> RunState:
	var run := RunState.new()
	run.begin()
	run.currency = gold
	return run

func _hold(run: RunState, id: String, armed: bool = false) -> int:
	run.hand.append({ "id": id, "armed": armed })
	return run.hand.size() - 1

func _play(run: RunState, id: String) -> Dictionary:
	return Prophecies.play_in_shop(run, _hold(run, id))

func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _give(run: RunState, type: Piece.Type, count: int) -> Array:
	var ids: Array = []
	for i in count:
		ids.append(run.add_to_roster(type))
	return ids

# ---- gold -------------------------------------------------------------------------------------

func test_purse_of_gold_gives_twelve_gold_and_is_used_up() -> void:
	var run := _run(10)
	var result := _play(run, "purse_of_gold")
	check(result.ok, "played")
	check_eq(run.currency, 22, "+12 gold")
	check(run.hand.is_empty(), "the card is used up")

# ---- the lottery -------------------------------------------------------------------------------

func test_lucky_draw_makes_the_next_pull_free_and_only_that_one() -> void:
	var run := _run(50)
	check(_play(run, "lucky_draw").ok, "played")
	check_eq(Lottery.price(run), 0, "the pull is free")
	var started := Lottery.start_pull(run, _rng())
	check(started.ok, "the pull works")
	check_eq(run.currency, 50, "and costs nothing")
	check_eq(run.pulls_made, 0, "a free pull doesn't make the next one dearer")
	check_eq(Lottery.price(run), RunConfig.PULL_PRICE_BASE, "the next pull costs the usual")
	Lottery.start_pull(run, _rng())
	check_eq(run.currency, 50 - RunConfig.PULL_PRICE_BASE, "and is paid for")

func test_lucky_draw_cannot_be_stacked() -> void:
	var run := _run()
	_play(run, "lucky_draw")
	var index := _hold(run, "lucky_draw")
	var second := Prophecies.play_in_shop(run, index)
	check(not second.ok, "one free pull at a time")
	check_eq(run.hand.size(), 1, "and the second card is not wasted")

func test_loaded_dice_make_the_next_pull_at_least_uncommon_once() -> void:
	var run := _run(10000000)                     # pulls get dearer each time, so plenty for 300 of them
	var rng := _rng(5)
	var commons := 0
	for i in 200:
		var r := _run(10000)
		check(_play(r, "loaded_dice").ok, "played")
		var tier: Piece.Tier = Lottery.start_pull(r, rng).tier
		check(tier != Piece.Tier.COMMON, "never common with loaded dice")
		if failures.size() > 3:
			break
	for i in 300:
		if Lottery.start_pull(run, rng).tier == Piece.Tier.COMMON:
			commons += 1
	check(commons > 0, "and the dice only affect one pull: ordinary pulls still give commons")
	var again := _run()
	_play(again, "loaded_dice")
	Lottery.start_pull(again, rng)
	check(not again.shop_effects.has("min_tier"), "the dice are used up")

func test_wider_net_shows_seven_cards_once() -> void:
	var run := _run()
	check(_play(run, "wider_net").ok, "played")
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	check_eq(run.pending.cards.size(), 7, "seven cards")
	check(run.pending.cards.map(func(c): return c.type).size() == 7, "seven cards")
	run.pending = {}
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	check_eq(run.pending.cards.size(), 5, "back to five for the next offer")

func test_wider_net_keeps_three_owned_cards_and_adds_new_ones() -> void:
	var run := _run()
	for type in [Piece.Type.SCOUT, Piece.Type.SERF, Piece.Type.CRAB]:
		run.add_to_roster(type)
	_play(run, "wider_net")
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull", _rng())
	check_eq(run.pending.cards.filter(func(c): return c.kind == "add").size(), 3, "three you hold")
	check_eq(run.pending.cards.filter(func(c): return c.kind == "new").size(), 4, "four new")

func test_second_sight_deals_the_cards_again() -> void:
	var run := _run()
	Lottery.begin_choice(run, Piece.Tier.UNCOMMON, "pull", _rng(3))
	var before: Array = run.pending.cards.map(func(c): return c.type)
	var index := _hold(run, "second_sight")
	var result := Prophecies.play_in_shop(run, index, _rng(99))
	check(result.ok, "played")
	check_eq(run.pending.cards.size(), before.size(), "the same number of cards")
	check(run.pending.cards.map(func(c): return c.type) != before, "a different deal")
	check(run.hand.is_empty(), "the card is used up")
	check_eq(run.pending.stage, "pick", "still your choice")

func test_second_sight_needs_an_offer_in_front_of_you() -> void:
	var run := _run()
	var index := _hold(run, "second_sight")
	var result := Prophecies.play_in_shop(run, index)
	check(not result.ok and result.reason.contains("choosing from an offer"), result.reason)
	check_eq(run.hand.size(), 1, "and you keep the card")

# ---- trading up ---------------------------------------------------------------------------------

func test_fair_trade_takes_two_off_the_next_trade_up_only() -> void:
	var run := _run()
	_play(run, "fair_trade")
	check_eq(Shop.trade_up_cost(Piece.Tier.COMMON, run), 3, "five commons -> three")
	check_eq(Shop.trade_up_cost(Piece.Tier.RARE, run), 5, "seven rares -> five")
	check_eq(Shop.trade_up_cost(Piece.Tier.COMMON), 5, "the base price is unchanged")
	var ids := _give(run, PAWN, 3)
	var check := Shop.check_trade_up(run, ids)
	check(check.ok and check.count == 3, "three pawns are enough now")
	check(Shop.trade_up(run, ids).ok, "traded")
	check_eq(Shop.trade_up_cost(Piece.Tier.COMMON, run), 5, "and it is back to five afterwards")

func test_queens_favor_only_helps_the_rare_to_legendary_upgrade() -> void:
	var run := _run()
	_play(run, "queens_favor")
	check_eq(Shop.trade_up_cost(Piece.Tier.RARE, run), 5, "rares cost five")
	check_eq(Shop.trade_up_cost(Piece.Tier.COMMON, run), 5, "commons are unchanged")
	Shop.trade_up(run, _give(run, PAWN, 5))
	check(run.shop_effects.get("queens_favor", false), "a common trade-up doesn't use it up")
	run.pending = {}
	var rares := _give(run, ROOK, 5)
	var result := Shop.trade_up(run, rares)
	check(result.ok and result.to == Piece.Tier.LEGENDARY, "five rares reach a legendary")
	check(not run.shop_effects.has("queens_favor"), "and the favour is spent")

func test_fair_trade_and_queens_favor_stack() -> void:
	var run := _run()
	_play(run, "fair_trade")
	_play(run, "queens_favor")
	check_eq(Shop.trade_up_cost(Piece.Tier.RARE, run), 3, "7 - 2 - 2")

# ---- upgrades -------------------------------------------------------------------------------------

func test_hagglers_charm_halves_upgrade_prices_until_you_leave() -> void:
	var run := _run(100)
	var points_price := Shop.points_upgrade_price(run)
	var zone_price := Shop.zone_upgrade_price(run)
	_play(run, "hagglers_charm")
	check_eq(Shop.points_upgrade_price(run), int(ceil(points_price / 2.0)), "points half price")
	check_eq(Shop.zone_upgrade_price(run), int(ceil(zone_price / 2.0)), "zone half price")
	var gold := run.currency
	check(Shop.buy_points(run), "bought")
	check_eq(gold - run.currency, int(ceil(points_price / 2.0)), "and you paid half")
	Prophecies.end_shop(run)
	check_eq(Shop.zone_upgrade_price(run), zone_price, "the discount ends with the shop visit")

# ---- legendaries -----------------------------------------------------------------------------------

func test_unsealed_tomb_unlocks_a_boss_legendary_for_upgrades() -> void:
	var run := _run()
	var result := Prophecies.play_in_shop(run, _hold(run, "unsealed_tomb"), _rng(4))
	check(result.ok, "played")
	check_eq(run.unlocked_legendaries.size(), 1, "one unlocked")
	check(RunConfig.BOSSES.has(run.unlocked_legendaries[0]), "a boss piece")
	check(Legendaries.available_upgrades(run).has(run.unlocked_legendaries[0]), "and you can upgrade into it")
	check(result.note.contains(Piece.display_name(run.unlocked_legendaries[0])), result.note)

func test_unsealed_tomb_never_repeats_and_runs_out() -> void:
	var run := _run()
	for i in RunConfig.BOSSES.size():
		check(Prophecies.play_in_shop(run, _hold(run, "unsealed_tomb"), _rng(i)).ok, "unlock %d" % (i + 1))
		run.hand.clear()
	check_eq(run.unlocked_legendaries.size(), RunConfig.BOSSES.size(), "all twelve, each once")
	var index := _hold(run, "unsealed_tomb")
	var refused := Prophecies.play_in_shop(run, index)
	check(not refused.ok and refused.reason.contains("already unlocked"), refused.reason)
	check_eq(run.hand.size(), 1, "you keep the card")

# ---- Merlin's Bargain -------------------------------------------------------------------------------

func test_merlins_bargain_trades_a_piece_for_three_times_its_points() -> void:
	var run := _run(10)
	var index := _hold(run, "merlins_bargain")
	var result := Prophecies.play_in_shop(run, index)
	check(result.ok and result.waiting, "it waits for your choice")
	check_eq(run.pending.kind, "bargain", "pending")
	check_eq(run.hand.size(), 1, "the card isn't used up yet")
	var rook: int = run.roster.filter(func(e): return e.type == ROOK)[0].id
	var roster_before := run.roster.size()
	var done := Prophecies.resolve_bargain(run, rook)
	check(done.ok and done.gold == Piece.value(ROOK) * 3, "the rook fetches 15 gold")
	check_eq(run.currency, 10 + Piece.value(ROOK) * 3, "paid")
	check_eq(run.roster.size(), roster_before - 1, "the rook is gone")
	check(run.hand.is_empty() and run.pending.is_empty(), "the card is used and the choice is over")

func test_merlins_bargain_can_be_cancelled_and_only_takes_your_pieces() -> void:
	var run := _run()
	Prophecies.play_in_shop(run, _hold(run, "merlins_bargain"))
	check(not Prophecies.resolve_bargain(run, 9999).ok, "not a piece you own")
	check_eq(run.pending.kind, "bargain", "still waiting")
	Prophecies.cancel_bargain(run)
	check(run.pending.is_empty() and run.hand.size() == 1, "cancelled: nothing lost, you keep the card")
	check(not Prophecies.resolve_bargain(run, run.roster[0].id).ok, "and nothing to resolve any more")
	check(run.roster.all(func(e): return e.type != KING), "the king is never in your roster, so it can't be sold")

# ---- guards ------------------------------------------------------------------------------------------

func test_other_cards_cannot_be_played_in_the_shop() -> void:
	var run := _run()
	for id in ["rising_tide", "final_blow", "golden_tithe"]:
		var index := _hold(run, id)
		var result := Prophecies.play_in_shop(run, index)
		check(not result.ok, "%s can't be played here: %s" % [id, result.reason])
	check_eq(run.hand.size(), 3, "and none were used up")
	check(not Prophecies.play_in_shop(run, 9).ok, "no such card")
