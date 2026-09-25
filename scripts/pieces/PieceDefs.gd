class_name PieceDefs
extends RefCounted
## The data-driven pieces (everything beyond the six chess pieces): tier, value,
## board label and a list of movement rules that PieceMoves turns into moves.
## See docs/PIECES.md for what each piece is meant to do.
##
## A rule is a Dictionary:
##   kind   "step" (one hop per vector), "leap" (path-traced jump, like a knight),
##          "slide", "cannon", "grasshopper", "twin_leap", "step_slide",
##          "shot" (capture exactly `distance` squares away without moving),
##          "fire" (capture every enemy within `range` in one line without moving, then rest)
##   to / dirs   the vectors (offsets for step/leap, directions for the others)
##   mode   "any" (default), "move" (empty squares only) or "capture" (enemies only)
##   local  true: vectors are (sideways, forward) relative to the piece's heading
##   slide options: min, max (0 = unlimited), through (pass over pieces), bounce,
##                  double_capture (after taking a piece, may run on and take a second)
##   shot options: distance, clear_line (nothing may stand in between)
##
## A definition may also carry `protection` (who can't capture the piece) and
## `aura` (who can't capture its neighbours) - see CaptureRules.
##   step_slide: then_max (how far the straight part goes)

static var _cache: Dictionary = {}

static func has(type: Piece.Type) -> bool:
	return _defs().has(type)

## Every data-driven type, in definition order.
static func types() -> Array:
	return _defs().keys()

static func tier(type: Piece.Type) -> Piece.Tier:
	return _defs()[type].tier

static func value(type: Piece.Type) -> int:
	return _defs()[type].value

## Short text drawn on the piece's disc on the board.
static func label(type: Piece.Type) -> String:
	return _defs()[type].label

## Reward-only pieces come from beating a knight, not from the shop.
static func is_reward_only(type: Piece.Type) -> bool:
	return _defs()[type].reward

## Who may not capture this piece (rules for CaptureRules).
static func protection(type: Piece.Type) -> Array:
	return _defs()[type].protection

## Rules that shield friendly pieces standing next to this one.
static func aura(type: Piece.Type) -> Array:
	return _defs()[type].aura

static func rules(type: Piece.Type) -> Array:
	return _defs()[type].rules

static func _defs() -> Dictionary:
	if _cache.is_empty():
		_cache = _build()
	return _cache

# ---- vector helpers ---------------------------------------------------------

const ORTHOGONAL := Piece.ROOK_DIRECTIONS
const DIAGONAL := Piece.BISHOP_DIRECTIONS
const ALL_DIRECTIONS := Piece.KING_OFFSETS

## (a, b) in every sign and axis combination: all 8 for a != b, 4 for a == b or 0.
static func _symmetric(a: int, b: int) -> Array:
	var out: Array = []
	for pair in [Vector2i(a, b), Vector2i(b, a)]:
		for sx in [1, -1]:
			for sy in [1, -1]:
				var v := Vector2i(pair.x * sx, pair.y * sy)
				if not out.has(v):
					out.append(v)
	return out

static func _def(tier_value: Piece.Tier, value_points: int, text: String, rule_list: Array, reward: bool = false) -> Dictionary:
	return { "tier": tier_value, "value": value_points, "label": text, "rules": rule_list, "reward": reward, "protection": [], "aura": [] }

## The same definition, with capture protection for the piece itself and/or an aura for its neighbours.
static func _guarded(definition: Dictionary, own: Array, neighbours: Array = []) -> Dictionary:
	definition["protection"] = own
	definition["aura"] = neighbours
	return definition

