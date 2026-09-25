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

const MIN_DIM := 2
const MAX_DIM := 10

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
@onready var moves_spin_box: SpinBox = $VBox/MatchRow/MovesSpinBox
@onready var target_spin_box: SpinBox = $VBox/MatchRow/TargetSpinBox
@onready var start_match_button: Button = $VBox/MatchRow/StartMatchButton
@onready var match_status_label: Label = $VBox/MatchRow/MatchStatusLabel

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
	knight_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KNIGHT))
	pawn_button.pressed.connect(_on_place_pressed.bind(Piece.Type.PAWN))
	remove_button.pressed.connect(func(): remove_requested.emit())
	start_match_button.pressed.connect(func(): start_match_requested.emit(int(moves_spin_box.value), int(target_spin_box.value)))

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

## Locks (or unlocks) every sandbox setup control, so a match in progress
## can't have its boards, zones or armies changed underneath it.
func set_sandbox_enabled(enabled: bool) -> void:
	var controls: Array = [
		count_spin_box, refresh_button, white_zone_spin_box, black_zone_spin_box, generate_zones_button,
		white_points_spin_box, black_points_spin_box, round_option, auto_place_white_button, auto_place_black_button,
		side_check_button, zone_edit_button, king_button, queen_button, rook_button, bishop_button, knight_button,
		pawn_button, remove_button, moves_spin_box, target_spin_box, start_match_button,
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

func _on_place_pressed(type: Piece.Type) -> void:
	place_requested.emit(type)

func _on_size_value_changed(value: float, index: int, is_width: bool) -> void:
	board_size_changed.emit(index, is_width, int(value))

func _rebuild_size_controls(count: int) -> void:
	for child in sizes_row.get_children():
		child.queue_free()
	_width_boxes.clear()
	_height_boxes.clear()

	for i in count:
		var label := Label.new()
		label.text = "Board %d:" % (i + 1)
		sizes_row.add_child(label)

		var width_box := _make_size_box()
		width_box.value_changed.connect(_on_size_value_changed.bind(i, true))
		sizes_row.add_child(width_box)

		var height_box := _make_size_box()
		height_box.value_changed.connect(_on_size_value_changed.bind(i, false))
		sizes_row.add_child(height_box)

		_width_boxes.append(width_box)
		_height_boxes.append(height_box)

func _make_size_box() -> SpinBox:
	var box := SpinBox.new()
	box.min_value = MIN_DIM
	box.max_value = MAX_DIM
	box.value = randi_range(MIN_DIM, MAX_DIM)
	box.custom_minimum_size = Vector2(60, 0)
	return box
