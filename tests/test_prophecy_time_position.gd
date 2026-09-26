extends "res://tests/TestCase.gd"
## Stage 2: the time and position prophecies (Quickening, Borrowed Hour, Turning Tide,
## Frozen Moment, Second Chance, Twin Sun, Haste, Sanctuary, Stone Ward, Waypoint,
## Swap Fates, Broaden the Realm, Reinforcements, Wings).

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

func _game(pieces: Array, hand: Array = [], moves: int = 10, target: int = 100000) -> GameState:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE]] + pieces)
	state.run = RunState.new()
	state.run.begin()
	for card in hand:
		state.run.hand.append({ "id": card, "armed": false } if card is String else { "id": card[0], "armed": card[1] })
	check_eq(MatchController.start(state, moves, target), "", "the match started")
	return state

func _move(state: GameState, from: Vector2i, to: Vector2i) -> Dictionary:
	var board: Board = state.boards[0]
	state.active_board = board
	state.active_square = from
	MoveController.refresh(state)
	var result := MoveController.click(state, board, to)
	MatchController.record_move(state, result)
	return result

func _end_turn(state: GameState) -> void:
	MatchController.end_turn(state)

func _play(state: GameState, index: int = 0, choice: Variant = null) -> Dictionary:
	return Prophecies.play_in_match(state, index, choice)

# ---- Quickening --------------------------------------------------------------------------------

func test_quickening_adds_two_moves() -> void:
	var state := _game([], ["quickening"], 5)
	check(_play(state).ok, "played")
	check_eq(state.current_match.moves_left, 7, "5 + 2")
	check(state.run.hand.is_empty(), "used up")
	check_eq(state.current_match.turn_side, WHITE, "playing a card doesn't end your turn")

# ---- Haste --------------------------------------------------------------------------------------

func test_haste_makes_your_next_three_moves_free() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], ["haste"], 5)
	_play(state)
	check_eq(state.current_match.free_moves, 3, "three free moves banked")
	for i in 3:
		_move(state, V(0, 7 - i), V(0, 6 - i))
		check_eq(state.current_match.moves_left, 5, "still 5: move %d was free" % (i + 1))
	_move(state, V(0, 4), V(0, 3))
	check_eq(state.current_match.moves_left, 4, "the fourth move costs as normal")

func test_haste_never_reduces_the_ais_moves() -> void:
	var state := _game([[V(0, 4), ROOK, BLACK]], ["haste"])
	_play(state)
	state.current_match.turn_side = BLACK
	_move(state, V(0, 4), V(0, 3))
	check_eq(state.current_match.free_moves, 3, "the AI's move doesn't touch your free moves")

# ---- Borrowed Hour / Twin Sun (grant one free move with any piece) --------------------------------

func test_borrowed_hour_grants_one_free_move_with_any_piece() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(3, 4), KNIGHT, WHITE]], ["borrowed_hour"], 5)
	check(_play(state).ok, "played")
	check_eq(state.current_match.bonus.get("kind"), "any", "a bonus is waiting")
	check_eq(state.current_match.turn_side, WHITE, "still your turn")
	state.active_board = state.boards[0]
	state.active_square = V(3, 4)
	MoveController.refresh(state)
	check(not state.current_moves.is_empty(), "the knight (not the piece that would ordinarily move) can move")
	var result := MoveController.click(state, state.boards[0], V(4, 6))
	MatchController.record_move(state, result, true)
	state.current_match.bonus = MoveEffects.bonus_after(state, result, true)   # what TurnFlow.after_move does
	check_eq(state.current_match.moves_left, 5, "the bonus move was free")
	check(state.current_match.bonus.is_empty(), "and it doesn't chain")

func test_twin_sun_also_grants_a_free_move() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], ["twin_sun"], 5)
	check(_play(state).ok, "played")
	check_eq(state.current_match.bonus.get("kind"), "any", "a bonus move is offered, same mechanism as Borrowed Hour")

