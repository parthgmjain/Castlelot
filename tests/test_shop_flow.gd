extends "res://tests/TestCase.gd"
## The shop screen between matches, through the real UI.

func _begin_run(main: Node) -> void:
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

# Wins the current match, presses Next Match, and leaves you standing in the shop.
func _to_shop(main: Node, gold: int = -1) -> ShopScreen:
	_begin_run(main)
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	if gold >= 0:
		main.state.run.currency = gold
		main.shop_screen.refresh()
	return main.shop_screen

# The piece buttons in one tier's row (0 = common, 1 = uncommon, 2 = rare, 3 = legendary).
func _row(shop: ShopScreen, tier_index: int) -> Array:
	return shop.roster_box.get_child(tier_index).get_children().filter(func(c): return c is Button)

func _row_label(shop: ShopScreen, tier_index: int) -> String:
	return shop.roster_box.get_child(tier_index).get_child(0).text

# The buttons of the choice on offer (cards, replacement slots or legendaries).
func _choices(shop: ShopScreen) -> Array:
	return shop.choice_row.get_children().filter(func(c): return c is Button)

# Makes whatever choice is waiting, always taking the first button, until nothing is left to decide.
func _resolve(shop: ShopScreen) -> void:
	for i in 4:
		if not shop.is_busy():
			return
		_choices(shop)[0].pressed.emit()

func test_the_shop_opens_after_a_win_and_shows_everything() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	check(not main.shop_screen.visible, "no shop before the first match")
	var shop := _to_shop(main)
	check(shop.visible, "the shop is open")
	check(shop.title_label.text.contains("Round 1/12 - Match 2/3"), shop.title_label.text)
	check_eq(shop.gold_label.text, "Gold: %d" % main.state.run.currency, "gold shown")
	check_eq(_row(shop, 0).size(), 3, "three pawns in the common row")
	check_eq(_row(shop, 1).size(), 2, "knight and bishop in the uncommon row")
	check_eq(_row(shop, 2).size(), 1, "the rook is rare")
	check_eq(_row(shop, 3).size(), 0, "no legendary pieces yet")
	check(_row_label(shop, 0).contains("Common (1/5 types)"), _row_label(shop, 0))
	check(_row_label(shop, 1).contains("Uncommon (2/5 types)"), _row_label(shop, 1))
	check(_row_label(shop, 2).contains("Rare (1/3 types)"), _row_label(shop, 2))
	check(_row_label(shop, 3).contains("Legendary (0/2 types)"), _row_label(shop, 3))
	check(_row(shop, 2)[0].text.contains("Rook (5)"), "each piece shows what it costs: %s" % _row(shop, 2)[0].text)
	check_eq(shop.pull_button.text, "Lottery Pull - %d gold" % RunConfig.PULL_PRICE_BASE, "the lottery button")
	var odds := Lottery.odds(main.state.run)
	for tier in odds:
		var shown := "%s %d%%" % [Piece.TIER_NAMES[tier], roundi(odds[tier] * 100.0)]
		check(shop.odds_label.text.contains(shown), "odds label shows '%s': %s" % [shown, shop.odds_label.text])
	check(not shop.odds_label.text.contains("Legendary"), "legendaries aren't drawn")
	check(not shop.choice_box.visible, "no choice waiting")
	check(shop.points_upgrade_button.text.begins_with("Allocated points 14 -> 16"), shop.points_upgrade_button.text)
	check(shop.zone_upgrade_button.text.begins_with("Zone size 10 -> 11"), shop.zone_upgrade_button.text)
	check_eq(shop.cards_row.get_child(0).get_child(1).get_child_count(), RunConfig.PROPHECY_OFFERS, "prophecies are for sale")
	check_eq(shop.leave_button.text, "Next Match", "leave button")

