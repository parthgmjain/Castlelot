extends "res://tests/TestCase.gd"
## Pawns head for the enemy zone: keep one direction while it helps, then turn.

# Follows a lone pawn's first non-capturing move until it has none.
func _walk(board: Board, square: Vector2i, side: Piece.Side) -> Array:
	var path := [{ "board": board, "square": square }]
	for i in 80:
		var next = null
		for m in PawnMovement.moves(side, path[-1].board, path[-1].square):
			if not m.capture:
				next = m
				break
		if next == null:
			break
		path.append({ "board": next.board, "square": next.square })
	return path

func _turns(path: Array) -> int:
	var turns := 0
	var last := Vector2i.ZERO
	for i in range(1, path.size()):
		if path[i].board != path[i - 1].board:
			continue
		var d: Vector2i = path[i].square - path[i - 1].square
		if last != Vector2i.ZERO and d != last:
			turns += 1
		last = d
	return turns

func test_without_an_enemy_zone_pawns_move_like_before() -> void:
	var board := make_board()
	check_eq(squares_of(PawnMovement.moves(WHITE, board, Vector2i(2, 7))), [Vector2i(2, 6), Vector2i(2, 5)], "white from its home row")
	check_eq(squares_of(PawnMovement.moves(BLACK, board, Vector2i(2, 0))), [Vector2i(2, 1), Vector2i(2, 2)], "black from its home row")
	put(board, Vector2i(2, 5), PAWN, BLACK)
	check_eq(squares_of(PawnMovement.moves(WHITE, board, Vector2i(2, 7))), [Vector2i(2, 6)], "double step blocked")
	put(board, Vector2i(1, 6), PAWN, BLACK)
	check(squares_of(PawnMovement.moves(WHITE, board, Vector2i(2, 7))).has(Vector2i(1, 6)), "diagonal capture")
	check_eq(squares_of(PawnMovement.moves(WHITE, board, Vector2i(2, 4))), [Vector2i(2, 3)], "no double step off the home row")

func test_pawn_goes_straight_then_turns_once_toward_the_zone() -> void:
	var board := make_board()
	for sq in [Vector2i(6, 1), Vector2i(7, 1), Vector2i(6, 0), Vector2i(7, 0)]:
		board.zone_owner[sq] = BLACK
	var path := _walk(board, Vector2i(0, 7), WHITE)
	check_eq(path.size() - 1, 12, "steps")
	check_eq(_turns(path), 1, "turns")
	check_eq(board.zone_owner.get(path[-1].square), BLACK, "ends in the zone")
	check_eq(PawnMovement.heading(board, Vector2i(0, 7), WHITE), Vector2i(0, -1), "starts heading up")
	check_eq(PawnMovement.heading(board, Vector2i(0, 1), WHITE), Vector2i(1, 0), "then right")

func test_pawn_with_the_zone_behind_it_walks_back() -> void:
	var board := make_board()
	for x in 8:
		board.zone_owner[Vector2i(x, 7)] = BLACK
	var path := _walk(board, Vector2i(3, 2), WHITE)
	check_eq(path.size() - 1, 5, "steps")
	check_eq(_turns(path), 0, "no oscillation")
	check_eq(PawnMovement.heading(board, Vector2i(3, 2), WHITE), Vector2i(0, 1), "heads down")

func test_pawn_walks_through_a_portal_into_the_zone() -> void:
	var rig := make_rig([0, 1, 2, 3], 4)
	var a: Board = rig[0]
	var b: Board = rig[1]
	for sq in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 0), Vector2i(3, 0)]:
		b.zone_owner[sq] = BLACK
	check_eq(PawnMovement.distance_field(a, WHITE)[a][Vector2i(0, 3)], 8, "distance across the portal")
	var path := _walk(a, Vector2i(0, 3), WHITE)
	check_eq(path.size() - 1, 8, "steps")
	check(path[-1].board == b and b.zone_owner.get(path[-1].square) == BLACK, "ends inside the zone on board B")

func test_captures_follow_the_turned_heading() -> void:
	var board := make_board()
	for r in 8:
		board.zone_owner[Vector2i(7, r)] = BLACK
	check_eq(PawnMovement.heading(board, Vector2i(1, 3), WHITE), Vector2i(1, 0), "heading right")
	put(board, Vector2i(2, 2), PAWN, BLACK)
	put(board, Vector2i(2, 4), KNIGHT, BLACK)
	put(board, Vector2i(0, 2), PAWN, BLACK)   # behind it
	put(board, Vector2i(1, 2), PAWN, BLACK)   # straight up: not a capture
	var squares := squares_of(PawnMovement.moves(WHITE, board, Vector2i(1, 3)))
	check(squares.has(Vector2i(2, 3)) and squares.has(Vector2i(2, 2)) and squares.has(Vector2i(2, 4)), "step + both forward diagonals")
	check(not squares.has(Vector2i(0, 2)) and not squares.has(Vector2i(1, 2)), "not backward or sideways")
	put(board, Vector2i(2, 3), PAWN, WHITE)
	var blocked := squares_of(PawnMovement.moves(WHITE, board, Vector2i(1, 3)))
	check(not blocked.has(Vector2i(2, 3)) and blocked.has(Vector2i(2, 2)), "a blocker stops the step but not the captures")

func test_double_step_only_while_it_stays_on_the_path() -> void:
	var far := make_board()
	for x in 8:
		far.zone_owner[Vector2i(x, 0)] = BLACK
	check_eq(squares_of(PawnMovement.moves(WHITE, far, Vector2i(3, 7))), [Vector2i(3, 6), Vector2i(3, 5)], "double step toward a far zone")
	var near := make_board()
	for x in 8:
		near.zone_owner[Vector2i(x, 6)] = BLACK
	check_eq(squares_of(PawnMovement.moves(WHITE, near, Vector2i(3, 7))), [Vector2i(3, 6)], "no overshoot past the zone")
	check(PawnMovement.moves(WHITE, near, Vector2i(3, 6)).is_empty(), "nothing forward once inside the zone")

func test_every_pawn_in_random_worlds_reaches_the_enemy_zone_by_a_shortest_path() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel.count_spin_box.value = 4
	await pump()
	var pawns := 0
	for world in 12:
		await new_world(main, randi_range(3, 20), randi_range(3, 20))
		for board in main.state.boards:
			board.pieces.clear()
		for side in [WHITE, BLACK]:
			var enemy := Piece.opponent(side)
			for board in main.state.boards:
				for square in board.zone_owner:
					if board.zone_owner[square] != side:
						continue
					var field := PawnMovement.distance_field(board, side)
					var start_distance: int = field[board][square]
					var path := _walk(board, square, side)
					pawns += 1
					if path[-1].board.zone_owner.get(path[-1].square) != enemy or path.size() - 1 != start_distance:
						check(false, "pawn at %s did not take a shortest path into the enemy zone" % square)
						continue
					for i in range(1, path.size()):
						if field[path[i].board][path[i].square] != start_distance - i:
							check(false, "distance did not drop by one each step")
							break
	check(pawns > 100, "checked %d pawns" % pawns)
