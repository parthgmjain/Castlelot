class_name Payout
extends RefCounted

## Placeholder numbers - tune freely. BASE was 5 until a 2026-09-27 full-run simulation
## pass showed gold income couldn't keep pace with AI_BUDGET's per-match growth (a player
## saving every coin for Points upgrades was still ~2 boss-budget-multiples behind by
## round 4) - raised to keep pace with a rebalanced boss curve (see RunConfig.match_setup).
const BASE := 10
const PER_LEFTOVER_MOVE := 1
const INTEREST_STEP := 5       # 1 interest for every this much currency held...
const INTEREST_CAP := 5        # ...up to this much

## What a won match pays: a base amount, a bonus per move left over, and
## interest on the currency held going in (Merchant's/Banker's Banner can
## raise or lower the interest cap; Reckless Banner scales the total).
## Returns { base, moves_left, moves_bonus, held, interest, total }.
static func calculate(current_match: MatchState, held: int, interest_cap: int = INTEREST_CAP, gold_multiplier: float = 1.0) -> Dictionary:
	var moves_bonus := maxi(current_match.moves_left, 0) * PER_LEFTOVER_MOVE
	var interest := mini(held / INTEREST_STEP, interest_cap)
	return {
		"base": BASE,
		"moves_left": maxi(current_match.moves_left, 0),
		"moves_bonus": moves_bonus,
		"held": held,
		"interest": interest,
		"total": int(round((BASE + moves_bonus + interest) * gold_multiplier)),
	}
