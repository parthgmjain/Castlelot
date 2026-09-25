extends "res://tests/TestCase.gd"
## Random multi-board generation: touching boards, connections, colours.

func test_random_layouts_are_connected_non_overlapping_and_colour_matched() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel.count_spin_box.value = 5
	await pump()
	check_eq(panel._width_boxes.size(), 5, "size controls follow the board count")
	var problems := 0
	for trial in 80:
		panel.refresh_button.pressed.emit()
		await pump()
		var state: GameState = main.state
		if state.boards.size() != 5 or not boards_connected(state.boards) or any_overlap(state.boards):
			problems += 1
			continue
		for conn in state.connections:
			if conn.a_squares.is_empty() or conn.b_squares.is_empty():
				problems += 1
				continue
			var a: Board = state.boards[conn.a_board]
			var b: Board = state.boards[conn.b_board]
			for k in conn.a_squares.size():
				var ca: int = (conn.a_squares[k].x + conn.a_squares[k].y + a.color_parity) % 2
				var cb: int = (conn.b_squares[k].x + conn.b_squares[k].y + b.color_parity) % 2
				if ca == cb:
					problems += 1
	check_eq(problems, 0, "layouts that were disconnected, overlapping, empty-seamed or colour-clashing out of 80")

func test_default_startup_builds_three_connected_boards() -> void:
	var main = await load_main()
	check_eq(main.state.boards.size(), 3, "boards")
	check_eq(main.state.connections.size(), 2, "connections")
	check(boards_connected(main.state.boards), "connected")

func test_resizing_one_board_relays_everything_out() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel._width_boxes[0].value = 3
	check_eq(main.state.boards[0].grid_width, 3, "width applied")
	check(boards_connected(main.state.boards) and not any_overlap(main.state.boards), "still connected and non-overlapping")
	panel._height_boxes[1].value = 7
	check_eq(main.state.boards[1].grid_height, 7, "height applied")
	check(boards_connected(main.state.boards) and not any_overlap(main.state.boards), "and again")

func test_board_count_control_rebuilds_the_size_controls() -> void:
	var main = await load_main()
	var panel: ControlPanel = main.panel
	panel.count_spin_box.value = 5
	await pump()
	check_eq(panel._width_boxes.size(), 5, "five width boxes")
	panel.refresh_button.pressed.emit()
	await pump()
	check_eq(main.state.boards.size(), 5, "refresh builds five boards")
	panel.count_spin_box.value = 1
	await pump()
	panel.refresh_button.pressed.emit()
	await pump()
	check_eq(main.state.boards.size(), 1, "and one board")
	check(main.state.connections.is_empty(), "with no connections")
