class_name BossThemes
extends RefCounted
## Reskins the 12 legendary boss pieces (mechanics untouched, this is names only) as the
## heaven-invasion cast: Saint Peter guards the gate alone in round 1, then the Four
## Horsemen, then a band of angels, then a trio of virtues, each group shuffled within
## itself but never mixed across groups - see `ordered_bosses()`. `RunConfig.FINAL_BOSS`
## (round 13, "Arthur" originally) is now "God" - see RunState.boss_name().

const PETER := Piece.Type.CHRONOMANCER

## Picked for how well their existing mechanic fits: Lich raises the fallen into your own
## pawns (Death commands the dead), Warlord's bonus move escalates with every kill (War),
## Titan takes two pieces in one pass (Famine devours), Hydra splits into many knights
## when struck (Pestilence spreads).
const HORSEMEN := [Piece.Type.LICH, Piece.Type.WARLORD, Piece.Type.TITAN, Piece.Type.HYDRA]

## Dragon's line-fire ("the burning ones"), Paladin's ally-shielding (a guardian
## commander), Storm Witch's teleport (a swift messenger), Wraith's near-uncapturability
## (unseen, hard to pin down).
const ANGELS := [Piece.Type.DRAGON, Piece.Type.PALADIN, Piece.Type.STORM_WITCH, Piece.Type.WRAITH]

## Empress's raw power renamed Humility (deliberate irony), Phoenix's return from death
## as Diligence (never stays down), Oracle's every-other-turn bonus as Temperance
## (measured, disciplined).
const VIRTUES := [Piece.Type.EMPRESS, Piece.Type.PHOENIX, Piece.Type.ORACLE]

## The boss's display name for the round banner/title. Piece.display_name (the piece's
## mechanical identity, used everywhere else - shop, roster, tooltips) is untouched;
## this only reskins the boss *encounter*.
const NAMES := {
	Piece.Type.CHRONOMANCER: "Saint Peter",
	Piece.Type.LICH: "Death",
	Piece.Type.WARLORD: "War",
	Piece.Type.TITAN: "Famine",
	Piece.Type.HYDRA: "Pestilence",
	Piece.Type.DRAGON: "Seraphim",
	Piece.Type.PALADIN: "Archangel Michael",
	Piece.Type.STORM_WITCH: "Archangel Gabriel",
	Piece.Type.WRAITH: "Principality",
	Piece.Type.EMPRESS: "Humility",
	Piece.Type.PHOENIX: "Diligence",
	Piece.Type.ORACLE: "Temperance",
}

static func display_name(type: Piece.Type) -> String:
	return NAMES.get(type, Piece.display_name(type))

## This run's boss order: Peter first (always), then the Horsemen, then the Angels,
## then the Virtues - each of those three groups independently shuffled (so the run
## still varies match to match) but never interleaved with each other.
static func ordered_bosses() -> Array:
	var horsemen := HORSEMEN.duplicate()
	var angels := ANGELS.duplicate()
	var virtues := VIRTUES.duplicate()
	horsemen.shuffle()
	angels.shuffle()
	virtues.shuffle()
	return [PETER] + horsemen + angels + virtues