func test_a_pull_pays_then_shows_five_cards_and_the_shop_waits_for_your_pick() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.pull_button.pressed.emit()
	var run: RunState = main.state.run
	check_eq(run.currency, 50 - RunConfig.PULL_PRICE_BASE, "gold spent")
	check_eq(run.roster.size(), 6, "no piece yet")
	check(shop.choice_box.visible, "the cards are on the table")
	check_eq(_choices(shop).size(), 5, "five cards")
	check(shop.choice_prompt.text.begins_with("Choose one of these"), shop.choice_prompt.text)
	check(shop.pull_button.disabled and shop.trade_up_button.disabled and shop.points_upgrade_button.disabled and shop.zone_upgrade_button.disabled and shop.leave_button.disabled, "everything else waits")
	check_eq(shop.gold_label.text, "Gold: %d" % run.currency, "shop gold updated")
	check_eq(main.panel.wallet_label.text, "Gold: %d" % run.currency, "and the main wallet label")
	var texts := _choices(shop).map(func(b): return b.text)
	check(texts.any(func(t): return t.begins_with("+1 ")) and texts.any(func(t): return t.begins_with("NEW: ")), "some cards add a copy and some are new: %s" % str(texts))
	_choices(shop)[0].pressed.emit()
	check_eq(run.roster.size(), 7, "the piece you chose joined your roster")
	check(not shop.choice_box.visible and not shop.is_busy(), "the choice is gone")
	check(not shop.pull_button.disabled and not shop.leave_button.disabled, "and the shop is usable again")
	check(shop.pull_button.text.contains("%d gold" % (RunConfig.PULL_PRICE_BASE + RunConfig.PULL_PRICE_STEP)), "the next pull costs more: %s" % shop.pull_button.text)
	check(shop.message_label.text.begins_with("You now hold"), shop.message_label.text)

func test_the_tier_is_revealed_before_the_cards() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.reveal_delay = 0.3
	shop.pull_button.pressed.emit()
	check(shop.message_label.text.begins_with("You drew a ") and shop.message_label.text.ends_with(" piece..."), "step 1: the tier is shown: %s" % shop.message_label.text)
	check(shop.message_label.has_theme_color_override("font_color"), "tinted with the tier's color")
	check(not shop.choice_box.visible and main.state.run.pending.is_empty(), "but no cards yet")
	check_eq(main.state.run.currency, 50 - RunConfig.PULL_PRICE_BASE, "the pull is already paid for")
	check(shop.pull_button.disabled and shop.trade_up_button.disabled and shop.leave_button.disabled, "everything waits for the reveal")
	await main.get_tree().create_timer(0.5).timeout
	check(shop.choice_box.visible and _choices(shop).size() == 5, "step 2: the five cards appear")
	check(shop.message_label.text.ends_with("! Pick a card."), shop.message_label.text)

func test_leaving_during_the_reveal_shows_the_cards_instead_of_losing_the_pull() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.reveal_delay = 0.3
	shop.pull_button.pressed.emit()
	shop.leave_button.pressed.emit()
	check(shop.visible and shop.choice_box.visible, "the shop stays open with the cards showing")
	check(not main.state.deployment.active, "you haven't moved on")
	await main.get_tree().create_timer(0.5).timeout
	check_eq(_choices(shop).size(), 5, "and the late timer doesn't deal a second offer")
	check_eq(main.state.run.pulls_made, 1, "one pull")

func test_you_cannot_leave_until_you_have_chosen() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.pull_button.pressed.emit()
	shop.leave_button.pressed.emit()
	check(shop.visible and not main.state.deployment.active, "still in the shop")
	check_eq(shop.message_label.text, "Make your choice first.", "and it says why")
	_resolve(shop)
	shop.leave_button.pressed.emit()
	check(not shop.visible and main.state.deployment.active, "once you have picked you can go")

func test_a_second_pull_is_ignored_while_cards_are_showing() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.pull_button.pressed.emit()
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.currency, 50 - RunConfig.PULL_PRICE_BASE, "only one pull was paid for")
	check_eq(main.state.run.pulls_made, 1, "and counted")

func test_you_cannot_buy_what_you_cannot_afford() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 0)
	check(shop.pull_button.disabled and shop.points_upgrade_button.disabled and shop.zone_upgrade_button.disabled, "everything is greyed out with no gold")
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 6, "nothing drawn")
	check(not shop.choice_box.visible, "no cards")
	check(shop.message_label.text.begins_with("Not enough gold"), shop.message_label.text)

