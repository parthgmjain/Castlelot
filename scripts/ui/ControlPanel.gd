class_name ControlPanel
extends Control

signal refresh_requested
signal board_size_changed(index: int, is_width: bool, value: int)
signal generate_zones_requested
signal auto_place_requested(side: Piece.Side)
signal points_allocation_changed
signal side_changed(side: Piece.Side)
signal zone_edit_toggled(enabled: bool)
signal place_requested(type: Piece.Type)
signal remove_requested
signal start_match_requested(moves: int, target: int)
signal start_run_requested
signal bench_piece_selected(id: int)
signal auto_deploy_requested
signal ready_requested
signal debug_toggled(enabled: bool)
signal debug_win_requested
signal debug_lose_requested
signal debug_pass_requested
signal debug_goto_requested(round_number: int, match_number: int)
signal debug_gold_changed(amount: int)
signal debug_moves_changed(amount: int)
signal debug_prophecy_requested(id: String)
signal skip_bonus_requested

const MIN_DIM := 2
const MAX_DIM := 10

@onready var debug_check: CheckButton = $VBox/RunRow/DebugCheckButton
@onready var debug_row: HBoxContainer = $VBox/DebugRow
@onready var debug_win_button: Button = $VBox/DebugRow/DebugWinButton
@onready var debug_lose_button: Button = $VBox/DebugRow/DebugLoseButton
@onready var debug_pass_button: Button = $VBox/DebugRow/DebugPassButton
@onready var debug_round_spin: SpinBox = $VBox/DebugRow/DebugRoundSpin
@onready var debug_match_spin: SpinBox = $VBox/DebugRow/DebugMatchSpin
@onready var debug_go_button: Button = $VBox/DebugRow/DebugGoButton
@onready var debug_gold_spin: SpinBox = $VBox/DebugRow/DebugGoldSpin
@onready var debug_moves_spin: SpinBox = $VBox/DebugRow/DebugMovesSpin
var debug_prophecy_picker: OptionButton
var debug_prophecy_button: Button
@onready var deploy_row: HBoxContainer = $VBox/DeployRow
@onready var bench_box: HBoxContainer = $VBox/DeployRow/BenchBox
@onready var auto_deploy_button: Button = $VBox/DeployRow/AutoDeployButton
@onready var ready_button: Button = $VBox/DeployRow/ReadyButton
@onready var deploy_status_label: Label = $VBox/DeployRow/DeployStatusLabel
@onready var start_run_button: Button = $VBox/RunRow/StartRunButton
@onready var run_status_label: Label = $VBox/RunRow/RunStatusLabel
@onready var count_spin_box: SpinBox = $VBox/CountRow/CountSpinBox
@onready var refresh_button: Button = $VBox/CountRow/RefreshButton
@onready var sizes_row: HBoxContainer = $VBox/SizesRow
@onready var white_zone_spin_box: SpinBox = $VBox/ZoneRow/WhiteZoneSpinBox
@onready var black_zone_spin_box: SpinBox = $VBox/ZoneRow/BlackZoneSpinBox
@onready var generate_zones_button: Button = $VBox/ZoneRow/GenerateZonesButton
@onready var white_points_spin_box: SpinBox = $VBox/PointsRow/WhitePointsSpinBox
@onready var black_points_spin_box: SpinBox = $VBox/PointsRow/BlackPointsSpinBox
@onready var points_status_label: Label = $VBox/PointsRow/PointsStatusLabel
@onready var round_option: OptionButton = $VBox/AutoPlaceRow/RoundOption
@onready var auto_place_white_button: Button = $VBox/AutoPlaceRow/AutoPlaceWhiteButton
@onready var auto_place_black_button: Button = $VBox/AutoPlaceRow/AutoPlaceBlackButton
@onready var auto_place_status_label: Label = $VBox/AutoPlaceRow/AutoPlaceStatusLabel
@onready var side_check_button: CheckButton = $VBox/PieceRow/SideCheckButton
@onready var zone_edit_button: CheckButton = $VBox/PieceRow/ZoneEditButton
@onready var king_button: Button = $VBox/PieceRow/KingButton
@onready var queen_button: Button = $VBox/PieceRow/QueenButton
@onready var rook_button: Button = $VBox/PieceRow/RookButton
@onready var bishop_button: Button = $VBox/PieceRow/BishopButton
@onready var knight_button: Button = $VBox/PieceRow/KnightButton
@onready var pawn_button: Button = $VBox/PieceRow/PawnButton
@onready var remove_button: Button = $VBox/PieceRow/RemoveButton
var extra_piece_picker: OptionButton
var skip_bonus_button: Button
@onready var moves_spin_box: SpinBox = $VBox/MatchRow/MovesSpinBox
@onready var target_spin_box: SpinBox = $VBox/MatchRow/TargetSpinBox
@onready var start_match_button: Button = $VBox/MatchRow/StartMatchButton
@onready var match_status_label: Label = $VBox/MatchStatusLabel
@onready var wallet_label: Label = $VBox/MatchRow/WalletLabel

