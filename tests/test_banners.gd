extends "res://tests/TestCase.gd"
## Run banners: the data (Banners.gd), their numeric effects on a fresh
## RunState/match setup, the side swap (White/Black Banner), the economy hooks
## (Merchant's/Banker's/Hoarder's), Guardian's one-time save, and the
## three-step Banner Select screen (Start Menu -> side -> trait -> difficulty
## -> a run begins directly, Balatro-deck-select style). Difficulty's own
## numeric effects (AI budget, target, gold, prices, Easy's retry) are covered
## separately in tests/test_difficulty.gd - this file just checks the picker
## stores the choice and carries it through restarts/UI correctly.

## Loads the real Main scene stopped at the Start Menu - unlike TestCase's own
## load_main(), which deliberately skips past Banner Select into a blank,
## run-inactive sandbox for the ~600 gameplay tests that don't care about
## banners at all.
func _load_main_at_start_menu() -> Node:
	var main = MainScene.instantiate()
	tree.root.add_child(main)
	main.turn_flow.ai_delay = 0.0
	main.shop_screen.reveal_delay = 0.0
	track(main)
	await pump(2)
	return main

## Drives the real Start Menu -> three-step Banner Select flow (through the
## actual signals, the way a player would), landing with a real run begun
## under both banners and the given difficulty (defaults to Normal - most
## tests don't care).
func _start_with_banners(side_id: Banners.Id, trait_id: Banners.Id, difficulty: Difficulty.Level = Difficulty.Level.NORMAL) -> Node:
	var main = await _load_main_at_start_menu()
	main.start_menu.start_button.pressed.emit()
	var side_index: int = [Banners.Id.WHITE, Banners.Id.BLACK].find(side_id)
	main.banner_screen.list.get_child(side_index).pressed.emit()
	var traits: Array = Banners.ids().filter(func(id): return not Banners.is_side(id))
	main.banner_screen.list.get_child(traits.find(trait_id)).pressed.emit()
	main.banner_screen.list.get_child(Difficulty.levels().find(difficulty)).pressed.emit()
	return main

func _ready_up(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func _force_result(main: Node, result: String) -> void:
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = result
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()

# ---- data --------------------------------------------------------------------------------

func test_seventeen_unique_banners_each_with_a_name_and_description() -> void:
	var ids := Banners.ids()
	check_eq(ids.size(), 17, "White, Black and the 15 trait banners")
	var names := {}
	for id in ids:
		check(not Banners.display_name(id).is_empty(), "has a name")
		check(not Banners.description(id).is_empty(), "has a description")
		names[Banners.display_name(id)] = true
	check_eq(names.size(), ids.size(), "every name is unique")

func test_only_white_and_black_are_side_banners() -> void:
	var sides := Banners.ids().filter(func(id): return Banners.is_side(id))
	check_eq(sides, [Banners.Id.WHITE, Banners.Id.BLACK], "exactly these two")

# ---- numeric run-start effects -------------------------------------------------------------

func test_no_banner_matches_the_old_unbannered_defaults() -> void:
	var run := RunState.new()
	run.begin()
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START, "points unchanged")
	check_eq(run.zone_tiles, RunConfig.PLAYER_ZONE_TILES, "zone unchanged")
	check_eq(run.bonus_moves, 0, "moves unchanged")
	check_eq(Banners.player_side(run), WHITE, "white by default")

func test_iron_banner_trades_points_for_moves() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.IRON])
	check_eq(run.bonus_moves, 3, "+3 moves")
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START - 2, "-2 points")

func test_vanguard_banner_trades_moves_for_points() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.VANGUARD])
	check_eq(run.bonus_moves, -3, "-3 moves")
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START + 3, "+3 points")

func test_broad_and_narrow_banners_trade_zone_for_points() -> void:
	var broad := RunState.new()
	broad.begin([Banners.Id.BROAD])
	check_eq(broad.zone_tiles, RunConfig.PLAYER_ZONE_TILES + 5, "broad: +5 zone")
	check_eq(broad.allocated_points, RunConfig.PLAYER_POINTS_START - 2, "broad: -2 points")

	var narrow := RunState.new()
	narrow.begin([Banners.Id.NARROW])
	check_eq(narrow.zone_tiles, RunConfig.PLAYER_ZONE_TILES - 3, "narrow: -3 zone")
	check_eq(narrow.allocated_points, RunConfig.PLAYER_POINTS_START + 3, "narrow: +3 points")

func test_prophetic_banner_trades_moves_for_hand_size() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.PROPHETIC])
	check_eq(run.bonus_moves, -2, "-2 moves")
	check_eq(Banners.hand_size(run), RunConfig.HAND_SIZE + 1, "+1 hand size")

