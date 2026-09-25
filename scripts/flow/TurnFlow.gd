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
	var current := state.current_match
	if result.get("undo", false):              # a rewind: no move was made, and it is still your turn
		MoveController.mark_last_move(state, {})
		view_changed.emit()
		return
	var was_bonus := not current.bonus.is_empty()
	MatchController.record_move(state, result, was_bonus)
	MoveController.mark_last_move(state, result)
	current.bonus = MoveEffects.bonus_after(state, result, was_bonus) if current.active else {}
	if not current.bonus.is_empty() and not MoveEffects.bonus_playable(state):
		current.bonus = {}                    # nothing could use it, so don't offer it
	if current.result != "":
		state.pending_promotion = {}
	if not state.pending_promotion.is_empty() and current.result == "":
		promotion_picker.open(state.pending_promotion.piece.side)
		view_changed.emit()
		return
	_continue_turn()

func promotion_chosen(type: Piece.Type) -> void:
	PawnMovement.promote(state.pending_promotion.piece, type)
	state.pending_promotion.board.queue_redraw()
	state.pending_promotion = {}
	_continue_turn()

## Passes the turn on, unless the move earned a bonus move that is still to be taken.
func _continue_turn() -> void:
	var current := state.current_match
	if current.active and not current.bonus.is_empty():
		view_changed.emit()
		if current.turn_side != current.player_side and not state.debug_mode:
			run_ai_bonus()
		return
	finish_turn()

## Gives up a bonus move and ends the turn.
func skip_bonus() -> void:
	if state.current_match.bonus.is_empty():
		return
	state.current_match.bonus = {}
	MoveController.clear_selection(state)
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

## The AI takes its bonus move if there is a worthwhile one, otherwise skips it.
func run_ai_bonus() -> void:
	await get_tree().create_timer(ai_delay).timeout
	var current := state.current_match
	if not current.active or current.bonus.is_empty() or current.turn_side == current.player_side or state.debug_mode:
		return
	var choice := GreedyAI.choose_bonus_move(state, current.turn_side)
	if choice.is_empty():
		skip_bonus()
		return
	state.active_board = choice.board
	state.active_square = choice.square
	var result := MoveController.execute(state, choice.move)
	if not state.pending_promotion.is_empty():
		PawnMovement.promote(state.pending_promotion.piece, PawnMovement.PROMOTION_CHOICES[0])
		state.pending_promotion = {}
	after_move(result)