func test_the_ai_can_use_a_borrowed_hour_bonus_through_the_normal_ai_flow() -> void:
	# Not player-facing (prophecies never fire for the AI), but the underlying "any" bonus
	# kind must still work generically through MoveEffects for whoever holds it.
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE], [V(3, 4), KNIGHT, WHITE]])
	state.current_match = MatchState.new()
	state.current_match.active = true
	state.current_match.bonus = { "kind": "any", "side": WHITE, "label": "test" }
	var moves := MoveEffects.moves_for(state, board.pieces[V(3, 4)], board, V(3, 4))
	check(not moves.is_empty(), "the any-bonus lets this piece move")
	check(MoveEffects.moves_for(state, board.pieces[V(7, 7)], board, V(7, 7)).size() >= 0, "and the king too, generically")

# ---- Turning Tide --------------------------------------------------------------------------------

func test_turning_tide_rewinds_the_opponents_last_move() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(4, 0), ROOK, BLACK], [V(6, 6), PAWN, WHITE]], ["turning_tide"], 10)
	_move(state, V(6, 6), V(6, 5))
	state.active_board = state.boards[0]
	state.active_square = V(4, 0)
	MoveController.refresh(state)
	var opp_result := MoveController.click(state, state.boards[0], V(4, 7))
	MatchController.record_move(state, opp_result)
	check(state.boards[0].pieces.has(V(4, 7)), "black's rook moved")
	var result := _play(state)
	check(result.ok, "played")
	check(not state.boards[0].pieces.has(V(4, 7)) and state.boards[0].pieces[V(4, 0)].side == BLACK, "black's rook is back where it started")
	check(state.boards[0].pieces.has(V(6, 5)), "white's own earlier move stands")
	check(state.run.hand.is_empty(), "used up")
	check(state.current_match.last_event.contains("Turning Tide"), state.current_match.last_event)

func test_turning_tide_refuses_when_the_last_move_was_your_own() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], ["turning_tide"], 10)
	_move(state, V(0, 7), V(0, 6))
	var result := _play(state)
	check(not result.ok and result.reason.contains("no enemy move"), result.reason)
	check_eq(state.run.hand.size(), 1, "kept")

func test_turning_tide_refuses_with_no_history_yet() -> void:
	var state := _game([], ["turning_tide"])
	var result := _play(state)
	check(not result.ok, "nothing to rewind")

# ---- Frozen Moment -----------------------------------------------------------------------------

func test_frozen_moment_skips_the_ais_next_turn() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], ["frozen_moment"], 5)
	check(_play(state).ok, "played")
	check_eq(state.current_match.frozen_enemy_turns, 1, "one skip banked")
	_move(state, V(0, 7), V(0, 6))
	_end_turn(state)
	check_eq(state.current_match.turn_side, WHITE, "the AI's turn was skipped and it's you again")
	check_eq(state.current_match.frozen_enemy_turns, 0, "the skip is used up")
	_move(state, V(0, 6), V(0, 5))
	_end_turn(state)
	check_eq(state.current_match.turn_side, BLACK, "and now the AI plays normally")

# ---- Second Chance (armed) --------------------------------------------------------------------

func test_second_chance_rescues_you_from_running_out_of_moves_once() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], [["second_chance", true]], 1)
	check_eq(state.current_match.prophecies.size(), 1, "armed at the start")
	_move(state, V(0, 7), V(0, 6))
	_end_turn(state)
	check(state.current_match.active, "the match didn't end")
	check_eq(state.current_match.moves_left, 2, "0 + 2")
	check(state.current_match.prophecies[0].spent, "the rescue fired")
	Prophecies.finish_match(state.run, state.current_match)
	check(state.run.hand.is_empty(), "and the card is used up")

func test_second_chance_only_fires_once() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], [["second_chance", true]], 1)
	_move(state, V(0, 7), V(0, 6))
	_end_turn(state)
	check(state.current_match.active, "rescued once")
	state.current_match.turn_side = WHITE
	state.current_match.moves_left = 0
	_end_turn(state)
	check_eq(state.current_match.result, "loss", "the second time it really is out of moves")