func test_hoarder_banner_also_raises_hand_size() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.HOARDER])
	check_eq(Banners.hand_size(run), RunConfig.HAND_SIZE + 1, "+1 hand size")

func test_guardian_banner_lowers_moves() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.GUARDIAN])
	check_eq(run.bonus_moves, -4, "-4 moves")
	check(not run.guardian_used, "save not spent yet")

func test_twin_banner_adds_two_copies_of_one_common_piece() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.TWIN], RandomNumberGenerator.new())
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START - 3, "-3 points")
	check_eq(run.roster.size(), RunConfig.STARTING_ROSTER.size() + 2, "2 extra pieces")
	var extra_types := run.roster.slice(RunConfig.STARTING_ROSTER.size())
	check_eq(extra_types[0].type, extra_types[1].type, "both copies are the same type")
	check_eq(Piece.tier(extra_types[0].type), Piece.Tier.COMMON, "a common piece")

func test_royal_banner_starts_with_a_queen() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.ROYAL])
	check_eq(run.allocated_points, RunConfig.PLAYER_POINTS_START - 5, "-5 points")
	check(run.roster.any(func(e): return e.type == QUEEN), "a queen in the roster")

func test_erratic_banner_randomizes_the_roster_within_a_bigger_budget() -> void:
	# Deterministic: with the same seed, begin()'s Erratic roster must match a
	# fresh select_army call at the bonus-inflated budget exactly - a loose
	# "value <= budget" check alone can't tell Erratic apart from the plain
	# starting roster, since that also fits under the bigger budget.
	var run := RunState.new()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	run.begin([Banners.Id.ERRATIC], rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var expected: Array = PieceSelector.select_army(RunConfig.PLAYER_POINTS_START + Banners.ERRATIC_BONUS_POINTS, "normal", rng2)

	check(not expected.is_empty(), "the comparison actually produced pieces")
	check_eq(run.roster.map(func(e): return e.type), expected, "matches select_army at the bonus budget with the same seed")
	for entry in run.roster:
		check(entry.type != KING, "the king is never in the roster list")

# ---- match_setup: board size, ai budget, target ---------------------------------------------

func test_steady_banner_locks_boards_to_this_rounds_biggest_size_and_raises_ai_budget() -> void:
	var plain := RunState.new()
	plain.begin()
	var plain_setup := RunConfig.match_setup(plain)

	var run := RunState.new()
	run.begin([Banners.Id.STEADY])
	var setup := RunConfig.match_setup(run)
	for size in setup.board_sizes:
		check_eq(size.x, size.y, "square")
	var sizes: Array = setup.board_sizes.map(func(s): return s.x)
	check_eq(sizes, sizes.filter(func(x): return x == sizes[0]), "every board the same size")
	check_eq(setup.ai_budget, plain_setup.ai_budget + 1, "+1 AI budget")

func test_stormcaller_banner_softens_the_first_three_rounds_but_raises_the_target() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.STORMCALLER])
	var plain := RunState.new()
	plain.begin()

	run.round_number = 1
	plain.round_number = 1
	var early := RunConfig.match_setup(run)
	var plain_early := RunConfig.match_setup(plain)
	check_eq(early.ai_budget, plain_early.ai_budget - 1, "easier rounds 1-3")

	run.round_number = 5
	plain.round_number = 5
	var late := RunConfig.match_setup(run)
	var plain_late := RunConfig.match_setup(plain)
	check_eq(late.ai_budget, plain_late.ai_budget, "back to normal by round 5")
	check_eq(late.target, int(round(plain_late.target * 1.1)), "+10% target all run")

func test_reckless_banner_raises_target_and_gold() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.RECKLESS])
	var plain := RunState.new()
	plain.begin()
	var setup := RunConfig.match_setup(run)
	var plain_setup := RunConfig.match_setup(plain)
	check_eq(setup.target, int(round(plain_setup.target * 1.15)), "+15% target")
	check_eq(Banners.gold_multiplier(run), 1.25, "+25% gold")

func test_reckless_banner_actually_boosts_a_real_wins_payout() -> void:
	# Computed from the raw Payout constants directly (not by calling
	# Payout.calculate/Banners.gold_multiplier itself), so this proves the
	# multiplier really reaches RunFlow's real payout, not just the helpers.
	var main = await _start_with_banners(Banners.Id.WHITE, Banners.Id.RECKLESS)
	_ready_up(main)
	_force_result(main, "win")               # sets moves_left = 6, currency starts at 0
	var expected := int(round((Payout.BASE + 6 * Payout.PER_LEFTOVER_MOVE) * 1.25))
	check_eq(main.state.run.currency, expected, "reckless's +25% gold reached the real payout")

