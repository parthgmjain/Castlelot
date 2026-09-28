extends "res://tests/TestCase.gd"
## The bottom-of-screen roster strip shown during an active match (mutually
## exclusive in time with the deployment bench - see scripts/ui/RosterStrip.gd).

func _start_run() -> Node:
	var main = await load_main()
	main.run_flow.start_run([], null, Difficulty.Level.NORMAL)
	return main

func _ready_up(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func test_hidden_outside_a_run() -> void:
	var main = await load_main()
	check(not main.roster_strip.visible, "no run active")

func test_hidden_during_deployment() -> void:
	var main = await _start_run()
	check(main.state.deployment.active, "still deploying")
	check(not main.roster_strip.visible, "the bench is showing instead")

func test_shown_with_one_card_per_roster_piece_once_the_match_starts() -> void:
	var main = await _start_run()
	_ready_up(main)
	check(main.roster_strip.visible, "match is active")
	check_eq(main.roster_strip.box.get_child_count(), main.state.run.roster.size(), "one card per roster piece")

func test_a_benched_piece_is_dimmer_than_a_deployed_one() -> void:
	var main = await _start_run()
	var target: Dictionary = Roster.free_squares(main.state.boards, WHITE)[0]
	main.panel.bench_box.get_children()[0].pressed.emit()
	main._on_square_selected(target.square, target.board)   # deploy just the first piece
	main.panel.ready_button.pressed.emit()
	var cards: Array = main.roster_strip.box.get_children()
	var deployed_alphas := []
	var benched_alphas := []
	var deployed_ids := Roster.on_field(main.state.boards, WHITE).keys()
	for i in main.state.run.roster.size():
		var alpha: float = cards[i].modulate.a
		if deployed_ids.has(main.state.run.roster[i].id):
			deployed_alphas.append(alpha)
		else:
			benched_alphas.append(alpha)
	check(not deployed_alphas.is_empty() and not benched_alphas.is_empty(), "test actually covers both cases")
	for a in deployed_alphas:
		check_eq(a, 1.0, "deployed piece shown at full strength")
	for a in benched_alphas:
		check(a < 1.0, "benched piece dimmed")

func test_hides_again_after_the_match_ends() -> void:
	var main = await _start_run()
	_ready_up(main)
	check(main.roster_strip.visible, "shown mid-match")
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	main._refresh_view()
	check(not main.roster_strip.visible, "hidden once the match ends")
