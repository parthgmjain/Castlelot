class_name InfoSidebar
extends Control
## Left-side run/match info panel, Balatro-style boxed stat readouts, plus a
## scrollable reference of what every piece is worth. Shown throughout an
## active run (not just mid-match), so round/gold context stays visible
## during deployment too; the match-only stats (score/moves/turn) hide until
## a match is actually active.

@onready var round_label: Label = $Margin/VBox/Stats/RoundLabel
@onready var gold_label: Label = $Margin/VBox/Stats/GoldLabel
@onready var score_label: Label = $Margin/VBox/Stats/ScoreLabel
@onready var moves_label: Label = $Margin/VBox/Stats/MovesLabel
@onready var turn_label: Label = $Margin/VBox/Stats/TurnLabel
@onready var value_list: VBoxContainer = $Margin/VBox/Scroll/ValueList

func _ready() -> void:
	_build_value_reference()

## Refreshes every stat row for the run's current state.
func update(state: GameState) -> void:
	visible = state.run.active
	if not visible:
		return
	var run := state.run
	var current := state.current_match
	round_label.text = run.title()
	gold_label.text = "Gold: %d" % run.currency

	var mid_match := current.active
	score_label.visible = mid_match
	moves_label.visible = mid_match
	turn_label.visible = mid_match
	if mid_match:
		score_label.text = "Score: %d / %d" % [current.scores[current.player_side], current.target_score]
		moves_label.text = "Moves left: %d" % current.moves_left
		turn_label.text = "Your Turn" if current.turn_side == current.player_side else "AI Thinking..."

## Every piece's point value, grouped by tier - built once, since it never
## changes with game state (unlike the stat rows above).
func _build_value_reference() -> void:
	for child in value_list.get_children():
		value_list.remove_child(child)
		child.queue_free()
	for tier in [Piece.Tier.COMMON, Piece.Tier.UNCOMMON, Piece.Tier.RARE, Piece.Tier.LEGENDARY]:
		var header := Label.new()
		header.text = Piece.TIER_NAMES[tier]
		header.add_theme_font_size_override("font_size", 14)
		value_list.add_child(header)
		for type in Piece.types_in_tier(tier):
			var row := Label.new()
			row.text = "%s - %d" % [Piece.display_name(type), Piece.value(type)]
			row.add_theme_font_size_override("font_size", 12)
			value_list.add_child(row)
