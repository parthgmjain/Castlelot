class_name RosterStrip
extends Control
## Bottom-of-screen strip showing your whole roster as cards during an
## active match. Occupies the same screen region as the deployment bench
## (see DeploymentBench) but the two are always mutually exclusive in time:
## deployment ends (and the match begins) before this ever shows.

## A separate component from DeploymentBench's and BannerScreen's cards (see
## _make_roster_card) even though the shapes are similar today, so any of
## the three can diverge later without entangling the others.
const CARD_SIZE := Vector2(90, 130)

@onready var box: HBoxContainer = $Margin/Scroll/Box

## Rebuilds the strip for the run's current roster and match state. A
## benched piece (not currently on a board) is dimmed relative to a
## deployed one.
func update(state: GameState) -> void:
	visible = state.run.active and state.current_match.active
	if not visible:
		return
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var side := Banners.player_side(state.run)
	var on_field := Roster.on_field(state.boards, side)
	for entry in state.run.roster:
		box.add_child(_make_roster_card(entry, on_field.has(entry.id)))

## One roster card: a reserved `Art` slot (an empty TextureRect - real
## artwork drops in later) above the piece's name. `deployed` pieces show at
## full strength; benched ones are dimmed to tell them apart at a glance.
func _make_roster_card(entry: Dictionary, deployed: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.modulate = Color(1, 1, 1, 1.0) if deployed else Color(1, 1, 1, 0.5)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(art)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = Piece.Type.find_key(entry.type).capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	return card