func test_merchant_banner_actually_lowers_a_real_wins_interest() -> void:
	var main = await _start_with_banners(Banners.Id.WHITE, Banners.Id.MERCHANT)
	main.state.run.currency = 100             # enough to hit the interest cap either way
	_ready_up(main)
	_force_result(main, "win")
	var halved_cap := int(Payout.INTEREST_CAP / 2.0)
	var expected := Payout.BASE + 6 * Payout.PER_LEFTOVER_MOVE + mini(100 / Payout.INTEREST_STEP, halved_cap)
	check_eq(main.state.run.currency, 100 + expected, "merchant's halved interest cap reached the real payout")

# ---- economy: shop, lottery, prophecies -----------------------------------------------------

func test_merchants_and_bankers_banners_move_shop_prices_opposite_ways() -> void:
	var plain := RunState.new()
	plain.begin()
	var merchant := RunState.new()
	merchant.begin([Banners.Id.MERCHANT])
	var banker := RunState.new()
	banker.begin([Banners.Id.BANKER])

	check(Shop.points_upgrade_price(merchant) < Shop.points_upgrade_price(plain), "cheaper upgrades")
	check(Shop.points_upgrade_price(banker) > Shop.points_upgrade_price(plain), "pricier upgrades")
	check(Lottery.price(merchant) < Lottery.price(plain), "cheaper pulls")
	check(Lottery.price(banker) > Lottery.price(plain), "pricier pulls")

func test_merchants_and_bankers_banners_move_the_interest_cap_opposite_ways() -> void:
	check(Banners.interest_cap(_with(Banners.Id.MERCHANT)) < Payout.INTEREST_CAP, "halved")
	check(Banners.interest_cap(_with(Banners.Id.BANKER)) > Payout.INTEREST_CAP, "doubled")
	check_eq(Banners.interest_cap(RunState.new()), Payout.INTEREST_CAP, "unchanged with no banner")

func _with(id: Banners.Id) -> RunState:
	var run := RunState.new()
	run.begin([id])
	return run

func test_hoarder_banner_raises_the_lottery_price() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.HOARDER])
	var plain := RunState.new()
	plain.begin()
	check_eq(Lottery.price(run), Lottery.price(plain) + 2, "+2 gold base")

func test_hoarder_banner_actually_lets_you_carry_a_fourth_prophecy() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.HOARDER])
	run.currency = 500
	run.prophecy_offers = ["rising_tide", "blood_moon", "song_of_the_small", "giant_slayer"]
	for slot in 3:
		check(Prophecies.buy(run, slot).ok, "card %d fits" % (slot + 1))
	check(Prophecies.buy(run, 3).ok, "a fourth fits too, thanks to Hoarder's Banner")
	check_eq(run.hand.size(), 4, "carrying 4")

func test_prophecy_price_is_scaled_by_banner_price_multiplier() -> void:
	var id: String = ProphecyDefs.ids()[0]
	var plain_price := Prophecies.price(id)
	check_eq(Prophecies.price(id, RunState.new()), plain_price, "a fresh, un-begun run has no discount")
	check(Prophecies.price(id, _with(Banners.Id.MERCHANT)) < plain_price, "merchant discount applies")

# ---- side swap -----------------------------------------------------------------------------

func test_white_banner_plays_as_white_by_default() -> void:
	var main = await _start_with_banners(Banners.Id.WHITE, Banners.Id.IRON)
	check_eq(Banners.player_side(main.state.run), WHITE, "white")
	_ready_up(main)
	check_eq(main.state.current_match.player_side, WHITE, "match agrees")
	check(not Roster.on_field(main.state.boards, WHITE).is_empty(), "your pieces are on White's zone")

func test_black_banner_plays_as_black_and_the_ai_takes_white() -> void:
	var main = await _start_with_banners(Banners.Id.BLACK, Banners.Id.IRON)
	check_eq(Banners.player_side(main.state.run), BLACK, "black")
	# Before you deploy anything, only the AI's bought army is on the boards -
	# check it landed on White (and not also on Black, your own side). White
	# always has a free king regardless, so check the AI's actual BOUGHT army
	# (which costs points), not just "some White piece exists".
	check(ArmyPlacer.points_used(main.state.boards, WHITE) > 0, "the AI's army (not just its king) is on White")
	check_eq(ArmyPlacer.points_used(main.state.boards, BLACK), 0, "nothing bought for Black yet")
	check_eq(count_zone(main.state.boards, BLACK), RunConfig.PLAYER_ZONE_TILES, "your zone size, not swapped")
	check_eq(count_zone(main.state.boards, WHITE), int(RunConfig.AI_ZONE_TILES_BASE), "the AI's zone size, not swapped")

	_ready_up(main)
	check_eq(main.state.current_match.player_side, BLACK, "match agrees")
	check(not Roster.on_field(main.state.boards, BLACK).is_empty(), "your pieces are deployed onto Black's zone")

# ---- Guardian's Banner: one free continue -----------------------------------------------------

