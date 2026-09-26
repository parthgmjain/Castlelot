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
# ---- prophecies (placeholders): one-time cards bought in the shop
const HAND_SIZE := 3                   # how many you can carry
const PROPHECY_OFFERS := 4             # cards for sale each shop visit
## Chance of each rarity when the shop picks a card: the rarer, the more powerful.
const PROPHECY_WEIGHTS := {
	Piece.Tier.COMMON: 55.0,
	Piece.Tier.UNCOMMON: 30.0,
	Piece.Tier.RARE: 12.0,
	Piece.Tier.LEGENDARY: 3.0,
}
const PROPHECY_PRICES := {
	Piece.Tier.COMMON: 4,
	Piece.Tier.UNCOMMON: 8,
	Piece.Tier.RARE: 15,
	Piece.Tier.LEGENDARY: 30,
}
const POINTS_UPGRADE_AMOUNT := 2
const POINTS_UPGRADE_PRICE_BASE := 10
const POINTS_UPGRADE_PRICE_STEP := 5
const ZONE_UPGRADE_AMOUNT := 1
const ZONE_UPGRADE_PRICE_BASE := 8
const ZONE_UPGRADE_PRICE_STEP := 4
const MAX_BONUS_MOVES := 30
const MOVES_UPGRADE_AMOUNT := 2
const MOVES_UPGRADE_PRICE_BASE := 8
const MOVES_UPGRADE_PRICE_STEP := 4

# ---- placeholder scaling: every value below is meant to be tuned ---------
# A value grows by "PER_MATCH" for every match played so far in the run.
# Basic balance pass (2026-09-25): TARGET_BASE/PER_MATCH used to grow far faster than the AI's
# material (round 1 asked for ~50% of the enemy's total value in captures; by round 12 it was
# ~98%, an unwinnable wall). They're now set so the target stays a roughly constant share
# (~35%) of the AI's total value (AI_budget x Scoring.CHIPS_PER_VALUE) across the whole run:
# target(index) ~= 0.35 x AI_budget(index) x CHIPS_PER_VALUE. MOVES was nudged up a little too,
# since even at the old target a lot of a 15-move match was spent just closing the distance
# across boards before any capturing could start. Simulated with tests/run.sh-style greedy play
# on both sides before and after - still meant to be tuned further by hand.
const MOVES := 18
const PLAYER_ZONE_TILES := 10

const AI_BUDGET_BASE := 8.0
const AI_BUDGET_PER_MATCH := 0.5
const AI_ZONE_TILES_BASE := 8.0
const AI_ZONE_TILES_PER_MATCH := 0.25

const TARGET_BASE := 28.0
const TARGET_PER_MATCH := 2.0

## Boards grow gradually as a run goes on - more of them, and each one a little bigger - but
## capped well before it gets so big that the common-tier pieces (mostly 1-square movers) can't
## meaningfully reach anything. The ramp is linear from round 1 to BOARD_GROWTH_FULL_ROUND, then
## holds at the cap (Arthur, round ROUNDS + 1, stays at the cap too). The starting size is already
## a proper little arena, not a cramped one - it's the CAP that keeps things from ballooning.
const BOARD_COUNT_MIN := 2
const BOARD_COUNT_MAX := 4
const BOARD_SIZE_MIN_START := 5
const BOARD_SIZE_MIN_CAP := 6
const BOARD_SIZE_MAX_START := 6
const BOARD_SIZE_MAX_CAP := 8
const BOARD_GROWTH_FULL_ROUND := 10

## The zone you can actually deploy into is also capped per round, on the same growth curve as
## the boards: a small early world can't hold as big a zone as a fully-grown one can, even if
## you've already bought more with the shop's Zone Size upgrade (that gold isn't wasted - the
## extra just becomes usable once the world has grown enough for it). Reaches MAX_ZONE_TILES
## (the shop's own ceiling) by BOARD_GROWTH_FULL_ROUND, same as the boards.
const PLAYER_ZONE_CAP_START := 12

const BOSS_TARGET_MULTIPLIER := 1.5
const BOSS_AI_BUDGET_MULTIPLIER := 1.25

## Arthur (round ROUNDS + 1): on top of the usual boss multipliers, he always fields this many
## distinct random legendaries (from BOSSES; reserved, same as any boss's own piece), and every
## piece of his - reserved or bought - costs half as much against his budget (so roughly twice
## the army for the same numbers) but is only worth half the usual score when you capture it. The
## two roughly cancel out for total capturable score, so the extra difficulty is a bigger, more
## defensively coordinated army (with four legendaries in it) rather than a higher score wall.
const ARTHUR_LEGENDARY_COUNT := 4
const ARTHUR_BUDGET_MULTIPLIER := 2.0
const ARTHUR_SCORE_MULTIPLIER := 0.5

## How far along the board-growth ramp `round_number` is: 0 at round 1, 1.0 from
## BOARD_GROWTH_FULL_ROUND onward (Arthur included).
static func board_growth(round_number: int) -> float:
	return clampf(float(round_number - 1) / float(BOARD_GROWTH_FULL_ROUND - 1), 0.0, 1.0)

## Everything needed to build the run's current match.
static func match_setup(run: RunState) -> Dictionary:
	var index := run.matches_played()
	var boss := run.is_boss()

	var growth := board_growth(run.round_number)
	var board_count := int(round(lerp(float(BOARD_COUNT_MIN), float(BOARD_COUNT_MAX), growth)))
	var size_min := int(round(lerp(float(BOARD_SIZE_MIN_START), float(BOARD_SIZE_MIN_CAP), growth)))
	var size_max := maxi(int(round(lerp(float(BOARD_SIZE_MAX_START), float(BOARD_SIZE_MAX_CAP), growth))), size_min)
	var board_sizes: Array = []
	for i in board_count:
		board_sizes.append(Vector2i(randi_range(size_min, size_max), randi_range(size_min, size_max)))
	var zone_cap := int(round(lerp(float(PLAYER_ZONE_CAP_START), float(MAX_ZONE_TILES), growth)))

	var target := TARGET_BASE + TARGET_PER_MATCH * index
	var ai_budget := AI_BUDGET_BASE + AI_BUDGET_PER_MATCH * index
	if boss:
		target *= BOSS_TARGET_MULTIPLIER
		ai_budget *= BOSS_AI_BUDGET_MULTIPLIER
	if run.is_final_round():
		ai_budget *= ARTHUR_BUDGET_MULTIPLIER

	return {
		"board_sizes": board_sizes,
		"white_zone": mini(run.zone_tiles, zone_cap),
		"black_zone": int(AI_ZONE_TILES_BASE + AI_ZONE_TILES_PER_MATCH * index),
		"ai_budget": int(round(ai_budget)),
		"moves": MOVES + run.bonus_moves,
		"target": int(round(target)),
		"round_type": "boss" if boss else "normal",
		"boss_name": run.boss_name(),
		"boss_piece": run.boss_piece(),
	}
