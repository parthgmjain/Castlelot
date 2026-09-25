class_name ProphecyEffect
extends ScoreModifier
## A prophecy that is working during a match. It changes what your captures score (see
## ScoreModifier) and can keep a little state of its own. Created by Prophecies.

var id := ""
## How many more captures it applies to; -1 for the rest of the match.
var uses := -1
var data: Dictionary = {}
## True when the card came from an armed card, so the card is used up once this has fired.
var armed_card := false
var spent := false

static func make(card_id: String, remaining_uses: int = -1, extra: Dictionary = {}) -> ProphecyEffect:
	var effect := ProphecyEffect.new()
	effect.id = card_id
	effect.uses = remaining_uses
	effect.data = extra
	return effect

func on_capture(context: Dictionary) -> void:
	if context.side != context.player_side:
		return                                   # prophecies only ever help you
	match id:
		"omen_of_plunder":
			context.mult *= 2.0
			_use()
		"rising_tide":
			context.chips += 10.0
		"blood_moon":
			context.mult *= 1.5
			_use()
		"song_of_the_small":
			if Piece.tier(context.attacker.type) == Piece.Tier.COMMON:
				context.mult *= 1.5
		"giant_slayer":
			if Piece.value(context.victim.type) > Piece.value(context.attacker.type):
				context.mult *= 1.5
		"blessing_of_the_blade":
			if context.attacker.type == data.type:
				context.mult *= 1.5
		"chain_of_fate":
			context.mult *= 1.0 + 0.5 * data.streak
		"final_blow":
			if context.moves_left <= 0:
				context.mult *= 3.0
				spent = true
		"marked_for_death":
			if context.victim.get("marked_for_death", false):
				context.mult *= 2.0

## Called after each of your moves: `captured` is whether it took something.
func on_player_move(captured: bool) -> void:
	if id == "chain_of_fate":
		data["streak"] = data.streak + 1 if captured else 0

func is_used_up() -> bool:
	return uses == 0

func _use() -> void:
	if uses > 0:
		uses -= 1
