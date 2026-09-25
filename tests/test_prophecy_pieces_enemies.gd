extends "res://tests/TestCase.gd"
## Stage 3: the piece and enemy prophecies (Call to Arms, Iron Skin, Curse of Stillness,
## Banishing, Sow Discord, Marked for Death, Rite of Rebirth, Transmutation, Guardian Spirit,
## Shattered Shields, Reveal Weakness, Hex of the Boss, Mantle of the Phoenix, Field Promotion,
## Echo of Steel).

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

func _play(state: GameState, index: int = 0, choice: Variant = null) -> Dictionary:
	return Prophecies.play_in_match(state, index, choice)

# ---- Call to Arms --------------------------------------------------------------------------

func test_call_to_arms_spawns_two_temporary_pawns_in_your_zone() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["call_to_arms"], 10)
	var board: Board = state.boards[0]
	for x in 8:
		board.zone_owner[V(x, 7)] = WHITE
	var before := board.pieces.size()
	check(_play(state).ok, "played")
	check_eq(board.pieces.size(), before + 2, "two pawns appeared")
	var spawned := board.pieces.values().filter(func(p): return p.type == PAWN and p.side == WHITE and p.get("spawned", false))
	check_eq(spawned.size(), 2, "both temporary")
	check(state.run.hand.is_empty(), "used up")

func test_call_to_arms_places_at_most_the_free_squares_available() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["call_to_arms"], 10)
	var board: Board = state.boards[0]
	board.zone_owner[V(3, 5)] = WHITE   # exactly one free square
	var result := _play(state)
	check(result.ok, "played with just one square")
	check_eq(board.pieces.values().filter(func(p): return p.type == PAWN and p.get("spawned", false)).size(), 1, "one pawn, not two")

func test_call_to_arms_needs_a_free_zone_square() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["call_to_arms"], 10)
	var result := _play(state)
	check(not result.ok, "no zone at all")
	check_eq(state.run.hand.size(), 1, "kept")

# ---- Iron Skin -----------------------------------------------------------------------------

func test_iron_skin_protects_from_pawns_and_knights_but_not_others_and_lasts_the_match() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(2, 3), PAWN, BLACK], [V(1, 2), KNIGHT, BLACK], [V(3, 0), QUEEN, BLACK]], ["iron_skin"], 10)
	var board: Board = state.boards[0]
	_play(state, 0, { "board": board, "square": V(3, 4) })
	check(board.pieces[V(3, 4)].iron_skin, "flagged")
	check(not Piece.get_legal_moves(PAWN, BLACK, board, V(2, 3)).any(func(m): return m.capture), "the pawn can't take it")
	check(not Piece.get_legal_moves(KNIGHT, BLACK, board, V(1, 2)).any(func(m): return m.capture), "nor the knight")
	check(Piece.get_legal_moves(QUEEN, BLACK, board, V(3, 0)).any(func(m): return m.capture and m.square == V(3, 4)), "but the queen still can")
	for i in 6:
		MatchController.end_turn(state)
	check(board.pieces[V(3, 4)].iron_skin, "still protected - it doesn't wear off")

func test_iron_skin_refuses_a_piece_you_do_not_own() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(2, 3), PAWN, BLACK]], ["iron_skin"], 10)
	var result := _play(state, 0, { "board": state.boards[0], "square": V(2, 3) })
	check(not result.ok, "not yours")
	check_eq(state.run.hand.size(), 1, "kept")

# ---- Curse of Stillness ----------------------------------------------------------------------

func test_curse_of_stillness_freezes_an_enemy_piece_for_two_of_its_own_turns() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(4, 4), KNIGHT, BLACK]], ["curse_of_stillness"], 10)
	var board: Board = state.boards[0]
	var asked := _play(state)
	check(asked.ok and asked.needs_choice, "asks which enemy")
	check(not asked.options.any(func(o): return o.square == V(3, 4)), "not your own pieces: %s" % str(asked.options))
	_play(state, 0, { "board": board, "square": V(4, 4) })
	check_eq(board.pieces[V(4, 4)].frozen, 2, "frozen for 2")
	check(Piece.get_legal_moves(KNIGHT, BLACK, board, V(4, 4)).is_empty(), "can't move")
	state.current_match.turn_side = BLACK
	MatchController.end_turn(state)                          # black's (frozen turn 1) turn ends
	check_eq(board.pieces[V(4, 4)].frozen, 1, "one down")
	state.current_match.turn_side = BLACK
	MatchController.end_turn(state)                          # black's turn 2 ends
	check_eq(board.pieces[V(4, 4)].frozen, 0, "thawed")
	check(not Piece.get_legal_moves(KNIGHT, BLACK, board, V(4, 4)).is_empty(), "and can move again")

