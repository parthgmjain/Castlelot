class_name TurnFlow
extends Node
## What happens after each move: scoring, promotion, passing the turn, and the AI's reply.

signal view_changed

var state: GameState
var promotion_picker: PromotionPicker

## Pause before the AI moves so its move can be followed.
var ai_delay := 0.6

## Everything that follows a completed move, for either side.
func after_move(result: Dictionary) -> void:
	MatchController.record_move(state, result)
	MoveController.mark_last_move(state, result)
	if state.current_match.result != "":
		state.pending_promotion = {}
	if not state.pending_promotion.is_empty() and state.current_match.result == "":
		promotion_picker.open(state.pending_promotion.piece.side)
		view_changed.emit()
		return
	finish_turn()

func promotion_chosen(type: Piece.Type) -> void:
	PawnMovement.promote(state.pending_promotion.piece, type)
	state.pending_promotion.board.queue_redraw()
	state.pending_promotion = {}
	finish_turn()

func finish_turn() -> void:
	MatchController.end_turn(state)
	view_changed.emit()
	var current := state.current_match
	if current.active and current.turn_side != current.player_side and not state.debug_mode:
		run_ai_turn()

func run_ai_turn() -> void:
	await get_tree().create_timer(ai_delay).timeout
	var current := state.current_match
	if not current.active or current.turn_side == current.player_side or state.debug_mode:
		return

	var choice := GreedyAI.choose_move(state, current.turn_side)
	if choice.is_empty():
		finish_turn()
		return

	state.active_board = choice.board
	state.active_square = choice.square
	var result := MoveController.execute(state, choice.move)
	if not state.pending_promotion.is_empty():
		PawnMovement.promote(state.pending_promotion.piece, PawnMovement.PROMOTION_CHOICES[0])
		state.pending_promotion = {}
	after_move(result)