var _width_boxes: Array = []
var _height_boxes: Array = []

func _ready() -> void:
	count_spin_box.value_changed.connect(func(value: float): _rebuild_size_controls(int(value)))
	refresh_button.pressed.connect(func(): refresh_requested.emit())
	generate_zones_button.pressed.connect(func(): generate_zones_requested.emit())
	side_check_button.toggled.connect(func(pressed: bool): side_changed.emit(Piece.Side.BLACK if pressed else Piece.Side.WHITE))
	zone_edit_button.toggled.connect(func(pressed: bool): zone_edit_toggled.emit(pressed))
	white_points_spin_box.value_changed.connect(func(_v): points_allocation_changed.emit())
	black_points_spin_box.value_changed.connect(func(_v): points_allocation_changed.emit())

	for round_type in PieceSelector.ROUND_MODIFIERS:
		round_option.add_item(round_type.capitalize())
	auto_place_white_button.pressed.connect(_on_auto_place_pressed.bind(Piece.Side.WHITE))
	auto_place_black_button.pressed.connect(_on_auto_place_pressed.bind(Piece.Side.BLACK))

	king_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KING))
	queen_button.pressed.connect(_on_place_pressed.bind(Piece.Type.QUEEN))
	rook_button.pressed.connect(_on_place_pressed.bind(Piece.Type.ROOK))
	bishop_button.pressed.connect(_on_place_pressed.bind(Piece.Type.BISHOP))
	king_button.tooltip_text = Piece.description(Piece.Type.KING)
	queen_button.tooltip_text = Piece.description(Piece.Type.QUEEN)
	rook_button.tooltip_text = Piece.description(Piece.Type.ROOK)
	bishop_button.tooltip_text = Piece.description(Piece.Type.BISHOP)
	knight_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KNIGHT))
	pawn_button.pressed.connect(_on_place_pressed.bind(Piece.Type.PAWN))
	knight_button.tooltip_text = Piece.description(Piece.Type.KNIGHT)
	pawn_button.tooltip_text = Piece.description(Piece.Type.PAWN)
	_build_extra_piece_picker()
	_build_skip_bonus_button()
	_build_debug_prophecy_picker()
	remove_button.pressed.connect(func(): remove_requested.emit())
	start_match_button.pressed.connect(func(): start_match_requested.emit(int(moves_spin_box.value), int(target_spin_box.value)))
	start_run_button.pressed.connect(func(): start_run_requested.emit())
	auto_deploy_button.pressed.connect(func(): auto_deploy_requested.emit())
	debug_check.toggled.connect(func(pressed: bool): debug_toggled.emit(pressed))
	debug_win_button.pressed.connect(func(): debug_win_requested.emit())
	debug_lose_button.pressed.connect(func(): debug_lose_requested.emit())
	debug_pass_button.pressed.connect(func(): debug_pass_requested.emit())
	debug_go_button.pressed.connect(func(): debug_goto_requested.emit(int(debug_round_spin.value), int(debug_match_spin.value)))
	debug_gold_spin.value_changed.connect(func(value: float): debug_gold_changed.emit(int(value)))
	debug_moves_spin.value_changed.connect(func(value: float): debug_moves_changed.emit(int(value)))
	ready_button.pressed.connect(func(): ready_requested.emit())

	_rebuild_size_controls(board_count())

func board_count() -> int:
	return int(count_spin_box.value)

func board_width(index: int) -> int:
	return int(_width_boxes[index].value)