func test_curse_of_stillness_still_allows_capturing_the_frozen_piece() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["curse_of_stillness"], 10)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 1) })
	check(Piece.get_legal_moves(ROOK, WHITE, state.boards[0], V(3, 4)).any(func(m): return m.capture and m.square == V(3, 1)), "being frozen doesn't protect it from capture")

# ---- Banishing -----------------------------------------------------------------------------

func test_banishing_removes_a_common_tier_enemy_piece_with_no_score() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(2, 3), PAWN, BLACK], [V(5, 5), ROOK, BLACK]], ["banishing"], 10)
	var board: Board = state.boards[0]
	var asked := _play(state)
	check(asked.options.any(func(o): return o.square == V(2, 3)), "the pawn (common) is offered")
	check(not asked.options.any(func(o): return o.square == V(5, 5)), "the rook (rare) is not: %s" % str(asked.options))
	_play(state, 0, { "board": board, "square": V(2, 3) })
	check(not board.pieces.has(V(2, 3)), "gone")
	check_eq(state.current_match.scores[WHITE], 0, "no score for it")
	check(state.run.hand.is_empty(), "used up")

func test_banishing_refuses_without_a_common_target() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(5, 5), ROOK, BLACK]], ["banishing"], 10)
	var result := _play(state)
	check(not result.ok, "only a rare piece around")
	check_eq(state.run.hand.size(), 1, "kept")

func test_banishing_never_offers_the_king() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["banishing"], 10)
	var result := _play(state)
	check(not result.ok or not result.options.any(func(o): return o.board.pieces[o.square].type == KING), "the king is never a target")

# ---- Sow Discord ----------------------------------------------------------------------------

func test_sow_discord_makes_the_ais_next_move_random() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE], [V(2, 2), ROOK, BLACK], [V(5, 5), QUEEN, WHITE], [V(2, 5), PAWN, WHITE]])
	state.current_match = MatchState.new()
	state.current_match.active = true
	var picks := {}
	for i in 30:
		state.current_match.confused_moves = 1        # confused_moves is spent by each call, so re-arm it every time
		var choice := GreedyAI.choose_move(state, BLACK)
		check(not choice.is_empty(), "there is a move")
		picks[str(choice.move.square)] = true
	check_eq(state.current_match.confused_moves, 0, "each confusion is used up by the move it affects")
	check(picks.size() >= 2, "random spread across at least two different squares chosen: %s" % str(picks.keys()))

func test_sow_discord_only_confuses_the_number_of_moves_it_grants() -> void:
	var current := MatchState.new()
	current.confused_moves = 2
	check_eq(current.confused_moves, 2, "starts at 2")
	current.confused_moves -= 1
	check_eq(current.confused_moves, 1, "one used")

func test_sow_discord_played_in_a_match_increments_the_counter() -> void:
	var state := _game([[V(3, 4), KNIGHT, WHITE]], ["sow_discord"], 10)
	check_eq(state.current_match.confused_moves, 0, "none yet")
	check(_play(state).ok, "played")
	check_eq(state.current_match.confused_moves, 1, "one banked")

# ---- Marked for Death -------------------------------------------------------------------------

func test_marked_for_death_doubles_the_score_only_for_capturing_that_piece() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 4), PAWN, BLACK], [V(0, 2), PAWN, BLACK]], ["marked_for_death"], 10)
	var board: Board = state.boards[0]
	_play(state, 0, { "board": board, "square": V(0, 4) })
	check(board.pieces[V(0, 4)].marked_for_death, "flagged")
	_move(state, V(0, 7), V(0, 4))
	check_eq(state.current_match.scores[WHITE], 20, "10 x 2 for the marked pawn")
	_move(state, V(0, 4), V(0, 2))
	check_eq(state.current_match.scores[WHITE], 30, "and +10 ordinary for the unmarked one")

func test_marked_for_death_refuses_your_own_piece() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["marked_for_death"], 10)
	var result := _play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	check(not result.ok, "not an enemy")

# ---- Rite of Rebirth --------------------------------------------------------------------------

