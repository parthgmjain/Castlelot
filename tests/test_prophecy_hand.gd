extends "res://tests/TestCase.gd"
## Carrying prophecies: buying, the hand limit, discarding, arming and carrying on.

func _run(gold: int = 100) -> RunState:
	var run := RunState.new()
	run.begin()
	run.currency = gold
	return run

func _offer(run: RunState, ids: Array) -> void:
	run.prophecy_offers = ids.duplicate()

func test_buying_a_card_costs_its_price_and_puts_it_in_your_hand() -> void:
	var run := _run(50)
	_offer(run, ["rising_tide", "omen_of_plunder", "chain_of_fate", "final_blow"])
	var result := Prophecies.buy(run, 1)
	check(result.ok and result.id == "omen_of_plunder", "bought")
	check_eq(run.currency, 50 - Prophecies.price("omen_of_plunder"), "gold spent")
	check_eq(run.hand, [{ "id": "omen_of_plunder", "armed": false }], "in your hand, not armed")
	check_eq(run.prophecy_offers[1], "", "the slot is sold")
	check_eq(run.prophecy_offers[0], "rising_tide", "the others are still for sale")
	check(not Prophecies.buy(run, 1).ok, "a sold card can't be bought again")

func test_you_cannot_buy_what_you_cannot_afford() -> void:
	var run := _run(3)
	_offer(run, ["omen_of_plunder"])
	var result := Prophecies.buy(run, 0)
	check(not result.ok and result.reason.begins_with("Not enough gold"), result.reason)
	check_eq(run.currency, 3, "nothing spent")
	check(run.hand.is_empty() and run.prophecy_offers[0] == "omen_of_plunder", "and nothing changed")

func test_you_can_carry_three_and_must_discard_to_buy_more() -> void:
	var run := _run(500)
	_offer(run, ["rising_tide", "blood_moon", "song_of_the_small", "giant_slayer"])
	for slot in 3:
		check(Prophecies.buy(run, slot).ok, "card %d fits" % (slot + 1))
	check_eq(run.hand.size(), RunConfig.HAND_SIZE, "a full hand")
	var gold := run.currency
	var refused := Prophecies.buy(run, 3)
	check(not refused.ok and refused.reason.contains("discard"), refused.reason)
	check_eq(run.currency, gold, "and it costs nothing")
	check_eq(run.prophecy_offers[3], "giant_slayer", "the card is still for sale")
	check(Prophecies.discard(run, 0).ok, "discarding one...")
	check_eq(run.hand.size(), 2, "makes room")
	check(Prophecies.buy(run, 3).ok, "and now you can buy")
	check_eq(run.hand.map(func(h): return h.id), ["blood_moon", "song_of_the_small", "giant_slayer"], "the discarded card is gone")

func test_discarding_a_card_that_isnt_there_is_refused() -> void:
	var run := _run()
	check(not Prophecies.discard(run, 0).ok and not Prophecies.discard(run, -1).ok, "nothing to discard")

func test_only_armed_cards_can_be_armed() -> void:
	var run := _run()
	run.hand = [{ "id": "final_blow", "armed": false }, { "id": "rising_tide", "armed": false }]
	check(Prophecies.set_armed(run, 0, true).ok, "final blow arms")
	check(run.hand[0].armed, "and is armed")
	check(Prophecies.set_armed(run, 0, false).ok and not run.hand[0].armed, "and disarms")
	var refused := Prophecies.set_armed(run, 1, true)
	check(not refused.ok and not run.hand[1].armed, "a played card can't be armed")
	check(not Prophecies.set_armed(run, 5, true).ok, "no such card")

func test_unused_cards_carry_from_match_to_match_but_not_into_a_new_run() -> void:
	var run := _run()
	run.hand = [{ "id": "rising_tide", "armed": false }, { "id": "final_blow", "armed": true }]
	run.advance()
	run.advance()
	run.advance()
	check_eq(run.hand.size(), 2, "still holding both after three matches")
	check(run.hand[1].armed, "and the armed one is still armed")
	run.begin()
	check(run.hand.is_empty() and run.prophecy_offers.is_empty() and run.shop_effects.is_empty(), "a new run starts empty-handed")

func test_each_shop_visit_deals_a_fresh_set_of_offers() -> void:
	var run := _run()
	Prophecies.refresh_offers(run)
	check_eq(run.prophecy_offers.size(), RunConfig.PROPHECY_OFFERS, "four for sale")
	var seen := {}
	for i in 30:
		Prophecies.refresh_offers(run)
		seen[str(run.prophecy_offers)] = true
	check(seen.size() > 5, "the offers vary from visit to visit")
