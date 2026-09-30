extends "res://tests/TestCase.gd"
## The left-side Balatro-style run/match info panel. See scripts/ui/InfoSidebar.gd.
## The piece-value reference it used to show inline is now a popup opened
## from here - see tests/test_piece_values_popup.gd for that.

func _start_run() -> Node:
	var main = await load_main()
	main.run_flow.start_run([], null, Difficulty.Level.NORMAL)
	return main

func _ready_up(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func test_hidden_outside_a_run() -> void:
	var main = await load_main()
	check(not main.info_sidebar.visible, "no run active")

func test_shown_with_round_match_gold_and_the_move_allotment_during_deployment() -> void:
	var main = await _start_run()
	check(main.info_sidebar.visible, "a run is active")
	check_eq(main.info_sidebar.round_label.text, "Round %d/%d" % [main.state.run.round_number, RunConfig.ROUNDS], "round box")
	check_eq(main.info_sidebar.match_label.text, "Match %d/%d" % [main.state.run.match_number, main.state.run.matches_in_round()], "match box")
	check(main.info_sidebar.gold_label.text.contains("0"), main.info_sidebar.gold_label.text)
	check_eq(main.info_sidebar.moves_label.text, "Moves: %d" % main.state.deployment.setup.moves, "the match's move allotment, before it starts")
	check(not main.info_sidebar.score_box.visible, "no score exists yet")

func test_moves_switches_to_a_countdown_and_score_appears_once_the_match_starts() -> void:
	var main = await _start_run()
	_ready_up(main)
	var current: MatchState = main.state.current_match
	check_eq(main.info_sidebar.moves_label.text, "Moves left: %d" % current.moves_left, "moves line")
	check(main.info_sidebar.score_box.visible, "match is active")
	check_eq(main.info_sidebar.score_label.text, "Score: %d / %d" % [current.scores[current.player_side], current.target_score], "score line")

func test_round_label_has_no_denominator_on_arthurs_round() -> void:
	var main = await _start_run()
	main.state.run.round_number = RunConfig.ROUNDS + 1
	main._refresh_view()
	check_eq(main.info_sidebar.round_label.text, "Round %d" % (RunConfig.ROUNDS + 1), "no /12 once past the normal rounds")

func test_gold_updates_after_a_win() -> void:
	var main = await _start_run()
	_ready_up(main)
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	check(main.info_sidebar.gold_label.text.contains(str(main.state.run.currency)), main.info_sidebar.gold_label.text)
	check(main.state.run.currency > 0, "actually paid out")

func test_the_values_button_opens_the_piece_values_popup() -> void:
	var main = await load_main()
	check(not main.piece_values_popup.visible, "closed by default")
	main.info_sidebar.values_button.pressed.emit()
	check(main.piece_values_popup.visible, "opened by the sidebar's button")

func test_hides_again_once_the_run_ends() -> void:
	var main = await _start_run()
	check(main.info_sidebar.visible, "shown")
	main.state.run.active = false
	main._refresh_view()
	check(not main.info_sidebar.visible, "hidden once the run is no longer active")