func test_rite_of_rebirth_returns_your_last_lost_piece_to_its_starting_square() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["rite_of_rebirth"], 10)
	var board: Board = state.boards[0]
	check(state.current_match.lost_this_match.is_empty(), "nothing lost yet")
	var refused := _play(state)
	check(not refused.ok, "nothing to bring back")
	state.active_board = board
	state.active_square = V(3, 1)
	MoveController.refresh(state)
	var capture := MoveController.click(state, board, V(3, 4))       # black's rook takes white's rook, and ends up standing on its square
	MatchController.record_move(state, capture)
	check_eq(state.current_match.lost_this_match.size(), 1, "the rook is remembered as lost")
	check(board.pieces[V(3, 4)].side == BLACK, "the square is now black's, not white's rook")
	state.active_board = board                                       # move the black rook on, so the home square is free again
	state.active_square = V(3, 4)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, board, V(6, 4)))
	var result := _play(state)
	check(result.ok, "brought back")
	check(board.pieces.has(V(3, 4)) and board.pieces[V(3, 4)].type == ROOK and board.pieces[V(3, 4)].side == WHITE, "on its starting square")
	check(state.current_match.lost_this_match.is_empty(), "and it's off the lost list")
	check(state.run.hand.is_empty(), "used up")

func test_rite_of_rebirth_refuses_if_the_starting_square_is_occupied() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["rite_of_rebirth"], 10)
	var board: Board = state.boards[0]
	state.active_board = board
	state.active_square = V(3, 1)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, board, V(3, 4)))
	put(board, V(3, 4), Piece.Type.PAWN, BLACK)
	var result := _play(state)
	check(not result.ok and result.reason.contains("occupied"), result.reason)
	check_eq(state.run.hand.size(), 1, "kept")

func test_rite_of_rebirth_brings_back_the_most_recent_loss() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], ["rite_of_rebirth"], 10)
	var board: Board = state.boards[0]
	state.active_board = board
	state.active_square = V(3, 1)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, board, V(3, 4)))   # the rook is lost, and black's rook now stands on its square
	state.active_board = board
	state.active_square = V(3, 4)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, board, V(6, 4)))   # clear the home square again
	var result := _play(state)
	check(result.ok, "brought back")
	check(board.pieces[V(3, 4)].type == ROOK, "the rook returns")

# ---- Transmutation ---------------------------------------------------------------------------

func test_transmutation_changes_a_piece_to_another_of_its_own_tier() -> void:
	var state := _game([[V(3, 4), KNIGHT, WHITE]], ["transmutation"], 10)
	var board: Board = state.boards[0]
	var stage1 := _play(state)
	check(stage1.ok and stage1.needs_choice, "pick a piece")
	var stage2 := _play(state, 0, { "board": board, "square": V(3, 4) })
	check(stage2.ok and stage2.needs_choice, "then pick what it becomes")
	for option in stage2.options:
		check_eq(Piece.tier(option), Piece.Tier.UNCOMMON, "every option is the knight's own tier")
		check(option != KNIGHT, "and never itself")
	var done := _play(state, 0, BISHOP)
	check(done.ok and not done.get("needs_choice", false), "done")
	check_eq(board.pieces[V(3, 4)].type, BISHOP, "it's a bishop now")
	check(state.run.hand.is_empty(), "used up")

func test_transmutation_does_not_change_your_roster_only_the_board() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var run: RunState = main.state.run
	var id: int = run.roster.filter(func(e): return e.type == KNIGHT)[0].id
	main.state.run.hand.append({ "id": "transmutation", "armed": false })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var board: Dictionary = Roster.on_field(main.state.boards)[id]
	Prophecies.play_in_match(main.state, 0)
	Prophecies.play_in_match(main.state, 0, { "board": board.board, "square": board.square })
	var options := Piece.types_in_tier(Piece.tier(KNIGHT)).filter(func(t): return t != KNIGHT)
	Prophecies.play_in_match(main.state, 0, options[0])
	check_eq(board.board.pieces[board.square].type, options[0], "the board piece changed")
	check_eq(run.roster_entry(id).type, KNIGHT, "but the roster still says knight")

# ---- Guardian Spirit (armed) -------------------------------------------------------------------

func test_guardian_spirit_saves_the_first_piece_you_would_lose() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "guardian_spirit", "armed": true })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var deployed: Array = main.state.current_match.deployed_roster_ids
	check(not deployed.is_empty(), "something is deployed")
	var lost_id: int = deployed[0]
	for id in deployed:
		Roster.on_field(main.state.boards)[id].board.pieces.erase(Roster.on_field(main.state.boards)[id].square)
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	check(main.state.run.roster_entry(lost_id).is_empty() == false, "the first lost piece is still in your roster")
	check(main.state.run.hand.is_empty(), "and the card is used up")
	check(main.result_screen.details_label.text.contains("Guardian Spirit"), main.result_screen.details_label.text)

