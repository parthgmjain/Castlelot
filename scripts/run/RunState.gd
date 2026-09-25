class_name RunState
extends RefCounted

## Everything that lasts across matches within one run. A lost match ends the
## run, which starts over with a fresh RunState.
var currency: int = 0

var active: bool = false
var complete: bool = false
var round_number: int = 1
var match_number: int = 1
var boss_order: Array = []     # this run's knights, one per round

## What you may field per match: total piece value, and zone size (king's square included).
var allocated_points: int = RunConfig.PLAYER_POINTS_START
var zone_tiles: int = RunConfig.PLAYER_ZONE_TILES

## Purchases so far - each one makes the next of its kind cost more.
var pulls_made: int = 0
var points_upgrades_bought: int = 0
var zone_upgrades_bought: int = 0

## Every piece you own except the king: [{ id, type }]. Pieces are removed for
## good when they are captured in a match you go on to win.
var roster: Array = []
var _next_roster_id: int = 1

func begin() -> void:
	active = true
	complete = false
	round_number = 1
	match_number = 1
	boss_order = RunConfig.KNIGHTS.duplicate()
	boss_order.shuffle()
	allocated_points = RunConfig.PLAYER_POINTS_START
	zone_tiles = RunConfig.PLAYER_ZONE_TILES
	pulls_made = 0
	points_upgrades_bought = 0
	zone_upgrades_bought = 0
	roster.clear()
	_next_roster_id = 1
	for type in RunConfig.STARTING_ROSTER:
		add_to_roster(type)

func add_to_roster(type: Piece.Type) -> int:
	var id := _next_roster_id
	_next_roster_id += 1
	roster.append({ "id": id, "type": type })
	return id

func roster_entry(id: int) -> Dictionary:
	for entry in roster:
		if entry.id == id:
			return entry
	return {}

func remove_from_roster(id: int) -> void:
	for i in roster.size():
		if roster[i].id == id:
			roster.remove_at(i)
			return

## Arthur's round, after the last ordinary one.
func is_final_round() -> bool:
	return round_number > RunConfig.ROUNDS

func matches_in_round() -> int:
	return 1 if is_final_round() else RunConfig.MATCHES_PER_ROUND

func is_boss() -> bool:
	return match_number == matches_in_round()

func boss_name() -> String:
	if not is_boss():
		return ""
	if is_final_round():
		return RunConfig.FINAL_BOSS
	return "Sir %s" % boss_order[round_number - 1] if boss_order.size() >= round_number else "Sir Knight"

## How many matches came before this one in the run.
func matches_played() -> int:
	return (round_number - 1) * RunConfig.MATCHES_PER_ROUND + (match_number - 1)

## Moves to the next match. Returns false (and completes the run) after Arthur.
func advance() -> bool:
	if match_number < matches_in_round():
		match_number += 1
		return true
	if is_final_round():
		active = false
		complete = true
		return false
	round_number += 1
	match_number = 1
	return true

func title() -> String:
	if complete:
		return "Run complete!"
	if not active:
		return "No run in progress"
	if is_final_round():
		return "Round %d - %s (final boss)" % [round_number, boss_name()]
	var text := "Round %d/%d - Match %d/%d" % [round_number, RunConfig.ROUNDS, match_number, matches_in_round()]
	if is_boss():
		text += " - BOSS: %s" % boss_name()
	return text