func test_choosing_a_new_type_for_a_full_tier_asks_which_slot_to_swap_out() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	var run: RunState = main.state.run
	for type in [Piece.Type.SCOUT, Piece.Type.SERF, Piece.Type.CRAB, Piece.Type.DRUMMER]:
		run.add_to_roster(type)
	Lottery.begin_choice(run, Piece.Tier.COMMON, "pull")
	shop.refresh()
	check(_row_label(shop, 0).contains("Common (5/5 types)"), _row_label(shop, 0))
	check_eq(_choices(shop).size(), 5, "five cards: three you hold, two new")
	var new_cards := _choices(shop).filter(func(b): return b.text.begins_with("NEW: "))
	check_eq(new_cards.size(), 2, "two replacement cards")
	check(new_cards[0].text.contains("swaps out a type"), "and they say so: %s" % new_cards[0].text)
	var incoming: Piece.Type = run.pending.cards[3].type
	new_cards[0].pressed.emit()
	check(shop.choice_prompt.text.contains("slots are full"), shop.choice_prompt.text)
	check_eq(_choices(shop).size(), 5, "one button per type you hold")
	check(_choices(shop).any(func(b): return b.text == "Pawn x3"), "with how many you have: %s" % str(_choices(shop).map(func(b): return b.text)))
	check_eq(run.roster.size(), 10, "nothing has changed yet")
	var pawn_button: Button = _choices(shop).filter(func(b): return b.text == "Pawn x3")[0]
	pawn_button.pressed.emit()
	check_eq(run.count_of(PAWN), 0, "the pawns are gone")
	check_eq(run.count_of(incoming), 3, "and the same number of the new type took over")
	check_eq(run.roster.size(), 10, "no pieces gained or lost")
	check(shop.message_label.text.contains("swapped for"), shop.message_label.text)
	check(not shop.choice_box.visible, "decided")

func test_selecting_five_pieces_of_one_tier_trades_them_up_for_a_choice_of_cards() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 100)
	main.state.run.add_to_roster(PAWN)
	main.state.run.add_to_roster(PAWN)
	shop.refresh()
	check_eq(_row(shop, 0).size(), 5, "five pawns")
	check(shop.trade_up_button.disabled and shop.trade_up_button.text == "Trade up (0/5 selected)", shop.trade_up_button.text)
	for i in 5:
		_row(shop, 0)[i].pressed.emit()
	check(not shop.trade_up_button.disabled, "trade-up is available")
	check_eq(shop.trade_up_button.text, "Trade up 5 pieces -> Uncommon", "and says what you get")
	check(_row(shop, 0).all(func(b): return b.button_pressed), "the chosen pieces show as selected")
	shop.trade_up_button.pressed.emit()
	check_eq(_row(shop, 0).size(), 0, "the five pawns are gone")
	check(shop.choice_box.visible and shop.choice_prompt.text.contains("UNCOMMON"), "and you choose from uncommon cards: %s" % shop.choice_prompt.text)
	check_eq(_choices(shop).size(), 5, "five cards")
	check(shop.trade_up_button.disabled and shop.leave_button.disabled, "nothing else until you choose")
	_choices(shop)[0].pressed.emit()
	check_eq(main.state.run.roster.size(), 6 - 3 + 1, "one piece in return (the starting three pawns were sacrificed with the two new ones)")

func test_trade_up_stays_disabled_for_the_wrong_selection_and_says_why() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 0)
	for i in 3:
		_row(shop, 0)[i].pressed.emit()          # three pawns
	_row(shop, 1)[0].pressed.emit()              # and a piece of another tier
	_row(shop, 1)[1].pressed.emit()
	check(shop.trade_up_button.disabled, "five mixed pieces can't be traded")
	check_eq(shop.trade_up_button.tooltip_text, "All the pieces must be the same tier", "the reason")
	_row(shop, 1)[0].pressed.emit()              # unselect one -> four selected
	check_eq(shop.trade_up_button.text, "Trade up (4/5 selected)", "count shown")
	shop.trade_up_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 6, "pressing a disabled trade changes nothing")

