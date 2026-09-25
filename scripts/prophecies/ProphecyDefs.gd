class_name ProphecyDefs
extends RefCounted
## The fifty prophecy cards (see docs/PROPHECIES.md): one-time cards, carried up to
## RunConfig.HAND_SIZE at a time, bought in the shop. The rarer a card is, the more powerful.
##
## timing: "match"  played on your turn during a match (free: it costs no move)
##         "armed"  armed before a match, then fires on its own when its moment comes
##         "shop"   played in the shop
## ready:  whether the card is built yet. Only ready cards are ever offered.
## Rarity reuses Piece.Tier (common / uncommon / rare / legendary).

const C := Piece.Tier.COMMON
const U := Piece.Tier.UNCOMMON
const R := Piece.Tier.RARE
const L := Piece.Tier.LEGENDARY

static var _cache: Dictionary = {}

static func has(id: String) -> bool:
	return _defs().has(id)

## Every card id, in list order.
static func ids() -> Array:
	return _defs().keys()

static func get_def(id: String) -> Dictionary:
	return _defs()[id]

static func display_name(id: String) -> String:
	return _defs()[id].name

static func rarity(id: String) -> Piece.Tier:
	return _defs()[id].rarity

static func timing(id: String) -> String:
	return _defs()[id].timing

static func text(id: String) -> String:
	return _defs()[id].text

static func is_ready(id: String) -> bool:
	return _defs()[id].ready

static func ready_ids() -> Array:
	return ids().filter(func(id): return is_ready(id))

static func ids_of_rarity(tier: Piece.Tier, only_ready: bool = false) -> Array:
	return ids().filter(func(id): return rarity(id) == tier and (not only_ready or is_ready(id)))

static func _defs() -> Dictionary:
	if _cache.is_empty():
		for row in _rows():
			_cache[row[0]] = { "id": row[0], "name": row[1], "rarity": row[2], "timing": row[3], "text": row[4], "ready": row[5] }
	return _cache

