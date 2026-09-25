extends "res://tests/TestCase.gd"
## Prophecies through the real screens: the shop's offers and hand, and the hand strip.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# Wins the first match and stands in the shop with `gold`.
func _to_shop(main: Node, gold: int = 100) -> ShopScreen:
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	main.state.run.currency = gold
	main.shop_screen.refresh()
	return main.shop_screen

func _offers(shop: ShopScreen) -> Array:
	return shop.cards_row.get_child(0).get_child(1).get_children()

# The rows of cards you hold, each a VBox of [title, description, buttons].
func _hand_rows(shop: ShopScreen) -> Array:
	return shop.cards_row.get_child(1).get_children().filter(func(c): return c is VBoxContainer)

func _row_buttons(row: Node) -> Array:
	return row.get_child(2).get_children()

func _button(row: Node, text: String) -> Button:
	var found := _row_buttons(row).filter(func(b): return b.text == text)
	return found[0] if not found.is_empty() else null

func _stock(shop: ShopScreen, ids: Array) -> void:
	shop._run.prophecy_offers = ids.duplicate()
	shop.refresh()

# ---- the shop ----------------------------------------------------------------------------------

func test_the_shop_sells_four_prophecies_with_their_rarity_and_price() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var offers := _offers(shop)
	check_eq(offers.size(), 4, "four for sale")
	for i in offers.size():
		var id: String = main.state.run.prophecy_offers[i]
		check(offers[i].text.contains(ProphecyDefs.display_name(id)) and offers[i].text.contains("%d gold" % Prophecies.price(id)) and offers[i].text.contains(Piece.TIER_NAMES[ProphecyDefs.rarity(id)]), offers[i].text)
	check(shop.cards_row.get_child(1).get_child(0).text == "Your hand (0/3)", "an empty hand")

func test_buying_a_prophecy_puts_it_in_your_hand() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	_stock(shop, ["omen_of_plunder", "rising_tide", "final_blow", "purse_of_gold"])
	_offers(shop)[0].pressed.emit()
	check_eq(main.state.run.currency, 50 - Prophecies.price("omen_of_plunder"), "gold spent")
	check_eq(shop.gold_label.text, "Gold: %d" % main.state.run.currency, "and shown")
	check_eq(_offers(shop)[0].text, "Sold", "the slot is sold")
	check(_offers(shop)[0].disabled, "and can't be bought again")
	check_eq(_hand_rows(shop).size(), 1, "one card in your hand")
	check(_hand_rows(shop)[0].get_child(0).text.begins_with("Omen of Plunder"), _hand_rows(shop)[0].get_child(0).text)
	check_eq(shop.cards_row.get_child(1).get_child(0).text, "Your hand (1/3)", "the count")
	check(shop.message_label.text.begins_with("Bought Omen of Plunder"), shop.message_label.text)

func test_you_cannot_afford_what_costs_too_much() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 5)
	_stock(shop, ["omen_of_plunder", "rising_tide", "final_blow", "purse_of_gold"])
	check(_offers(shop)[0].disabled and _offers(shop)[2].disabled, "the 8 and 30 gold cards are greyed out")
	check(not _offers(shop)[1].disabled and not _offers(shop)[3].disabled, "the 4 gold ones are not")

func test_a_full_hand_asks_you_to_discard_first() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 500)
	_stock(shop, ["rising_tide", "blood_moon", "song_of_the_small", "giant_slayer"])
	for i in 3:
		_offers(shop)[i].pressed.emit()
	check_eq(_hand_rows(shop).size(), 3, "a full hand")
	var gold: int = main.state.run.currency
	_offers(shop)[3].pressed.emit()
	check(shop.message_label.text.contains("discard"), shop.message_label.text)
	check_eq(main.state.run.currency, gold, "nothing was bought")
	check_eq(_hand_rows(shop).size(), 3, "still three")
	_button(_hand_rows(shop)[0], "Discard").pressed.emit()
	check_eq(_hand_rows(shop).size(), 2, "discarded one")
	_offers(shop)[3].pressed.emit()
	check_eq(_hand_rows(shop).size(), 3, "now the new one fits")

