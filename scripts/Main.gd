extends Node2D
## Wiring only: creates the boards, connects the UI to the flows in scripts/flow/,
## and routes clicks. Game logic lives in the controllers and flows.

const BOARD_SCENE := preload("res://scenes/Board.tscn")

@onready var boards_container: Node2D = $BoardsContainer
@onready var panel: ControlPanel = $UI
@onready var promotion_picker: PromotionPicker = $PromotionLayer/PromotionPicker
@onready var result_screen: ResultScreen = $ResultLayer/ResultScreen
@onready var shop_screen: ShopScreen = $ShopLayer/ShopScreen

var state := GameState.new()

var run_flow := RunFlow.new()
var turn_flow := TurnFlow.new()
var deployment_flow := DeploymentFlow.new()
var debug_flow := DebugFlow.new()

func _ready() -> void:
	_setup_flows()
	_connect_panel()
	promotion_picker.piece_chosen.connect(turn_flow.promotion_chosen)
	result_screen.continue_pressed.connect(run_flow.result_continued)
	shop_screen.closed.connect(run_flow.begin_match)
	shop_screen.changed.connect(_refresh_view)
	_generate_boards()

func _setup_flows() -> void:
	run_flow.state = state
	run_flow.panel = panel
	run_flow.result_screen = result_screen
	run_flow.shop_screen = shop_screen
	run_flow.generate_boards = _generate_boards
	turn_flow.state = state
	turn_flow.promotion_picker = promotion_picker
	deployment_flow.state = state
	deployment_flow.panel = panel
	debug_flow.state = state
	debug_flow.panel = panel
	debug_flow.run_flow = run_flow
	debug_flow.turn_flow = turn_flow
	for flow in [run_flow, turn_flow, deployment_flow, debug_flow]:
		flow.view_changed.connect(_refresh_view)
		add_child(flow)

func _connect_panel() -> void:
	panel.refresh_requested.connect(_generate_boards)
	panel.board_size_changed.connect(_on_board_size_changed)
	panel.generate_zones_requested.connect(_on_generate_zones)
	panel.auto_place_requested.connect(_on_auto_place)
	panel.points_allocation_changed.connect(_update_points_status)
	panel.side_changed.connect(func(side: Piece.Side): state.current_side = side)
	panel.zone_edit_toggled.connect(_on_zone_edit_toggled)
	panel.place_requested.connect(_on_place)
	panel.remove_requested.connect(_on_remove)
	panel.start_match_requested.connect(run_flow.start_match)
	panel.start_run_requested.connect(run_flow.start_run)
	panel.bench_piece_selected.connect(deployment_flow.bench_selected)
	panel.auto_deploy_requested.connect(deployment_flow.auto_deploy)
	panel.ready_requested.connect(run_flow.ready_to_fight)
	panel.debug_toggled.connect(debug_flow.toggled)
	panel.debug_win_requested.connect(debug_flow.force_result.bind(true))
	panel.debug_lose_requested.connect(debug_flow.force_result.bind(false))
	panel.debug_pass_requested.connect(debug_flow.pass_turn)
	panel.debug_goto_requested.connect(debug_flow.goto)
	panel.debug_gold_changed.connect(debug_flow.set_gold)
	panel.debug_moves_changed.connect(debug_flow.set_moves)

func _generate_boards() -> void:
	for board in state.boards:
		board.queue_free()
	state.boards.clear()
	state.attach_info.clear()
	state.connections.clear()
	state.clear_active()
	state.pending_promotion = {}
	state.current_match = MatchState.new()
	state.deployment = DeploymentState.new()
	promotion_picker.hide()
	result_screen.hide()
	shop_screen.hide()

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
	panel.set_match_status(MatchController.status_text(state))
	panel.set_sandbox_enabled(state.debug_mode or (not state.current_match.active and not state.run.active))
	if state.debug_mode:
		panel.sync_debug_values(state.run.round_number, state.run.match_number, state.run.currency, state.current_match.moves_left)
	run_flow.settle_if_finished()
	panel.set_wallet(state.run.currency)
	panel.set_run_status(state.run.title())
	deployment_flow.refresh_ui()

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
	elif state.deployment.active and (not state.debug_mode or state.deployment.armed_id != -1):
		deployment_flow.click(square, board)
	elif not MatchController.accepts_click(state, board, square):
		MoveController.clear_selection(state)
	else:
		var result := MoveController.click(state, board, square)
		if result.is_empty():
			_refresh_view()          # a new selection: its moves, and any hint about them
		else:
			turn_flow.after_move(result)

func _on_square_right_clicked(square: Vector2i, board: Board) -> void:
	if state.zone_edit_mode:
		board.clear_zone(square)
	elif MatchController.accepts_click(state, board, square):
		var result := MoveController.click(state, board, square, true)     # attack without moving
		if not result.is_empty():
			turn_flow.after_move(result)

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
