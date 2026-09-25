extends "res://tests/TestCase.gd"
## The data-driven pieces (see docs/PIECES.md): exact move sets on an open board.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# Moves for `type` standing on `from` of a fresh 8x8 board, with `others` = [[square, type, side], ...].
func _moves(type: Piece.Type, from: Vector2i, others: Array = [], side: Piece.Side = WHITE, board: Board = null) -> Array:
	if board == null:
		board = make_board(8, 8)
	put(board, from, type, side)
	for other in others:
		put(board, other[0], other[1], other[2])
	return Piece.get_legal_moves(type, side, board, from)

func _plain(moves: Array) -> Array:
	return moves.filter(func(m): return not m.capture).map(func(m): return m.square)

func _caps(moves: Array) -> Array:
	return moves.filter(func(m): return m.capture).map(func(m): return m.square)

func _same(actual: Array, expected: Array, message: String) -> void:
	var missing := expected.filter(func(s): return not actual.has(s))
	var extra := actual.filter(func(s): return not expected.has(s))
	check(missing.is_empty() and extra.is_empty() and actual.size() == expected.size(), "%s: missing %s, unexpected %s" % [message, str(missing), str(extra)])

# ---- pawn tier ---------------------------------------------------------------

func test_scout_moves_forward_or_sideways_and_captures_diagonally_forward() -> void:
	var open := _moves(Piece.Type.SCOUT, V(3, 4))
	_same(_plain(open), [V(3, 3), V(2, 4), V(4, 4)], "empty board")
	check(_caps(open).is_empty(), "nothing to capture")
	var busy := _moves(Piece.Type.SCOUT, V(3, 4), [[V(3, 3), PAWN, BLACK], [V(2, 3), PAWN, BLACK], [V(4, 5), PAWN, BLACK], [V(4, 4), PAWN, WHITE]])
	_same(_plain(busy), [V(2, 4)], "the enemy ahead blocks it, a friend beside blocks it")
	_same(_caps(busy), [V(2, 3)], "only the forward diagonal is a capture")

func test_black_pieces_face_down_the_board() -> void:
	_same(_plain(_moves(Piece.Type.SCOUT, V(3, 3), [], BLACK)), [V(3, 4), V(2, 3), V(4, 3)], "black scout")

func test_serf_steps_diagonally_and_captures_straight_ahead() -> void:
	var open := _moves(Piece.Type.SERF, V(3, 4))
	_same(_plain(open), [V(2, 3), V(4, 3)], "diagonal steps")
	var busy := _moves(Piece.Type.SERF, V(3, 4), [[V(3, 3), PAWN, BLACK], [V(2, 3), PAWN, BLACK]])
	_same(_caps(busy), [V(3, 3)], "captures straight ahead only")
	_same(_plain(busy), [V(4, 3)], "a diagonal enemy blocks rather than being captured")

func test_militia_walks_any_orthogonal_way_and_captures_diagonally_forward() -> void:
	var open := _moves(Piece.Type.MILITIA, V(3, 4))
	_same(_plain(open), [V(3, 3), V(3, 5), V(2, 4), V(4, 4)], "four orthogonal steps, backward included")
	var busy := _moves(Piece.Type.MILITIA, V(3, 4), [[V(2, 3), PAWN, BLACK], [V(3, 3), PAWN, BLACK], [V(2, 5), PAWN, BLACK]])
	_same(_caps(busy), [V(2, 3)], "only forward diagonals")
	check(not _plain(busy).has(V(3, 3)), "no walking into a piece")

func test_crab_moves_sideways_and_captures_on_every_diagonal() -> void:
	var busy := _moves(Piece.Type.CRAB, V(3, 4), [[V(2, 3), PAWN, BLACK], [V(4, 5), PAWN, BLACK], [V(3, 3), PAWN, BLACK]])
	_same(_plain(busy), [V(2, 4), V(4, 4)], "sideways only")
	_same(_caps(busy), [V(2, 3), V(4, 5)], "captures forward or backward diagonally, not straight")

func test_pawn_tier_pieces_use_their_heading_not_the_screen() -> void:
	var board := make_board(8, 8)
	for row in 8:
		board.zone_owner[V(7, row)] = BLACK                    # the enemy zone is on the right
	var moves := _moves(Piece.Type.SCOUT, V(3, 4), [[V(4, 5), PAWN, BLACK]], WHITE, board)
	_same(_plain(moves), [V(4, 4), V(3, 5), V(3, 3)], "forward is now right, sideways is up and down")
	_same(_caps(moves), [V(4, 5)], "and its forward diagonal follows")

