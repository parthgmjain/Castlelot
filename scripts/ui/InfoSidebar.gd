class_name InfoSidebar
extends Control
## Left-side run/match info panel, Balatro-style boxed stat readouts: a top
## row with Round and Match in their own boxes, then Gold, then Moves, then
## Score, then the Piece Values button. Shown throughout an active run (not
## just mid-match), so round/gold/moves context stays visible during
## deployment too - Moves shows the match's move allotment before it starts,
## then counts down once it's active. Score only exists once a match is
## actually active (there's nothing to show before then). The full
## piece-value reference used to live inline here - it's now a popup (see
## PieceValuesPopup) opened via `values_requested`.

signal values_requested

@onready var round_label: Label = $Margin/VBox/Stats/TopRow/RoundBox/RoundLabel
@onready var match_label: Label = $Margin/VBox/Stats/TopRow/MatchBox/MatchLabel
@onready var gold_label: Label = $Margin/VBox/Stats/GoldBox/GoldLabel
@onready var moves_label: Label = $Margin/VBox/Stats/MovesBox/MovesLabel
@onready var score_box: PanelContainer = $Margin/VBox/Stats/ScoreBox
@onready var score_label: Label = $Margin/VBox/Stats/ScoreBox/ScoreLabel
@onready var values_button: Button = $Margin/VBox/ValuesButton

func _ready() -> void:
	for box in [round_label.get_parent(), match_label.get_parent(), gold_label.get_parent(), moves_label.get_parent(), score_box]:
		box.add_theme_stylebox_override("panel", ModalStyle.panel())
	values_button.pressed.connect(func(): values_requested.emit())

## Refreshes every stat box for the run's current state.
func update(state: GameState) -> void:
	visible = state.run.active
	if not visible:
		return
	var run := state.run
	var current := state.current_match
	round_label.text = ("Round %d" % run.round_number) if run.is_final_round() else "Round %d/%d" % [run.round_number, RunConfig.ROUNDS]
	match_label.text = "Match %d/%d" % [run.match_number, run.matches_in_round()]
	gold_label.text = "Gold: %d" % run.currency

	if current.active:
		moves_label.text = "Moves left: %d" % current.moves_left
	elif state.deployment.active:
		moves_label.text = "Moves: %d" % state.deployment.setup.get("moves", 0)
	else:
		moves_label.text = "Moves: -"

	score_box.visible = current.active
	if current.active:
		score_label.text = "Score: %d / %d" % [current.scores[current.player_side], current.target_score]
