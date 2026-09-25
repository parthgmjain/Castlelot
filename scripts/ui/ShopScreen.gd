class_name ShopScreen
extends Control

signal closed
signal changed          # something was bought or drawn, so the wallet display needs refreshing

const TIER_ORDER := [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]
const TIER_COLORS := {
	Piece.Tier.COMMON: Color(0.82, 0.82, 0.82),
	Piece.Tier.UNCOMMON: Color(0.45, 0.88, 0.5),
	Piece.Tier.RARE: Color(0.45, 0.7, 1.0),
	Piece.Tier.LEGENDARY: Color(1.0, 0.8, 0.25),
}

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var gold_label: Label = $Center/Panel/Margin/VBox/Gold
@onready var message_label: Label = $Center/Panel/Margin/VBox/Message
@onready var roster_box: VBoxContainer = $Center/Panel/Margin/VBox/RosterBox
@onready var odds_label: Label = $Center/Panel/Margin/VBox/OddsLabel
@onready var pull_button: Button = $Center/Panel/Margin/VBox/PieceActions/PullButton
@onready var trade_up_button: Button = $Center/Panel/Margin/VBox/PieceActions/TradeUpButton
@onready var points_upgrade_button: Button = $Center/Panel/Margin/VBox/UpgradeActions/PointsUpgradeButton
@onready var zone_upgrade_button: Button = $Center/Panel/Margin/VBox/UpgradeActions/ZoneUpgradeButton
@onready var cards_row: HBoxContainer = $Center/Panel/Margin/VBox/CardsRow
@onready var leave_button: Button = $Center/Panel/Margin/VBox/Leave

## Where a choice from run.pending is laid out: a prompt and a row of buttons (built in _ready).
var choice_box: VBoxContainer
var choice_prompt: Label
var choice_row: HBoxContainer

## Seconds between learning the tier and being shown the cards.
var reveal_delay := 0.8

var _run: RunState
var _next_title := ""
var _selected: Dictionary = {}     # roster ids picked for sacrificing
var _message := ""
var _message_tier := -1            # colors the message; -1 = plain
var _pending_tier := -1            # a pull whose cards haven't been shown yet

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())
	pull_button.pressed.connect(_on_pull)
	trade_up_button.pressed.connect(_on_trade_up)
	points_upgrade_button.pressed.connect(_on_buy_points)
	zone_upgrade_button.pressed.connect(_on_buy_zone)
	leave_button.pressed.connect(_on_leave)
	_build_choice_box()

func _build_choice_box() -> void:
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 6)
	choice_prompt = Label.new()
	choice_row = HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 8)
	choice_box.add_child(choice_prompt)
	choice_box.add_child(choice_row)
	choice_box.hide()
	message_label.get_parent().add_child(choice_box)
	message_label.get_parent().move_child(choice_box, message_label.get_index() + 1)

## Opens the shop for `run`. Its full-screen backdrop swallows clicks until you leave.
func open(run: RunState, next_title: String) -> void:
	_run = run
	_next_title = next_title
	_selected.clear()
	_message = ""
	_message_tier = -1
	_pending_tier = -1
	Prophecies.refresh_offers(run)
	show()
	refresh()
	leave_button.grab_focus()

## Something has to be decided before you can do anything else in the shop.
func is_busy() -> bool:
	return _run != null and (_pending_tier != -1 or not _run.pending.is_empty())

