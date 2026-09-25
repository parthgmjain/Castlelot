class_name RunConfig
extends RefCounted

# ---- run structure --------------------------------------------------------
const ROUNDS := 12
const MATCHES_PER_ROUND := 3          # the last match of every round is a boss
const FINAL_BOSS := "Arthur"          # faced alone in round ROUNDS + 1
const KNIGHTS := [
	"Lancelot", "Gawain", "Percival", "Galahad", "Bors", "Kay",
	"Bedivere", "Gareth", "Tristan", "Lamorak", "Palamedes", "Yvain",
]

# ---- placeholder scaling: every value below is meant to be tuned ---------
# A value grows by "PER_MATCH" for every match played so far in the run.
const MOVES := 15
const PLAYER_BUDGET := 20             # stands in for a real roster until that exists
const PLAYER_ZONE_TILES := 10

const AI_BUDGET_BASE := 8.0
const AI_BUDGET_PER_MATCH := 0.5
const AI_ZONE_TILES_BASE := 8.0
const AI_ZONE_TILES_PER_MATCH := 0.25

const TARGET_BASE := 40.0
const TARGET_PER_MATCH := 6.0

const BOARDS_BASE := 2
const BOARDS_MAX := 4
const MATCHES_PER_EXTRA_BOARD := 12
const BOARD_SIZE_MIN := 4
const BOARD_SIZE_MAX := 8

const BOSS_TARGET_MULTIPLIER := 1.5
const BOSS_AI_BUDGET_MULTIPLIER := 1.25

## Everything needed to build the run's current match.
static func match_setup(run: RunState) -> Dictionary:
	var index := run.matches_played()
	var boss := run.is_boss()

	var board_count := mini(BOARDS_BASE + index / MATCHES_PER_EXTRA_BOARD, BOARDS_MAX)
	var board_sizes: Array = []
	for i in board_count:
		board_sizes.append(Vector2i(randi_range(BOARD_SIZE_MIN, BOARD_SIZE_MAX), randi_range(BOARD_SIZE_MIN, BOARD_SIZE_MAX)))

	var target := TARGET_BASE + TARGET_PER_MATCH * index
	var ai_budget := AI_BUDGET_BASE + AI_BUDGET_PER_MATCH * index
	if boss:
		target *= BOSS_TARGET_MULTIPLIER
		ai_budget *= BOSS_AI_BUDGET_MULTIPLIER

	return {
		"board_sizes": board_sizes,
		"white_zone": PLAYER_ZONE_TILES,
		"black_zone": int(AI_ZONE_TILES_BASE + AI_ZONE_TILES_PER_MATCH * index),
		"player_budget": PLAYER_BUDGET,
		"ai_budget": int(round(ai_budget)),
		"moves": MOVES,
		"target": int(round(target)),
		"round_type": "boss" if boss else "normal",
		"boss_name": run.boss_name(),
	}
