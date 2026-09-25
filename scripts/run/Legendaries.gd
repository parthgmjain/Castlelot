class_name Legendaries
extends RefCounted

## Legendary pieces: never drawn. They come from beating a boss (its own piece) or from
## trading up 7 rares. You can hold two legendary types at once, one copy of each.
##
## Waiting choices (in run.pending):
##   { kind: "legendary_pick", options }   after a trade-up: which legendary you want
##   { kind: "legendary_full", incoming }  both slots hold something else: which of the three to give up

## What a trade-up can give: the queen, plus every boss piece you have beaten this run,
## minus what you already hold.
static func available_upgrades(run: RunState) -> Array:
	var options: Array = []
	for type in RunConfig.DEFAULT_LEGENDARIES + run.unlocked_legendaries:
		if not options.has(type) and run.count_of(type) == 0:
			options.append(type)
	return options

## Gives `type` to the player. Returns "owned" (you already hold it), "added" (a slot was free)
## or "choose" (both slots are taken: run.pending now asks which of the three to give up).
static func grant(run: RunState, type: Piece.Type) -> String:
	if not RunConfig.DEFAULT_LEGENDARIES.has(type) and not run.unlocked_legendaries.has(type):
		run.unlocked_legendaries.append(type)
	if run.count_of(type) > 0:
		return "owned"
	if run.free_slots(Piece.Tier.LEGENDARY) > 0:
		run.add_to_roster(type)
		return "added"
	run.pending = { "kind": "legendary_full", "incoming": type }
	return "choose"

## After a trade-up: takes the chosen legendary. Returns { ok, reason, status } (see grant).
static func pick_upgrade(run: RunState, type: Piece.Type) -> Dictionary:
	if run.pending.get("kind") != "legendary_pick" or not run.pending.options.has(type):
		return { "ok": false, "reason": "You can't pick that legendary." }
	run.pending = {}
	return { "ok": true, "reason": "", "status": grant(run, type) }

## Both slots were full: gives up `give_up` - one of your two legendaries, or the incoming one
## (declining it). Returns { ok, reason, kept_incoming }.
static func resolve_full(run: RunState, give_up: Piece.Type) -> Dictionary:
	if run.pending.get("kind") != "legendary_full":
		return { "ok": false, "reason": "Nothing to decide right now." }
	var incoming: Piece.Type = run.pending.incoming
	if give_up != incoming and not run.held_types(Piece.Tier.LEGENDARY).has(give_up):
		return { "ok": false, "reason": "You don't hold that piece." }
	if give_up != incoming:
		run.remove_all_of_type(give_up)
		run.add_to_roster(incoming)
	run.pending = {}
	return { "ok": true, "reason": "", "kept_incoming": give_up != incoming }