func refresh() -> void:
	if _run == null:
		return
	for id in _selected.keys():
		if _run.roster_entry(id).is_empty():
			_selected.erase(id)
	var busy := is_busy()

	title_label.text = "SHOP - next: %s" % _next_title
	gold_label.text = "Gold: %d" % _run.currency
	message_label.text = _message
	if _message_tier != -1:
		message_label.add_theme_color_override("font_color", TIER_COLORS[_message_tier])
	else:
		message_label.remove_theme_color_override("font_color")
	_rebuild_roster()
	_rebuild_choice()
	_rebuild_prophecies()

	var odds := Lottery.odds(_run)
	var parts: Array = []
	for tier in TIER_ORDER:
		if odds.has(tier):
			parts.append("%s %d%%" % [Piece.TIER_NAMES[tier], int(round(odds[tier] * 100.0))])
	odds_label.text = "Lottery odds: %s  (the tier is revealed first, then you choose from %d cards)" % ["  |  ".join(parts), RunConfig.CARDS_OFFERED]

	var price := Lottery.price(_run)
	pull_button.text = "Lottery Pull - %d gold" % price
	pull_button.disabled = busy or _run.currency < price

	var check := Shop.check_trade_up(_run, _selected.keys())
	if check.ok:
		trade_up_button.text = "Trade up %d pieces -> %s" % [check.count, Piece.TIER_NAMES[check.to]]
	else:
		trade_up_button.text = "Trade up (%d/%d selected)" % [_selected.size(), check.get("count", RunConfig.TRADE_UP_COUNTS[Piece.Tier.COMMON])]
	trade_up_button.disabled = busy or not check.ok
	trade_up_button.tooltip_text = check.reason

	points_upgrade_button.text = "Allocated points %d -> %d - %d gold" % [
		_run.allocated_points, mini(_run.allocated_points + RunConfig.POINTS_UPGRADE_AMOUNT, RunConfig.MAX_ALLOCATED_POINTS), Shop.points_upgrade_price(_run)]
	points_upgrade_button.disabled = busy or not Shop.can_buy_points(_run)
	zone_upgrade_button.text = "Zone size %d -> %d - %d gold" % [
		_run.zone_tiles, mini(_run.zone_tiles + RunConfig.ZONE_UPGRADE_AMOUNT, RunConfig.MAX_ZONE_TILES), Shop.zone_upgrade_price(_run)]
	zone_upgrade_button.disabled = busy or not Shop.can_buy_zone(_run)
	leave_button.disabled = busy

func _rebuild_roster() -> void:
	for child in roster_box.get_children():
		roster_box.remove_child(child)
		child.queue_free()
	for tier in TIER_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = "%s (%d/%d types):" % [Piece.TIER_NAMES[tier], _run.held_types(tier).size(), RunConfig.SLOTS_PER_TIER[tier]]
		label.custom_minimum_size = Vector2(190, 0)
		label.add_theme_color_override("font_color", TIER_COLORS[tier])
		row.add_child(label)
		var pieces: Array = _run.roster.filter(func(entry): return Piece.tier(entry.type) == tier)
		if pieces.is_empty():
			var none := Label.new()
			none.text = "-"
			row.add_child(none)
		for entry in pieces:
			var button := Button.new()
			button.toggle_mode = true
			button.button_pressed = _selected.has(entry.id)
			button.text = "%s %s (%d)" % [Piece.symbol(entry.type, Piece.Side.WHITE), Piece.display_name(entry.type), Piece.value(entry.type)]
			button.pressed.connect(_on_piece_toggled.bind(entry.id))
			row.add_child(button)
		roster_box.add_child(row)

# ---- the choice waiting in run.pending -----------------------------------------------------