func test_a_shop_card_is_played_from_the_hand() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 20)
	main.state.run.hand.append({ "id": "purse_of_gold", "armed": false })
	shop.refresh()
	_button(_hand_rows(shop)[0], "Play").pressed.emit()
	check_eq(main.state.run.currency, 32, "+12 gold")
	check(main.state.run.hand.is_empty(), "the card is used up")
	check(shop.message_label.text.contains("+12 gold"), shop.message_label.text)
	check_eq(main.panel.wallet_label.text, "Gold: 32", "the wallet follows")

func test_match_cards_have_no_play_button_in_the_shop() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	main.state.run.hand.append({ "id": "rising_tide", "armed": false })
	shop.refresh()
	check_eq(_row_buttons(_hand_rows(shop)[0]).map(func(b): return b.text), ["Discard"], "only discard")
	check(_hand_rows(shop)[0].get_child(0).text.contains("played in a match"), "and the row says when it is played")

func test_armed_cards_can_be_armed_and_disarmed_in_the_shop() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	main.state.run.hand.append({ "id": "final_blow", "armed": false })
	shop.refresh()
	_button(_hand_rows(shop)[0], "Arm").pressed.emit()
	check(main.state.run.hand[0].armed, "armed")
	check(_hand_rows(shop)[0].get_child(0).text.contains("[ARMED]"), "and it says so")
	_button(_hand_rows(shop)[0], "Disarm").pressed.emit()
	check(not main.state.run.hand[0].armed, "disarmed")

func test_second_sight_can_be_played_while_choosing_and_rerolls_the_cards() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 100)
	main.state.run.hand.append({ "id": "second_sight", "armed": false })
	shop.refresh()
	shop.pull_button.pressed.emit()
	check(shop.is_busy() and shop.choice_box.visible, "cards on the table")
	var before: Array = main.state.run.pending.cards.map(func(c): return c.type)
	var play := _button(_hand_rows(shop)[0], "Play")
	check(not play.disabled, "Second Sight is playable while you're choosing")
	check(_button(_hand_rows(shop)[0], "Discard").disabled, "but you can't discard")
	play.pressed.emit()
	check(main.state.run.pending.cards.size() == before.size(), "the same number of cards")
	check(main.state.run.hand.is_empty(), "the card is used")
	check(shop.message_label.text.contains("dealt again"), shop.message_label.text)

func test_merlins_bargain_lets_you_pick_a_piece_or_keep_them_all() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 10)
	main.state.run.hand.append({ "id": "merlins_bargain", "armed": false })
	shop.refresh()
	_button(_hand_rows(shop)[0], "Play").pressed.emit()
	check(shop.choice_box.visible and shop.choice_prompt.text.contains("Merlin"), shop.choice_prompt.text)
	var buttons := shop.choice_row.get_children().filter(func(c): return c is Button)
	check_eq(buttons.size(), main.state.run.roster.size() + 1, "one button per piece plus a way out")
	check(shop.leave_button.disabled, "you have to decide first")
	buttons.back().pressed.emit()
	check(not shop.choice_box.visible and main.state.run.hand.size() == 1, "cancelled and you keep the card")
	_button(_hand_rows(shop)[0], "Play").pressed.emit()
	var rook_button: Button = shop.choice_row.get_children().filter(func(c): return c is Button and c.text.begins_with("Rook"))[0]
	var roster_before: int = main.state.run.roster.size()
	rook_button.pressed.emit()
	check_eq(main.state.run.currency, 10 + Piece.value(ROOK) * 3, "the rook was sold for 15 gold")
	check_eq(main.state.run.roster.size(), roster_before - 1, "and is gone")
	check(main.state.run.hand.is_empty(), "the card is used")

