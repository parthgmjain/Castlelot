extends Node2D

@onready var board: Node2D = $Board
@onready var width_spin_box: SpinBox = $UI/VBox/DimRow/WidthSpinBox
@onready var height_spin_box: SpinBox = $UI/VBox/DimRow/HeightSpinBox
@onready var side_check_button: CheckButton = $UI/VBox/PieceRow/SideCheckButton
@onready var king_button: Button = $UI/VBox/PieceRow/KingButton
@onready var queen_button: Button = $UI/VBox/PieceRow/QueenButton
@onready var rook_button: Button = $UI/VBox/PieceRow/RookButton
@onready var bishop_button: Button = $UI/VBox/PieceRow/BishopButton
@onready var knight_button: Button = $UI/VBox/PieceRow/KnightButton
@onready var pawn_button: Button = $UI/VBox/PieceRow/PawnButton
@onready var remove_button: Button = $UI/VBox/PieceRow/RemoveButton

var current_side: Piece.Side = Piece.Side.WHITE

func _ready() -> void:
	width_spin_box.value = board.grid_width
	height_spin_box.value = board.grid_height
	width_spin_box.value_changed.connect(_on_width_changed)
	height_spin_box.value_changed.connect(_on_height_changed)

	side_check_button.toggled.connect(_on_side_toggled)

	king_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KING))
	queen_button.pressed.connect(_on_place_pressed.bind(Piece.Type.QUEEN))
	rook_button.pressed.connect(_on_place_pressed.bind(Piece.Type.ROOK))
	bishop_button.pressed.connect(_on_place_pressed.bind(Piece.Type.BISHOP))
	knight_button.pressed.connect(_on_place_pressed.bind(Piece.Type.KNIGHT))
	pawn_button.pressed.connect(_on_place_pressed.bind(Piece.Type.PAWN))
	remove_button.pressed.connect(_on_remove_pressed)

func _on_width_changed(value: float) -> void:
	board.grid_width = int(value)

func _on_height_changed(value: float) -> void:
	board.grid_height = int(value)

func _on_side_toggled(pressed: bool) -> void:
	current_side = Piece.Side.BLACK if pressed else Piece.Side.WHITE

func _on_place_pressed(type: Piece.Type) -> void:
	board.place_piece(board.selected_square, type, current_side)

func _on_remove_pressed() -> void:
	board.remove_piece(board.selected_square)
