class_name BannerScreen
extends Control
## Pick your run's banners and difficulty before a run begins, Balatro-deck-
## select style: step 1 is White Banner vs Black Banner (which side you
## play), step 2 is one of the 15 trait banners (an advantage/disadvantage
## pair), step 3 is a difficulty (Easy/Normal/Hard/Nightmare - a selector
## only, not wired to any effect yet). Emits `chosen` with all three once the
## third pick is made.

signal chosen(side_id: Banners.Id, trait_id: Banners.Id, difficulty: Difficulty.Level)

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/List

var _side_id: Banners.Id = Banners.Id.WHITE
var _trait_id: Banners.Id = Banners.Id.IRON

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())

## Resets to step 1 (side choice) and shows the screen.
func open() -> void:
	_show_side_step()
	show()

func _show_side_step() -> void:
	title_label.text = "Choose your side"
	_populate_banners([Banners.Id.WHITE, Banners.Id.BLACK], _on_side_chosen)

func _show_trait_step() -> void:
	title_label.text = "Choose your banner"
	var traits: Array = Banners.ids().filter(func(id): return not Banners.is_side(id))
	_populate_banners(traits, _on_trait_chosen)

func _show_difficulty_step() -> void:
	title_label.text = "Choose your difficulty"
	_clear_list()
	for level in Difficulty.levels():
		var button := Button.new()
		button.text = Difficulty.display_name(level)
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_difficulty_chosen.bind(level))
		list.add_child(button)

## Removes the previous step's buttons immediately (not just queue_free, which
## would leave them counted in get_children() until the next frame).
func _clear_list() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

func _populate_banners(ids: Array, handler: Callable) -> void:
	_clear_list()
	for id in ids:
		var button := Button.new()
		button.text = "%s - %s" % [Banners.display_name(id), Banners.description(id)]
		button.tooltip_text = Banners.description(id)
		button.custom_minimum_size = Vector2(0, 44)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(handler.bind(id))
		list.add_child(button)

func _on_side_chosen(id: Banners.Id) -> void:
	_side_id = id
	_show_trait_step()

func _on_trait_chosen(id: Banners.Id) -> void:
	_trait_id = id
	_show_difficulty_step()

func _on_difficulty_chosen(level: Difficulty.Level) -> void:
	hide()
	chosen.emit(_side_id, _trait_id, level)