func test_guardians_banner_survives_its_first_loss_then_ends_the_run_on_the_second() -> void:
	var main = await _start_with_banners(Banners.Id.WHITE, Banners.Id.GUARDIAN)
	var round_title: String = main.state.run.title()
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check(main.state.run.active, "the run survives")
	check(main.state.run.guardian_used, "the save is spent")
	check_eq(main.state.run.title(), round_title, "retrying the same match")
	check(main.state.deployment.active, "back to deployment for another try")

	_ready_up(main)
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check_eq(main.state.run.title(), "Round 1/12 - Match 1/3", "second loss really restarts")
	check(main.state.run.banners.has(Banners.Id.GUARDIAN), "the banner carries over the restart")
	check(not main.state.run.guardian_used, "a fresh save on the new run")

# ---- the three-step picker UI -----------------------------------------------------------------

func test_the_side_step_offers_exactly_white_and_black() -> void:
	var main = await _load_main_at_start_menu()
	main.start_menu.start_button.pressed.emit()
	check_eq(main.banner_screen.list.get_child_count(), 2, "White and Black only")
	check_eq(main.banner_screen.title_label.text, "Choose your side", "step 1 title")

func test_the_trait_step_follows_the_side_step_and_offers_the_other_fifteen() -> void:
	var main = await _load_main_at_start_menu()
	main.start_menu.start_button.pressed.emit()
	main.banner_screen.list.get_child(0).pressed.emit()          # White
	check_eq(main.banner_screen.list.get_child_count(), 15, "the 15 trait banners")
	check_eq(main.banner_screen.title_label.text, "Choose your banner", "step 2 title")
	check(main.state.screen == GameState.Screen.BANNER_SELECT, "still selecting, not in the game yet")

func test_the_difficulty_step_follows_the_trait_step_and_offers_all_four_levels() -> void:
	var main = await _load_main_at_start_menu()
	main.start_menu.start_button.pressed.emit()
	main.banner_screen.list.get_child(0).pressed.emit()          # White
	main.banner_screen.list.get_child(0).pressed.emit()          # first trait banner
	check_eq(main.banner_screen.list.get_child_count(), 4, "Easy, Normal, Hard, Nightmare")
	check_eq(main.banner_screen.title_label.text, "Choose your difficulty", "step 3 title")
	check(main.state.screen == GameState.Screen.BANNER_SELECT, "still selecting, not in the game yet")

func test_completing_all_three_steps_starts_a_run_with_both_banners_and_enters_the_game() -> void:
	var main = await _start_with_banners(Banners.Id.BLACK, Banners.Id.IRON, Difficulty.Level.HARD)
	check(not main.banner_screen.visible, "closed once all three picks are made")
	check_eq(main.state.screen, GameState.Screen.GAME, "moved straight into the game")
	check(main.panel.visible and main.boards_container.visible, "the game is showing")
	check(main.state.run.active, "a real run began")
	check(main.state.run.banners.has(Banners.Id.BLACK) and main.state.run.banners.has(Banners.Id.IRON), "both banners kept")
	check_eq(main.state.run.difficulty, Difficulty.Level.HARD, "difficulty kept")
	check(main.state.deployment.active, "straight into deploying for match 1")

## begin() itself (starting points/zone/moves) is untouched by difficulty - only
## match_setup/Shop/Payout are, which is what tests/test_difficulty.gd covers.
## See that file's header for why (RunState.begin's numbers are Banners' turf).
func test_difficulty_does_not_change_the_starting_roster_setup() -> void:
	var easy := RunState.new()
	easy.begin([Banners.Id.WHITE], null, Difficulty.Level.EASY)
	var nightmare := RunState.new()
	nightmare.begin([Banners.Id.WHITE], null, Difficulty.Level.NIGHTMARE)
	check_eq(easy.allocated_points, nightmare.allocated_points, "same points")
	check_eq(easy.zone_tiles, nightmare.zone_tiles, "same zone")
	check_eq(easy.bonus_moves, nightmare.bonus_moves, "same moves")

func test_difficulty_defaults_to_normal_when_not_specified() -> void:
	var run := RunState.new()
	run.begin([Banners.Id.WHITE])
	check_eq(run.difficulty, Difficulty.Level.NORMAL, "normal by default")

func test_real_mouse_clicks_through_all_three_steps_work() -> void:
	var main = await _load_main_at_start_menu()
	await click_control(main.start_menu.start_button)
	await click_control(main.banner_screen.list.get_child(0))     # White
	await click_control(main.banner_screen.list.get_child(0))     # first trait banner
	await click_control(main.banner_screen.list.get_child(0))     # first difficulty
	check_eq(main.state.screen, GameState.Screen.GAME, "reached the game via real clicks")
	check(main.state.run.active, "a run began")