# ---- uncommon tier: leapers ----------------------------------------------------

func test_camel_and_zebra_leap_over_everything() -> void:
	var crowd: Array = []
	for x in range(2, 5):
		for y in range(3, 6):
			if V(x, y) != V(3, 4):
				crowd.append([V(x, y), PAWN, WHITE])
	_same(_plain(_moves(Piece.Type.CAMEL, V(3, 4), crowd)), [V(6, 3), V(6, 5), V(0, 3), V(0, 5), V(4, 1), V(2, 1), V(4, 7), V(2, 7)], "camel is 3-1")
	_same(_plain(_moves(Piece.Type.ZEBRA, V(3, 4))), [V(6, 2), V(6, 6), V(0, 2), V(0, 6), V(5, 1), V(1, 1), V(5, 7), V(1, 7)], "zebra is 3-2")

func test_camel_captures_where_it_lands_and_is_stopped_by_friends_there() -> void:
	var moves := _moves(Piece.Type.CAMEL, V(3, 4), [[V(6, 3), PAWN, BLACK], [V(6, 5), PAWN, WHITE]])
	_same(_caps(moves), [V(6, 3)], "enemy landing square")
	check(not _plain(moves).has(V(6, 5)), "friendly landing square")

func test_hawk_leaps_exactly_two_or_three_in_any_line() -> void:
	var moves := _moves(Piece.Type.HAWK, V(3, 3))
	_same(_plain(moves), [
		V(5, 3), V(1, 3), V(3, 5), V(3, 1), V(5, 5), V(1, 5), V(5, 1), V(1, 1),
		V(6, 3), V(0, 3), V(3, 6), V(3, 0), V(6, 6), V(0, 6), V(6, 0), V(0, 0),
	], "sixteen squares")
	var blocked := _moves(Piece.Type.HAWK, V(3, 3), [[V(4, 3), PAWN, WHITE], [V(4, 4), PAWN, WHITE]])
	check_eq(_plain(blocked).size(), 16, "pieces in between don't matter")

func test_twin_rider_makes_one_or_two_jumps_the_same_way() -> void:
	var moves := _moves(Piece.Type.TWIN_RIDER, V(3, 4))
	_same(_plain(moves), [
		V(4, 6), V(5, 5), V(2, 6), V(1, 5), V(4, 2), V(5, 3), V(2, 2), V(1, 3),      # single jumps
		V(7, 6), V(5, 0), V(7, 2), V(1, 0),                                          # second jumps that stay on the board
	], "twelve squares")
	var friend := _moves(Piece.Type.TWIN_RIDER, V(3, 4), [[V(5, 5), PAWN, WHITE]])
	check(not _plain(friend).has(V(5, 5)) and not _plain(friend).has(V(7, 6)), "a friend on the first landing square stops both")
	var enemy := _moves(Piece.Type.TWIN_RIDER, V(3, 4), [[V(5, 5), PAWN, BLACK]])
	_same(_caps(enemy), [V(5, 5)], "an enemy there can be captured")
	check(not _plain(enemy).has(V(7, 6)), "but you can't jump on past it")

func test_ferz_guard_steps_or_leaps_diagonally() -> void:
	var moves := _moves(Piece.Type.FERZ_GUARD, V(3, 3), [[V(4, 4), PAWN, WHITE]])
	_same(_plain(moves), [V(2, 4), V(4, 2), V(2, 2), V(5, 5), V(1, 5), V(5, 1), V(1, 1)], "the leap goes over the blocker")

# ---- uncommon tier: sliders ----------------------------------------------------

func test_ranger_goes_up_to_three_squares_orthogonally() -> void:
	_same(_plain(_moves(Piece.Type.RANGER, V(3, 3))), [
		V(3, 2), V(3, 1), V(3, 0), V(3, 4), V(3, 5), V(3, 6), V(2, 3), V(1, 3), V(0, 3), V(4, 3), V(5, 3), V(6, 3)], "twelve squares")