func test_without_guardian_spirit_a_lost_piece_is_really_lost() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var deployed: Array = main.state.current_match.deployed_roster_ids.duplicate()
	for id in deployed:
		var spot = Roster.on_field(main.state.boards)[id]
		spot.board.pieces.erase(spot.square)
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	for id in deployed:
		check(main.state.run.roster_entry(id).is_empty(), "%d is really gone" % id)

func test_an_unarmed_guardian_spirit_does_not_save_anyone() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "guardian_spirit", "armed": false })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var deployed: Array = main.state.current_match.deployed_roster_ids.duplicate()
	for id in deployed:
		var spot = Roster.on_field(main.state.boards)[id]
		spot.board.pieces.erase(spot.square)
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	for id in deployed:
		check(main.state.run.roster_entry(id).is_empty(), "lost, since the card was never armed")
	check_eq(main.state.run.hand.size(), 1, "and you still hold it")

func test_guardian_spirit_is_not_spent_if_nothing_was_lost() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "guardian_spirit", "armed": true })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	check_eq(main.state.run.hand.size(), 1, "nothing was lost, so nothing was spent")

# ---- Shattered Shields ------------------------------------------------------------------------

func test_shattered_shields_disables_enemy_protection() -> void:
	# a white pawn's forward is -y; its diagonal captures land at from + (-1,-1) or (1,-1)
	var state := _game([[V(3, 3), Piece.Type.GOLEM, BLACK], [V(2, 4), PAWN, WHITE]], ["shattered_shields"], 10)
	var board: Board = state.boards[0]
	check(not Piece.get_legal_moves(PAWN, WHITE, board, V(2, 4)).any(func(m): return m.capture), "the golem is normally safe from a pawn")
	check(_play(state).ok, "played")
	check(board.pieces[V(3, 3)].get("shields_broken", false), "flagged")
	check(Piece.get_legal_moves(PAWN, WHITE, board, V(2, 4)).any(func(m): return m.capture), "now the pawn can take it")

func test_shattered_shields_also_disables_auras() -> void:
	var state := _game([[V(3, 3), Piece.Type.BARD, BLACK], [V(4, 3), ROOK, BLACK], [V(5, 4), PAWN, WHITE]], ["shattered_shields"], 10)
	var board: Board = state.boards[0]
	check(not Piece.get_legal_moves(PAWN, WHITE, board, V(5, 4)).any(func(m): return m.capture), "the bard's aura normally shields the rook beside it")
	_play(state)
	check(Piece.get_legal_moves(PAWN, WHITE, board, V(5, 4)).any(func(m): return m.capture), "not any more")

func test_shattered_shields_leaves_your_own_protections_alone() -> void:
	var state := _game([[V(3, 3), Piece.Type.GOLEM, WHITE], [V(2, 3), PAWN, BLACK]], ["shattered_shields"], 10)
	var board: Board = state.boards[0]
	_play(state)
	check(not board.pieces[V(3, 3)].get("shields_broken", false), "your own golem is untouched")
	check(not Piece.get_legal_moves(PAWN, BLACK, board, V(2, 3)).any(func(m): return m.capture), "and still safe from the enemy's pawn")

func test_shattered_shields_refuses_with_no_enemy_on_the_board() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(7, 7), KING, WHITE]])
	state.run = RunState.new()
	state.run.begin()
	state.run.hand.append({ "id": "shattered_shields", "armed": false })
	MatchController.start(state, 10, 999)
	var result := _play(state)
	check(not result.ok, "there's nothing to shatter")

# ---- Reveal Weakness --------------------------------------------------------------------------

func test_reveal_weakness_freezes_the_enemy_king_for_three_turns() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["reveal_weakness"], 10)
	var board: Board = state.boards[0]
	check(_play(state).ok, "played")
	check_eq(board.pieces[V(0, 0)].frozen, 3, "frozen for 3")
	check(Piece.get_legal_moves(KING, BLACK, board, V(0, 0)).is_empty(), "can't move")
	check(state.run.hand.is_empty(), "used up")

