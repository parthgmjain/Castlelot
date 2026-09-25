class_name RunFlow
extends Node
## Match and run lifecycle: starting runs and matches, paying out results, and
## moving on to the shop or the next match.

signal view_changed

var state: GameState
var panel: ControlPanel
var result_screen: ResultScreen
var shop_screen: ShopScreen

## Rebuilds the boards from scratch (owned by Main, which owns the board nodes).
var generate_boards: Callable

func start_run() -> void:
	state.run = RunState.new()
	state.run.begin()
	begin_match()

## Builds the run's current match from RunConfig and starts deployment.
func begin_match() -> void:
	var setup := RunConfig.match_setup(state.run)
	state.run.temp_points_bonus = 0
	if state.run.active:
		if Prophecies.consume_armed(state.run, "broaden_the_realm"):
			setup.white_zone += Prophecies.ZONE_BONUS
		if Prophecies.consume_armed(state.run, "reinforcements"):
			state.run.temp_points_bonus = Prophecies.POINTS_BONUS
	panel.apply_setup(setup)
	generate_boards.call()
	ZoneController.generate(state.boards, setup.white_zone, setup.black_zone)
	var boss_army: Array = [setup.boss_piece] if setup.boss_piece >= 0 else []
	ArmyPlacer.auto_place(state.boards, Piece.Side.BLACK, setup.ai_budget, setup.round_type, boss_army)
	state.deployment.begin(setup)
	MoveController.mark_last_move(state, {})
	view_changed.emit()

## Start Match during deployment: whatever is on the field goes into the match.
func ready_to_fight() -> void:
	if not state.deployment.active:
		return
	var setup := state.deployment.setup
	state.deployment.finish()
	MatchController.start(state, setup.moves, setup.target)
	state.current_match.deployed_roster_ids = Roster.field_ids(state.boards)
	MoveController.mark_last_move(state, {})
	view_changed.emit()

## Sandbox Start Match (outside a run).
func start_match(moves: int, target: int) -> void:
	var error := MatchController.start(state, moves, target)
	if error != "":
		panel.set_match_status(error)
		return
	MoveController.mark_last_move(state, {})
	view_changed.emit()

## Pays out a won match (once) and shows the result screen for either outcome.
func settle_if_finished() -> void:
	var current := state.current_match
	if current.result == "" or current.settled:
		return
	current.settled = true
	if state.run.active:
		Prophecies.finish_match(state.run, current)
	var payout := {}
	var notes: Array = []
	if current.result == "win":
		payout = Payout.calculate(current, state.run.currency)
		if state.run.active:
			payout = Prophecies.apply_payout(state.run, payout)
			if payout.has("tithe"):
				notes.append("Golden Tithe: +%d gold" % payout.tithe)
		state.run.currency += payout.total
		if state.run.active:
			var waiting: Array = current.revivals.map(func(r): return r.piece.get("roster_id", -1))
			var alive := Roster.on_field(state.boards)
			var first_lost: Array = current.deployed_roster_ids.filter(func(id): return not alive.has(id) and not waiting.has(id))
			if not first_lost.is_empty() and Prophecies.has_armed(state.run, "guardian_spirit"):
				waiting.append(first_lost[0])
				Prophecies.consume_armed(state.run, "guardian_spirit")
				notes.append("Guardian Spirit kept your %s in your roster!" % Piece.display_name(state.run.roster_entry(first_lost[0]).type))
			notes.append(_report_losses(Roster.settle(state.run, state.boards, current.deployed_roster_ids, waiting)))
			var reward := state.run.boss_piece()
			if reward >= 0:
				var name := Piece.display_name(reward)
				match Legendaries.grant(state.run, reward):
					"added":
						notes.append("REWARD: the %s joins your roster!" % name)
					"owned":
						notes.append("You already hold the %s." % name)
					"choose":
						notes.append("REWARD: the %s has arrived, but both legendary slots are full - you'll choose which to keep in the shop." % name)
	var context := ""
	var button := ""
	if state.run.active:
		context = state.run.title()
		if current.result == "loss":
			button = "Restart Run"
		else:
			button = "Finish Run" if state.run.is_final_round() else "Next Match"
	result_screen.show_result(current, payout, state.run.currency, context, button, notes)

## In a run: a win moves on to the next match (or finishes the run after
## Arthur) and a loss starts a new run. Outside a run a loss just wipes the gold.
func result_continued() -> void:
	var lost := state.current_match.result == "loss"
	if state.run.active:
		if lost:
			start_run()
		elif state.run.advance():
			shop_screen.open(state.run, state.run.title())
		else:
			view_changed.emit()
		return
	if lost:
		state.run = RunState.new()
	view_changed.emit()

func _report_losses(lost: Array) -> String:
	if lost.is_empty():
		return "No pieces lost."
	var names := lost.map(func(entry): return Piece.Type.find_key(entry.type).capitalize())
	return "Lost: %s" % ", ".join(names)
