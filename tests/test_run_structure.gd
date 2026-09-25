extends "res://tests/TestCase.gd"
## The shape of a run: 12 rounds of 3 matches (the third a boss), then Arthur.

func _started() -> RunState:
	var run := RunState.new()
	run.begin()
	return run

func test_a_new_run_starts_at_round_one_match_one() -> void:
	var run := _started()
	check(run.active and not run.complete, "active")
	check_eq(run.round_number, 1, "round")
	check_eq(run.match_number, 1, "match")
	check(not run.is_boss(), "the first match isn't a boss")

func test_the_third_match_of_every_round_is_a_boss() -> void:
	var run := _started()
	for round_index in RunConfig.ROUNDS:
		for match_index in RunConfig.MATCHES_PER_ROUND:
			check_eq(run.is_boss(), match_index == RunConfig.MATCHES_PER_ROUND - 1, "round %d match %d" % [run.round_number, run.match_number])
			run.advance()
	check(run.is_final_round(), "then the final round")

func test_a_run_is_thirty_six_matches_then_arthur() -> void:
	var run := _started()
	var count := 1
	while run.advance():
		count += 1
	check_eq(count, RunConfig.ROUNDS * RunConfig.MATCHES_PER_ROUND + 1, "36 ordinary matches plus Arthur")
	check(run.complete and not run.active, "finishing Arthur completes the run")
	check(not run.advance(), "nothing after that")

func test_arthur_is_a_single_boss_match_in_round_thirteen() -> void:
	var run := _started()
	run.round_number = RunConfig.ROUNDS + 1
	check(run.is_final_round() and run.is_boss(), "a boss match")
	check_eq(run.matches_in_round(), 1, "the only match")
	check_eq(run.boss_name(), "Arthur", "Arthur")

func test_each_round_gets_its_own_boss_and_the_order_is_random() -> void:
	var seen := {}
	var orders := {}
	for i in 12:
		var run := _started()
		check_eq(run.boss_order.size(), RunConfig.ROUNDS, "one boss per round")
		var unique := {}
		for boss in run.boss_order:
			unique[boss] = true
		check_eq(unique.size(), RunConfig.ROUNDS, "no boss repeats within a run")
		orders[str(run.boss_order)] = true
	check(orders.size() > 1, "the order differs between runs")
	var run := _started()
	run.match_number = 3
	check_eq(run.boss_name(), Piece.display_name(run.boss_order[0]), "the boss is named after its piece")
	run.match_number = 1
	check_eq(run.boss_name(), "", "ordinary matches have no boss name")

func test_the_matches_played_counter() -> void:
	var run := _started()
	check_eq(run.matches_played(), 0, "none yet")
	run.advance()
	run.advance()
	check_eq(run.matches_played(), 2, "two matches in")
	run.advance()
	check_eq(run.matches_played(), 3, "round two starts")
	check_eq(run.round_number, 2, "round")

func test_titles_describe_where_you_are() -> void:
	var run := RunState.new()
	check_eq(run.title(), "No run in progress", "before a run")
	run.begin()
	check_eq(run.title(), "Round 1/12 - Match 1/3", "first match")
	run.match_number = 3
	check_eq(run.title(), "Round 1/12 - Match 3/3 - BOSS: %s" % Piece.display_name(run.boss_order[0]), "the title names the boss")
	run.round_number = 13
	run.match_number = 1
	check_eq(run.title(), "Round 13 - Arthur (final boss)", "final")
	run.advance()
	check_eq(run.title(), "Run complete!", "done")