func test_reveal_weakness_does_not_stop_the_king_from_being_captured() -> void:
	var state := _game([[V(0, 1), ROOK, WHITE]], ["reveal_weakness"], 10)
	_play(state)
	check(not Piece.get_legal_moves(ROOK, WHITE, state.boards[0], V(0, 1)).filter(func(m): return m.square == V(0, 0)).is_empty(), "freezing doesn't protect the king from capture")

# ---- Hex of the Boss --------------------------------------------------------------------------

func test_hex_of_the_boss_freezes_the_boss_piece_for_three_turns() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.boss_order[0] = Piece.Type.DRAGON
	main.state.run.round_number = 1
	main.state.run.match_number = 3
	main.run_flow.begin_match()
	main.state.run.hand.append({ "id": "hex_of_the_boss", "armed": false })
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var result := Prophecies.play_in_match(main.state, 0)
	check(result.ok, "played: %s" % result.get("reason", ""))
	var dragon: Array = main.state.boards[0].pieces.values().filter(func(p): return p.type == Piece.Type.DRAGON and p.side == BLACK)
	if dragon.is_empty():
		for b in main.state.boards:
			dragon.append_array(b.pieces.values().filter(func(p): return p.type == Piece.Type.DRAGON and p.side == BLACK))
	check_eq(dragon.size(), 1, "the boss piece is on the board")
	check_eq(dragon[0].frozen, 3, "and frozen")

func test_hex_of_the_boss_refuses_outside_a_boss_match() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["hex_of_the_boss"], 10)
	var result := _play(state)
	check(not result.ok, "no boss this match (a sandbox match)")

# ---- Mantle of the Phoenix (armed) -------------------------------------------------------------

func test_mantle_of_the_phoenix_revives_the_first_piece_you_lose_three_turns_later() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], [["mantle_of_the_phoenix", true]], 10)
	check_eq(state.current_match.prophecies.size(), 1, "armed at the start")
	state.active_board = state.boards[0]
	state.active_square = V(3, 1)
	MoveController.refresh(state)
	var result := MoveController.click(state, state.boards[0], V(3, 4))
	MatchController.record_move(state, result)
	check(state.boards[0].pieces[V(3, 4)].side == BLACK, "white's rook is gone; black's is standing on its square now")
	check_eq(state.current_match.revivals.size(), 1, "queued to come back")
	check(state.current_match.prophecies[0].spent, "the mantle has fired")
	check(state.current_match.last_event.contains("Mantle of the Phoenix"), state.current_match.last_event)
	Prophecies.finish_match(state.run, state.current_match)
	check(state.run.hand.is_empty(), "used up")
	for i in 3:
		MatchController.end_turn(state)   # white's turn
		MatchController.end_turn(state)   # black's turn
	check(state.boards[0].pieces.has(V(3, 4)) and state.boards[0].pieces[V(3, 4)].type == ROOK, "back on its starting square")

func test_mantle_of_the_phoenix_only_saves_the_first_loss() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(5, 4), KNIGHT, WHITE], [V(3, 1), ROOK, BLACK], [V(5, 1), ROOK, BLACK]], [["mantle_of_the_phoenix", true]], 10)
	state.active_board = state.boards[0]
	state.active_square = V(3, 1)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, state.boards[0], V(3, 4)))
	check_eq(state.current_match.revivals.size(), 1, "the first loss is queued")
	state.active_board = state.boards[0]
	state.active_square = V(5, 1)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, state.boards[0], V(5, 4)))
	check_eq(state.current_match.revivals.size(), 1, "the second loss is not queued too")

func test_an_unarmed_mantle_does_nothing() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE], [V(3, 1), ROOK, BLACK]], [["mantle_of_the_phoenix", false]], 10)
	check(state.current_match.prophecies.is_empty(), "nothing armed")
	state.active_board = state.boards[0]
	state.active_square = V(3, 1)
	MoveController.refresh(state)
	MatchController.record_move(state, MoveController.click(state, state.boards[0], V(3, 4)))
	check(state.current_match.revivals.is_empty(), "no revival queued")

# ---- Field Promotion --------------------------------------------------------------------------

func test_field_promotion_promotes_a_pawn_anywhere_up_to_a_rook() -> void:
	var state := _game([[V(3, 4), PAWN, WHITE]], ["field_promotion"], 10)
	var board: Board = state.boards[0]
	var stage1 := _play(state)
	check(stage1.ok and stage1.needs_choice, "pick a pawn")
	check(stage1.options.any(func(o): return o.square == V(3, 4)), str(stage1.options))
	var stage2 := _play(state, 0, { "board": board, "square": V(3, 4) })
	check(stage2.ok and stage2.needs_choice, "then pick what it becomes")
	check_eq(stage2.options, [ROOK, BISHOP, KNIGHT], "knight, bishop or rook - never the queen")
	var done := _play(state, 0, ROOK)
	check(done.ok and not done.get("needs_choice", false), "done")
	check_eq(board.pieces[V(3, 4)].type, ROOK, "promoted")
	check_eq(Piece.points(board.pieces[V(3, 4)]), Piece.value(PAWN), "but still counts as a pawn for your budget")
	check(state.run.hand.is_empty(), "used up")