func _rebuild_choice() -> void:
	for child in choice_row.get_children():
		choice_row.remove_child(child)
		child.queue_free()
	var pending := _run.pending
	choice_box.visible = not pending.is_empty()
	if pending.is_empty():
		return
	match pending.kind:
		"cards":
			var tier: Piece.Tier = pending.tier
			choice_prompt.add_theme_color_override("font_color", TIER_COLORS[tier])
			if pending.stage == "pick":
				choice_prompt.text = "Choose one of these %s cards:" % Piece.TIER_NAMES[tier].to_upper()
				for i in pending.cards.size():
					choice_row.add_child(_card_button(pending.cards[i], tier, i))
			else:
				choice_prompt.text = "Your %s slots are full. Which type do you swap out for the %s? (Your pieces of that type become %s.)" % [
					Piece.TIER_NAMES[tier].to_lower(), Piece.display_name(pending.card.type), Piece.display_name(pending.card.type)]
				for type in _run.held_types(tier):
					var button := Button.new()
					button.text = "%s x%d" % [Piece.display_name(type), _run.count_of(type)]
					button.custom_minimum_size = Vector2(130, 56)
					button.pressed.connect(_on_replace_picked.bind(type))
					choice_row.add_child(button)
		"bargain":
			choice_prompt.add_theme_color_override("font_color", TIER_COLORS[ProphecyDefs.rarity("merlins_bargain")])
			choice_prompt.text = "Merlin's Bargain: which piece do you give up? You get %dx its points in gold." % Prophecies.BARGAIN_MULTIPLIER
			for entry in _run.roster:
				var button := Button.new()
				button.text = "%s\n-> %d gold" % [Piece.display_name(entry.type), Piece.value(entry.type) * Prophecies.BARGAIN_MULTIPLIER]
				button.custom_minimum_size = Vector2(110, 56)
				button.pressed.connect(_on_bargain_picked.bind(entry.id))
				choice_row.add_child(button)
			var cancel := Button.new()
			cancel.text = "Keep my\npieces"
			cancel.custom_minimum_size = Vector2(110, 56)
			cancel.pressed.connect(_on_bargain_cancelled)
			choice_row.add_child(cancel)
		"legendary_pick":
			choice_prompt.add_theme_color_override("font_color", TIER_COLORS[Piece.Tier.LEGENDARY])
			choice_prompt.text = "Choose your LEGENDARY:"
			for type in pending.options:
				var button := Button.new()
				button.text = "%s\nvalue %d" % [Piece.display_name(type), Piece.value(type)]
				button.custom_minimum_size = Vector2(130, 64)
				button.pressed.connect(_on_upgrade_picked.bind(type))
				choice_row.add_child(button)
		"legendary_full":
			choice_prompt.add_theme_color_override("font_color", TIER_COLORS[Piece.Tier.LEGENDARY])
			choice_prompt.text = "Both legendary slots are full and the %s has arrived. Which one do you give up?" % Piece.display_name(pending.incoming)
			for type in _run.held_types(Piece.Tier.LEGENDARY):
				var button := Button.new()
				button.text = "Give up\n%s" % Piece.display_name(type)
				button.custom_minimum_size = Vector2(130, 64)
				button.pressed.connect(_on_give_up.bind(type))
				choice_row.add_child(button)
			var decline := Button.new()
			decline.text = "Decline the\n%s" % Piece.display_name(pending.incoming)
			decline.custom_minimum_size = Vector2(130, 64)
			decline.pressed.connect(_on_give_up.bind(pending.incoming))
			choice_row.add_child(decline)

# ---- prophecies -----------------------------------------------------------------------------------

