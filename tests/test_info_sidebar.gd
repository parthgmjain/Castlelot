extends "res://tests/TestCase.gd"
## The left-side Balatro-style run/match info panel and its piece-value
## reference. See scripts/ui/InfoSidebar.gd.

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

func test_shown_with_round_and_gold_during_deployment_but_no_match_stats_yet() -> void:
	var main = await _start_run()
	check(main.info_sidebar.visible, "a run is active")
	check_eq(main.info_sidebar.round_label.text, main.state.run.title(), "round/match title")
	check(main.info_sidebar.gold_label.text.contains("0"), main.info_sidebar.gold_label.text)
	check(not main.info_sidebar.score_label.visible, "no match yet")
	check(not main.info_sidebar.moves_label.visible, "no match yet")
	check(not main.info_sidebar.turn_label.visible, "no match yet")

func test_shows_score_moves_and_turn_once_the_match_starts() -> void:
	var main = await _start_run()
	_ready_up(main)
	var current: MatchState = main.state.current_match
	check(main.info_sidebar.score_label.visible, "match is active")
	check_eq(main.info_sidebar.score_label.text, "Score: %d / %d" % [current.scores[current.player_side], current.target_score], "score line")
	check_eq(main.info_sidebar.moves_label.text, "Moves left: %d" % current.moves_left, "moves line")
	check_eq(main.info_sidebar.turn_label.text, "Your Turn", "white moves first")

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

func test_the_piece_value_reference_lists_every_non_king_piece_grouped_by_tier() -> void:
	var main = await load_main()
	var rows: Array = main.info_sidebar.value_list.get_children()
	var everyone := Piece.types_in_tier(Piece.Tier.COMMON) + Piece.types_in_tier(Piece.Tier.UNCOMMON) \
		+ Piece.types_in_tier(Piece.Tier.RARE) + Piece.types_in_tier(Piece.Tier.LEGENDARY)
	check_eq(rows.size(), everyone.size() + 4, "one row per piece plus 4 tier headers")
	var text := rows.map(func(r): return r.text)
	check(text.has("Pawn - 1"), "pawn's value")
	check(text.has("Queen - 9"), "queen's value")
	check(not text.any(func(t): return t.begins_with("King")), "the king isn't a card, not listed")

func test_hides_again_once_the_run_ends() -> void:
	var main = await _start_run()
	check(main.info_sidebar.visible, "shown")
	main.state.run.active = false
	main._refresh_view()
	check(not main.info_sidebar.visible, "hidden once the run is no longer active")
