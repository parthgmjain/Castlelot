class_name DebugFlow
extends Node
## Debug mode: you play both sides (the AI never moves on its own), any piece
## can move at any time, and the setup tools stay usable during runs.

signal view_changed

var state: GameState
var panel: ControlPanel
var run_flow: RunFlow
var turn_flow: TurnFlow

## Off puts black back under the AI's control.
func toggled(enabled: bool) -> void:
	state.debug_mode = enabled
	panel.set_debug_visible(enabled)
	view_changed.emit()
	var current := state.current_match
	if not enabled and current.active and current.turn_side != current.player_side:
		turn_flow.run_ai_turn()

## Ends the current match as a win or a loss. While you're still deploying it
## starts the match first, so the buttons work right after Start Run.
func force_result(won: bool) -> void:
	if state.deployment.active:
		run_flow.ready_to_fight()
	var current := state.current_match
	if not current.active:
		_message("no match to end - press Start Run (or Start Match) first")
		return
	current.active = false
	current.result = "win" if won else "loss"
	current.result_reason = "Debug"
	state.pending_promotion = {}
	view_changed.emit()

## Ends the side-to-move's turn without a move.
func pass_turn() -> void:
	var current := state.current_match
	if not current.active:
		_message("no match in progress - press Start Match to begin fighting first")
		return
	current.last_mover = current.turn_side
	MoveController.clear_selection(state)
	turn_flow.finish_turn()

## Jumps to any round/match of a run (starting a run if none is going) and deals it.
func goto(round_number: int, match_number: int) -> void:
	if not state.run.active:
		state.run = RunState.new()
		state.run.begin()
	state.run.round_number = clampi(round_number, 1, RunConfig.ROUNDS + 1)
	state.run.match_number = clampi(match_number, 1, state.run.matches_in_round())
	run_flow.begin_match()

func set_gold(amount: int) -> void:
	state.run.currency = amount
	view_changed.emit()

func set_moves(amount: int) -> void:
	var current := state.current_match
	if not current.active:
		_message("no match in progress, so there are no moves to set")
		return
	current.moves_left = amount
	view_changed.emit()

## Debug buttons that can't do anything say so instead of failing silently.
func _message(text: String) -> void:
	panel.set_match_status("DEBUG: %s" % text)
