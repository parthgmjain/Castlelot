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
const CARD_SLOTS := 4

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
	for i in CARD_SLOTS:
		var slot := Button.new()
		slot.text = "Empty"
		slot.disabled = true
		slot.custom_minimum_size = Vector2(120, 64)
		slot.tooltip_text = "Planet cards and jokers will be sold here."
		cards_row.add_child(slot)
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
	hide()
	closed.emit()
