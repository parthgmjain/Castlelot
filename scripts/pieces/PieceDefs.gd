class_name PieceDefs
extends RefCounted
## The data-driven pieces (everything beyond the six chess pieces): tier, value,
## board label and a list of movement rules that PieceMoves turns into moves.
## See docs/PIECES.md for what each piece is meant to do.
##
## A rule is a Dictionary:
##   kind   "step" (one hop per vector), "leap" (path-traced jump, like a knight),
##          "slide", "cannon", "grasshopper", "twin_leap", "step_slide",
##          "pawn" (moves and captures like a pawn), "swap" (trade places with a friend),
##          "teleport" (to any empty square next to an enemy), "king_teleport" (to any empty
##          square next to your own king, but only while an enemy could capture it),
##          "shot" (capture exactly `distance` squares away without moving),
##          "fire" (capture every enemy within `range` in one line without moving, then rest)
##   to / dirs   the vectors (offsets for step/leap, directions for the others)
##   mode   "any" (default), "move" (empty squares only) or "capture" (enemies only)
##   local  true: vectors are (sideways, forward) relative to the piece's heading
##   when   only while true: { adjacent_friend: [types] } (a friend of that type next to it)
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

## A one-line description of what the piece does, for tooltips wherever it's shown before
## it's on the board (the sandbox picker, the bench, the shop, promotion). See docs/PIECES.md.
static func description(type: Piece.Type) -> String:
	return _DESCRIPTIONS.get(type, "")

const _DESCRIPTIONS := {
	# ---- common
	Piece.Type.SCOUT: "1 forward or 1 sideways (no capture); captures diagonally forward.",
	Piece.Type.SHIELDBEARER: "Pawn move/capture, but can't be captured by a piece directly in front of it.",
	Piece.Type.ARCHER: "1 forward. Instead of moving it can capture a piece exactly 2 squares straight ahead and stay put.",
	Piece.Type.SERF: "1 diagonally forward (no capture); captures straight forward.",
	Piece.Type.MILITIA: "1 orthogonally in any direction incl. backward (no capture); captures diagonally forward.",
	Piece.Type.CRAB: "1 sideways only (no capture); captures 1 diagonally in any direction.",
	Piece.Type.TORCHBEARER: "Moves like a pawn. When captured, the capturing piece is destroyed too.",
	Piece.Type.DRUMMER: "1 forward, can't capture. Friendly pawns next to it can move 2 forward.",
	Piece.Type.PILGRIM: "1 forward or backward, or swaps places with an adjacent friendly piece.",
	Piece.Type.SQUIRE: "Moves like a pawn. Starting a turn next to a friendly knight, it can make a knight jump instead.",
	# ---- uncommon
	Piece.Type.CAMEL: "3-1 leaper.",
	Piece.Type.ZEBRA: "3-2 leaper.",
	Piece.Type.TWIN_RIDER: "One or two knight jumps in the same direction (the square between the jumps must be empty).",
	Piece.Type.NINJA: "Knight move; after a capture it may move 1 more square.",
	Piece.Type.HAWK: "Leaps exactly 2 or 3 squares in any straight or diagonal direction.",
	Piece.Type.CANNON: "Rook move; captures by jumping over exactly one piece.",
	Piece.Type.CHARGER: "Rook move of at least 2 squares.",
	Piece.Type.RANGER: "Up to 3 squares orthogonally.",
	Piece.Type.LANCER: "Any distance forward, only 1 square backward or sideways.",
	Piece.Type.CATAPULT: "Never moves. Captures any piece exactly 3 squares away orthogonally, over blockers.",
	Piece.Type.TORTOISE: "Up to 2 squares orthogonally; can only be captured from behind or the sides.",
	Piece.Type.MIRROR: "Bishop move that can bounce off a board edge once per move.",
	Piece.Type.MONK: "Up to 3 squares diagonally, or 1 square orthogonally without capturing.",
	Piece.Type.FERZ_GUARD: "1 square diagonally or leaps 2 squares diagonally.",
	Piece.Type.GRASSHOPPER: "Along any queen line, must hop over one piece and land directly behind it.",
	Piece.Type.GOLEM: "1 square orthogonally; can't be captured by pawns or knights.",
	Piece.Type.ALCHEMIST: "King move, or swaps places with any friendly piece within 2 squares.",
	Piece.Type.GHOST: "Up to 2 squares in any direction, passing through pieces.",
	Piece.Type.SPEARMAN: "1 square any direction; captures up to 2 squares straight ahead.",
	Piece.Type.BARD: "King move, can't capture. Adjacent friendly pieces can't be captured by pawns.",
	Piece.Type.GRIFFON: "1 square diagonally, then up to 3 squares straight outward.",
	# ---- legendary (boss rewards)
	Piece.Type.PALADIN: "Bishop + knight. Adjacent friendly pieces can't be captured. When the king is attacked it can teleport next to the king.",
	Piece.Type.WARLORD: "Rook + knight. Every capture gives a bonus move with one pawn.",
	Piece.Type.EMPRESS: "Queen + knight.",
	Piece.Type.DRAGON: "Rook move, or breathes fire capturing every enemy up to 3 squares along one line, then rests a turn.",
	Piece.Type.PHOENIX: "Queen move. The first time it is captured it returns to its starting square 3 turns later.",
	Piece.Type.HYDRA: "Up to 2 squares any direction. When captured it splits into 4 knights (none adjacent) or 2 (any adjacent), never more than the empty squares beside it.",
	Piece.Type.WRAITH: "Queen move, phases through pieces. Can only be captured by pawns or other legendaries.",
	Piece.Type.LICH: "King move or 2-square leap. Every piece it captures returns as your pawn on your back rank.",
	Piece.Type.CHRONOMANCER: "Bishop move. Once per game it can undo the opponent's last move.",
	Piece.Type.TITAN: "Rook move that can capture up to 2 pieces in its path in one move.",
	Piece.Type.ORACLE: "Up to 3 squares any direction. Every second turn it takes two moves in a row.",
	Piece.Type.STORM_WITCH: "Queen move, or teleports next to an enemy piece (no capture that turn).",
}