func test_seven_rares_trade_up_to_a_legendary_of_your_choice() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var run: RunState = main.state.run
	for i in 6:
		run.add_to_roster(ROOK)
	shop.refresh()
	check_eq(_row(shop, 2).size(), 7, "seven rares")
	for i in 6:
		_row(shop, 2)[i].pressed.emit()
	check(shop.trade_up_button.disabled and shop.trade_up_button.text == "Trade up (6/7 selected)", shop.trade_up_button.text)
	_row(shop, 2)[6].pressed.emit()
	check_eq(shop.trade_up_button.text, "Trade up 7 pieces -> Legendary", "seven is the price")
	shop.trade_up_button.pressed.emit()
	check_eq(_row(shop, 2).size(), 0, "all seven sacrificed")
	check(shop.choice_prompt.text.contains("LEGENDARY"), shop.choice_prompt.text)
	check_eq(_choices(shop).size(), 1, "only the queen is on offer")
	check(_choices(shop)[0].text.begins_with("Queen"), _choices(shop)[0].text)
	_choices(shop)[0].pressed.emit()
	check_eq(_row(shop, 3).size(), 1, "a legendary piece")
	check(run.roster.any(func(e): return e.type == QUEEN), "the queen")
	check(_row_label(shop, 3).contains("Legendary (1/2 types)"), _row_label(shop, 3))
	check(shop.message_label.text.contains("The Queen joins you!"), shop.message_label.text)

func test_an_unlocked_legendary_can_be_chosen_instead_of_the_queen() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var run: RunState = main.state.run
	Legendaries.grant(run, Piece.Type.DRAGON)
	run.remove_all_of_type(Piece.Type.DRAGON)
	for i in 6:
		run.add_to_roster(ROOK)
	shop.refresh()
	for entry in run.roster.filter(func(e): return e.type == ROOK).slice(0, 7):
		_row(shop, 2)[run.roster.filter(func(e): return Piece.tier(e.type) == Piece.Tier.RARE).find(entry)].pressed.emit()
	shop.trade_up_button.pressed.emit()
	var texts := _choices(shop).map(func(b): return b.text.split("\n")[0])
	check_eq(texts, ["Queen", "Dragon"], "the queen and the dragon you beat")

func test_a_boss_piece_with_both_legendary_slots_full_asks_which_to_give_up() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var run: RunState = main.state.run
	Legendaries.grant(run, Piece.Type.DRAGON)
	Legendaries.grant(run, Piece.Type.HYDRA)
	check_eq(Legendaries.grant(run, Piece.Type.LICH), "choose", "a third legendary arrives")
	shop.open(run, "next")
	check(shop.choice_box.visible and shop.choice_prompt.text.contains("Lich"), shop.choice_prompt.text)
	var texts := _choices(shop).map(func(b): return b.text.replace("\n", " "))
	check_eq(texts, ["Give up Dragon", "Give up Hydra", "Decline the Lich"], "the two you hold, or turn the new one down")
	check(shop.leave_button.disabled, "you can't skip the decision")
	_choices(shop)[0].pressed.emit()
	check_eq(run.held_types(Piece.Tier.LEGENDARY), [Piece.Type.HYDRA, Piece.Type.LICH], "the dragon went, the lich stayed")
	check(not shop.choice_box.visible and not shop.leave_button.disabled, "decided")
	check(shop.message_label.text.contains("Lich is yours"), shop.message_label.text)

func test_declining_a_legendary_keeps_what_you_have() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var run: RunState = main.state.run
	Legendaries.grant(run, Piece.Type.DRAGON)
	Legendaries.grant(run, Piece.Type.HYDRA)
	Legendaries.grant(run, Piece.Type.LICH)
	shop.open(run, "next")
	_choices(shop)[2].pressed.emit()
	check_eq(run.held_types(Piece.Tier.LEGENDARY), [Piece.Type.DRAGON, Piece.Type.HYDRA], "unchanged")
	check(not shop.is_busy(), "decided")

