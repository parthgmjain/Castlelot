class_name PromotionPicker
extends Control

signal piece_chosen(type: Piece.Type)

@onready var panel: PanelContainer = $Center/Panel
@onready var buttons_row: HBoxContainer = $Center/Panel/Margin/VBox/Buttons

var _buttons: Dictionary = {}

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.16)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	for type in PawnMovement.PROMOTION_CHOICES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_choice_pressed.bind(type))
		buttons_row.add_child(button)
		_buttons[type] = button

## Shows the picker with `side`'s piece glyphs. Its full-screen backdrop
## swallows clicks, so nothing else can be used until a piece is chosen.
func open(side: Piece.Side) -> void:
	for type in _buttons:
		_buttons[type].text = "%s %s" % [Piece.symbol(type, side), Piece.Type.find_key(type).capitalize()]
	show()
	_buttons[PawnMovement.PROMOTION_CHOICES[0]].grab_focus()

func _on_choice_pressed(type: Piece.Type) -> void:
	hide()
	piece_chosen.emit(type)
