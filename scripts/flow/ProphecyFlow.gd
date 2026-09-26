class_name ProphecyFlow
extends Node
## Playing prophecies during a run from the hand strip: playing a match card (asking for a
## choice when it needs one), arming, and discarding. The shop has its own controls for these.

signal view_changed

var state: GameState
var strip: ProphecyStrip

var _choosing_index := -1

func connect_strip(new_strip: ProphecyStrip) -> void:
	strip = new_strip
	strip.play_requested.connect(play)
	strip.arm_requested.connect(arm)
	strip.discard_requested.connect(discard)
	strip.choice_made.connect(choose)

func refresh_ui() -> void:
	if strip == null:
		return
	if _choosing_index >= _hand_size() or not state.current_match.active:
		_cancel_choice()
	strip.update(state)

func play(index: int) -> void:
	_finish(Prophecies.play_in_match(state, index), index)

## The answer to a card's question.
func choose(value: Variant) -> void:
	if _choosing_index < 0:
		return
	var index := _choosing_index
	_finish(Prophecies.play_in_match(state, index, value), index)

func arm(index: int, armed: bool) -> void:
	var result := Prophecies.set_armed(state.run, index, armed)
	strip.set_message("" if result.ok else result.reason)
	view_changed.emit()

func discard(index: int) -> void:
	var result := Prophecies.discard(state.run, index)
	strip.set_message("Discarded %s." % ProphecyDefs.display_name(result.id) if result.ok else result.reason)
	_cancel_choice()
	view_changed.emit()

func _finish(result: Dictionary, index: int) -> void:
	if not result.ok:
		strip.set_message(result.reason)
		return
	if result.get("needs_choice", false):
		_choosing_index = index
		var options: Array = result.options.map(func(opt): return { "text": _label(opt), "value": opt, "tooltip": _tooltip(opt) })
		strip.show_choice(result.get("prompt", "Which piece type?"), options)
		strip.set_message("")
		return
	_cancel_choice()
	strip.set_message("")
	view_changed.emit()

## A choice's raw value can be a Piece.Type (Blessing of the Blade) or a piece
## reference { board, square } (Sanctuary, Stone Ward, Wings, Swap Fates, Waypoint).
func _label(option: Variant) -> String:
	if option is Dictionary:
		var piece = option.board.pieces.get(option.square)
		if piece != null:
			return "%s at %s" % [Piece.display_name(piece.type), option.square]
		return "Empty square %s" % option.square
	return Piece.display_name(option)

## What the choice's underlying piece does, or "" for an empty destination square.
func _tooltip(option: Variant) -> String:
	if option is Dictionary:
		var piece = option.board.pieces.get(option.square)
		return Piece.description(piece.type) if piece != null else ""
	return Piece.description(option)

func _cancel_choice() -> void:
	_choosing_index = -1
	Prophecies.cancel_choice(state)
	if strip != null:
		strip.hide_choice()

func _hand_size() -> int:
	return state.run.hand.size()