## Reward-only pieces come from beating a knight, not from the shop.
static func is_reward_only(type: Piece.Type) -> bool:
	return _defs()[type].reward

## Who may not capture this piece (rules for CaptureRules).
static func protection(type: Piece.Type) -> Array:
	return _defs()[type].protection

## Things that happen when this piece captures (`on_capture`), is captured
## (`on_captured`) or moves (`on_move`), and special `actions` it can take instead
## of moving: a list of { kind, ... } handled by MoveEffects.
static func effects(type: Piece.Type, key: String) -> Array:
	return _defs()[type].get(key, [])

## Movement boosts this piece gives friendly pieces next to it (see PawnMovement).
static func boosts(type: Piece.Type) -> Array:
	return _defs()[type].get("boost", [])

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

## The same definition with extra keys (`on_capture`, `on_captured`, `boost`).
static func _with(definition: Dictionary, extra: Dictionary) -> Dictionary:
	definition.merge(extra, true)
	return definition

## The same definition, with capture protection for the piece itself and/or an aura for its neighbours.
static func _guarded(definition: Dictionary, own: Array, neighbours: Array = []) -> Dictionary:
	definition["protection"] = own
	definition["aura"] = neighbours
	return definition

static func _build() -> Dictionary:
	var common := Piece.Tier.COMMON
	var uncommon := Piece.Tier.UNCOMMON
	var rare := Piece.Tier.RARE
	var legendary := Piece.Tier.LEGENDARY
	var forward := [Vector2i(0, 1)]
	var beside := [Vector2i(1, 0), Vector2i(-1, 0)]
	var front_diagonals := [Vector2i(1, 1), Vector2i(-1, 1)]
	var within_two: Array = []
	for x in range(-2, 3):
		for y in range(-2, 3):
			if x != 0 or y != 0:
				within_two.append(Vector2i(x, y))
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
		Piece.Type.PILGRIM: _def(common, 2, "Pi", [
			{ "kind": "step", "to": [Vector2i(0, 1), Vector2i(0, -1)], "mode": "move", "local": true },
			{ "kind": "swap", "to": ALL_DIRECTIONS },
		]),
		Piece.Type.TORCHBEARER: _with(_def(common, 2, "Tb", [{ "kind": "pawn" }]),
			{ "on_captured": [{ "kind": "destroy_attacker" }] }),
		Piece.Type.DRUMMER: _with(_def(common, 1, "Dm", [{ "kind": "step", "to": forward, "mode": "move", "local": true }]),
			{ "boost": ["pawn_double_step"] }),
		Piece.Type.SQUIRE: _def(common, 2, "Sq", [
			{ "kind": "pawn" },
			{ "kind": "leap", "to": Piece.KNIGHT_OFFSETS, "when": { "adjacent_friend": [Piece.Type.KNIGHT] } },
		]),
		Piece.Type.ARCHER: _def(common, 2, "Ar", [
			{ "kind": "step", "to": forward, "mode": "move", "local": true },
			{ "kind": "shot", "dirs": forward, "distance": 2, "clear_line": true, "local": true },
		]),
		# ---- uncommon tier
		Piece.Type.CAMEL: _def(uncommon, 3, "Ca", [{ "kind": "leap", "to": _symmetric(3, 1) }]),
		Piece.Type.ZEBRA: _def(uncommon, 3, "Ze", [{ "kind": "leap", "to": _symmetric(3, 2) }]),
		Piece.Type.TWIN_RIDER: _def(rare, 4, "Tw", [{ "kind": "twin_leap", "to": Piece.KNIGHT_OFFSETS }]),
		Piece.Type.HAWK: _def(uncommon, 3, "Ha", [{ "kind": "leap", "to": hawk_jumps }]),
		Piece.Type.CANNON: _def(rare, 5, "Cn", [{ "kind": "cannon", "dirs": ORTHOGONAL }]),
		Piece.Type.CHARGER: _def(uncommon, 3, "Ch", [{ "kind": "slide", "dirs": ORTHOGONAL, "min": 2 }]),
		Piece.Type.RANGER: _def(uncommon, 3, "Ra", [{ "kind": "slide", "dirs": ORTHOGONAL, "max": 3 }]),
		Piece.Type.LANCER: _def(rare, 4, "La", [
			{ "kind": "slide", "dirs": forward, "local": true },
			{ "kind": "step", "to": beside + [Vector2i(0, -1)], "local": true },
		]),
		Piece.Type.MIRROR: _def(rare, 4, "Mr", [{ "kind": "slide", "dirs": DIAGONAL, "bounce": 1 }]),
		Piece.Type.MONK: _def(uncommon, 3, "Mo", [
			{ "kind": "slide", "dirs": DIAGONAL, "max": 3 },
			{ "kind": "step", "to": ORTHOGONAL, "mode": "move" },
		]),
		Piece.Type.FERZ_GUARD: _def(uncommon, 2, "Fg", [
			{ "kind": "step", "to": DIAGONAL },
			{ "kind": "leap", "to": _symmetric(2, 2) },
		]),
		Piece.Type.GRASSHOPPER: _def(rare, 4, "Gr", [{ "kind": "grasshopper", "dirs": ALL_DIRECTIONS }]),
		Piece.Type.GHOST: _def(rare, 5, "Gh", [{ "kind": "slide", "dirs": ALL_DIRECTIONS, "max": 2, "through": true }]),
		Piece.Type.SPEARMAN: _def(uncommon, 3, "Sp", [
			{ "kind": "step", "to": ALL_DIRECTIONS },
			{ "kind": "slide", "dirs": forward, "max": 2, "mode": "capture", "local": true },
		]),
		Piece.Type.GRIFFON: _def(rare, 5, "Gf", [{ "kind": "step_slide", "dirs": DIAGONAL, "then_max": 3 }]),
		Piece.Type.TORTOISE: _guarded(_def(uncommon, 3, "To", [{ "kind": "slide", "dirs": ORTHOGONAL, "max": 2 }]),
			[{ "kind": "from_front" }]),
		Piece.Type.GOLEM: _guarded(_def(uncommon, 3, "Go", [{ "kind": "step", "to": ORTHOGONAL }]),
			[{ "kind": "attacker_types", "types": [Piece.Type.PAWN, Piece.Type.KNIGHT] }]),
		Piece.Type.BARD: _guarded(_def(uncommon, 2, "Ba", [{ "kind": "step", "to": ALL_DIRECTIONS, "mode": "move" }]),
			[], [{ "kind": "attacker_types", "types": [Piece.Type.PAWN] }]),
		Piece.Type.NINJA: _with(_def(rare, 4, "Ni", [{ "kind": "leap", "to": Piece.KNIGHT_OFFSETS }]),
			{ "on_capture": [{ "kind": "bonus_step" }] }),
		Piece.Type.ALCHEMIST: _def(rare, 4, "Al", [
			{ "kind": "step", "to": ALL_DIRECTIONS },
			{ "kind": "swap", "to": within_two },
		]),
		Piece.Type.CATAPULT: _def(rare, 4, "Ct", [{ "kind": "shot", "dirs": ORTHOGONAL, "distance": 3 }]),
		# ---- legendary tier (boss rewards)
		Piece.Type.TITAN: _def(legendary, 10, "Ti", [{ "kind": "slide", "dirs": ORTHOGONAL, "double_capture": true }], true),
		Piece.Type.WRAITH: _guarded(_def(legendary, 10, "Wr", [{ "kind": "slide", "dirs": ALL_DIRECTIONS, "through": true }], true),
			[{ "kind": "only_attackers", "types": [Piece.Type.PAWN], "tiers": [Piece.Tier.LEGENDARY] }]),
		Piece.Type.LICH: _with(_def(legendary, 10, "Li", [
			{ "kind": "step", "to": ALL_DIRECTIONS },
			{ "kind": "leap", "to": _symmetric(2, 0) + _symmetric(2, 2) },
		], true), { "on_capture": [{ "kind": "raise_pawn" }] }),
		Piece.Type.WARLORD: _with(_def(legendary, 10, "Wa", [
			{ "kind": "slide", "dirs": ORTHOGONAL },
			{ "kind": "leap", "to": Piece.KNIGHT_OFFSETS },
		], true), { "on_capture": [{ "kind": "bonus_pawn" }] }),
		Piece.Type.PHOENIX: _with(_def(legendary, 10, "Ph", [{ "kind": "slide", "dirs": ALL_DIRECTIONS }], true),
			{ "on_captured": [{ "kind": "rebirth", "turns": 3 }] }),
		Piece.Type.HYDRA: _with(_def(legendary, 10, "Hy", [{ "kind": "slide", "dirs": ALL_DIRECTIONS, "max": 2 }], true),
			{ "on_captured": [{ "kind": "split", "alone": 4, "crowded": 2 }] }),
		Piece.Type.EMPRESS: _def(legendary, 12, "Em", [
			{ "kind": "slide", "dirs": ALL_DIRECTIONS },
			{ "kind": "leap", "to": Piece.KNIGHT_OFFSETS },
		], true),
		Piece.Type.PALADIN: _guarded(_def(legendary, 11, "Pa", [
			{ "kind": "slide", "dirs": DIAGONAL },
			{ "kind": "leap", "to": Piece.KNIGHT_OFFSETS },
			{ "kind": "king_teleport" },
		], true), [], [{ "kind": "any_attacker" }]),
		Piece.Type.STORM_WITCH: _def(legendary, 11, "Sw", [
			{ "kind": "slide", "dirs": ALL_DIRECTIONS },
			{ "kind": "teleport" },
		], true),
		Piece.Type.ORACLE: _with(_def(legendary, 10, "Or", [{ "kind": "slide", "dirs": ALL_DIRECTIONS, "max": 3 }], true),
			{ "on_move": [{ "kind": "double_turn", "every": 2 }] }),
		Piece.Type.CHRONOMANCER: _with(_def(legendary, 10, "Cm", [{ "kind": "slide", "dirs": DIAGONAL }], true),
			{ "actions": [{ "kind": "undo" }] }),
		Piece.Type.DRAGON: _def(legendary, 11, "Dr", [
			{ "kind": "slide", "dirs": ORTHOGONAL },
			{ "kind": "fire", "dirs": ORTHOGONAL, "range": 3, "rest": 2 },
		], true),
	}