# [id, name, rarity, timing, text, ready]
static func _rows() -> Array:
	return [
		# ---- common (18)
		["rising_tide", "Rising Tide", C, "match", "Every capture for the rest of the match scores +10.", true],
		["blood_moon", "Blood Moon", C, "match", "Your next 3 captures score x1.5.", true],
		["song_of_the_small", "Song of the Small", C, "match", "Captures by common-tier pieces score x1.5 this match.", true],
		["waypoint", "Waypoint", C, "match", "Move any of your pieces to an empty square in your zone.", false],
		["swap_fates", "Swap Fates", C, "match", "Swap any two of your pieces.", false],
		["wings", "Wings", C, "match", "A piece of yours moves like a queen this turn.", false],
		["broaden_the_realm", "Broaden the Realm", C, "armed", "Arm before a match: your zone is 6 tiles bigger.", false],
		["call_to_arms", "Call to Arms", C, "match", "Two temporary pawns appear in your zone.", false],
		["iron_skin", "Iron Skin", C, "match", "A piece of yours can't be captured by pawns or knights this match.", false],
		["curse_of_stillness", "Curse of Stillness", C, "match", "An enemy piece can't move for 2 of the AI's turns.", false],
		["banishing", "Banishing", C, "match", "Remove a common-tier enemy piece (never the king; no score).", false],
		["sow_discord", "Sow Discord", C, "match", "The AI's next move is random.", false],
		["purse_of_gold", "Purse of Gold", C, "shop", "+12 gold.", true],
		["lucky_draw", "Lucky Draw", C, "shop", "Your next lottery pull is free.", true],
		["wider_net", "Wider Net", C, "shop", "Your next offer shows 7 cards.", true],
		["hagglers_charm", "Haggler's Charm", C, "shop", "Points and zone upgrades are half price this shop visit.", true],
		["second_sight", "Second Sight", C, "shop", "Reroll the offer you're looking at.", true],
		["merlins_bargain", "Merlin's Bargain", C, "shop", "Destroy one of your pieces for 3x its points in gold.", true],
		# ---- uncommon (16)
		["omen_of_plunder", "Omen of Plunder", U, "match", "Your next capture scores x2.", true],
		["blessing_of_the_blade", "Blessing of the Blade", U, "match", "Pick a piece type: its captures score x1.5 this match.", true],
		["giant_slayer", "Giant Slayer", U, "match", "Capturing a piece worth more than your capturer scores x1.5 this match.", true],
		["marked_for_death", "Marked for Death", U, "match", "Pick an enemy piece: capturing it scores x2.", false],
		["quickening", "Quickening", U, "match", "+2 moves this match.", false],
		["second_chance", "Second Chance", U, "armed", "Arm before a match: if you'd run out of moves short of the target, gain 2 moves once.", false],
		["haste", "Haste", U, "match", "Your next 3 moves cost nothing.", false],
		["sanctuary", "Sanctuary", U, "match", "A piece of yours can't be captured for 3 of your turns.", false],
		["reinforcements", "Reinforcements", U, "armed", "Arm before a match: +5 allocated points this match.", false],
		["rite_of_rebirth", "Rite of Rebirth", U, "match", "The last piece you lost this match returns to its starting square.", false],
		["transmutation", "Transmutation", U, "match", "A piece of yours becomes another of the same tier for this match.", false],
		["guardian_spirit", "Guardian Spirit", U, "armed", "Arm before a match: the first piece you'd lose for good stays in your roster.", false],
		["shattered_shields", "Shattered Shields", U, "match", "The enemy's protections and auras stop working this match.", false],
		["reveal_weakness", "Reveal Weakness", U, "match", "The enemy king can't move for 3 turns.", false],
		["loaded_dice", "Loaded Dice", U, "shop", "Your next pull's tier is at least Uncommon.", true],
		["fair_trade", "Fair Trade", U, "shop", "Your next trade-up costs 2 fewer pieces.", true],
		# ---- rare (11)
		["borrowed_hour", "Borrowed Hour", R, "match", "Take an extra move right now.", false],
		["twin_sun", "Twin Sun", R, "match", "This turn you may move two different pieces.", false],
		["turning_tide", "Turning Tide", R, "match", "Rewind the opponent's last move.", false],
		["stone_ward", "Stone Ward", R, "match", "No piece can capture on a chosen square for 3 turns.", false],
		["chain_of_fate", "Chain of Fate", R, "match", "Captures on consecutive turns build a multiplier: x1, x1.5, x2... It resets when you miss.", true],
		["prophecy_of_ruin", "Prophecy of Ruin", R, "match", "This match's target score is 20% lower.", true],
		["gilded_ledger", "Gilded Ledger", R, "match", "Add 15% of the target score to your score now.", true],
		["golden_tithe", "Golden Tithe", R, "armed", "Arm before a match: this match's payout is x1.5.", true],
		["hex_of_the_boss", "Hex of the Boss", R, "match", "The boss's legendary is frozen for 3 turns.", false],
		["mantle_of_the_phoenix", "Mantle of the Phoenix", R, "armed", "Arm before a match, pick a piece: the first time it's captured it returns 3 turns later.", false],
		["field_promotion", "Field Promotion", R, "match", "Promote any pawn, anywhere, to a piece of your choice up to a rook.", false],
		# ---- legendary (5)
		["final_blow", "Final Blow", L, "armed", "Arm before a match: captures on your last move score x3.", true],
		["frozen_moment", "Frozen Moment", L, "match", "The AI skips its next turn.", false],
		["echo_of_steel", "Echo of Steel", L, "match", "Copy one of your pieces onto a free zone square for this match.", false],
		["queens_favor", "Queen's Favor", L, "shop", "Your next 7-rare upgrade costs 5 rares.", true],
		["unsealed_tomb", "Unsealed Tomb", L, "shop", "Unlock a random boss legendary for upgrades this run.", true],
	]
