class_name Difficulty
extends RefCounted
## The difficulty picked alongside your banners before a run starts, threaded through
## RunConfig.match_setup/Payout/Shop/RunFlow the same way Banners.gd's deltas are - see
## each function below for exactly what it moves. Numbers are a first calibration from a
## 2026-09-27 simulation pass (greedy AI on both sides, no prophecies - a lower-bound
## proxy): Normal is 1.0/0 everywhere, so picking Normal reproduces the old unconditional
## behavior exactly; the other three tiers are deltas off that same baseline, same as a banner.

enum Level { EASY, NORMAL, HARD, NIGHTMARE }

const NAMES := {
	Level.EASY: "Easy",
	Level.NORMAL: "Normal",
	Level.HARD: "Hard",
	Level.NIGHTMARE: "Nightmare",
}

## Multiplies the AI's per-match budget before any boss multiplier is applied.
const AI_BUDGET_MULTIPLIER := {
	Level.EASY: 0.85, Level.NORMAL: 1.0, Level.HARD: 1.1, Level.NIGHTMARE: 1.25,
}

## Extra multiplier stacked onto a boss match's existing target/budget multipliers on top
## of AI_BUDGET_MULTIPLIER/TARGET_MULTIPLIER - bosses swing harder than normal matches at
## every difficulty away from Normal, since that's where this game's own identity (the
## legendary boss pieces) lives.
const BOSS_MULTIPLIER := {
	Level.EASY: 0.7, Level.NORMAL: 1.0, Level.HARD: 1.15, Level.NIGHTMARE: 1.3,
}

const TARGET_MULTIPLIER := {
	Level.EASY: 0.85, Level.NORMAL: 1.0, Level.HARD: 1.1, Level.NIGHTMARE: 1.15,
}

## Multiplies a won match's whole payout (stacks with Banners.gold_multiplier).
const GOLD_MULTIPLIER := {
	Level.EASY: 1.4, Level.NORMAL: 1.0, Level.HARD: 0.8, Level.NIGHTMARE: 0.65,
}

## Multiplies every shop upgrade price (points/zone/moves) - how fast your fieldable
## strength can keep pace with the AI's (stacks with Banners.price_multiplier).
const PRICE_MULTIPLIER := {
	Level.EASY: 0.85, Level.NORMAL: 1.0, Level.HARD: 1.1, Level.NIGHTMARE: 1.2,
}

## Rounds added to (or subtracted from) the round number fed into the AI's own
## extra-piece-unlock schedule (PieceSelector.EXTRA_TIER_UNLOCK) - Nightmare's AI reaches
## for the exotic pieces sooner, Easy's later. See ai_unlock_round.
const AI_UNLOCK_SHIFT := {
	Level.EASY: -1, Level.NORMAL: 0, Level.HARD: 1, Level.NIGHTMARE: 2,
}

## Easy grants Guardian's Banner's one-free-retry-per-run safety net for free (shares
## RunState.guardian_used - picking Easy AND the Guardian banner together still only
## grants the one retry, not two).
const GRANTS_RETRY := {
	Level.EASY: true, Level.NORMAL: false, Level.HARD: false, Level.NIGHTMARE: false,
}

static func levels() -> Array:
	return NAMES.keys()

static func display_name(level: Level) -> String:
	return NAMES[level]

static func ai_budget_multiplier(level: Level) -> float:
	return AI_BUDGET_MULTIPLIER[level]

static func boss_multiplier(level: Level) -> float:
	return BOSS_MULTIPLIER[level]

static func target_multiplier(level: Level) -> float:
	return TARGET_MULTIPLIER[level]

static func gold_multiplier(level: Level) -> float:
	return GOLD_MULTIPLIER[level]

static func price_multiplier(level: Level) -> float:
	return PRICE_MULTIPLIER[level]

## The round number to hand to PieceSelector's extra-piece unlock curve for the AI's army
## this match - `round_number` shifted by AI_UNLOCK_SHIFT, never below 0 (0 still means
## "everything past round 1 locked", same as a real round 1 would with no shift).
static func ai_unlock_round(level: Level, round_number: int) -> int:
	return maxi(round_number + AI_UNLOCK_SHIFT[level], 0)

static func grants_retry(level: Level) -> bool:
	return GRANTS_RETRY[level]
