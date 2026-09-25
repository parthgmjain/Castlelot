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

# The piece buttons in one tier's row (0 = common, 1 = uncommon, 2 = legendary).
func _row(shop: ShopScreen, tier_index: int) -> Array:
	return shop.roster_box.get_child(tier_index).get_children().filter(func(c): return c is Button)

func test_the_shop_opens_after_a_win_and_shows_everything() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	check(not main.shop_screen.visible, "no shop before the first match")
	var shop := _to_shop(main)
	check(shop.visible, "the shop is open")
	check(shop.title_label.text.contains("Round 1/12 - Match 2/3"), shop.title_label.text)
	check_eq(shop.gold_label.text, "Gold: %d" % main.state.run.currency, "gold shown")
	check_eq(_row(shop, 0).size(), 3, "three pawns in the common row")
	check_eq(_row(shop, 1).size(), 3, "rook, knight and bishop in the uncommon row")
	check_eq(_row(shop, 2).size(), 0, "no legendary pieces yet")
	check_eq(shop.pull_button.text, "Lottery Pull - %d gold" % RunConfig.PULL_PRICE_BASE, "the lottery button")
	var odds := Lottery.odds(main.state.run)
	for tier in odds:
		var shown := "%s %d%%" % [Piece.TIER_NAMES[tier], roundi(odds[tier] * 100.0)]
		check(shop.odds_label.text.contains(shown), "odds label shows '%s': %s" % [shown, shop.odds_label.text])
	check(shop.points_upgrade_button.text.begins_with("Allocated points 14 -> 16"), shop.points_upgrade_button.text)
	check(shop.zone_upgrade_button.text.begins_with("Zone size 10 -> 11"), shop.zone_upgrade_button.text)
	check_eq(shop.cards_row.get_child_count(), ShopScreen.CARD_SLOTS, "a row of trading-card slots")
	check(shop.cards_row.get_children().all(func(slot): return slot.disabled), "all placeholders for now")
	check_eq(shop.leave_button.text, "Next Match", "leave button")

func test_a_lottery_pull_spends_gold_gives_a_piece_and_updates_prices_and_the_wallet() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.currency, 50 - RunConfig.PULL_PRICE_BASE, "gold spent")
	check_eq(main.state.run.roster.size(), 7, "a piece was added")
	var rows := _row(shop, 0).size() + _row(shop, 1).size() + _row(shop, 2).size()
	check_eq(rows, 7, "and shown in its tier's row")
	check(shop.pull_button.text.contains("%d gold" % (RunConfig.PULL_PRICE_BASE + RunConfig.PULL_PRICE_STEP)), "the next pull costs more: %s" % shop.pull_button.text)
	check_eq(shop.gold_label.text, "Gold: %d" % main.state.run.currency, "shop gold updated")
	check_eq(main.panel.wallet_label.text, "Gold: %d" % main.state.run.currency, "and the main wallet label")
	check(shop.message_label.text.contains("! You got a "), shop.message_label.text)
	var got: Dictionary = main.state.run.roster.back()
	check(shop.message_label.text.begins_with(Piece.TIER_NAMES[Piece.tier(got.type)]), "the message names the drawn tier: %s" % shop.message_label.text)

func test_the_tier_is_revealed_before_the_piece() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.reveal_delay = 0.3
	shop.pull_button.pressed.emit()
	check(shop.message_label.text.begins_with("You drew a ") and shop.message_label.text.ends_with(" piece..."), "step 1: the tier is shown: %s" % shop.message_label.text)
	check(shop.message_label.has_theme_color_override("font_color"), "tinted with the tier's color")
	check_eq(main.state.run.roster.size(), 6, "but no piece yet")
	check_eq(main.state.run.currency, 50 - RunConfig.PULL_PRICE_BASE, "the pull is already paid for")
	check(shop.pull_button.disabled and shop.trade_up_button.disabled and shop.points_upgrade_button.disabled and shop.zone_upgrade_button.disabled, "everything waits for the reveal")
	await main.get_tree().create_timer(0.5).timeout
	check_eq(main.state.run.roster.size(), 7, "step 2: the piece arrives")
	check(shop.message_label.text.contains("! You got a "), shop.message_label.text)
	check(not shop.pull_button.disabled, "and you can pull again")

