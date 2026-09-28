class_name PieceValuesPopup
extends Control
## The full piece-value reference, opened from InfoSidebar's "Piece Values"
## button (it used to live inline in the sidebar at all times; moved here so
## the sidebar's own space stays free for match info like moves left).

@onready var panel: PanelContainer = $Center/Panel
@onready var value_list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/ValueList
@onready var close_button: Button = $Center/Panel/Margin/VBox/CloseButton

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())
	close_button.pressed.connect(hide)
	_build_value_reference()

func open() -> void:
	show()
	close_button.grab_focus()

## Every piece's point value, grouped by tier - built once in _ready, since
## it never changes with game state.
func _build_value_reference() -> void:
	for child in value_list.get_children():
		value_list.remove_child(child)
		child.queue_free()
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]:
		var header := Label.new()
		header.text = Piece.TIER_NAMES[tier]
		header.add_theme_font_size_override("font_size", 16)
		value_list.add_child(header)
		for type in Piece.types_in_tier(tier):
			var row := Label.new()
			row.text = "%s - %d" % [Piece.display_name(type), Piece.value(type)]
			row.add_theme_font_size_override("font_size", 13)
			value_list.add_child(row)
