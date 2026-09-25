extends "res://tests/TestCase.gd"
## A whole run through the real UI: Start Run, deploying, matches setting
## themselves up, bosses, winning on, losing back to the start, and finishing
## after Arthur.

func _start(main: Node) -> void:
	main.panel.start_run_button.pressed.emit()

# Deploys everything you can and starts the match, through the real buttons.
func _ready_up(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func _begin(main: Node) -> void:
	_start(main)
	_ready_up(main)

# Ends the current match with the given result without playing it out.
func _force_result(main: Node, result: String) -> void:
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = result
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()

func _continue(main: Node) -> void:
	main.result_screen.continue_button.pressed.emit()

# Leaves the shop, first deciding anything it asks (the last option each time: it turns a third
# legendary down, since a full run hands out a boss piece every round and the slots fill up).
func _leave_shop(main: Node) -> void:
	var shop: ShopScreen = main.shop_screen
	for i in 4:
		if not shop.is_busy():
			break
		shop.choice_row.get_children().back().pressed.emit()
	shop.leave_button.pressed.emit()

# Win, press Next Match, leave the shop, and get the following match going.
func _win_and_continue(main: Node) -> void:
	_force_result(main, "win")
	_continue(main)
	_leave_shop(main)
	_ready_up(main)

func test_starting_a_run_builds_the_world_then_waits_for_you_to_deploy() -> void:
	var main = await load_main()
	_start(main)
	var state: GameState = main.state
	check(state.run.active, "run active")
	check_eq(state.run.title(), "Round 1/12 - Match 1/3", "title")
	check_eq(main.panel.run_status_label.text, "Round 1/12 - Match 1/3", "shown on screen")
	check(state.deployment.active and not state.current_match.active, "deploying, not yet fighting")
	check_eq(state.boards.size(), RunConfig.BOARDS_BASE, "board count from the config")
	check(boards_connected(state.boards), "boards connected")
	check(king_alive(state.boards, WHITE) and king_alive(state.boards, BLACK), "both kings")
	check_eq(count_zone(state.boards, WHITE), RunConfig.PLAYER_ZONE_TILES, "your zone")
	check_eq(count_zone(state.boards, BLACK), int(RunConfig.AI_ZONE_TILES_BASE), "the AI's zone")
	check(ArmyPlacer.points_used(state.boards, BLACK) <= int(RunConfig.AI_BUDGET_BASE), "the AI army within budget")
	check(pieces_of(state.boards, BLACK, false).size() > 0, "the AI's army is already in place")
	check(pieces_of(state.boards, WHITE, false).is_empty(), "yours is still on the bench")

func test_pressing_start_match_begins_the_fight() -> void:
	var main = await load_main()
	_begin(main)
	var state: GameState = main.state
	var current := state.current_match
	check(current.active and current.turn_side == WHITE and not state.deployment.active, "match running, your turn")
	check_eq(current.moves_left, RunConfig.MOVES, "moves from the config")
	check_eq(current.target_score, int(RunConfig.TARGET_BASE), "target from the config")
	check_eq(pieces_of(state.boards, WHITE, false).size(), RunConfig.STARTING_ROSTER.size(), "your whole roster is on the board")
	check(not main.panel.deploy_row.visible, "the deploy row is gone")

func test_setup_controls_stay_locked_for_the_whole_run() -> void:
	var main = await load_main()
	_start(main)
	var panel: ControlPanel = main.panel
	check(panel.refresh_button.disabled and panel.start_run_button.disabled and panel.start_match_button.disabled and panel.generate_zones_button.disabled, "locked while deploying")
	_ready_up(main)
	check(panel.refresh_button.disabled and panel.start_run_button.disabled, "locked mid-match")
	_force_result(main, "win")
	check(panel.refresh_button.disabled and panel.start_run_button.disabled, "still locked while the result is showing")
	_continue(main)
	check(panel.refresh_button.disabled and panel.start_run_button.disabled, "and locked when the next match is being set up")

func test_winning_carries_on_to_the_next_matchs_deployment() -> void:
	var main = await load_main()
	_begin(main)
	_force_result(main, "win")
	var screen: ResultScreen = main.result_screen
	check(screen.visible, "result screen")
	check_eq(screen.context_label.text, "Round 1/12 - Match 1/3", "says where you were")
	check_eq(screen.continue_button.text, "Next Match", "button")
	var gold: int = main.state.run.currency
	check(gold > 0, "paid out (%d)" % gold)
	_continue(main)
	check(not screen.visible, "closed")
	check(main.shop_screen.visible and not main.state.deployment.active, "the shop opens before the next match")
	check(main.shop_screen.title_label.text.contains("Round 1/12 - Match 2/3"), main.shop_screen.title_label.text)
	_leave_shop(main)
	check(not main.shop_screen.visible, "shop closed")
	check_eq(main.state.run.title(), "Round 1/12 - Match 2/3", "moved to match 2")
	check(main.state.deployment.active and not main.state.current_match.active, "deploying for it")
	check_eq(main.state.run.currency, gold, "gold carried over")

func test_the_third_match_is_a_boss_with_a_boss_army() -> void:
	var main = await load_main()
	_begin(main)
	_win_and_continue(main)
	_win_and_continue(main)
	var run: RunState = main.state.run
	check(run.is_boss(), "match 3 is a boss")
	check(main.panel.run_status_label.text.contains("BOSS: %s" % run.boss_name()), main.panel.run_status_label.text)
	check(not main.panel.run_status_label.text.contains("Sir "), "no knights any more")
	check_eq(main.panel.round_option.get_item_text(main.panel.round_option.selected), "Boss", "boss army type")
	var normal_target := int(RunConfig.TARGET_BASE + RunConfig.TARGET_PER_MATCH * 1)
	check(main.state.current_match.target_score > normal_target, "a tougher target than match 2")
	_force_result(main, "win")
	check(main.result_screen.context_label.text.contains("BOSS"), "the result screen names the boss")
	check_eq(main.result_screen.continue_button.text, "Next Match", "carries on")

func test_three_wins_start_the_next_round() -> void:
	var main = await load_main()
	_begin(main)
	for i in 3:
		_win_and_continue(main)
	check_eq(main.state.run.title(), "Round 2/12 - Match 1/3", "round two")
	check(main.state.current_match.active, "and a match is running")

func test_a_full_run_is_thirty_seven_matches_then_arthur_then_done() -> void:
	var main = await load_main()
	_begin(main)
	var matches := 1
	var boss_names := []
	while true:
		var state: GameState = main.state
		check(state.current_match.active, "match %d is running" % matches)
		check(king_alive(state.boards, WHITE) and king_alive(state.boards, BLACK) and boards_connected(state.boards), "match %d is a valid world" % matches)
		if state.run.is_boss():
			boss_names.append(state.run.boss_name())
		_force_result(main, "win")
		if state.run.is_final_round():
			check_eq(main.result_screen.continue_button.text, "Finish Run", "the last button")
			break
		_continue(main)
		_leave_shop(main)
		_ready_up(main)
		matches += 1
	check_eq(matches, 37, "36 ordinary matches plus Arthur")
	check_eq(boss_names.size(), 13, "12 legendary bosses and Arthur")
	check_eq(boss_names[12], "Arthur", "Arthur last")
	var unique := {}
	for n in boss_names.slice(0, 12):
		unique[n] = true
	check_eq(unique.size(), 12, "every boss faced exactly once")
	_continue(main)
	check(main.state.run.complete and not main.state.run.active, "run complete")
	check_eq(main.panel.run_status_label.text, "Run complete!", "status")
	check(not main.panel.refresh_button.disabled and not main.panel.start_run_button.disabled, "setup unlocked, ready for another run")

func test_losing_restarts_the_run_from_the_beginning() -> void:
	var main = await load_main()
	_begin(main)
	_win_and_continue(main)
	_win_and_continue(main)
	var gold_before: int = main.state.run.currency
	check(gold_before > 0, "some gold to lose")
	_force_result(main, "loss")
	check_eq(main.result_screen.continue_button.text, "Restart Run", "button")
	check_eq(main.result_screen.wallet_label.text, "Gold lost: %d" % gold_before, "shows the loss")
	_continue(main)
	check_eq(main.state.run.title(), "Round 1/12 - Match 1/3", "back to the start")
	check_eq(main.state.run.currency, 0, "gold wiped")
	check(main.state.deployment.active, "a new first match is being set up")

func test_gold_and_interest_build_up_across_a_runs_matches() -> void:
	var main = await load_main()
	_begin(main)
	_win_and_continue(main)
	var after_one: int = main.state.run.currency
	_force_result(main, "win")
	var interest: int = mini(after_one / Payout.INTEREST_STEP, Payout.INTEREST_CAP)
	check(main.result_screen.details_label.text.contains("Interest (%d held): +%d" % [after_one, interest]), main.result_screen.details_label.text)
	check_eq(main.state.run.currency, after_one + Payout.BASE + 6 * Payout.PER_LEFTOVER_MOVE + interest, "second payout includes interest")

func test_a_finished_run_can_be_started_again() -> void:
	var main = await load_main()
	_begin(main)
	main.state.run.round_number = RunConfig.ROUNDS + 1
	main.state.run.match_number = 1
	_force_result(main, "win")
	_continue(main)
	check(main.state.run.complete, "finished")
	_start(main)
	check(main.state.run.active and not main.state.run.complete, "a new run")
	check_eq(main.state.run.title(), "Round 1/12 - Match 1/3", "from the start")
	check_eq(main.state.run.currency, 0, "with an empty wallet")
	check_eq(main.state.run.roster.size(), RunConfig.STARTING_ROSTER.size(), "and a full roster")

func test_sandbox_matches_still_work_outside_a_run() -> void:
	var main = await load_main()
	await new_world(main, 8, 8, true)
	main.panel.start_match_button.pressed.emit()
	check(main.state.current_match.active and not main.state.run.active, "a sandbox match, no run")
	_force_result(main, "loss")
	check_eq(main.result_screen.continue_button.text, "Restart Run", "default loss button")
	check_eq(main.result_screen.context_label.text, "", "no run context")
	_continue(main)
	check(not main.state.run.active and not main.state.current_match.active, "back to the sandbox, no run started")
	check(not main.panel.refresh_button.disabled, "setup unlocked")

func test_a_run_match_can_actually_be_played_against_the_ai() -> void:
	var main = await load_main()
	_begin(main)
	var state: GameState = main.state
	var current := state.current_match
	var rounds := 0
	while current.active and rounds < 60:
		rounds += 1
		var options := []
		for entry in pieces_of(state.boards, WHITE):
			for m in Piece.get_legal_moves(entry.piece.type, WHITE, entry.board, entry.square):
				options.append({ "board": entry.board, "square": entry.square, "move": m })
		if options.is_empty():
			break
		var pick = options.pick_random()
		main._on_square_selected(pick.square, pick.board)
		main._on_square_selected(pick.move.square, pick.move.board)
		if main.promotion_picker.visible:
			main.promotion_picker._buttons[QUEEN].pressed.emit()
		var waited := 0
		while current.active and current.turn_side == BLACK and waited < 30:
			await pump()
			waited += 1
	check(not current.active and current.result != "", "the match reached a result (%s)" % current.result_reason)
	check(main.result_screen.visible, "and the result screen is up")
	check(main.result_screen.context_label.text.begins_with("Round 1/12"), main.result_screen.context_label.text)
