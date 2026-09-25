extends "res://tests/TestCase.gd"
## Deploying your roster before a run match, and losing pieces for good.

func _start(main: Node) -> void:
	main.panel.start_run_button.pressed.emit()

func _bench_buttons(main: Node) -> Array:
	return main.panel.bench_box.get_children()

func _free_zone_square(main: Node) -> Dictionary:
	var free := Roster.free_squares(main.state.boards, WHITE)
	return free[0] if not free.is_empty() else {}

func _force_result(main: Node, result: String) -> void:
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = result
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()

func _ready_up(main: Node) -> void:
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()

func test_a_run_match_opens_with_your_whole_roster_on_the_bench() -> void:
	var main = await load_main()
	_start(main)
	var panel: ControlPanel = main.panel
	check(panel.deploy_row.visible, "the deploy row is showing")
	check_eq(_bench_buttons(main).size(), 6, "one button per roster piece")
	var labels := _bench_buttons(main).map(func(b): return b.text)
	check(labels.any(func(t): return t.contains("Rook")) and labels.any(func(t): return t.contains("Knight")) and labels.any(func(t): return t.contains("Bishop")), "labels: %s" % str(labels))
	check_eq(labels.filter(func(t): return t.contains("Pawn")).size(), 3, "three pawns")
	check(king_alive(main.state.boards, WHITE), "your king is already in place")
	check(pieces_of(main.state.boards, WHITE, false).is_empty(), "nothing else deployed")
	var marked := 0
	for board in main.state.boards:
		marked += board.move_squares.size()
	check_eq(marked, Roster.free_squares(main.state.boards, WHITE).size(), "every free zone square is marked")
	check(panel.deploy_status_label.text.begins_with("6 on the bench | "), panel.deploy_status_label.text)

func test_arming_a_bench_piece_and_clicking_a_zone_square_deploys_it() -> void:
	var main = await load_main()
	_start(main)
	var target := _free_zone_square(main)
	var button: Button = _bench_buttons(main)[0]
	button.pressed.emit()
	check_eq(main.state.deployment.armed_id, main.state.run.roster[0].id, "armed")
	check(_bench_buttons(main)[0].button_pressed, "the armed piece is shown pressed in")
	main._on_square_selected(target.square, target.board)
	var piece: Dictionary = target.board.pieces[target.square]
	check(piece.side == WHITE and piece.type == main.state.run.roster[0].type and piece.roster_id == main.state.run.roster[0].id, "the right piece landed there")
	check_eq(_bench_buttons(main).size(), 5, "the bench shrank")
	check_eq(main.state.deployment.armed_id, -1, "no longer armed")
	check(not target.board.move_squares.has(target.square), "that square isn't marked free any more")

func test_pressing_the_armed_piece_again_puts_it_down() -> void:
	var main = await load_main()
	_start(main)
	_bench_buttons(main)[0].pressed.emit()
	_bench_buttons(main)[0].pressed.emit()
	check_eq(main.state.deployment.armed_id, -1, "disarmed")

func test_you_cannot_deploy_outside_your_zone_or_onto_another_piece() -> void:
	var main = await load_main()
	_start(main)
	var state: GameState = main.state
	_bench_buttons(main)[0].pressed.emit()
	var outside := Vector2i(-1, -1)
	var outside_board: Board = null
	for board in state.boards:
		for x in board.grid_width:
			for y in board.grid_height:
				if board.zone_owner.get(Vector2i(x, y)) == null and not board.pieces.has(Vector2i(x, y)) and outside_board == null:
					outside_board = board
					outside = Vector2i(x, y)
	main._on_square_selected(outside, outside_board)
	check(pieces_of(state.boards, WHITE, false).is_empty(), "nothing placed on a neutral square")
	check_eq(state.deployment.armed_id, state.run.roster[0].id, "still armed")
	var enemy: Dictionary = pieces_of(state.boards, BLACK, false)[0]
	main._on_square_selected(enemy.square, enemy.board)
	check(pieces_of(state.boards, WHITE, false).is_empty(), "nothing placed on an enemy piece")
	check(enemy.board.pieces.has(enemy.square), "the enemy piece is untouched")

func test_clicking_a_deployed_piece_picks_it_back_up() -> void:
	var main = await load_main()
	_start(main)
	var target := _free_zone_square(main)
	_bench_buttons(main)[0].pressed.emit()
	main._on_square_selected(target.square, target.board)
	check_eq(_bench_buttons(main).size(), 5, "deployed")
	main._on_square_selected(target.square, target.board)
	check(not target.board.pieces.has(target.square), "picked back up")
	check_eq(_bench_buttons(main).size(), 6, "and back on the bench")
	var king: Dictionary = pieces_of(main.state.boards, WHITE)[0]
	main._on_square_selected(king.square, king.board)
	check(king.board.pieces.has(king.square) and king.board.pieces[king.square].type == KING, "the king can't be picked up")

func test_clicks_during_deployment_never_select_or_move_pieces() -> void:
	var main = await load_main()
	_start(main)
	var king: Dictionary = pieces_of(main.state.boards, WHITE)[0]
	main._on_square_selected(king.square, king.board)
	check(main.state.active_board == null, "the king was not selected for moving")
	check(king.board.pieces.has(king.square), "and is where it was")