func test_hagglers_charm_halves_the_upgrade_buttons_until_you_leave() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 100)
	main.state.run.hand.append({ "id": "hagglers_charm", "armed": false })
	shop.refresh()
	check(shop.points_upgrade_button.text.ends_with("- 10 gold"), shop.points_upgrade_button.text)
	_button(_hand_rows(shop)[0], "Play").pressed.emit()
	check(shop.points_upgrade_button.text.ends_with("- 5 gold"), shop.points_upgrade_button.text)
	check(shop.zone_upgrade_button.text.ends_with("- 4 gold"), shop.zone_upgrade_button.text)
	shop.leave_button.pressed.emit()
	check(not main.state.run.shop_effects.has("haggle"), "the discount ended with the visit")

func test_lucky_draw_shows_a_free_pull() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 20)
	main.state.run.hand.append({ "id": "lucky_draw", "armed": false })
	shop.refresh()
	_button(_hand_rows(shop)[0], "Play").pressed.emit()
	check_eq(shop.pull_button.text, "Lottery Pull - 0 gold", shop.pull_button.text)
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.currency, 20, "nothing was paid")

func test_each_shop_visit_has_fresh_offers_but_your_hand_carries_on() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 500)
	_stock(shop, ["rising_tide", "blood_moon", "song_of_the_small", "giant_slayer"])
	_offers(shop)[0].pressed.emit()
	var hand_before: Array = main.state.run.hand.duplicate(true)
	shop.leave_button.pressed.emit()
	shop.open(main.state.run, "next")
	check_eq(main.state.run.hand, hand_before, "you still hold the card")
	check(main.state.run.prophecy_offers.all(func(id): return id != ""), "and the shop dealt a full new set")

# ---- the hand strip -------------------------------------------------------------------------------

func _strip_rows(main: Node) -> Array:
	return main.prophecy_strip.get_child(0).get_child(1).get_children()

func _strip_button(main: Node, row: int, text: String) -> Button:
	var found := _row_buttons(_strip_rows(main)[row]).filter(func(b): return b.text == text)
	return found[0] if not found.is_empty() else null

# A running match on a closed board with `pieces`, and `cards` in your hand.
func _match(pieces: Array, cards: Array) -> Dictionary:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.grid_width = 8                        # a run deals boards of random sizes; these tests want a fixed 8x8
	board.grid_height = 8
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	for p in pieces:
		put(board, p[0], p[1], p[2])
	for id in cards:
		main.state.run.hand.append({ "id": id, "armed": false })
	main.turn_flow.ai_delay = 5.0
	main.panel.ready_button.pressed.emit()
	main._refresh_view()
	return { "main": main, "board": board, "state": main.state, "match": main.state.current_match }

func test_the_strip_is_hidden_without_a_run_or_a_hand() -> void:
	var main = await load_main()
	check(not main.prophecy_strip.visible, "no run")
	main.panel.start_run_button.pressed.emit()
	check(not main.prophecy_strip.visible, "a run but nothing in hand")
	main.state.run.hand.append({ "id": "rising_tide", "armed": false })
	main._refresh_view()
	check(main.prophecy_strip.visible, "a card in hand")
	check_eq(_strip_rows(main).size(), 1, "one row")

func test_playing_a_match_card_from_the_strip() -> void:
	var g := await _match([[V(0, 7), ROOK, WHITE], [V(0, 4), PAWN, BLACK]], ["rising_tide"])
	var play := _strip_button(g.main, 0, "Play")
	check(play != null and not play.disabled, "Play is available on your turn")
	play.pressed.emit()
	check(g.state.run.hand.is_empty(), "the card is used")
	check_eq(g.match.prophecies.size(), 1, "the effect is working")
	check(not g.main.prophecy_strip.visible, "and the empty strip hides")
	g.main._on_square_selected(V(0, 7), g.board)
	g.main._on_square_selected(V(0, 4), g.board)
	check_eq(g.match.scores[WHITE], 20, "the capture scored 10 + 10")