func board_height(index: int) -> int:
	return int(_height_boxes[index].value)

func zone_tiles(side: Piece.Side) -> int:
	return int(white_zone_spin_box.value if side == Piece.Side.WHITE else black_zone_spin_box.value)

func points_allocated(side: Piece.Side) -> int:
	return int(white_points_spin_box.value if side == Piece.Side.WHITE else black_points_spin_box.value)

func round_type() -> String:
	return PieceSelector.ROUND_MODIFIERS.keys()[round_option.selected]

func set_points_status(white_used: int, white_cap: int, black_used: int, black_cap: int) -> void:
	points_status_label.text = "White: %d/%d   Black: %d/%d" % [white_used, white_cap, black_used, black_cap]

func set_auto_place_status(text: String) -> void:
	auto_place_status_label.text = text

func set_match_status(text: String) -> void:
	match_status_label.text = text

func set_debug_visible(shown: bool) -> void:
	debug_row.visible = shown

## Shows the live values in the debug row without firing its change signals.
func sync_debug_values(round_number: int, match_number: int, gold: int, moves_left: int) -> void:
	debug_round_spin.set_value_no_signal(round_number)
	debug_match_spin.set_value_no_signal(match_number)
	debug_gold_spin.set_value_no_signal(gold)
	debug_moves_spin.set_value_no_signal(moves_left)

func set_deployment_visible(shown: bool) -> void:
	deploy_row.visible = shown

func set_deploy_status(text: String) -> void:
	deploy_status_label.text = text

## One toggle button per benched roster piece; the armed one is pressed in.
func set_bench(entries: Array, armed_id: int) -> void:
	for child in bench_box.get_children():
		bench_box.remove_child(child)
		child.queue_free()
	for entry in entries:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = entry.id == armed_id
		button.text = "%s %s" % [Piece.symbol(entry.type, Piece.Side.WHITE), Piece.Type.find_key(entry.type).capitalize()]
		button.tooltip_text = Piece.description(entry.type)
		button.pressed.connect(_on_bench_pressed.bind(entry.id))
		bench_box.add_child(button)

func _on_bench_pressed(id: int) -> void:
	bench_piece_selected.emit(id)

func set_run_status(text: String) -> void:
	run_status_label.text = text

## Mirrors a match setup (see RunConfig.match_setup) into the visible controls.
func apply_setup(setup: Dictionary) -> void:
	count_spin_box.set_value_no_signal(setup.board_sizes.size())
	_rebuild_size_controls(setup.board_sizes.size(), setup.board_sizes)
	white_zone_spin_box.value = setup.white_zone
	black_zone_spin_box.value = setup.black_zone
	# a boss's own piece comes on top of its army's budget, so count it in the readout
	black_points_spin_box.value = setup.ai_budget + (Piece.value(setup.boss_piece) if setup.get("boss_piece", -1) >= 0 else 0)
	moves_spin_box.value = setup.moves
	target_spin_box.value = setup.target
	round_option.select(PieceSelector.ROUND_MODIFIERS.keys().find(setup.round_type))

func set_wallet(currency: int) -> void:
	wallet_label.text = "Gold: %d" % currency

## Locks (or unlocks) every sandbox setup control, so a match in progress
## can't have its boards, zones or armies changed underneath it.
func set_sandbox_enabled(enabled: bool) -> void:
	var controls: Array = [
		count_spin_box, refresh_button, white_zone_spin_box, black_zone_spin_box, generate_zones_button,
		white_points_spin_box, black_points_spin_box, round_option, auto_place_white_button, auto_place_black_button,
		side_check_button, zone_edit_button, king_button, queen_button, rook_button, bishop_button, knight_button,
		pawn_button, extra_piece_picker, remove_button, moves_spin_box, target_spin_box, start_match_button, start_run_button,
	]
	controls.append_array(_width_boxes)
	controls.append_array(_height_boxes)
	for control in controls:
		if control is SpinBox:
			control.editable = enabled
		else:
			control.disabled = not enabled

func _on_auto_place_pressed(side: Piece.Side) -> void:
	auto_place_requested.emit(side)