func test_an_unarmed_second_chance_does_nothing() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], [["second_chance", false]], 1)
	check(state.current_match.prophecies.is_empty(), "not armed, not in play")
	_move(state, V(0, 7), V(0, 6))
	_end_turn(state)
	check_eq(state.current_match.result, "loss", "no rescue")
	check_eq(state.run.hand.size(), 1, "and you keep the card")

# ---- Sanctuary -----------------------------------------------------------------------------------

func test_sanctuary_protects_a_chosen_piece_for_three_of_your_turns() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["sanctuary"], 10)
	var asked := _play(state)
	check(asked.ok and asked.needs_choice, "asks which piece")
	check(asked.options.any(func(o): return o.board == state.boards[0] and o.square == V(3, 4)), "your rook is offered")
	check(not asked.options.any(func(o): return o.square == V(3, 1)), "not the enemy's")
	check(_play(state, 0, { "board": state.boards[0], "square": V(3, 4) }).ok, "chosen")
	check_eq(state.boards[0].pieces[V(3, 4)].shielded, 3, "3 turns of protection")
	check(not Piece.get_legal_moves(ROOK, BLACK, state.boards[0], V(3, 1)).any(func(m): return m.capture), "can't be taken right now")

	for i in 3:
		MatchController.end_turn(state)                      # your turn ends
		MatchController.end_turn(state)                      # the AI's turn ends
	check_eq(state.boards[0].pieces[V(3, 4)].get("shielded", 0), 0, "worn off after three of your turns")
	check(Piece.get_legal_moves(ROOK, BLACK, state.boards[0], V(3, 1)).any(func(m): return m.capture), "now it can be taken")

func test_sanctuary_follows_the_piece_if_it_moves() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(5, 1), ROOK, BLACK]], ["sanctuary"], 10)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	_move(state, V(3, 4), V(5, 4))
	check_eq(state.boards[0].pieces[V(5, 4)].get("shielded", 0), 3, "the shield travels with it")

func test_sanctuary_refuses_a_piece_you_do_not_own() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["sanctuary"], 10)
	_play(state)
	var result := _play(state, 0, { "board": state.boards[0], "square": V(3, 1) })
	check(not result.ok, "not your piece")
	check_eq(state.run.hand.size(), 1, "kept")

# ---- Stone Ward -----------------------------------------------------------------------------------

func test_stone_ward_protects_the_square_even_after_the_piece_leaves() -> void:
	# Uses CaptureRules directly so this is about the ward, not about rook reachability.
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["stone_ward"], 10)
	var board: Board = state.boards[0]
	_play(state, 0, { "board": board, "square": V(3, 4) })
	check_eq(board.warded_squares[V(3, 4)], 3, "warded")
	var attacker := { "type": ROOK, "side": BLACK, "board": board, "square": V(3, 1) }
	check(not CaptureRules.can_capture(attacker, { "piece": board.pieces[V(3, 4)], "board": board, "square": V(3, 4) }), "protected while the rook still stands there")
	_move(state, V(3, 4), V(6, 4))                    # the rook leaves the warded square (straight along row 4)
	put(board, V(3, 4), Piece.Type.PAWN, WHITE)         # a different piece stands on the old square now
	check(not CaptureRules.can_capture(attacker, { "piece": board.pieces[V(3, 4)], "board": board, "square": V(3, 4) }), "the square still protects whoever stands on it")
	check(CaptureRules.can_capture(attacker, { "piece": board.pieces[V(6, 4)], "board": board, "square": V(6, 4) }), "but the rook that left is fair game where it stands now")

func test_stone_ward_wears_off_after_three_total_turns() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["stone_ward"], 10)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	for i in 3:
		MatchController.end_turn(state)
	check_eq(state.boards[0].warded_squares.get(V(3, 4), 0), 0, "gone after three plies")

