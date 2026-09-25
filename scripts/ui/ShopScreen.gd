class_name ShopScreen
extends Control

signal closed
signal changed          # something was bought or drawn, so the wallet display needs refreshing

const TIER_ORDER := [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.LEGENDARY]
const TIER_COLORS := {
	Piece.Tier.COMMON: Color(0.82, 0.82, 0.82),
	Piece.Tier.UNCOMMON: Color(0.45, 0.88, 0.5),
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

## Seconds between learning the tier and learning the piece.
var reveal_delay := 0.8

var _run: RunState
var _next_title := ""
var _selected: Dictionary = {}     # roster ids picked for sacrificing
var _message := ""
var _message_tier := -1            # colors the message; -1 = plain
var _pending_tier := -1            # a pull whose piece hasn't been revealed yet

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

func refresh() -> void:
	if _run == null:
		return
	for id in _selected.keys():
		if _run.roster_entry(id).is_empty():
			_selected.erase(id)
	var busy := _pending_tier != -1

	title_label.text = "SHOP - next: %s" % _next_title
	gold_label.text = "Gold: %d" % _run.currency
	message_label.text = _message
	if _message_tier != -1:
		message_label.add_theme_color_override("font_color", TIER_COLORS[_message_tier])
	else:
		message_label.remove_theme_color_override("font_color")
	_rebuild_roster()

	var odds := Lottery.odds(_run)
	var parts: Array = []
	for tier in TIER_ORDER:
		if odds.has(tier):
			parts.append("%s %d%%" % [Piece.TIER_NAMES[tier], int(round(odds[tier] * 100.0))])
	odds_label.text = "Lottery odds: %s  (the tier is revealed first, then the piece)" % "  |  ".join(parts)

	var price := Lottery.price(_run)
	pull_button.text = "Lottery Pull - %d gold" % price
	pull_button.disabled = busy or _run.currency < price

	var check := Shop.check_trade_up(_run, _selected.keys())
	if check.ok:
		trade_up_button.text = "Trade up %d pieces -> 1 %s" % [RunConfig.TRADE_UP_COUNT, Piece.TIER_NAMES[check.to]]
	else:
		trade_up_button.text = "Trade up (%d/%d selected)" % [_selected.size(), RunConfig.TRADE_UP_COUNT]
	trade_up_button.disabled = busy or not check.ok
	trade_up_button.tooltip_text = check.reason

	points_upgrade_button.text = "Allocated points %d -> %d - %d gold" % [
		_run.allocated_points, mini(_run.allocated_points + RunConfig.POINTS_UPGRADE_AMOUNT, RunConfig.MAX_ALLOCATED_POINTS), Shop.points_upgrade_price(_run)]
	points_upgrade_button.disabled = busy or not Shop.can_buy_points(_run)
	zone_upgrade_button.text = "Zone size %d -> %d - %d gold" % [
		_run.zone_tiles, mini(_run.zone_tiles + RunConfig.ZONE_UPGRADE_AMOUNT, RunConfig.MAX_ZONE_TILES), Shop.zone_upgrade_price(_run)]
	zone_upgrade_button.disabled = busy or not Shop.can_buy_zone(_run)

func _rebuild_roster() -> void:
	for child in roster_box.get_children():
		roster_box.remove_child(child)
		child.queue_free()
	for tier in TIER_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = "%s:" % Piece.TIER_NAMES[tier]
		label.custom_minimum_size = Vector2(110, 0)
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
			button.text = "%s %s" % [Piece.symbol(entry.type, Piece.Side.WHITE), Piece.Type.find_key(entry.type).capitalize()]
			button.pressed.connect(_on_piece_toggled.bind(entry.id))
			row.add_child(button)
		roster_box.add_child(row)

func _on_piece_toggled(id: int) -> void:
	if _selected.has(id):
		_selected.erase(id)
	else:
		_selected[id] = true
	refresh()

## Pays, shows the tier straight away, then reveals the piece after a beat.
func _on_pull() -> void:
	if _pending_tier != -1:
		return
	var started := Lottery.start_pull(_run)
	if not started.ok:
		_message = started.reason
		_message_tier = -1
		changed.emit()
		refresh()
		return
	_pending_tier = started.tier
	_message = "You drew a %s piece..." % Piece.TIER_NAMES[started.tier].to_upper()
	_message_tier = started.tier
	changed.emit()
	refresh()
	if reveal_delay > 0.0:
		await get_tree().create_timer(reveal_delay).timeout
	_reveal()

## Completes a pending pull (also when you leave early, so a paid pull is never lost).
func _reveal() -> void:
	if _pending_tier == -1:
		return
	var tier: Piece.Tier = _pending_tier
	_pending_tier = -1
	var type := Lottery.finish_pull(_run, tier)
	var piece_name: String = Piece.Type.find_key(type).capitalize()
	_message = "%s! You got a %s." % [Piece.TIER_NAMES[tier], piece_name]
	_message_tier = tier
	changed.emit()
	refresh()

func _on_trade_up() -> void:
	var result := Shop.trade_up(_run, _selected.keys())
	if result.ok:
		var gained: String = Piece.Type.find_key(result.gained).capitalize()
		_message = "Traded %d pieces for a %s (%s)." % [RunConfig.TRADE_UP_COUNT, gained, Piece.TIER_NAMES[Piece.tier(result.gained)]]
		_message_tier = Piece.tier(result.gained)
		_selected.clear()
	else:
		_message = result.reason
		_message_tier = -1
	changed.emit()
	refresh()

func _on_buy_points() -> void:
	_message = "Allocated points increased." if Shop.buy_points(_run) else "Can't buy that."
	_message_tier = -1
	changed.emit()
	refresh()

func _on_buy_zone() -> void:
	_message = "Zone size increased." if Shop.buy_zone(_run) else "Can't buy that."
	_message_tier = -1
	changed.emit()
	refresh()

func _on_leave() -> void:
	_reveal()
	hide()
	closed.emit()
