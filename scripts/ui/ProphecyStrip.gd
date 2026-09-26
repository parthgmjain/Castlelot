class_name ProphecyStrip
extends PanelContainer
## The prophecies you carry, shown down the left of the board during a run: play a match card
## on your turn, arm an armed card before a match, or discard. A card that needs a choice
## (Blessing of the Blade) shows its options underneath.

signal play_requested(index: int)
signal arm_requested(index: int, armed: bool)
signal discard_requested(index: int)
signal choice_made(value: Variant)

var _rows: VBoxContainer
var _message: Label
var _choice_prompt: Label
var _choice_row: HFlowContainer

func _ready() -> void:
	position = Vector2(8, 385)
	custom_minimum_size = Vector2(260, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var header := Label.new()
	header.name = "Header"
	header.text = "PROPHECIES"
	box.add_child(header)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 12)
	_message.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(240, 0)
	box.add_child(_message)
	_choice_prompt = Label.new()
	_choice_prompt.hide()
	box.add_child(_choice_prompt)
	_choice_row = HFlowContainer.new()
	_choice_row.hide()
	box.add_child(_choice_row)
	hide()

## Redraws the hand for the current game.
func update(state: GameState) -> void:
	var run := state.run
	visible = run.active and not run.hand.is_empty()
	if not visible:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var current := state.current_match
	var in_match := current.active
	var my_turn := in_match and (current.turn_side == current.player_side or state.debug_mode) and state.pending_promotion.is_empty() and current.bonus.is_empty()
	for i in run.hand.size():
		var entry: Dictionary = run.hand[i]
		var buttons: Array = []
		match ProphecyDefs.timing(entry.id):
			"match":
				buttons.append({ "text": "Play", "disabled": not my_turn or not ProphecyDefs.is_ready(entry.id),
					"tooltip": "Play it on your turn during a match (it's free).", "action": func(): play_requested.emit(i) })
			"armed":
				buttons.append({ "text": "Disarm" if entry.armed else "Arm", "disabled": in_match,
					"tooltip": "Arm it before a match starts.", "action": func(): arm_requested.emit(i, not entry.armed) })
		buttons.append({ "text": "Discard", "disabled": false, "action": func(): discard_requested.emit(i) })
		_rows.add_child(ProphecyUI.hand_row(entry, buttons, true))

func set_message(text: String) -> void:
	_message.text = text

## Shows a choice: `options` is [{ text, value }].
func show_choice(prompt: String, options: Array) -> void:
	_choice_prompt.text = prompt
	_choice_prompt.show()
	for child in _choice_row.get_children():
		_choice_row.remove_child(child)
		child.queue_free()
	for option in options:
		var button := Button.new()
		button.text = option.text
		button.tooltip_text = option.get("tooltip", "")
		button.pressed.connect(func(): choice_made.emit(option.value))
		_choice_row.add_child(button)
	_choice_row.show()

func hide_choice() -> void:
	_choice_prompt.hide()
	_choice_row.hide()

func is_choosing() -> bool:
	return _choice_row.visible