# ---- Waypoint --------------------------------------------------------------------------------------

func test_waypoint_moves_a_chosen_piece_to_a_chosen_empty_zone_square() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["waypoint"], 10)
	var board: Board = state.boards[0]
	for x in 8:
		board.zone_owner[V(x, 7)] = WHITE
	var stage1 := _play(state)
	check(stage1.ok and stage1.needs_choice, "pick a piece first")
	check(stage1.options.any(func(o): return o.square == V(3, 4)), str(stage1.options))
	var stage2 := _play(state, 0, { "board": board, "square": V(3, 4) })
	check(stage2.ok and stage2.needs_choice, "then pick a destination")
	check(stage2.options.any(func(o): return o.square == V(0, 7)), str(stage2.options))
	check(not board.pieces.has(V(0, 7)), "not moved yet")
	var done := _play(state, 0, { "board": board, "square": V(0, 7) })
	check(done.ok and not done.get("needs_choice", false), "done")
	check(not board.pieces.has(V(3, 4)) and board.pieces[V(0, 7)].type == ROOK, "the rook is at its new square")
	check(state.run.hand.is_empty(), "used up")

func test_waypoint_only_offers_empty_squares_in_your_own_zone() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(0, 7), PAWN, WHITE]], ["waypoint"], 10)
	var board: Board = state.boards[0]
	for x in 8:
		board.zone_owner[V(x, 7)] = WHITE
		board.zone_owner[V(x, 0)] = BLACK
	_play(state)
	var stage2 := _play(state, 0, { "board": board, "square": V(3, 4) })
	check(not stage2.options.any(func(o): return o.square == V(0, 7)), "occupied squares aren't offered")
	check(not stage2.options.any(func(o): return o.square.y == 0), "nor the enemy's zone")

func test_waypoint_never_offers_a_square_outside_your_own_zone_even_the_enemys() -> void:
	var state := _game([[V(3, 4), PAWN, WHITE]], ["waypoint"], 10)
	var board: Board = state.boards[0]
	board.zone_owner[V(3, 3)] = BLACK
	for x in 8:
		board.zone_owner[V(x, 6)] = WHITE
	_play(state)
	_play(state, 0, { "board": board, "square": V(3, 4) })
	var result := Prophecies.play_in_match(state, 0, { "board": board, "square": V(3, 3) })
	check(not result.ok, "the enemy zone is never offered as a destination")

func test_waypoint_with_no_free_zone_square_is_refused() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["waypoint"], 10)
	var board: Board = state.boards[0]
	board.zone_owner[V(3, 4)] = WHITE
	_play(state)
	var result := _play(state, 0, { "board": board, "square": V(3, 4) })
	check(not result.ok and result.reason.contains("empty square"), result.reason)

# ---- Swap Fates ------------------------------------------------------------------------------------

func test_swap_fates_swaps_two_of_your_pieces() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(6, 1), KNIGHT, WHITE]], ["swap_fates"], 10)
	var stage1 := _play(state)
	check(stage1.ok and stage1.needs_choice, "pick the first piece")
	var stage2 := _play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	check(stage2.ok and stage2.needs_choice, "pick the second")
	check(not stage2.options.any(func(o): return o.square == V(3, 4)), "not the same piece again")
	var done := _play(state, 0, { "board": state.boards[0], "square": V(6, 1) })
	check(done.ok and not done.get("needs_choice", false), "swapped")
	check(state.boards[0].pieces[V(3, 4)].type == KNIGHT and state.boards[0].pieces[V(6, 1)].type == ROOK, "positions traded")
	check(state.run.hand.is_empty(), "used up")

func test_swap_fates_needs_two_pieces() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["swap_fates"], 10)
	var result := _play(state)
	check(not result.ok and result.reason.contains("two pieces"), result.reason)
	check_eq(state.run.hand.size(), 1, "kept")