func test_charger_must_travel_at_least_two() -> void:
	var open := _moves(Piece.Type.CHARGER, V(3, 3))
	_same(_plain(open), [V(3, 1), V(3, 0), V(3, 5), V(3, 6), V(3, 7), V(1, 3), V(0, 3), V(5, 3), V(6, 3), V(7, 3)], "open lines")
	var next_to := _moves(Piece.Type.CHARGER, V(3, 3), [[V(4, 3), PAWN, BLACK], [V(3, 2), PAWN, WHITE]])
	check(not _plain(next_to).has(V(5, 3)) and _caps(next_to).is_empty(), "an adjacent piece blocks the line and can't be captured")
	var far := _moves(Piece.Type.CHARGER, V(3, 3), [[V(5, 3), PAWN, BLACK]])
	_same(_caps(far), [V(5, 3)], "an enemy two away can be captured")
	check(not _plain(far).has(V(6, 3)), "and stops the line")

func test_lancer_charges_forward_but_only_steps_elsewhere() -> void:
	_same(_plain(_moves(Piece.Type.LANCER, V(3, 4))), [V(3, 3), V(3, 2), V(3, 1), V(3, 0), V(3, 5), V(2, 4), V(4, 4)], "white lancer")
	var blocked := _moves(Piece.Type.LANCER, V(3, 4), [[V(3, 2), PAWN, BLACK]])
	_same(_caps(blocked), [V(3, 2)], "captures at the end of its charge")
	check(not _plain(blocked).has(V(3, 1)), "and can't pass")

func test_mirror_slides_diagonally_and_bounces_once() -> void:
	var moves := _moves(Piece.Type.MIRROR, V(5, 5))
	_same(_plain(moves), [
		V(6, 6), V(7, 7),                                     # up-right into the corner: nowhere to bounce
		V(6, 4), V(7, 3), V(6, 2), V(5, 1), V(4, 0),          # up-right off the right edge, back up-left
		V(4, 6), V(3, 7), V(2, 6), V(1, 5), V(0, 4),          # down-left off the bottom, back up-left
		V(4, 4), V(3, 3), V(2, 2), V(1, 1), V(0, 0),          # straight to the corner
	], "seventeen squares")

func test_mirror_stops_at_a_piece_after_bouncing() -> void:
	var moves := _moves(Piece.Type.MIRROR, V(5, 5), [[V(6, 2), PAWN, BLACK]])
	check(_caps(moves).has(V(6, 2)), "captures on the rebound leg")
	check(not _plain(moves).has(V(5, 1)), "and stops there")

func test_monk_slides_three_diagonally_and_steps_orthogonally_without_capturing() -> void:
	var moves := _moves(Piece.Type.MONK, V(3, 3), [[V(3, 2), PAWN, BLACK], [V(5, 5), PAWN, BLACK]])
	_same(_plain(moves), [
		V(4, 4), V(2, 4), V(1, 5), V(0, 6), V(4, 2), V(5, 1), V(6, 0), V(2, 2), V(1, 1), V(0, 0), V(3, 4), V(2, 3), V(4, 3)], "moves")
	_same(_caps(moves), [V(5, 5)], "captures only diagonally")

func test_ghost_passes_through_pieces_up_to_two_squares() -> void:
	_check_ghost_open()
	var moves := _moves(Piece.Type.GHOST, V(3, 3), [[V(3, 2), PAWN, WHITE], [V(4, 4), PAWN, BLACK]])
	check(not _plain(moves).has(V(3, 2)), "can't stop on a friend")
	check(_plain(moves).has(V(3, 1)), "but passes over it")
	_same(_caps(moves), [V(4, 4)], "captures the enemy")
	check(_plain(moves).has(V(5, 5)), "and passes over that too")

func _check_ghost_open() -> void:
	check_eq(_moves(Piece.Type.GHOST, V(3, 3)).size(), 16, "sixteen squares on an open board")

# ---- uncommon tier: hoppers ------------------------------------------------------

func test_cannon_moves_like_a_rook_and_captures_over_one_screen() -> void:
	var moves := _moves(Piece.Type.CANNON, V(3, 3), [
		[V(3, 1), PAWN, WHITE], [V(3, 0), PAWN, BLACK],       # up: a screen, then an enemy
		[V(5, 3), PAWN, BLACK], [V(7, 3), PAWN, BLACK],       # right: an enemy that is itself the screen, another behind
	])
	_same(_caps(moves), [V(3, 0), V(7, 3)], "captures beyond the screens")
	check(_plain(moves).has(V(3, 2)) and _plain(moves).has(V(4, 3)), "plain rook moves up to the screen")
	check(not _plain(moves).has(V(6, 3)) and not _plain(moves).has(V(3, 1)), "never past or onto a screen")
	for row in range(4, 8):
		check(_plain(moves).has(V(3, row)), "open line down %d" % row)

