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

func start_run(banner_ids: Array = [], rng: RandomNumberGenerator = null) -> void:
	state.run = RunState.new()
	state.run.begin(banner_ids, rng)
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
	var ai_side := Piece.opponent(Banners.player_side(state.run))
	ZoneController.generate(state.boards, setup.white_zone, setup.black_zone, state.run.round_number)
	var boss_army: Array = [setup.boss_piece] if setup.boss_piece >= 0 else []
	if state.run.is_final_round():
		var legendaries := RunConfig.BOSSES.duplicate()
		legendaries.shuffle()
		boss_army = legendaries.slice(0, RunConfig.ARTHUR_LEGENDARY_COUNT)
	elif setup.boss_piece >= 0 and state.run.round_number >= RunConfig.BOSS_SECOND_LEGENDARY_ROUND:
		boss_army.append(Piece.Type.QUEEN)
	ArmyPlacer.auto_place(state.boards, ai_side, setup.ai_budget, setup.round_type, boss_army, state.run.round_number)
	if state.run.is_final_round():
		for board in state.boards:
			for piece in board.pieces.values():
				if piece.side == ai_side:
					piece["score_multiplier"] = RunConfig.ARTHUR_SCORE_MULTIPLIER
	state.deployment.begin(setup)
	MoveController.mark_last_move(state, {})
	view_changed.emit()

## Start Match during deployment: whatever is on the field goes into the match.
func ready_to_fight() -> void:
	if not state.deployment.active:
		return
	var setup := state.deployment.setup
	state.deployment.finish()
	MatchController.start(state, setup.moves, setup.target, Banners.player_side(state.run))
	state.current_match.deployed_roster_ids = Roster.field_ids(state.boards, Banners.player_side(state.run))
	MoveController.mark_last_move(state, {})
	view_changed.emit()

## Sandbox Start Match (outside a run, or in debug mode alongside one).
func start_match(moves: int, target: int) -> void:
	var error := MatchController.start(state, moves, target, Banners.player_side(state.run))
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
		payout = Payout.calculate(current, state.run.currency, Banners.interest_cap(state.run), Banners.gold_multiplier(state.run))
		if state.run.active:
			payout = Prophecies.apply_payout(state.run, payout)
			if payout.has("tithe"):
				notes.append("Golden Tithe: +%d gold" % payout.tithe)
		state.run.currency += payout.total
		if state.run.active:
			var waiting: Array = current.revivals.map(func(r): return r.piece.get("roster_id", -1))
			var alive := Roster.on_field(state.boards, Banners.player_side(state.run))
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
## Arthur) and a loss starts a new run (Guardian's Banner spends its one-time
## save instead, retrying the same match). Outside a run a loss just wipes the gold.
func result_continued() -> void:
	var lost := state.current_match.result == "loss"
	if state.run.active:
		if lost:
			if state.run.banners.has(Banners.Id.GUARDIAN) and not state.run.guardian_used:
				state.run.guardian_used = true
				begin_match()
			else:
				start_run(state.run.banners)
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