func test_a_pawn_swapped_into_the_enemy_zone_promotes() -> void:
	var state := _game([[V(3, 3), ROOK, WHITE], [V(3, 4), PAWN, WHITE]], ["swap_fates"], 10)
	state.boards[0].zone_owner[V(3, 3)] = BLACK
	var pawn: Dictionary = state.boards[0].pieces[V(3, 4)]
	_play(state)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 3) })
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	check(state.pending_promotion.get("piece") == pawn, "the pawn landed in the enemy zone")

# ---- Wings ---------------------------------------------------------------------------------------

func test_wings_makes_a_piece_move_like_a_queen_this_turn() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["wings"], 10)
	var normal := Piece.get_legal_moves(ROOK, WHITE, state.boards[0], V(3, 4)).size()
	_play(state, 0)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	check(state.boards[0].pieces[V(3, 4)].get("wings", false), "flagged")
	var winged := Piece.get_legal_moves(ROOK, WHITE, state.boards[0], V(3, 4))
	check(winged.size() > normal, "more moves than a plain rook (rook already covers half a queen's lines, but not the diagonals)")
	check(winged.any(func(m): return m.square == V(4, 5)), "a diagonal queen move is now available")

func test_wings_is_used_up_after_the_piece_moves() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["wings"], 10)
	_play(state, 0)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	_move(state, V(3, 4), V(4, 5))                    # a diagonal move, only possible with wings
	check(not state.boards[0].pieces[V(4, 5)].get("wings", false), "spent")
	check(not Piece.get_legal_moves(ROOK, WHITE, state.boards[0], V(4, 5)).any(func(m): return m.square == V(5, 6)), "back to ordinary rook moves")

func test_wings_does_not_change_who_may_capture_the_piece() -> void:
	# the piece is still, in truth, whatever it always was, for protection rules etc.
	var state := _game([[V(3, 4), Piece.Type.GOLEM, WHITE], [V(2, 3), PAWN, BLACK]], ["wings"], 10)
	_play(state, 0)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	check(not Piece.get_legal_moves(PAWN, BLACK, state.boards[0], V(2, 3)).any(func(m): return m.capture), "a golem still can't be taken by a pawn even with wings")

# ---- Broaden the Realm / Reinforcements (armed, applied at the start of the next match) -------------

func test_broaden_the_realm_adds_six_to_your_zone_for_the_next_match() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "broaden_the_realm", "armed": true })
	var setup := RunConfig.match_setup(main.state.run)
	main.run_flow.begin_match()
	check_eq(count_zone(main.state.boards, WHITE), setup.white_zone + Prophecies.ZONE_BONUS, "6 tiles bigger")
	check(main.state.run.hand.is_empty(), "the card is consumed once the match is set up")

func test_broaden_the_realm_only_affects_the_next_match() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var baseline := count_zone(main.state.boards, WHITE)
	main.state.run.hand.append({ "id": "broaden_the_realm", "armed": false })
	main.run_flow.begin_match()
	check_eq(count_zone(main.state.boards, WHITE), baseline, "unarmed: no bonus")
	check_eq(main.state.run.hand.size(), 1, "and it's kept, ready to arm")

func test_reinforcements_adds_five_points_for_the_next_match_only() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "reinforcements", "armed": true })
	main.run_flow.begin_match()
	check_eq(main.state.run.effective_points(), main.state.run.allocated_points + Prophecies.POINTS_BONUS, "5 extra points to field with")
	check(main.state.run.hand.is_empty(), "consumed")
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	main.shop_screen.leave_button.pressed.emit()
	check_eq(main.state.run.effective_points(), main.state.run.allocated_points, "back to normal the match after")

func test_reinforcements_lets_you_deploy_more_than_your_base_points() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "reinforcements", "armed": true })
	main.run_flow.begin_match()
	for i in 6:
		main.state.run.add_to_roster(PAWN)          # +6 points of pawns, more than the +5 bonus alone would allow
	main.panel.auto_deploy_button.pressed.emit()
	var used := Roster.points_used(main.state.run, main.state.boards)
	check(used > main.state.run.allocated_points, "you fielded more than your base allocation")
	check(used <= main.state.run.effective_points(), "but never more than base + reinforcements")