func _rebuild_prophecies() -> void:
	for child in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	cards_row.add_theme_constant_override("separation", 24)
	var busy := is_busy()

	var sale := VBoxContainer.new()
	var sale_header := Label.new()
	sale_header.text = "For sale"
	sale.add_child(sale_header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for slot in _run.prophecy_offers.size():
		var id: String = _run.prophecy_offers[slot]
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 80)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if id == "":
			button.text = "Sold"
			button.disabled = true
		else:
			button.text = "%s - %d gold\n%s\n%s" % [ProphecyDefs.display_name(id), Prophecies.price(id), Piece.TIER_NAMES[ProphecyDefs.rarity(id)], ProphecyDefs.text(id)]
			button.add_theme_color_override("font_color", ProphecyUI.color(id))
			button.disabled = busy or _run.currency < Prophecies.price(id)
			button.tooltip_text = "%s (%s)" % [ProphecyDefs.text(id), ProphecyUI.timing_note(id)]
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_buy_prophecy.bind(slot))
		grid.add_child(button)
	sale.add_child(grid)
	cards_row.add_child(sale)

	var hand := VBoxContainer.new()
	hand.custom_minimum_size = Vector2(330, 0)
	var hand_header := Label.new()
	hand_header.text = "Your hand (%d/%d)" % [_run.hand.size(), RunConfig.HAND_SIZE]
	hand.add_child(hand_header)
	if _run.hand.is_empty():
		var empty := Label.new()
		empty.text = "Nothing yet - buy a prophecy."
		empty.add_theme_font_size_override("font_size", 12)
		hand.add_child(empty)
	for i in _run.hand.size():
		var entry: Dictionary = _run.hand[i]
		var buttons: Array = []
		match ProphecyDefs.timing(entry.id):
			"shop":
				var second_sight: bool = entry.id == "second_sight" and _run.pending.get("kind") == "cards" and _run.pending.stage == "pick"
				buttons.append({ "text": "Play", "disabled": (busy and not second_sight) or not ProphecyDefs.is_ready(entry.id), "action": _on_play_prophecy.bind(i) })
			"armed":
				buttons.append({ "text": "Disarm" if entry.armed else "Arm", "disabled": busy, "tooltip": "Armed cards fire on their own in the next match.", "action": _on_arm_prophecy.bind(i, not entry.armed) })
		buttons.append({ "text": "Discard", "disabled": busy, "action": _on_discard_prophecy.bind(i) })
		hand.add_child(ProphecyUI.hand_row(entry, buttons))
	cards_row.add_child(hand)

func _on_buy_prophecy(slot: int) -> void:
	var result := Prophecies.buy(_run, slot)
	_say("Bought %s." % ProphecyDefs.display_name(result.id) if result.ok else result.reason, ProphecyDefs.rarity(result.id) if result.ok else -1)
	changed.emit()
	refresh()

func _on_play_prophecy(index: int) -> void:
	var name: String = ProphecyDefs.display_name(_run.hand[index].id) if index < _run.hand.size() else ""
	var result := Prophecies.play_in_shop(_run, index)
	if not result.ok:
		_say(result.reason)
	elif result.waiting:
		_say(result.note)
	else:
		_say("%s: %s" % [name, result.note])
	changed.emit()
	refresh()

func _on_arm_prophecy(index: int, armed: bool) -> void:
	var result := Prophecies.set_armed(_run, index, armed)
	_say(("%s %s." % [ProphecyDefs.display_name(_run.hand[index].id), "armed for the next match" if armed else "disarmed"]) if result.ok else result.reason)
	refresh()

func _on_discard_prophecy(index: int) -> void:
	var result := Prophecies.discard(_run, index)
	_say("Discarded %s." % ProphecyDefs.display_name(result.id) if result.ok else result.reason)
	changed.emit()
	refresh()

func _on_bargain_picked(roster_id: int) -> void:
	var result := Prophecies.resolve_bargain(_run, roster_id)
	_say("Merlin takes the %s and leaves you %d gold." % [Piece.display_name(result.piece), result.gold] if result.ok else result.reason)
	changed.emit()
	refresh()

func _on_bargain_cancelled() -> void:
	Prophecies.cancel_bargain(_run)
	_say("You keep your pieces (and the card).")
	refresh()

func _card_button(card: Dictionary, tier: Piece.Tier, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 78)
	var name := Piece.display_name(card.type)
	if card.kind == "add":
		button.text = "+1 %s\n(you have %d)\nvalue %d" % [name, _run.count_of(card.type), Piece.value(card.type)]
	else:
		var slot := "takes a free slot" if _run.free_slots(tier) > 0 else "swaps out a type"
		button.text = "NEW: %s\nvalue %d\n%s" % [name, Piece.value(card.type), slot]
	button.pressed.connect(_on_card_picked.bind(index))
	return button

