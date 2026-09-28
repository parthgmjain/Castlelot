class_name InfoSidebar
extends Control
## Left-side run/match info panel, Balatro-style boxed stat readouts (round,
## gold, score, moves left, turn). Shown throughout an active run (not just
## mid-match), so round/gold context stays visible during deployment too;
## the match-only stats (score/moves/turn) hide until a match is actually
## active. The full piece-value reference used to live inline here - it's
## now a popup (see PieceValuesPopup) opened via `values_requested`, so this
## sidebar's own space stays dedicated to match info.

signal values_requested

@onready var round_label: Label = $Margin/VBox/Stats/RoundLabel
@onready var gold_label: Label = $Margin/VBox/Stats/GoldLabel
@onready var score_label: Label = $Margin/VBox/Stats/ScoreLabel
@onready var moves_label: Label = $Margin/VBox/Stats/MovesLabel
@onready var turn_label: Label = $Margin/VBox/Stats/TurnLabel
@onready var values_button: Button = $Margin/VBox/ValuesButton

func _ready() -> void:
	values_button.pressed.connect(func(): values_requested.emit())

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