func test_play_is_disabled_on_the_ais_turn() -> void:
	var g := await _match([], ["rising_tide"])
	g.match.turn_side = BLACK
	g.main._refresh_view()
	check(_strip_button(g.main, 0, "Play").disabled, "wait for your turn")

func test_blessing_of_the_blade_asks_which_piece_type_from_the_strip() -> void:
	var g := await _match([[V(3, 4), KNIGHT, WHITE], [V(4, 2), PAWN, BLACK]], ["blessing_of_the_blade"])
	_strip_button(g.main, 0, "Play").pressed.emit()
	check(g.main.prophecy_strip.is_choosing(), "it asks which type")
	check_eq(g.state.run.hand.size(), 1, "the card isn't used yet")
	var choices: Array = g.main.prophecy_strip._choice_row.get_children().filter(func(c): return c is Button)
	check(choices.map(func(b): return b.text).has("Knight"), "your knight is an option: %s" % str(choices.map(func(b): return b.text)))
	choices.filter(func(b): return b.text == "Knight")[0].pressed.emit()
	check(g.state.run.hand.is_empty() and not g.main.prophecy_strip.is_choosing(), "chosen and used")
	g.main._on_square_selected(V(3, 4), g.board)
	g.main._on_square_selected(V(4, 2), g.board)
	check_eq(g.match.scores[WHITE], 15, "the knight's capture was blessed")

func test_armed_cards_are_armed_from_the_strip_before_the_match_only() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "final_blow", "armed": false })
	main._refresh_view()
	check(main.state.deployment.active, "still deploying")
	var arm := _strip_button(main, 0, "Arm")
	check(arm != null and not arm.disabled, "you can arm it now")
	arm.pressed.emit()
	check(main.state.run.hand[0].armed, "armed")
	check(_strip_button(main, 0, "Disarm") != null, "and the button flips")
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	check(_strip_button(main, 0, "Disarm").disabled, "once the match starts it can't be changed")
	check_eq(main.state.current_match.prophecies.size(), 1, "and the armed card is working")

func test_a_card_can_be_discarded_from_the_strip() -> void:
	var g := await _match([], ["rising_tide", "blood_moon"])
	_strip_button(g.main, 0, "Discard").pressed.emit()
	check_eq(g.state.run.hand.map(func(h): return h.id), ["blood_moon"], "the first was discarded")
	check_eq(_strip_rows(g.main).size(), 1, "and the strip shows one row")

func test_the_strip_says_why_a_card_cannot_be_played() -> void:
	var g := await _match([], ["rising_tide"])
	g.match.turn_side = BLACK
	g.main.prophecy_flow.play(0)
	check(g.main.prophecy_strip._message.text.contains("your turn"), g.main.prophecy_strip._message.text)

# ---- payout ------------------------------------------------------------------------------------------

func test_an_armed_golden_tithe_raises_the_payout_and_is_used_up() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "golden_tithe", "armed": true })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	var expected := Payout.calculate(current, main.state.run.currency)
	main._refresh_view()
	var bonus := int(round(expected.total * 0.5))
	check_eq(main.state.run.currency, expected.total + bonus, "the payout was x1.5")
	check(main.result_screen.details_label.text.contains("Golden Tithe: +%d gold" % bonus), main.result_screen.details_label.text)
	check(main.state.run.hand.is_empty(), "the card is used up")

func test_an_unarmed_golden_tithe_does_nothing() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "golden_tithe", "armed": false })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	var expected := Payout.calculate(current, main.state.run.currency)
	main._refresh_view()
	check_eq(main.state.run.currency, expected.total, "an ordinary payout")
	check_eq(main.state.run.hand.size(), 1, "and you still hold the card")