func test_cannon_cannot_capture_a_piece_with_no_screen_or_two_screens() -> void:
	var moves := _moves(Piece.Type.CANNON, V(3, 3), [[V(3, 2), PAWN, BLACK], [V(6, 3), PAWN, WHITE], [V(5, 3), PAWN, WHITE], [V(7, 3), PAWN, BLACK]])
	check(_caps(moves).is_empty(), "adjacent enemy and enemy behind two screens are both safe")

func test_grasshopper_hops_one_piece_and_lands_right_behind() -> void:
	var moves := _moves(Piece.Type.GRASSHOPPER, V(3, 3), [
		[V(3, 5), PAWN, WHITE],                                # over a friend onto an empty square
		[V(5, 5), PAWN, BLACK], [V(6, 6), PAWN, BLACK],        # over an enemy, capturing the one behind
		[V(2, 3), PAWN, BLACK], [V(1, 3), PAWN, WHITE],        # landing square occupied by a friend: no hop
	])
	_same(_plain(moves), [V(3, 6)], "the quiet hop")
	_same(_caps(moves), [V(6, 6)], "the capturing hop")

func test_griffon_steps_diagonally_then_runs_outward() -> void:
	var expected: Array = [V(4, 4), V(2, 4), V(4, 2), V(2, 2)]
	expected.append_array([V(5, 4), V(6, 4), V(7, 4), V(4, 5), V(4, 6), V(4, 7)])
	expected.append_array([V(1, 4), V(0, 4), V(2, 5), V(2, 6), V(2, 7)])
	expected.append_array([V(5, 2), V(6, 2), V(7, 2), V(4, 1), V(4, 0)])
	expected.append_array([V(1, 2), V(0, 2), V(2, 1), V(2, 0)])
	_same(_plain(_moves(Piece.Type.GRIFFON, V(3, 3))), expected, "twenty-four squares")
	var blocked := _moves(Piece.Type.GRIFFON, V(3, 3), [[V(4, 4), PAWN, BLACK]])
	_same(_caps(blocked), [V(4, 4)], "captures on the diagonal step")
	check(not _plain(blocked).has(V(5, 4)), "but can't run on from a occupied square")

func test_spearman_steps_like_a_king_and_captures_two_ahead() -> void:
	var open := _moves(Piece.Type.SPEARMAN, V(3, 4))
	check_eq(_plain(open).size(), 8, "king steps")
	var reach := _moves(Piece.Type.SPEARMAN, V(3, 4), [[V(3, 2), PAWN, BLACK]])
	check(_caps(reach).has(V(3, 2)), "captures two squares ahead")
	check_eq(_plain(reach).size(), 8, "and never moves two ahead without a capture")
	var blocked := _moves(Piece.Type.SPEARMAN, V(3, 4), [[V(3, 3), PAWN, WHITE], [V(3, 2), PAWN, BLACK]])
	check(_caps(blocked).is_empty(), "a friend in between blocks the thrust")

# ---- portals ----------------------------------------------------------------------

func test_leapers_and_hoppers_cross_portals() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	var hawk := _moves(Piece.Type.HAWK, V(3, 2), [], WHITE, a)
	check(has_move(hawk, b, V(0, 2)), "hawk: two squares right crosses the seam")

	var hopper := _moves(Piece.Type.GRASSHOPPER, V(3, 2), [[V(4, 2), PAWN, WHITE]], WHITE, a)
	check(has_move(hopper, b, V(0, 2)), "grasshopper: hops a screen at the seam and lands on board B")
	put(b, V(0, 2), PAWN, WHITE)
	var landing_taken := Piece.get_legal_moves(Piece.Type.GRASSHOPPER, WHITE, a, V(3, 2))
	check(not has_move(landing_taken, b, V(0, 2)), "but not onto a friend waiting there")

func test_cannon_screens_and_targets_can_be_on_the_next_board() -> void:
	var rig := make_rig([2])
	var a: Board = rig[0]
	var b: Board = rig[1]
	put(a, V(4, 2), PAWN, WHITE)                    # the screen, at the seam
	put(b, V(1, 2), PAWN, BLACK)                    # the target, beyond it
	var moves := _moves(Piece.Type.CANNON, V(2, 2), [], WHITE, a)
	check(has_move(moves, b, V(1, 2)) and moves.any(func(m): return m.board == b and m.square == V(1, 2) and m.capture), "captures across the seam")

