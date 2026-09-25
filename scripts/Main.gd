extends Node2D

const BOARD_SCENE := preload("res://scenes/Board.tscn")

@onready var boards_container: Node2D = $BoardsContainer
@onready var panel: ControlPanel = $UI
@onready var promotion_picker: PromotionPicker = $PromotionLayer/PromotionPicker
@onready var result_screen: ResultScreen = $ResultLayer/ResultScreen

## Pause before the AI moves so its move can be followed.
var ai_delay := 0.6

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
	panel.start_match_requested.connect(_on_start_match)
	panel.start_run_requested.connect(_start_run)
	promotion_picker.piece_chosen.connect(_on_promotion_chosen)
	result_screen.continue_pressed.connect(_on_result_continue)

	_generate_boards()

func _generate_boards() -> void:
	for board in state.boards:
		board.queue_free()
	state.boards.clear()
	state.attach_info.clear()
	state.connections.clear()
	state.clear_active()
	state.pending_promotion = {}
	state.current_match = MatchState.new()
	promotion_picker.hide()
	result_screen.hide()

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
	panel.set_sandbox_enabled(not state.current_match.active and not state.run.active)
	_settle_match_if_finished()
	panel.set_wallet(state.run.currency)
	panel.set_run_status(state.run.title())

## Pays out a won match (once) and shows the result screen for either outcome.
func _settle_match_if_finished() -> void:
	var current := state.current_match
	if current.result == "" or current.settled:
		return
	current.settled = true
	var payout := {}
	if current.result == "win":
		payout = Payout.calculate(current, state.run.currency)
		state.run.currency += payout.total
	var context := ""
	var button := ""
	if state.run.active:
		context = state.run.title()
		if current.result == "loss":
			button = "Restart Run"
		else:
			button = "Finish Run" if state.run.is_final_round() else "Next Match"
	result_screen.show_result(current, payout, state.run.currency, context, button)

## In a run: a win moves on to the next match (or finishes the run after
## Arthur) and a loss starts a new run. Outside a run a loss just wipes the gold.
func _on_result_continue() -> void:
	var lost := state.current_match.result == "loss"
	if state.run.active:
		if lost:
			_start_run()
		elif state.run.advance():
			_begin_run_match()
		else:
			_refresh_view()
		return
	if lost:
		state.run = RunState.new()
	_refresh_view()

func _start_run() -> void:
	state.run = RunState.new()
	state.run.begin()
	_begin_run_match()

## Builds the run's current match from RunConfig and starts it.
func _begin_run_match() -> void:
	var setup := RunConfig.match_setup(state.run)
	panel.apply_setup(setup)
	_generate_boards()
	ZoneController.generate(state.boards, setup.white_zone, setup.black_zone)
	ArmyPlacer.auto_place(state.boards, Piece.Side.BLACK, setup.ai_budget, setup.round_type)
	ArmyPlacer.auto_place(state.boards, Piece.Side.WHITE, setup.player_budget, "normal")
	MatchController.start(state, setup.moves, setup.target)
	_mark_last_move({})
	_refresh_view()

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
	elif not MatchController.accepts_click(state, board, square):
		MoveController.clear_selection(state)
	else:
		var result := MoveController.click(state, board, square)
		if not result.is_empty():
			_after_move(result)

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

func _on_promotion_chosen(type: Piece.Type) -> void:
	PawnMovement.promote(state.pending_promotion.piece, type)
	state.pending_promotion.board.queue_redraw()
	state.pending_promotion = {}
	_finish_turn()

func _on_start_match(moves: int, target: int) -> void:
	var error := MatchController.start(state, moves, target)
	if error != "":
		panel.set_match_status(error)
		return
	_mark_last_move({})
	_refresh_view()

## Everything that follows a completed move, for either side.
func _after_move(result: Dictionary) -> void:
	MatchController.record_move(state, result)
	_mark_last_move(result)
	if state.current_match.result != "":
		state.pending_promotion = {}
	if not state.pending_promotion.is_empty() and state.current_match.result == "":
		promotion_picker.open(state.pending_promotion.piece.side)
		_refresh_view()
		return
	_finish_turn()

func _finish_turn() -> void:
	MatchController.end_turn(state)
	_refresh_view()
	var current := state.current_match
	if current.active and current.turn_side != current.player_side:
		_run_ai_turn()

func _run_ai_turn() -> void:
	await get_tree().create_timer(ai_delay).timeout
	var current := state.current_match
	if not current.active or current.turn_side == current.player_side:
		return

	var choice := GreedyAI.choose_move(state, current.turn_side)
	if choice.is_empty():
		_finish_turn()
		return

	state.active_board = choice.board
	state.active_square = choice.square
	var result := MoveController.execute(state, choice.move)
	if not state.pending_promotion.is_empty():
		PawnMovement.promote(state.pending_promotion.piece, PawnMovement.PROMOTION_CHOICES[0])
		state.pending_promotion = {}
	_after_move(result)

func _mark_last_move(result: Dictionary) -> void:
	var squares: Dictionary = {}
	if not result.is_empty():
		squares[result.from_board] = [result.from_square]
		if not squares.has(result.board):
			squares[result.board] = []
		squares[result.board].append(result.square)
	for b in state.boards:
		b.set_last_move_squares(squares.get(b, []))
