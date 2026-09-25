class_name Payout
extends RefCounted

## Placeholder numbers - tune freely.
const BASE := 5
const PER_LEFTOVER_MOVE := 1
const INTEREST_STEP := 5       # 1 interest for every this much currency held...
const INTEREST_CAP := 5        # ...up to this much

## What a won match pays: a base amount, a bonus per move left over, and
## interest on the currency held going in. Returns { base, moves_left,
## moves_bonus, held, interest, total }.
static func calculate(current_match: MatchState, held: int) -> Dictionary:
	var moves_bonus := maxi(current_match.moves_left, 0) * PER_LEFTOVER_MOVE
	var interest := mini(held / INTEREST_STEP, INTEREST_CAP)
	return {
		"base": BASE,
		"moves_left": maxi(current_match.moves_left, 0),
		"moves_bonus": moves_bonus,
		"held": held,
		"interest": interest,
		"total": BASE + moves_bonus + interest,
	}