## A drop-down of every data-driven piece, for placing them in the sandbox.
func _build_extra_piece_picker() -> void:
	extra_piece_picker = OptionButton.new()
	extra_piece_picker.add_item("More pieces...")
	for type in PieceDefs.types():
		extra_piece_picker.add_item("%s (%s)" % [Piece.Type.find_key(type).capitalize(), Piece.TIER_NAMES[PieceDefs.tier(type)]])
		var index := extra_piece_picker.item_count - 1
		extra_piece_picker.set_item_metadata(index, type)
		extra_piece_picker.get_popup().set_item_tooltip(index, Piece.description(type))
	extra_piece_picker.item_selected.connect(_on_extra_piece_selected)
	remove_button.get_parent().add_child(extra_piece_picker)
	remove_button.get_parent().move_child(extra_piece_picker, remove_button.get_index())

## A dropdown of every prophecy (built or not, so a designed-but-unbuilt card can still be
## inspected) plus a button that adds one to your hand for free, bypassing the hand-size cap.
func _build_debug_prophecy_picker() -> void:
	debug_prophecy_picker = OptionButton.new()
	debug_prophecy_picker.add_item("Add prophecy...")
	for id in ProphecyDefs.ids():
		var label := "%s (%s)" % [ProphecyDefs.display_name(id), Piece.TIER_NAMES[ProphecyDefs.rarity(id)]]
		if not ProphecyDefs.is_ready(id):
			label += " - not built"
		debug_prophecy_picker.add_item(label)
		var index := debug_prophecy_picker.item_count - 1
		debug_prophecy_picker.set_item_metadata(index, id)
		debug_prophecy_picker.get_popup().set_item_tooltip(index, ProphecyDefs.text(id))
	debug_prophecy_button = Button.new()
	debug_prophecy_button.text = "Add"
	debug_prophecy_button.pressed.connect(_on_debug_add_prophecy)
	debug_row.add_child(debug_prophecy_picker)
	debug_row.add_child(debug_prophecy_button)

func _on_debug_add_prophecy() -> void:
	var index := debug_prophecy_picker.selected
	if index <= 0:
		return
	debug_prophecy_requested.emit(debug_prophecy_picker.get_item_metadata(index))
	debug_prophecy_picker.select(0)

## Shown only while a bonus move is on offer, so it can be declined.
func _build_skip_bonus_button() -> void:
	skip_bonus_button = Button.new()
	skip_bonus_button.text = "Skip Bonus Move"
	skip_bonus_button.hide()
	skip_bonus_button.pressed.connect(func(): skip_bonus_requested.emit())
	var row := start_match_button.get_parent()
	row.add_child(skip_bonus_button)
	row.move_child(skip_bonus_button, wallet_label.get_index())

func set_bonus_visible(shown: bool) -> void:
	skip_bonus_button.visible = shown

func _on_extra_piece_selected(index: int) -> void:
	if index <= 0:
		return
	var type: Piece.Type = extra_piece_picker.get_item_metadata(index)
	extra_piece_picker.select(0)
	place_requested.emit(type)

func _on_place_pressed(type: Piece.Type) -> void:
	place_requested.emit(type)

func _on_size_value_changed(value: float, index: int, is_width: bool) -> void:
	board_size_changed.emit(index, is_width, int(value))

## `sizes` (Vector2i per board) fills the boxes; without it they get random values.
func _rebuild_size_controls(count: int, sizes: Array = []) -> void:
	for child in sizes_row.get_children():
		child.queue_free()
	_width_boxes.clear()
	_height_boxes.clear()

	for i in count:
		var label := Label.new()
		label.text = "Board %d:" % (i + 1)
		sizes_row.add_child(label)

		var width_box := _make_size_box(sizes[i].x if i < sizes.size() else -1)
		width_box.value_changed.connect(_on_size_value_changed.bind(i, true))
		sizes_row.add_child(width_box)

		var height_box := _make_size_box(sizes[i].y if i < sizes.size() else -1)
		height_box.value_changed.connect(_on_size_value_changed.bind(i, false))
		sizes_row.add_child(height_box)

		_width_boxes.append(width_box)
		_height_boxes.append(height_box)

func _make_size_box(value: int = -1) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = MIN_DIM
	box.max_value = MAX_DIM
	box.value = value if value >= 0 else randi_range(MIN_DIM, MAX_DIM)
	box.custom_minimum_size = Vector2(60, 0)
	return box