static func _build() -> Dictionary:
	var common := Piece.Tier.COMMON
	var uncommon := Piece.Tier.UNCOMMON
	var legendary := Piece.Tier.LEGENDARY
	var forward := [Vector2i(0, 1)]
	var beside := [Vector2i(1, 0), Vector2i(-1, 0)]
	var front_diagonals := [Vector2i(1, 1), Vector2i(-1, 1)]
	var hawk_jumps: Array = []
	for distance in [2, 3]:
		hawk_jumps.append_array(_symmetric(distance, 0))
		hawk_jumps.append_array(_symmetric(distance, distance))

	return {
		# ---- pawn tier
		Piece.Type.SCOUT: _def(common, 1, "Sc", [
			{ "kind": "step", "to": forward + beside, "mode": "move", "local": true },
			{ "kind": "step", "to": front_diagonals, "mode": "capture", "local": true },
		]),
		Piece.Type.SERF: _def(common, 1, "Sf", [
			{ "kind": "step", "to": front_diagonals, "mode": "move", "local": true },
			{ "kind": "step", "to": forward, "mode": "capture", "local": true },
		]),
		Piece.Type.MILITIA: _def(common, 2, "Mi", [
			{ "kind": "step", "to": ORTHOGONAL, "mode": "move" },
			{ "kind": "step", "to": front_diagonals, "mode": "capture", "local": true },
		]),
		Piece.Type.CRAB: _def(common, 1, "Cr", [
			{ "kind": "step", "to": beside, "mode": "move", "local": true },
			{ "kind": "step", "to": DIAGONAL, "mode": "capture" },
		]),
		Piece.Type.SHIELDBEARER: _guarded(_def(common, 2, "Sb", [
			{ "kind": "step", "to": forward, "mode": "move", "local": true },
			{ "kind": "step", "to": front_diagonals, "mode": "capture", "local": true },
		]), [{ "kind": "front_adjacent" }]),
		Piece.Type.ARCHER: _def(common, 2, "Ar", [
			{ "kind": "step", "to": forward, "mode": "move", "local": true },
			{ "kind": "shot", "dirs": forward, "distance": 2, "clear_line": true, "local": true },
		]),
		# ---- uncommon tier
		Piece.Type.CAMEL: _def(uncommon, 3, "Ca", [{ "kind": "leap", "to": _symmetric(3, 1) }]),
		Piece.Type.ZEBRA: _def(uncommon, 3, "Ze", [{ "kind": "leap", "to": _symmetric(3, 2) }]),
		Piece.Type.TWIN_RIDER: _def(uncommon, 4, "Tw", [{ "kind": "twin_leap", "to": Piece.KNIGHT_OFFSETS }]),
		Piece.Type.HAWK: _def(uncommon, 3, "Ha", [{ "kind": "leap", "to": hawk_jumps }]),
		Piece.Type.CANNON: _def(uncommon, 4, "Cn", [{ "kind": "cannon", "dirs": ORTHOGONAL }]),
		Piece.Type.CHARGER: _def(uncommon, 3, "Ch", [{ "kind": "slide", "dirs": ORTHOGONAL, "min": 2 }]),
		Piece.Type.RANGER: _def(uncommon, 3, "Ra", [{ "kind": "slide", "dirs": ORTHOGONAL, "max": 3 }]),
		Piece.Type.LANCER: _def(uncommon, 4, "La", [
			{ "kind": "slide", "dirs": forward, "local": true },
			{ "kind": "step", "to": beside + [Vector2i(0, -1)], "local": true },
		]),
		Piece.Type.MIRROR: _def(uncommon, 3, "Mr", [{ "kind": "slide", "dirs": DIAGONAL, "bounce": 1 }]),
		Piece.Type.MONK: _def(uncommon, 3, "Mo", [
			{ "kind": "slide", "dirs": DIAGONAL, "max": 3 },
			{ "kind": "step", "to": ORTHOGONAL, "mode": "move" },
		]),
		Piece.Type.FERZ_GUARD: _def(uncommon, 2, "Fg", [
			{ "kind": "step", "to": DIAGONAL },
			{ "kind": "leap", "to": _symmetric(2, 2) },
		]),
		Piece.Type.GRASSHOPPER: _def(uncommon, 4, "Gr", [{ "kind": "grasshopper", "dirs": ALL_DIRECTIONS }]),
		Piece.Type.GHOST: _def(uncommon, 4, "Gh", [{ "kind": "slide", "dirs": ALL_DIRECTIONS, "max": 2, "through": true }]),
		Piece.Type.SPEARMAN: _def(uncommon, 3, "Sp", [
			{ "kind": "step", "to": ALL_DIRECTIONS },
			{ "kind": "slide", "dirs": forward, "max": 2, "mode": "capture", "local": true },
		]),
		Piece.Type.GRIFFON: _def(uncommon, 4, "Gf", [{ "kind": "step_slide", "dirs": DIAGONAL, "then_max": 3 }]),
		Piece.Type.TORTOISE: _guarded(_def(uncommon, 3, "To", [{ "kind": "slide", "dirs": ORTHOGONAL, "max": 2 }]),
			[{ "kind": "from_front" }]),
		Piece.Type.GOLEM: _guarded(_def(uncommon, 3, "Go", [{ "kind": "step", "to": ORTHOGONAL }]),
			[{ "kind": "attacker_types", "types": [Piece.Type.PAWN, Piece.Type.KNIGHT] }]),
		Piece.Type.BARD: _guarded(_def(uncommon, 2, "Ba", [{ "kind": "step", "to": ALL_DIRECTIONS, "mode": "move" }]),
			[], [{ "kind": "attacker_types", "types": [Piece.Type.PAWN] }]),
		Piece.Type.CATAPULT: _def(uncommon, 3, "Ct", [{ "kind": "shot", "dirs": ORTHOGONAL, "distance": 3 }]),
		# ---- legendary tier (boss rewards)
		Piece.Type.TITAN: _def(legendary, 10, "Ti", [{ "kind": "slide", "dirs": ORTHOGONAL, "double_capture": true }], true),
		Piece.Type.WRAITH: _guarded(_def(legendary, 10, "Wr", [{ "kind": "slide", "dirs": ALL_DIRECTIONS, "through": true }], true),
			[{ "kind": "only_attackers", "types": [Piece.Type.PAWN], "tiers": [Piece.Tier.LEGENDARY] }]),
		Piece.Type.DRAGON: _def(legendary, 11, "Dr", [
			{ "kind": "slide", "dirs": ORTHOGONAL },
			{ "kind": "fire", "dirs": ORTHOGONAL, "range": 3, "rest": 2 },
		], true),
	}
