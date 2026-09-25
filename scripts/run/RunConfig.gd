class_name RunConfig
extends RefCounted

# ---- run structure --------------------------------------------------------
const ROUNDS := 12
const MATCHES_PER_ROUND := 3          # the last match of every round is a boss
const FINAL_BOSS := "Arthur"          # faced alone in round ROUNDS + 1
## The round bosses, one per round in a random order each run. Each is a legendary
## piece: it takes the field with the boss's army and is yours if you win. Every
## reward-only piece in PieceDefs must be listed here exactly once.
const BOSSES := [
	Piece.Type.PALADIN, Piece.Type.WARLORD, Piece.Type.EMPRESS, Piece.Type.DRAGON,
	Piece.Type.PHOENIX, Piece.Type.HYDRA, Piece.Type.WRAITH, Piece.Type.LICH,
	Piece.Type.CHRONOMANCER, Piece.Type.TITAN, Piece.Type.ORACLE, Piece.Type.STORM_WITCH,
]

# The pieces (besides the king, who is always fielded) a run starts with.
const STARTING_ROSTER := [
	Piece.Type.ROOK, Piece.Type.KNIGHT, Piece.Type.BISHOP,
	Piece.Type.PAWN, Piece.Type.PAWN, Piece.Type.PAWN,
]

# ---- roster economy (placeholders): what you can field, and what the shop charges
const PLAYER_POINTS_START := 14        # exactly what the starting roster costs
const MAX_ZONE_TILES := 50
const MAX_ALLOCATED_POINTS := 100
## Pieces of a tier needed to trade up to the next: 5 commons -> uncommon, 5 uncommons -> rare, 7 rares -> legendary.
const TRADE_UP_COUNTS := {
	Piece.Tier.COMMON: 5,
	Piece.Tier.UNCOMMON: 5,
	Piece.Tier.RARE: 7,
}
## How many different piece types you can hold per tier (each type can be owned several times,
## except legendaries: one of each).
const SLOTS_PER_TIER := {
	Piece.Tier.COMMON: 5,
	Piece.Tier.UNCOMMON: 5,
	Piece.Tier.RARE: 3,
	Piece.Tier.LEGENDARY: 2,
}
## A lottery pull (and a trade-up) offers this many cards: up to OWNED_CARDS of types you already
## hold (choosing one adds a copy) and the rest new types (taking a free slot, or replacing one).
const CARDS_OFFERED := 5
const OWNED_CARDS := 3
## Legendaries you can upgrade into from the start; boss pieces you beat this run join them.
const DEFAULT_LEGENDARIES := [Piece.Type.QUEEN]
const PULL_PRICE_BASE := 4             # one lottery pull: reveals a tier, then a piece from it
const PULL_PRICE_STEP := 1             # each pull made costs this much more
## Relative chance of each tier per pull. Legendaries can't be drawn at all.
const TIER_WEIGHTS := {
	Piece.Tier.COMMON: 60.0,
	Piece.Tier.UNCOMMON: 30.0,
	Piece.Tier.RARE: 10.0,
}
const POINTS_UPGRADE_AMOUNT := 2
const POINTS_UPGRADE_PRICE_BASE := 10
const POINTS_UPGRADE_PRICE_STEP := 5
const ZONE_UPGRADE_AMOUNT := 1
const ZONE_UPGRADE_PRICE_BASE := 8
const ZONE_UPGRADE_PRICE_STEP := 4

# ---- placeholder scaling: every value below is meant to be tuned ---------
# A value grows by "PER_MATCH" for every match played so far in the run.
const MOVES := 15
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
		"white_zone": run.zone_tiles,
		"black_zone": int(AI_ZONE_TILES_BASE + AI_ZONE_TILES_PER_MATCH * index),
		"ai_budget": int(round(ai_budget)),
		"moves": MOVES,
		"target": int(round(target)),
		"round_type": "boss" if boss else "normal",
		"boss_name": run.boss_name(),
		"boss_piece": run.boss_piece(),
	}
