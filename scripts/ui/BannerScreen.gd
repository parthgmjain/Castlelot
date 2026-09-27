class_name BannerScreen
extends Control
## Pick a banner before a run: 17 buttons, one per Banners.Id, built from the
## data in Banners.gd. Choosing one hides the screen and emits `chosen`.

signal chosen(id: Banners.Id)

@onready var panel: PanelContainer = $Center/Panel
@onready var list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/List

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())
	for id in Banners.ids():
		var button := Button.new()
		button.text = "%s - %s" % [Banners.display_name(id), Banners.description(id)]
		button.tooltip_text = Banners.description(id)
		button.custom_minimum_size = Vector2(0, 44)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_chosen.bind(id))
		list.add_child(button)

func open() -> void:
	show()

func _on_chosen(id: Banners.Id) -> void:
	hide()
	chosen.emit(id)
