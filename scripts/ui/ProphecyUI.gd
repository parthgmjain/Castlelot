class_name ProphecyUI
extends RefCounted
## Small builders shared by the shop and the in-match hand strip.

static func color(id: String) -> Color:
	return ShopScreen.TIER_COLORS[ProphecyDefs.rarity(id)]

## How a card is played, in a few words.
static func timing_note(id: String) -> String:
	match ProphecyDefs.timing(id):
		"match":
			return "played in a match"
		"armed":
			return "armed before a match"
	return "played in the shop"

## One card in your hand: its name, what it does and a row of buttons. `buttons` is a list of
## { text, disabled, tooltip, action: Callable }.
static func hand_row(entry: Dictionary, buttons: Array, compact: bool = false) -> Control:
	var id: String = entry.id
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	var state_note := "  [ARMED]" if entry.armed else ""
	if compact:
		title.text = "%s (%s)%s" % [ProphecyDefs.display_name(id), Piece.TIER_NAMES[ProphecyDefs.rarity(id)], state_note]
	else:
		title.text = "%s  (%s, %s)%s" % [ProphecyDefs.display_name(id), Piece.TIER_NAMES[ProphecyDefs.rarity(id)], timing_note(id), state_note]
	title.add_theme_color_override("font_color", color(id))
	title.tooltip_text = ProphecyDefs.text(id)
	box.add_child(title)
	var text := Label.new()
	text.text = ProphecyDefs.text(id)
	text.add_theme_font_size_override("font_size", 12)
	text.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(240 if compact else 300, 0)
	box.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for spec in buttons:
		var button := Button.new()
		button.text = spec.text
		button.disabled = spec.get("disabled", false)
		button.tooltip_text = spec.get("tooltip", "")
		button.pressed.connect(spec.action)
		row.add_child(button)
	box.add_child(row)
	return box
