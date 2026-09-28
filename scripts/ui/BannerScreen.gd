class_name BannerScreen
extends Control
## Pick your run's banners and difficulty before a run begins, Balatro-deck-
## select style: step 1 is White Banner vs Black Banner (which side you
## play), step 2 is one of the 15 trait banners (an advantage/disadvantage
## pair), step 3 is a difficulty (Easy/Normal/Hard/Nightmare). All three
## steps share the same layout: a horizontal, side-scrolling carousel of
## vertical banner-shaped cards. Each card's `Art` node is an empty
## TextureRect - a reserved slot for real banner artwork later, not drawn
## here. Emits `chosen` with all three once the third pick is made.

signal chosen(side_id: Banners.Id, trait_id: Banners.Id, difficulty: Difficulty.Level)

## Vertical banner proportions: taller than wide.
const CARD_SIZE := Vector2(200, 440)

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var list: HBoxContainer = $Center/Panel/Margin/VBox/Scroll/List

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
	_clear_list()
	for id in [Banners.Id.WHITE, Banners.Id.BLACK]:
		list.add_child(_make_card(Banners.display_name(id), Banners.description(id), _on_side_chosen.bind(id)))

func _show_trait_step() -> void:
	title_label.text = "Choose your banner"
	_clear_list()
	for id in Banners.ids().filter(func(bid): return not Banners.is_side(bid)):
		list.add_child(_make_card(Banners.display_name(id), Banners.description(id), _on_trait_chosen.bind(id)))

func _show_difficulty_step() -> void:
	title_label.text = "Choose your difficulty"
	_clear_list()
	for level in Difficulty.levels():
		list.add_child(_make_card(Difficulty.display_name(level), "", _on_difficulty_chosen.bind(level)))

## One vertical banner card: a reserved `Art` slot (an empty TextureRect -
## real artwork drops in later, only the layout exists here) above a name
## label, the whole thing clickable. `description` (when given) becomes the
## card's tooltip. Every child has mouse_filter = IGNORE so clicks reach the
## button underneath them rather than being absorbed.
func _make_card(card_name: String, description: String, handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.tooltip_text = description
	button.pressed.connect(handler)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(vbox)

	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(art)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	return button

## Removes the previous step's cards immediately (not just queue_free, which
## would leave them counted in get_children() until the next frame).
func _clear_list() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

func _on_side_chosen(id: Banners.Id) -> void:
	_side_id = id
	_show_trait_step()

func _on_trait_chosen(id: Banners.Id) -> void:
	_trait_id = id
	_show_difficulty_step()

func _on_difficulty_chosen(level: Difficulty.Level) -> void:
	hide()
	chosen.emit(_side_id, _trait_id, level)