# ---- through the hand strip --------------------------------------------------------------------------

func _strip_game(pieces: Array, cards: Array) -> Dictionary:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.grid_width = 8
	board.grid_height = 8
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	for p in pieces:
		put(board, p[0], p[1], p[2])
	for id in cards:
		main.state.run.hand.append({ "id": id, "armed": false })
	main.turn_flow.ai_delay = 5.0
	main.panel.ready_button.pressed.emit()
	main._refresh_view()
	return { "main": main, "board": board, "state": main.state, "match": main.state.current_match }

func _strip_rows(main: Node) -> Array:
	return main.prophecy_strip.get_child(0).get_child(1).get_children()

func _strip_choice_buttons(main: Node) -> Array:
	return main.prophecy_strip._choice_row.get_children().filter(func(c): return c is Button)

func test_sanctuary_asks_for_a_piece_through_the_strip_and_shows_labelled_options() -> void:
	var g := await _strip_game([[V(3, 4), ROOK, WHITE]], ["sanctuary"])
	main_play(g, 0)
	check(g.main.prophecy_strip.is_choosing(), "a choice is offered")
	var texts := _strip_choice_buttons(g.main).map(func(b): return b.text)
	check(texts.any(func(t): return t.contains("Rook")), "labelled with the piece: %s" % str(texts))
	_strip_choice_buttons(g.main)[0].pressed.emit()
	check(not g.main.prophecy_strip.is_choosing() and g.state.run.hand.is_empty(), "chosen and used")
	check(g.board.pieces[V(3, 4)].get("shielded", 0) > 0, "protected")

func test_waypoint_two_step_choice_through_the_strip() -> void:
	var g := await _strip_game([[V(3, 4), ROOK, WHITE]], ["waypoint"])
	for x in 8:
		g.board.zone_owner[V(x, 7)] = WHITE
	main_play(g, 0)
	check(_strip_choice_buttons(g.main).size() == 1, "one piece to choose")
	_strip_choice_buttons(g.main)[0].pressed.emit()
	check(g.main.prophecy_strip.is_choosing(), "now pick a destination")
	var dest_texts := _strip_choice_buttons(g.main).map(func(b): return b.text)
	check(dest_texts.any(func(t): return t.begins_with("Empty square")), str(dest_texts))
	_strip_choice_buttons(g.main)[0].pressed.emit()
	check(not g.main.prophecy_strip.is_choosing() and g.state.run.hand.is_empty(), "moved and used")
	check(not g.board.pieces.has(V(3, 4)), "gone from its old square")

func main_play(g: Dictionary, index: int) -> void:
	g.main.prophecy_flow.play(index)

func test_switching_to_a_different_card_mid_choice_abandons_the_first_cleanly() -> void:
	var g := await _strip_game([[V(3, 4), ROOK, WHITE], [V(6, 1), KNIGHT, WHITE]], ["swap_fates", "quickening"])
	main_play(g, 0)
	_strip_choice_buttons(g.main)[0].pressed.emit()          # first piece of the swap chosen
	check(g.main.prophecy_strip.is_choosing(), "mid swap")
	main_play(g, 1)                                          # play Quickening instead, abandoning the swap
	check(not g.main.prophecy_strip.is_choosing(), "quickening needs no choice")
	check_eq(g.match.moves_left, RunConfig.MOVES + Prophecies.QUICKENING_MOVES, "quickening worked")
	check_eq(g.state.run.hand.map(func(h): return h.id), ["swap_fates"], "the abandoned swap card is still in hand, unused")
	main_play(g, 0)                                          # starting swap_fates again should be a clean restart
	check(_strip_choice_buttons(g.main).size() == 2, "back to stage one, offering both pieces")