func test_leaving_during_the_reveal_still_delivers_the_piece() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.reveal_delay = 0.3
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 6, "pending")
	shop.leave_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 7, "the paid-for piece is delivered on the way out")
	check(main.state.deployment.active and not shop.visible, "and you moved on")
	await main.get_tree().create_timer(0.5).timeout
	check_eq(main.state.run.roster.size(), 7, "the late timer doesn't add a second piece")

func test_a_second_pull_is_ignored_while_one_is_being_revealed() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.reveal_delay = 0.3
	shop.pull_button.pressed.emit()
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.currency, 50 - RunConfig.PULL_PRICE_BASE, "only one pull was paid for")
	await main.get_tree().create_timer(0.5).timeout
	check_eq(main.state.run.roster.size(), 7, "and one piece delivered")

func test_you_cannot_buy_what_you_cannot_afford() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 0)
	check(shop.pull_button.disabled and shop.points_upgrade_button.disabled and shop.zone_upgrade_button.disabled, "everything is greyed out with no gold")
	shop.pull_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 6, "nothing drawn")
	check(shop.message_label.text.begins_with("Not enough gold"), shop.message_label.text)

func test_selecting_five_pieces_of_one_tier_trades_them_up() -> void:
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
	check_eq(shop.trade_up_button.text, "Trade up 5 pieces -> 1 Uncommon", "and says what you get")
	check(_row(shop, 0).all(func(b): return b.button_pressed), "the chosen pieces show as selected")
	shop.trade_up_button.pressed.emit()
	check_eq(_row(shop, 0).size(), 0, "the five pawns are gone")
	check_eq(_row(shop, 1).size(), 4, "and there's a new uncommon piece")
	check(shop.message_label.text.begins_with("Traded 5 pieces for a "), shop.message_label.text)
	check(shop.trade_up_button.disabled, "selection cleared")

func test_trade_up_stays_disabled_for_the_wrong_selection_and_says_why() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 0)
	for i in 3:
		_row(shop, 0)[i].pressed.emit()          # three pawns
	_row(shop, 1)[0].pressed.emit()              # and a piece of another tier
	_row(shop, 1)[1].pressed.emit()
	check(shop.trade_up_button.disabled, "five mixed pieces can't be traded")
	check_eq(shop.trade_up_button.tooltip_text, "All five must be the same tier", "the reason")
	_row(shop, 1)[0].pressed.emit()              # unselect one -> four selected
	check_eq(shop.trade_up_button.text, "Trade up (4/5 selected)", "count shown")
	shop.trade_up_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 6, "pressing a disabled trade changes nothing")

func test_five_uncommon_pieces_become_a_queen() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	main.state.run.add_to_roster(KNIGHT)
	main.state.run.add_to_roster(BISHOP)
	shop.refresh()
	check_eq(_row(shop, 1).size(), 5, "five uncommon pieces")
	for i in 5:
		_row(shop, 1)[i].pressed.emit()
	shop.trade_up_button.pressed.emit()
	check_eq(_row(shop, 1).size(), 0, "all five sacrificed")
	check_eq(_row(shop, 2).size(), 1, "a legendary piece")
	check(main.state.run.roster.any(func(e): return e.type == QUEEN), "the queen")
	check(shop.message_label.text.contains("Queen (Legendary)"), shop.message_label.text)

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
	check_eq(main.state.run.roster.size(), 7, "a real click made a lottery pull")
	await click_control(_row(shop, 0)[0])
	check(shop.trade_up_button.text.contains("(1/5 selected)"), "a real click selected a piece: %s" % shop.trade_up_button.text)
	await click_control(shop.leave_button)
	check(main.state.deployment.active, "a real click on Next Match moved on")

func test_a_new_run_resets_the_shops_prices_and_limits() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 200)
	shop.pull_button.pressed.emit()
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