func _on_card_picked(index: int) -> void:
	var tier: Piece.Tier = _run.pending.get("tier", Piece.Tier.COMMON)
	var result := Lottery.pick_card(_run, index)
	if not result.ok:
		_say(result.reason)
	elif result.stage == "done":
		var name := Piece.display_name(result.gained)
		_say("You now hold %d x %s." % [_run.count_of(result.gained), name], tier)
	changed.emit()
	refresh()

func _on_replace_picked(type: Piece.Type) -> void:
	var tier: Piece.Tier = _run.pending.get("tier", Piece.Tier.COMMON)
	var result := Lottery.pick_replacement(_run, type)
	if result.ok:
		_say("%s swapped for %s - you keep your %d pieces." % [Piece.display_name(result.replaced), Piece.display_name(result.gained), _run.count_of(result.gained)], tier)
	else:
		_say(result.reason)
	changed.emit()
	refresh()

func _on_upgrade_picked(type: Piece.Type) -> void:
	var result := Legendaries.pick_upgrade(_run, type)
	if result.ok:
		match result.status:
			"added":
				_say("The %s joins you!" % Piece.display_name(type), Piece.Tier.LEGENDARY)
			"owned":
				_say("You already hold the %s." % Piece.display_name(type), Piece.Tier.LEGENDARY)
			"choose":
				_say("Your legendary slots are full - choose what to give up.", Piece.Tier.LEGENDARY)
	else:
		_say(result.reason)
	changed.emit()
	refresh()

func _on_give_up(type: Piece.Type) -> void:
	var result := Legendaries.resolve_full(_run, type)
	if result.ok:
		_say("Decided: you keep your legendaries." if not result.kept_incoming else "The %s is yours." % Piece.display_name(_run.held_types(Piece.Tier.LEGENDARY).back()), Piece.Tier.LEGENDARY)
	else:
		_say(result.reason)
	changed.emit()
	refresh()

func _say(text: String, tier: int = -1) -> void:
	_message = text
	_message_tier = tier

# ---- actions ------------------------------------------------------------------------------------

func _on_piece_toggled(id: int) -> void:
	if _selected.has(id):
		_selected.erase(id)
	else:
		_selected[id] = true
	refresh()

## Pays, shows the tier straight away, then lays out the cards after a beat.
func _on_pull() -> void:
	if is_busy():
		return
	var started := Lottery.start_pull(_run)
	if not started.ok:
		_say(started.reason)
		changed.emit()
		refresh()
		return
	_pending_tier = started.tier
	_say("You drew a %s piece..." % Piece.TIER_NAMES[started.tier].to_upper(), started.tier)
	changed.emit()
	refresh()
	if reveal_delay > 0.0:
		await get_tree().create_timer(reveal_delay).timeout
	_show_cards()

## Lays out the cards for a pull whose tier is known (also when you try to leave early).
func _show_cards() -> void:
	if _pending_tier == -1:
		return
	var tier: Piece.Tier = _pending_tier
	_pending_tier = -1
	Lottery.begin_choice(_run, tier, "pull")
	_say("%s! Pick a card." % Piece.TIER_NAMES[tier], tier)
	changed.emit()
	refresh()

func _on_trade_up() -> void:
	var result := Shop.trade_up(_run, _selected.keys())
	if result.ok:
		_selected.clear()
		_say("Traded in for the next tier - choose your reward.", result.to)
	else:
		_say(result.reason)
	changed.emit()
	refresh()

func _on_buy_points() -> void:
	_say("Allocated points increased." if Shop.buy_points(_run) else "Can't buy that.")
	changed.emit()
	refresh()

func _on_buy_zone() -> void:
	_say("Zone size increased." if Shop.buy_zone(_run) else "Can't buy that.")
	changed.emit()
	refresh()

func _on_leave() -> void:
	if _pending_tier != -1:
		_show_cards()
		return
	if not _run.pending.is_empty():
		_say("Make your choice first.")
		refresh()
		return
	Prophecies.end_shop(_run)
	hide()
	closed.emit()
