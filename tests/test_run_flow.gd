extends "res://tests/TestCase.gd"
## A whole run through the real UI: Start Run, matches setting themselves up,
## bosses, winning on, losing back to the start, and finishing after Arthur.

func _start(main: Node) -> void:
	main.panel.start_run_button.pressed.emit()

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

func _win_and_continue(main: Node) -> void:
	_force_result(main, "win")
	_continue(main)

func test_starting_a_run_builds_and_starts_the_first_match() -> void:
	var main = await load_main()
	_start(main)
	var state: GameState = main.state
	check(state.run.active, "run active")
	check_eq(state.run.title(), "Round 1/12 - Match 1/3", "title")
	check_eq(main.panel.run_status_label.text, "Round 1/12 - Match 1/3", "shown on screen")
	var current := state.current_match
	check(current.active and current.turn_side == WHITE, "match running, your turn")
	check_eq(current.moves_left, RunConfig.MOVES, "moves from the config")
	check_eq(current.target_score, int(RunConfig.TARGET_BASE), "target from the config")
	check_eq(state.boards.size(), RunConfig.BOARDS_BASE, "board count from the config")
	check(boards_connected(state.boards), "boards connected")
	check(king_alive(state.boards, WHITE) and king_alive(state.boards, BLACK), "both kings")
	check_eq(count_zone(state.boards, WHITE), RunConfig.PLAYER_ZONE_TILES, "your zone")
	check_eq(count_zone(state.boards, BLACK), int(RunConfig.AI_ZONE_TILES_BASE), "the AI's zone")
	check(ArmyPlacer.points_used(state.boards, WHITE) <= RunConfig.PLAYER_BUDGET, "your army within budget")
	check(ArmyPlacer.points_used(state.boards, BLACK) <= int(RunConfig.AI_BUDGET_BASE), "the AI army within budget")
	check(pieces_of(state.boards, WHITE, false).size() > 0 and pieces_of(state.boards, BLACK, false).size() > 0, "both sides have armies")

func test_setup_controls_stay_locked_for_the_whole_run() -> void:
	var main = await load_main()
	_start(main)
	var panel: ControlPanel = main.panel
	check(panel.refresh_button.disabled and panel.start_run_button.disabled and panel.start_match_button.disabled and panel.generate_zones_button.disabled, "locked mid-match")
	_force_result(main, "win")
	check(panel.refresh_button.disabled and panel.start_run_button.disabled, "still locked while the result is showing")
	_continue(main)
	check(panel.refresh_button.disabled and panel.start_run_button.disabled, "and locked in the next match")

func test_winning_carries_on_to_the_next_match_automatically() -> void:
	var main = await load_main()
	_start(main)
	_force_result(main, "win")
	var screen: ResultScreen = main.result_screen
	check(screen.visible, "result screen")
	check_eq(screen.context_label.text, "Round 1/12 - Match 1/3", "says where you were")
	check_eq(screen.continue_button.text, "Next Match", "button")
	var gold: int = main.state.run.currency
	check(gold > 0, "paid out (%d)" % gold)
	_continue(main)
	check(not screen.visible, "closed")
	check_eq(main.state.run.title(), "Round 1/12 - Match 2/3", "moved to match 2")
	check(main.state.current_match.active and main.state.current_match.result == "", "a fresh match is running")
	check_eq(main.state.run.currency, gold, "gold carried over")

func test_the_third_match_is_a_boss_with_a_boss_army() -> void:
	var main = await load_main()
	_start(main)
	_win_and_continue(main)
	_win_and_continue(main)
	var run: RunState = main.state.run
	check(run.is_boss(), "match 3 is a boss")
	check(main.panel.run_status_label.text.contains("BOSS: Sir "), main.panel.run_status_label.text)
	check_eq(main.panel.round_option.get_item_text(main.panel.round_option.selected), "Boss", "boss army type")
	var normal_target := int(RunConfig.TARGET_BASE + RunConfig.TARGET_PER_MATCH * 1)
	check(main.state.current_match.target_score > normal_target, "a tougher target than match 2")
	_force_result(main, "win")
	check(main.result_screen.context_label.text.contains("BOSS"), "the result screen names the boss")
	check_eq(main.result_screen.continue_button.text, "Next Match", "carries on")

func test_three_wins_start_the_next_round() -> void:
	var main = await load_main()
	_start(main)
	for i in 3:
		_win_and_continue(main)
	check_eq(main.state.run.title(), "Round 2/12 - Match 1/3", "round two")
	check(main.state.current_match.active, "and a match is running")

func test_a_full_run_is_thirty_seven_matches_then_arthur_then_done() -> void:
	var main = await load_main()
	_start(main)
	var matches := 1
	var last_boss_names := []
	while true:
		var state: GameState = main.state
		check(state.current_match.active, "match %d is running" % matches)
		check(king_alive(state.boards, WHITE) and king_alive(state.boards, BLACK) and boards_connected(state.boards), "match %d is a valid world" % matches)
		if state.run.is_boss():
			last_boss_names.append(state.run.boss_name())
		_force_result(main, "win")
		if state.run.is_final_round():
			check_eq(main.result_screen.continue_button.text, "Finish Run", "the last button")
			break
		_continue(main)
		matches += 1
	check_eq(matches, 37, "36 ordinary matches plus Arthur")
	check_eq(last_boss_names.size(), 13, "12 knights and Arthur")
	check_eq(last_boss_names[12], "Arthur", "Arthur last")
	var unique := {}
	for n in last_boss_names.slice(0, 12):
		unique[n] = true
	check_eq(unique.size(), 12, "every knight faced exactly once")
	_continue(main)
	check(main.state.run.complete and not main.state.run.active, "run complete")
	check_eq(main.panel.run_status_label.text, "Run complete!", "status")
	check(not main.panel.refresh_button.disabled and not main.panel.start_run_button.disabled, "setup unlocked, ready for another run")

func test_losing_restarts_the_run_from_the_beginning() -> void:
	var main = await load_main()
	_start(main)
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
	check(main.state.current_match.active, "a new first match is running")

func test_gold_and_interest_build_up_across_a_runs_matches() -> void:
	var main = await load_main()
	_start(main)
	_win_and_continue(main)
	var after_one: int = main.state.run.currency
	_force_result(main, "win")
	var interest: int = mini(after_one / Payout.INTEREST_STEP, Payout.INTEREST_CAP)
	check(main.result_screen.details_label.text.contains("Interest (%d held): +%d" % [after_one, interest]), main.result_screen.details_label.text)
	check_eq(main.state.run.currency, after_one + Payout.BASE + 6 * Payout.PER_LEFTOVER_MOVE + interest, "second payout includes interest")

func test_a_finished_run_can_be_started_again() -> void:
	var main = await load_main()
	_start(main)
	main.state.run.round_number = RunConfig.ROUNDS + 1
	main.state.run.match_number = 1
	_force_result(main, "win")
	_continue(main)
	check(main.state.run.complete, "finished")
	_start(main)
	check(main.state.run.active and not main.state.run.complete, "a new run")
	check_eq(main.state.run.title(), "Round 1/12 - Match 1/3", "from the start")
	check_eq(main.state.run.currency, 0, "with an empty wallet")

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
	_start(main)
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
