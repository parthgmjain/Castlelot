extends "res://tests/TestCase.gd"
## The top-of-screen boss portrait banner: shown only during a boss match
## (including Arthur), hidden the rest of the time. See scripts/ui/BossBanner.gd.

func _start_run() -> Node:
	var main = await load_main()
	main.run_flow.start_run([], null, Difficulty.Level.NORMAL)
	return main

func test_hidden_outside_a_run() -> void:
	var main = await load_main()
	check(not main.boss_banner.visible, "no run active, nothing to show")

func test_hidden_on_an_ordinary_match() -> void:
	var main = await _start_run()
	main.state.run.round_number = 1
	main.state.run.match_number = 1
	main.run_flow.begin_match()
	check(not main.boss_banner.visible, "match 1 of 3 isn't a boss")

func test_shown_and_named_on_a_boss_match() -> void:
	var main = await _start_run()
	main.state.run.round_number = 1
	main.state.run.match_number = 3
	main.run_flow.begin_match()
	check(main.boss_banner.visible, "match 3 of 3 is the boss")
	check_eq(main.boss_banner.name_label.text, main.state.run.boss_name(), "named for the actual boss")
	check(main.boss_banner.name_label.text != "", "never blank while shown")

func test_shown_and_named_for_arthur() -> void:
	var main = await _start_run()
	main.state.run.round_number = RunConfig.ROUNDS + 1
	main.state.run.match_number = 1
	main.run_flow.begin_match()
	check(main.boss_banner.visible, "arthur is a boss too")
	check_eq(main.boss_banner.name_label.text, RunConfig.FINAL_BOSS, "named Arthur")

func test_hides_again_once_the_run_ends() -> void:
	var main = await _start_run()
	main.state.run.round_number = 1
	main.state.run.match_number = 3
	main.run_flow.begin_match()
	check(main.boss_banner.visible, "shown during the boss match")
	main.state.run.active = false
	main._refresh_view()
	check(not main.boss_banner.visible, "hidden once the run is no longer active")
