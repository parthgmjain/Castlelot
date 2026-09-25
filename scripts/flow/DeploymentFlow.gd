class_name DeploymentFlow
extends Node
## Placing roster pieces in your zone before a run match: the bench, clicks on
## the board, and the deployment part of the control panel.

signal view_changed

var state: GameState
var panel: ControlPanel

func bench_selected(id: int) -> void:
	state.deployment.armed_id = -1 if state.deployment.armed_id == id else id
	view_changed.emit()

func auto_deploy() -> void:
	Roster.auto_deploy(state.run, state.boards, state.debug_mode)
	state.deployment.armed_id = -1
	view_changed.emit()

## A click during deployment: place the armed bench piece on a free zone square,
## or pick a deployed piece back up.
func click(square: Vector2i, board: Board) -> void:
	var piece = board.pieces.get(square)
	if piece != null:
		Roster.withdraw(board, square)
	elif state.deployment.armed_id != -1 and Roster.deploy(state.run, state.boards, state.deployment.armed_id, board, square, state.debug_mode):
		state.deployment.armed_id = -1
	MoveController.clear_selection(state)
	view_changed.emit()

func refresh_ui() -> void:
	var deployment := state.deployment
	panel.set_deployment_visible(deployment.active)
	if not deployment.active:
		return
	var bench := Roster.bench(state.run, state.boards)
	var free := Roster.free_squares(state.boards, Piece.Side.WHITE)
	panel.set_bench(bench, deployment.armed_id)
	panel.set_deploy_status("%d on the bench | %d free zone squares | Points %d/%d" % [
		bench.size(), free.size(), Roster.points_used(state.run, state.boards), state.run.effective_points()])
	var markers := {}
	for slot in free:
		if not markers.has(slot.board):
			markers[slot.board] = []
		markers[slot.board].append(slot.square)
	for board in state.boards:
		board.set_move_markers(markers.get(board, []), [])