func test_auto_deploy_fills_the_zone_and_start_match_begins_the_fight() -> void:
	var main = await load_main()
	_start(main)
	main.panel.auto_deploy_button.pressed.emit()
	check(_bench_buttons(main).is_empty(), "the bench is empty")
	check_eq(pieces_of(main.state.boards, WHITE, false).size(), 6, "all six deployed")
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	check(current.active and not main.state.deployment.active, "the match began")
	check_eq(current.deployed_roster_ids.size(), 6, "the deployed pieces were recorded")
	check(not main.panel.deploy_row.visible, "deploy row hidden")
	check(main.panel.match_status_label.text.begins_with("Your turn"), main.panel.match_status_label.text)
	for board in main.state.boards:
		check(board.move_squares.is_empty(), "no leftover deploy markers")

func test_you_can_start_with_pieces_left_on_the_bench() -> void:
	var main = await load_main()
	_start(main)
	for i in 2:
		var target := _free_zone_square(main)
		_bench_buttons(main)[0].pressed.emit()
		main._on_square_selected(target.square, target.board)
	main.panel.ready_button.pressed.emit()
	check(main.state.current_match.active, "started")
	check_eq(main.state.current_match.deployed_roster_ids.size(), 2, "only two were deployed")

func test_starting_with_only_the_king_is_allowed() -> void:
	var main = await load_main()
	_start(main)
	main.panel.ready_button.pressed.emit()
	check(main.state.current_match.active, "started")
	check(main.state.current_match.deployed_roster_ids.is_empty(), "nothing deployed")

func test_captured_pieces_leave_your_roster_when_you_win() -> void:
	var main = await load_main()
	_start(main)
	_ready_up(main)
	var state: GameState = main.state
	var knight_id := -1
	for entry in state.run.roster:
		if entry.type == KNIGHT:
			knight_id = entry.id
	var field := Roster.on_field(state.boards)
	var spot: Dictionary = field[knight_id]
	spot.board.pieces.erase(spot.square)                    # the AI captured your knight
	_force_result(main, "win")
	check(main.result_screen.details_label.text.contains("Lost: Knight"), main.result_screen.details_label.text)
	check(state.run.roster_entry(knight_id).is_empty(), "the knight is gone from the roster")
	check_eq(state.run.roster.size(), 5, "five pieces left")
	main.result_screen.continue_button.pressed.emit()
	check_eq(_bench_buttons(main).size(), 5, "the next bench has five pieces")
	check(not _bench_buttons(main).any(func(b): return b.text.contains("Knight")), "and no knight")

func test_a_win_with_no_losses_says_so_and_keeps_everything() -> void:
	var main = await load_main()
	_start(main)
	_ready_up(main)
	_force_result(main, "win")
	check(main.result_screen.details_label.text.contains("No pieces lost."), main.result_screen.details_label.text)
	check_eq(main.state.run.roster.size(), 6, "still six")

func test_pieces_you_kept_on_the_bench_cannot_be_lost() -> void:
	var main = await load_main()
	_start(main)
	var target := _free_zone_square(main)
	_bench_buttons(main)[0].pressed.emit()
	main._on_square_selected(target.square, target.board)
	var benched_ids := _bench_buttons(main).size()
	main.panel.ready_button.pressed.emit()
	target.board.pieces.erase(target.square)                # the one deployed piece dies
	_force_result(main, "win")
	check_eq(main.state.run.roster.size(), 5, "only the deployed piece was lost")
	check_eq(benched_ids, 5, "the other five were benched")

func test_losing_the_run_restores_a_full_roster() -> void:
	var main = await load_main()
	_start(main)
	_ready_up(main)
	var field := Roster.on_field(main.state.boards)
	var spot: Dictionary = field[field.keys()[0]]
	spot.board.pieces.erase(spot.square)
	_force_result(main, "win")
	main.result_screen.continue_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 5, "down a piece")
	_ready_up(main)
	_force_result(main, "loss")
	main.result_screen.continue_button.pressed.emit()
	check_eq(main.state.run.roster.size(), 6, "a lost run restarts with the full roster")
	check_eq(_bench_buttons(main).size(), 6, "on the bench")

func test_promotion_lasts_only_for_the_match() -> void:
	var main = await load_main()
	_start(main)
	_ready_up(main)
	var state: GameState = main.state
	var pawn_id := -1
	for entry in state.run.roster:
		if entry.type == PAWN:
			pawn_id = entry.id
	var spot: Dictionary = Roster.on_field(state.boards)[pawn_id]
	PawnMovement.promote(spot.board.pieces[spot.square], QUEEN)
	_force_result(main, "win")
	check(state.run.roster_entry(pawn_id).type == PAWN, "the roster still lists a pawn")
	check(main.result_screen.details_label.text.contains("No pieces lost."), "a promoted pawn isn't a lost piece")

func test_a_real_mouse_click_on_a_free_zone_square_deploys_the_armed_piece() -> void:
	var main = await load_main()
	_start(main)
	var target := _free_zone_square(main)
	_bench_buttons(main)[0].pressed.emit()
	click_at(square_position(target.board, target.square))
	check(target.board.pieces.has(target.square), "the click placed the piece")
	check_eq(target.board.selected_square, Vector2i(-1, -1), "and no selection outline is left behind")
	check_eq(_bench_buttons(main).size(), 5, "bench updated")
	click_at(square_position(target.board, target.square))
	check(not target.board.pieces.has(target.square), "clicking it again picks it back up")
