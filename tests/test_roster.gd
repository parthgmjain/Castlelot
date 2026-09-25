extends "res://tests/TestCase.gd"
## The roster: what you own, deploying it into your zone, and losing pieces.

func _run() -> RunState:
	var run := RunState.new()
	run.begin()
	return run

# One board with a white zone of `zone` squares (row 0) and the white king at (0,0).
func _world(zone: int = 6) -> Array:
	var board := make_board(8, 4)
	for x in zone:
		board.zone_owner[Vector2i(x, 0)] = WHITE
	put(board, Vector2i(0, 0), KING, WHITE)
	return [board]

func test_a_run_starts_with_a_rook_knight_bishop_and_three_pawns() -> void:
	var run := _run()
	var types := run.roster.map(func(e): return e.type)
	types.sort()
	var expected := [ROOK, KNIGHT, BISHOP, PAWN, PAWN, PAWN]
	expected.sort()
	check_eq(types, expected, "the starting roster")
	check(not types.has(KING), "the king isn't in the roster")
	var ids := {}
	for entry in run.roster:
		ids[entry.id] = true
	check_eq(ids.size(), 6, "every piece has its own id")

func test_a_new_run_gets_a_fresh_roster() -> void:
	var run := _run()
	run.remove_from_roster(run.roster[0].id)
	check_eq(run.roster.size(), 5, "lost one")
	var second := _run()
	check_eq(second.roster.size(), 6, "the next run starts complete")

func test_deploying_puts_a_bench_piece_on_a_free_zone_square() -> void:
	var run := _run()
	var boards := _world()
	var board: Board = boards[0]
	var rook: Dictionary = run.roster.filter(func(e): return e.type == ROOK)[0]
	check_eq(Roster.bench(run, boards).size(), 6, "everything starts on the bench")
	check(Roster.deploy(run, boards, rook.id, board, Vector2i(1, 0)), "deployed")
	check_eq(board.pieces[Vector2i(1, 0)].type, ROOK, "a rook is on the board")
	check_eq(board.pieces[Vector2i(1, 0)].side, WHITE, "on your side")
	check_eq(board.pieces[Vector2i(1, 0)].roster_id, rook.id, "and remembers which roster piece it is")
	check_eq(Roster.bench(run, boards).size(), 5, "the bench shrinks")

func test_deploy_rules_zone_occupancy_and_once_only() -> void:
	var run := _run()
	var boards := _world(3)
	var board: Board = boards[0]
	var id: int = run.roster[0].id
	check(not Roster.deploy(run, boards, id, board, Vector2i(5, 0)), "outside your zone")
	check(not Roster.deploy(run, boards, id, board, Vector2i(0, 0)), "onto the king")
	check(not Roster.deploy(run, boards, id, board, Vector2i(3, 3)), "on a neutral square")
	check(not Roster.deploy(run, boards, 999, board, Vector2i(1, 0)), "a piece you don't own")
	check(Roster.deploy(run, boards, id, board, Vector2i(1, 0)), "a legal square works")
	check(not Roster.deploy(run, boards, id, board, Vector2i(2, 0)), "the same piece twice")
	check(not Roster.deploy(run, boards, run.roster[1].id, board, Vector2i(1, 0)), "onto another piece")
	board.zone_owner[Vector2i(6, 0)] = BLACK
	check(not Roster.deploy(run, boards, run.roster[1].id, board, Vector2i(6, 0)), "into the enemy zone")

func test_withdrawing_returns_a_piece_to_the_bench() -> void:
	var run := _run()
	var boards := _world()
	var board: Board = boards[0]
	Roster.deploy(run, boards, run.roster[0].id, board, Vector2i(1, 0))
	check(not Roster.withdraw(board, Vector2i(0, 0)), "the king can't be withdrawn")
	check(not Roster.withdraw(board, Vector2i(2, 0)), "nothing there")
	check(Roster.withdraw(board, Vector2i(1, 0)), "withdrawn")
	check_eq(Roster.bench(run, boards).size(), 6, "back on the bench")
	check(not board.pieces.has(Vector2i(1, 0)), "and off the board")

func test_auto_deploy_fills_the_zone_and_leaves_the_rest_on_the_bench() -> void:
	var run := _run()
	var roomy := _world(8)
	check_eq(Roster.auto_deploy(run, roomy), 6, "all six fit in seven free squares")
	check(Roster.bench(run, roomy).is_empty(), "nothing left on the bench")
	var run2 := _run()
	var tight := _world(4)                                    # king + 3 free squares
	check_eq(Roster.auto_deploy(run2, tight), 3, "only three fit")
	check_eq(Roster.bench(run2, tight).size(), 3, "the rest stay benched")
	check(Roster.free_squares(tight, WHITE).is_empty(), "the zone is full")

func test_pieces_captured_in_a_match_leave_the_roster_but_benched_ones_are_safe() -> void:
	var run := _run()
	var boards := _world(8)
	var board: Board = boards[0]
	var knight: Dictionary = run.roster.filter(func(e): return e.type == KNIGHT)[0]
	var rook: Dictionary = run.roster.filter(func(e): return e.type == ROOK)[0]
	var bishop: Dictionary = run.roster.filter(func(e): return e.type == BISHOP)[0]
	Roster.deploy(run, boards, knight.id, board, Vector2i(1, 0))
	Roster.deploy(run, boards, rook.id, board, Vector2i(2, 0))
	var deployed := Roster.field_ids(boards)
	check_eq(deployed.size(), 2, "two deployed, four benched")
	board.pieces.erase(Vector2i(1, 0))                        # the knight is captured
	var lost := Roster.settle(run, boards, deployed)
	check_eq(lost.size(), 1, "one piece lost")
	check_eq(lost[0].type, KNIGHT, "the knight")
	check(run.roster_entry(knight.id).is_empty(), "gone from the roster")
	check(not run.roster_entry(rook.id).is_empty() and not run.roster_entry(bishop.id).is_empty(), "the survivor and the benched piece remain")
	check_eq(run.roster.size(), 5, "five pieces left")

func test_a_promoted_pawn_is_still_a_pawn_in_the_roster() -> void:
	var run := _run()
	var boards := _world(8)
	var board: Board = boards[0]
	var pawn: Dictionary = run.roster.filter(func(e): return e.type == PAWN)[0]
	Roster.deploy(run, boards, pawn.id, board, Vector2i(1, 0))
	PawnMovement.promote(board.pieces[Vector2i(1, 0)], QUEEN)
	var lost := Roster.settle(run, boards, Roster.field_ids(boards))
	check(lost.is_empty(), "the promoted pawn survived")
	check_eq(run.roster_entry(pawn.id).type, PAWN, "the roster still records a pawn")

func test_a_deployed_piece_that_moved_to_another_board_still_counts_as_alive() -> void:
	var run := _run()
	var rig := make_rig([0, 1, 2, 3, 4])
	var a: Board = rig[0]
	var b: Board = rig[1]
	for x in 5:
		a.zone_owner[Vector2i(x, 0)] = WHITE
	var boards := [a, b]
	var id: int = run.roster[0].id
	Roster.deploy(run, boards, id, a, Vector2i(1, 0))
	var deployed := Roster.field_ids(boards)
	var piece: Dictionary = a.pieces[Vector2i(1, 0)]
	a.pieces.erase(Vector2i(1, 0))
	b.pieces[Vector2i(2, 2)] = piece
	check(Roster.settle(run, boards, deployed).is_empty(), "found on the other board")
