class_name Banners
extends RefCounted
## Run banners: an identity picked before a run starts. White/Black just choose
## which side you play as run-wide - no bonus attached. Every other banner is a
## straight advantage/disadvantage pair. `RunState.banners` holds the ids picked
## for the run (today, always exactly one - combining a second one after a win
## is a later mechanic). Numbers are placeholders like the rest of the economy.

enum Id {
	WHITE, BLACK,
	IRON, VANGUARD, BROAD, NARROW, PROPHETIC, MERCHANT, BANKER,
	TWIN, ROYAL, STEADY, STORMCALLER, RECKLESS, HOARDER, ERRATIC, GUARDIAN,
}

const STORMCALLER_EASY_ROUNDS := 3
const ERRATIC_BONUS_POINTS := 3

const DEFS := {
	Id.WHITE: { "name": "White Banner", "text": "Play as White." },
	Id.BLACK: { "name": "Black Banner", "text": "Play as Black." },
	Id.IRON: { "name": "Iron Banner", "text": "+3 Moves every match / -2 starting Points" },
	Id.VANGUARD: { "name": "Vanguard Banner", "text": "+3 starting Points / -3 Moves every match" },
	Id.BROAD: { "name": "Broad Banner", "text": "+5 starting Zone tiles / -2 starting Points" },
	Id.NARROW: { "name": "Narrow Banner", "text": "+3 starting Points / -3 starting Zone tiles" },
	Id.PROPHETIC: { "name": "Prophetic Banner", "text": "+1 prophecy hand size / -2 Moves every match" },
	Id.MERCHANT: { "name": "Merchant's Banner", "text": "Shop prices -20% / interest cap halved" },
	Id.BANKER: { "name": "Banker's Banner", "text": "Interest cap doubled / shop prices +20%" },
	Id.TWIN: { "name": "Twin Banner", "text": "Start with 2 copies of a random common piece / -3 starting Points" },
	Id.ROYAL: { "name": "Royal Banner", "text": "Start with the Queen in your roster / -5 starting Points" },
	Id.STEADY: { "name": "Steady Banner", "text": "Boards always start at this round's biggest size / AI budget +1 every match" },
	Id.STORMCALLER: { "name": "Stormcaller Banner", "text": "AI budget -1 for rounds 1-3 / target score +10% all run" },
	Id.RECKLESS: { "name": "Reckless Banner", "text": "Gold rewards +25% / target score +15%" },
	Id.HOARDER: { "name": "Hoarder's Banner", "text": "Carry 4 prophecies instead of 3 / lottery pulls cost +2 gold" },
	Id.ERRATIC: { "name": "Erratic Banner", "text": "Starting roster has 3 extra points of free pieces / composition is randomized, not chosen" },
	Id.GUARDIAN: { "name": "Guardian's Banner", "text": "Your first loss this run doesn't end it / -4 Moves every match" },
}

static func ids() -> Array:
	return DEFS.keys()

static func display_name(id: Id) -> String:
	return DEFS[id].name

static func description(id: Id) -> String:
	return DEFS[id].text

static func is_side(id: Id) -> bool:
	return id == Id.WHITE or id == Id.BLACK

## Which side the player fields this run. Defaults to White when no side
## banner was picked (sandbox matches, and any pre-banner RunState).
static func player_side(run: RunState) -> Piece.Side:
	return Piece.Side.BLACK if run.banners.has(Id.BLACK) else Piece.Side.WHITE

static func points_delta(run: RunState) -> int:
	var delta := 0
	if run.banners.has(Id.IRON):
		delta -= 2
	if run.banners.has(Id.VANGUARD):
		delta += 3
	if run.banners.has(Id.BROAD):
		delta -= 2
	if run.banners.has(Id.NARROW):
		delta += 3
	if run.banners.has(Id.TWIN):
		delta -= 3
	if run.banners.has(Id.ROYAL):
		delta -= 5
	return delta

static func zone_delta(run: RunState) -> int:
	var delta := 0
	if run.banners.has(Id.BROAD):
		delta += 5
	if run.banners.has(Id.NARROW):
		delta -= 3
	return delta

static func moves_delta(run: RunState) -> int:
	var delta := 0
	if run.banners.has(Id.IRON):
		delta += 3
	if run.banners.has(Id.VANGUARD):
		delta -= 3
	if run.banners.has(Id.PROPHETIC):
		delta -= 2
	if run.banners.has(Id.GUARDIAN):
		delta -= 4
	return delta

static func hand_size(run: RunState) -> int:
	var size := RunConfig.HAND_SIZE
	if run.banners.has(Id.PROPHETIC):
		size += 1
	if run.banners.has(Id.HOARDER):
		size += 1
	return size

static func price_multiplier(run: RunState) -> float:
	var mult := 1.0
	if run.banners.has(Id.MERCHANT):
		mult *= 0.8
	if run.banners.has(Id.BANKER):
		mult *= 1.2
	return mult

static func interest_cap(run: RunState) -> int:
	var cap := Payout.INTEREST_CAP
	if run.banners.has(Id.MERCHANT):
		cap = int(cap / 2.0)
	if run.banners.has(Id.BANKER):
		cap *= 2
	return cap

static func pull_price_delta(run: RunState) -> int:
	return 2 if run.banners.has(Id.HOARDER) else 0

static func fixed_board_size(run: RunState) -> bool:
	return run.banners.has(Id.STEADY)

## Added to the AI's budget for a match (see RunConfig.match_setup).
static func ai_budget_delta(run: RunState, round_number: int) -> float:
	var delta := 0.0
	if run.banners.has(Id.STEADY):
		delta += 1.0
	if run.banners.has(Id.STORMCALLER) and round_number <= STORMCALLER_EASY_ROUNDS:
		delta -= 1.0
	return delta

static func target_multiplier(run: RunState) -> float:
	var mult := 1.0
	if run.banners.has(Id.STORMCALLER):
		mult *= 1.1
	if run.banners.has(Id.RECKLESS):
		mult *= 1.15
	return mult

static func gold_multiplier(run: RunState) -> float:
	return 1.25 if run.banners.has(Id.RECKLESS) else 1.0

static func uses_erratic_roster(run: RunState) -> bool:
	return run.banners.has(Id.ERRATIC)

## Pieces added straight to the roster at run start, on top of the normal (or
## Erratic) starting roster - Twin's copies and Royal's Queen.
static func starting_extra_pieces(run: RunState, rng: RandomNumberGenerator = null) -> Array:
	var extra: Array = []
	if run.banners.has(Id.TWIN):
		rng = rng if rng != null else RandomNumberGenerator.new()
		var commons: Array = Piece.types_in_tier(Piece.Tier.COMMON).filter(func(t): return not Piece.is_reward_only(t))
		var pick: Piece.Type = commons[rng.randi_range(0, commons.size() - 1)]
		extra.append(pick)
		extra.append(pick)
	if run.banners.has(Id.ROYAL):
		extra.append(Piece.Type.QUEEN)
	return extra
