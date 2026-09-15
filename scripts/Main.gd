extends Node2D

@onready var board: Node2D = $Board
@onready var width_spin_box: SpinBox = $UI/HBoxContainer/WidthSpinBox
@onready var height_spin_box: SpinBox = $UI/HBoxContainer/HeightSpinBox

func _ready() -> void:
	width_spin_box.value = board.grid_width
	height_spin_box.value = board.grid_height
	width_spin_box.value_changed.connect(_on_width_changed)
	height_spin_box.value_changed.connect(_on_height_changed)

func _on_width_changed(value: float) -> void:
	board.grid_width = int(value)

func _on_height_changed(value: float) -> void:
	board.grid_height = int(value)
