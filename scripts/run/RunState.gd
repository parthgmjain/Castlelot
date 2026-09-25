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

func begin() -> void:
	active = true
	complete = false
	round_number = 1
	match_number = 1
	boss_order = RunConfig.KNIGHTS.duplicate()
	boss_order.shuffle()

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