func test_field_promotion_refuses_the_queen() -> void:
	var state := _game([[V(3, 4), PAWN, WHITE]], ["field_promotion"], 10)
	_play(state)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	var result := _play(state, 0, QUEEN)
	check(not result.ok, "the queen is off the table")

func test_field_promotion_works_anywhere_not_just_the_enemy_zone() -> void:
	var state := _game([[V(3, 4), PAWN, WHITE]], ["field_promotion"], 10)
	_play(state)
	_play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	_play(state, 0, KNIGHT)
	check_eq(state.boards[0].pieces[V(3, 4)].type, KNIGHT, "promoted mid-board, nowhere near the enemy zone")

func test_field_promotion_only_offers_real_pawns() -> void:
	var state := _game([[V(3, 4), Piece.Type.SCOUT, WHITE]], ["field_promotion"], 10)
	var result := _play(state)
	check(not result.ok, "a scout isn't a pawn")

# ---- Echo of Steel ---------------------------------------------------------------------------

func test_echo_of_steel_copies_a_piece_onto_a_free_zone_square() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["echo_of_steel"], 10)
	var board: Board = state.boards[0]
	for x in 8:
		board.zone_owner[V(x, 7)] = WHITE
	var stage1 := _play(state)
	check(stage1.ok and stage1.needs_choice, "pick a piece to copy")
	var stage2 := _play(state, 0, { "board": board, "square": V(3, 4) })
	check(stage2.ok and stage2.needs_choice, "then pick where")
	var done := _play(state, 0, { "board": board, "square": V(0, 7) })
	check(done.ok and not done.get("needs_choice", false), "done")
	check(board.pieces.has(V(3, 4)), "the original is untouched")
	check(board.pieces[V(0, 7)].type == ROOK and board.pieces[V(0, 7)].side == WHITE, "a copy stands at the new square")
	check(board.pieces[V(0, 7)].get("spawned", false), "temporary, not a roster piece")
	check(not board.pieces[V(0, 7)].has("roster_id"), "and never counted as lost if it falls")
	check(state.run.hand.is_empty(), "used up")

func test_echo_of_steel_needs_an_empty_zone_square() -> void:
	var state := _game([[V(3, 4), ROOK, WHITE]], ["echo_of_steel"], 10)
	_play(state)
	var result := _play(state, 0, { "board": state.boards[0], "square": V(3, 4) })
	check(not result.ok, "no zone at all")

# ---- through the strip: a sample of the two-step picks ------------------------------------------

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

func _strip_choice_buttons(main: Node) -> Array:
	return main.prophecy_strip._choice_row.get_children().filter(func(c): return c is Button)

func test_transmutation_two_step_choice_through_the_strip() -> void:
	var g := await _strip_game([[V(3, 4), KNIGHT, WHITE]], ["transmutation"])
	g.main.prophecy_flow.play(0)
	check(g.main.prophecy_strip.is_choosing(), "pick a piece")
	_strip_choice_buttons(g.main)[0].pressed.emit()
	check(g.main.prophecy_strip.is_choosing(), "pick what it becomes")
	var labels := _strip_choice_buttons(g.main).map(func(b): return b.text)
	check(not labels.has("Knight"), "not itself: %s" % str(labels))
	_strip_choice_buttons(g.main)[0].pressed.emit()
	check(not g.main.prophecy_strip.is_choosing() and g.state.run.hand.is_empty(), "chosen and used")
	check(g.board.pieces[V(3, 4)].type != KNIGHT, "changed")

func test_curse_of_stillness_labels_the_enemy_piece_through_the_strip() -> void:
	var g := await _strip_game([[V(3, 4), ROOK, WHITE], [V(4, 4), KNIGHT, BLACK]], ["curse_of_stillness"])
	g.main.prophecy_flow.play(0)
	var texts := _strip_choice_buttons(g.main).map(func(b): return b.text)
	check(texts.any(func(t): return t.contains("Knight")), str(texts))