func test_a_slider_follows_a_portal() -> void:
	var rig := make_rig([2])
	var moves := _moves(Piece.Type.RANGER, V(3, 2), [], WHITE, rig[0])
	check(has_move(moves, rig[1], V(0, 2)) and has_move(moves, rig[1], V(1, 2)), "ranger walks onto board B")
	check(not has_move(moves, rig[1], V(2, 2)), "but only three squares in total")

# ---- how the rest of the game sees them -------------------------------------------

func test_every_data_piece_has_a_tier_value_and_a_unique_label() -> void:
	var labels: Dictionary = {}
	for type in PieceDefs.types():
		var name: String = Piece.Type.find_key(type)
		check(Piece.value(type) > 0, "%s has a value" % name)
		check(PieceDefs.label(type).length() in [2, 3], "%s has a short label" % name)
		check(not labels.has(PieceDefs.label(type)), "%s label is unique" % name)
		labels[PieceDefs.label(type)] = true
		check(Piece.types_in_tier(Piece.tier(type)).has(type), "%s is listed in its tier" % name)
		check(not PieceDefs.rules(type).is_empty(), "%s has rules" % name)
	check(not labels.has("Ki") and not labels.has("Q"), "no clash with chess pieces")

func test_new_pieces_join_the_lottery_pools() -> void:
	var commons := Lottery.pool(Piece.Tier.COMMON)
	for type in [PAWN, Piece.Type.SCOUT, Piece.Type.SERF, Piece.Type.MILITIA, Piece.Type.CRAB]:
		check(commons.has(type), "common pool has %s" % Piece.Type.find_key(type))
	var uncommons := Lottery.pool(Piece.Tier.UNCOMMON)
	for type in [BISHOP, KNIGHT, Piece.Type.CAMEL, Piece.Type.GOLEM]:
		check(uncommons.has(type), "uncommon pool has %s" % Piece.Type.find_key(type))
	var rares := Lottery.pool(Piece.Tier.RARE)
	for type in [ROOK, Piece.Type.GRIFFON, Piece.Type.MIRROR, Piece.Type.CANNON]:
		check(rares.has(type), "rare pool has %s" % Piece.Type.find_key(type))
	check(Lottery.pool(Piece.Tier.LEGENDARY).is_empty(), "legendaries are never drawn")

func test_a_new_piece_can_be_deployed_and_costs_its_value() -> void:
	var run := RunState.new()
	run.begin()
	var id: int = run.add_to_roster(Piece.Type.CAMEL)
	var board := make_board(8, 8)
	board.zone_owner[V(3, 3)] = WHITE
	var before := Roster.points_used(run, [board])
	check(Roster.deploy(run, [board], id, board, V(3, 3)), "deployed")
	check_eq(Roster.points_used(run, [board]) - before, Piece.value(Piece.Type.CAMEL), "counts its value against the budget")

func test_the_ai_uses_a_new_piece() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [
		[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE],
		[V(2, 2), Piece.Type.CAMEL, BLACK], [V(5, 3), QUEEN, WHITE],          # a camel jump (3,1) from (2,2)
	])
	var choice := GreedyAI.choose_move(state, BLACK)
	check(not choice.is_empty() and choice.square == V(2, 2) and choice.move.square == V(5, 3), "the camel takes the queen")

func test_scoring_uses_the_new_piece_value() -> void:
	var current := MatchState.new()
	var victim := { "type": Piece.Type.RANGER, "side": BLACK }
	var attacker := { "type": PAWN, "side": WHITE }
	check_eq(Scoring.capture_score(current, attacker, victim, make_board(), V(0, 0)), Piece.value(Piece.Type.RANGER) * Scoring.CHIPS_PER_VALUE, "capture score follows the piece's value")

func test_the_sandbox_picker_places_any_data_piece() -> void:
	var main = await load_main()
	var board: Board = main.state.boards[0]
	var picker: OptionButton = main.panel.extra_piece_picker
	check_eq(picker.item_count, PieceDefs.types().size() + 1, "one entry per piece plus the prompt")
	for index in range(1, picker.item_count):
		if picker.get_item_metadata(index) != Piece.Type.GRIFFON:
			continue
		main._on_square_selected(V(1, 1), board)
		picker.select(index)
		picker.item_selected.emit(index)
		check(board.pieces.has(V(1, 1)) and board.pieces[V(1, 1)].type == Piece.Type.GRIFFON, "the griffon was placed")
		check_eq(picker.selected, 0, "the picker resets to its prompt")