func test_upgrades_raise_what_you_can_field_next_match() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 100)
	shop.points_upgrade_button.pressed.emit()
	shop.zone_upgrade_button.pressed.emit()
	var run: RunState = main.state.run
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START + RunConfig.POINTS_UPGRADE_AMOUNT, "more points")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES + RunConfig.ZONE_UPGRADE_AMOUNT, "a bigger zone")
	check_eq(run.currency, 100 - RunConfig.POINTS_UPGRADE_PRICE_BASE - RunConfig.ZONE_UPGRADE_PRICE_BASE, "gold spent")
	check(shop.points_upgrade_button.text.contains("-> %d" % (run.allocated_points + RunConfig.POINTS_UPGRADE_AMOUNT)), "the button shows the next step: %s" % shop.points_upgrade_button.text)
	shop.leave_button.pressed.emit()
	check(main.state.deployment.active and not shop.visible, "deploying the next match")
	check_eq(count_zone(main.state.boards, WHITE), run.zone_tiles, "the new zone size is in effect")
	check(main.panel.deploy_status_label.text.ends_with("Points 0/%d" % run.allocated_points), main.panel.deploy_status_label.text)

func test_a_bigger_roster_than_your_points_allow_leaves_pieces_on_the_bench() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 100)
	for i in 3:
		main.state.run.add_to_roster(PAWN)        # +3 points of pawns on top of the starting 14
	shop.leave_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	var used := Roster.points_used(main.state.run, main.state.boards)
	check(used <= main.state.run.allocated_points and used > 0, "auto deploy stays within your points (%d/%d)" % [used, main.state.run.allocated_points])
	check(not Roster.bench(main.state.run, main.state.boards).is_empty(), "some pieces had to stay on the bench")
	check(main.panel.deploy_status_label.text.contains("Points %d/%d" % [used, main.state.run.allocated_points]), main.panel.deploy_status_label.text)

func test_leaving_the_shop_starts_the_next_matchs_deployment() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	shop.leave_button.pressed.emit()
	check(not shop.visible and main.state.deployment.active and not main.state.current_match.active, "deploying")
	check_eq(main.state.run.title(), "Round 1/12 - Match 2/3", "the next match")

func test_there_is_no_shop_after_the_final_boss_or_after_a_loss() -> void:
	var main = await load_main()
	_begin_run(main)
	main.state.run.round_number = RunConfig.ROUNDS + 1
	main.state.run.match_number = 1
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	check(main.state.run.complete and not main.shop_screen.visible, "no shop after Arthur")
	_begin_run(main)
	var lost: MatchState = main.state.current_match
	lost.active = false
	lost.result = "loss"
	lost.result_reason = "Test"
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	check(not main.shop_screen.visible and main.state.deployment.active, "a loss restarts the run with no shop")

func test_the_shop_blocks_the_screen_behind_it() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	check_eq(shop.mouse_filter, Control.MOUSE_FILTER_STOP, "swallows clicks")
	check(shop.size.is_equal_approx(Vector2(main.get_tree().root.get_visible_rect().size)), "covers the whole viewport")

func test_real_mouse_clicks_work_in_the_shop() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 60)
	await pump(2)
	await click_control(shop.pull_button)
	check(shop.choice_box.visible, "a real click made a lottery pull and laid out the cards")
	await pump(2)
	await click_control(_choices(shop)[0])
	check_eq(main.state.run.roster.size(), 7, "a real click on a card picked it")
	await pump(2)
	await click_control(_row(shop, 0)[0])
	check(shop.trade_up_button.text.contains("(1/5 selected)"), "a real click selected a piece: %s" % shop.trade_up_button.text)
	await click_control(shop.leave_button)
	check(main.state.deployment.active, "a real click on Next Match moved on")

func test_a_new_run_resets_the_shops_prices_and_limits() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 200)
	shop.pull_button.pressed.emit()
	_resolve(shop)
	shop.points_upgrade_button.pressed.emit()
	shop.zone_upgrade_button.pressed.emit()
	shop.leave_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "loss"
	current.result_reason = "Test"
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	var run: RunState = main.state.run
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START, "points reset")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES, "zone reset")
	check_eq(Lottery.price(run), RunConfig.PULL_PRICE_BASE, "prices reset")
	check_eq(run.roster.size(), 6, "roster reset")
