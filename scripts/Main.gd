extends Node2D

const BOARD_SCENE := preload("res://scenes/Board.tscn")

@onready var boards_container: Node2D = $BoardsContainer
@onready var panel: ControlPanel = $UI

var state := GameState.new()

func _ready() -> void:
	panel.refresh_requested.connect(_generate_boards)
	panel.board_size_changed.connect(_on_board_size_changed)
	panel.generate_zones_requested.connect(_on_generate_zones)
	panel.auto_place_requested.connect(_on_auto_place)
	panel.points_allocation_changed.connect(_update_points_status)
	panel.side_changed.connect(func(side: Piece.Side): state.current_side = side)
	panel.zone_edit_toggled.connect(_on_zone_edit_toggled)
	panel.place_requested.connect(_on_place)
	panel.remove_requested.connect(_on_remove)

	_generate_boards()

func _generate_boards() -> void:
	for board in state.boards:
		board.queue_free()
	state.boards.clear()
	state.attach_info.clear()
	state.connections.clear()
	state.clear_active()

	for i in panel.board_count():
		var board: Board = BOARD_SCENE.instantiate()
		boards_container.add_child(board)
		board.grid_width = panel.board_width(i)
		board.grid_height = panel.board_height(i)
		board.square_selected.connect(_on_square_selected.bind(board))
		board.square_right_clicked.connect(_on_square_right_clicked.bind(board))
		state.boards.append(board)
		state.attach_info.append(BoardLayout.random_attach(i))

	_relayout()

func _relayout() -> void:
	if state.boards.is_empty():
		return
	var layout := BoardLayout.arrange(state.boards, state.attach_info, boards_container)
	state.connections = BoardConnections.build(state.boards, state.attach_info, layout.positions, layout.sizes)
	BoardColorizer.assign_colors(state.boards, state.connections)
	BoardConnections.build_portals(state.boards, state.attach_info, state.connections)
	_refresh_view()

func _refresh_view() -> void:
	MoveController.refresh(state)
	_update_points_status()

func _update_points_status() -> void:
	panel.set_points_status(
		ArmyPlacer.points_used(state.boards, Piece.Side.WHITE), panel.points_allocated(Piece.Side.WHITE),
		ArmyPlacer.points_used(state.boards, Piece.Side.BLACK), panel.points_allocated(Piece.Side.BLACK),
	)

func _on_board_size_changed(index: int, is_width: bool, value: int) -> void:
	if index >= state.boards.size():
		return
	if is_width:
		state.boards[index].grid_width = value
	else:
		state.boards[index].grid_height = value
	_relayout()

func _on_square_selected(square: Vector2i, board: Board) -> void:
	if state.zone_edit_mode:
		board.set_zone(square, state.current_side)
	else:
		MoveController.click(state, board, square)

func _on_square_right_clicked(square: Vector2i, board: Board) -> void:
	if state.zone_edit_mode:
		board.clear_zone(square)

func _on_zone_edit_toggled(enabled: bool) -> void:
	state.zone_edit_mode = enabled
	MoveController.clear_selection(state)

func _on_generate_zones() -> void:
	MoveController.clear_selection(state)
	ZoneController.generate(state.boards, panel.zone_tiles(Piece.Side.WHITE), panel.zone_tiles(Piece.Side.BLACK))
	_refresh_view()

func _on_auto_place(side: Piece.Side) -> void:
	MoveController.clear_selection(state)
	panel.set_auto_place_status(ArmyPlacer.auto_place(state.boards, side, panel.points_allocated(side), panel.round_type()))
	_refresh_view()

func _on_place(type: Piece.Type) -> void:
	ArmyPlacer.place(state, type, panel.points_allocated(state.current_side))
	_refresh_view()

func _on_remove() -> void:
	ArmyPlacer.remove(state)
	_refresh_view()
