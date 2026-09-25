class_name Prophecies
extends RefCounted
## What you can do with prophecy cards: buy them (each shop visit offers a few), carry up to
## RunConfig.HAND_SIZE, discard, arm, and play them in the shop or in a match.
## Every function that can fail returns { ok, reason } (plus extras). No prophecy can ever
## capture or destroy a king.

# ---- numbers on the cards (placeholders)
const PURSE_GOLD := 12
const WIDE_OFFER_CARDS := 7
const RUIN_CUT := 0.20
const LEDGER_SHARE := 0.15
const TITHE_BONUS := 0.5
const BARGAIN_MULTIPLIER := 3
const ZONE_BONUS := 6
const POINTS_BONUS := 5
const HASTE_MOVES := 3
const QUICKENING_MOVES := 2
const SANCTUARY_TURNS := 3
const WARD_TURNS := 3

# ---- the shop ---------------------------------------------------------------------------------

static func price(id: String) -> int:
	return RunConfig.PROPHECY_PRICES[ProphecyDefs.rarity(id)]

## The cards for sale this visit: distinct built cards, each picked by rarity (the rarer, the
## less likely) and then evenly within the rarity.
static func roll_offers(rng: RandomNumberGenerator = null) -> Array:
	rng = rng if rng != null else RandomNumberGenerator.new()
	var taken: Array = []
	var weights := {}
	for tier in RunConfig.PROPHECY_WEIGHTS:
		weights[tier] = RunConfig.PROPHECY_WEIGHTS[tier]
	while taken.size() < RunConfig.PROPHECY_OFFERS:
		for tier in weights.keys():
			if ProphecyDefs.ids_of_rarity(tier, true).filter(func(id): return not taken.has(id)).is_empty():
				weights.erase(tier)                  # nothing left of that rarity
		if weights.is_empty():
			break
		var tier := _pick_rarity(weights, rng)
		var pool: Array = ProphecyDefs.ids_of_rarity(tier, true).filter(func(id): return not taken.has(id))
		taken.append(pool[rng.randi_range(0, pool.size() - 1)])
	return taken

static func _pick_rarity(weights: Dictionary, rng: RandomNumberGenerator) -> Piece.Tier:
	var total := 0.0
	for tier in weights:
		total += weights[tier]
	var roll := rng.randf() * total
	var last: Piece.Tier = weights.keys()[0]
	for tier in weights:
		last = tier
		roll -= weights[tier]
		if roll < 0.0:
			return tier
	return last

## A fresh set of cards for sale (called when the shop opens).
static func refresh_offers(run: RunState, rng: RandomNumberGenerator = null) -> void:
	run.prophecy_offers = roll_offers(rng)

## Buys the card in offer slot `slot`.
static func buy(run: RunState, slot: int) -> Dictionary:
	if slot < 0 or slot >= run.prophecy_offers.size() or run.prophecy_offers[slot] == "":
		return { "ok": false, "reason": "That card isn't for sale." }
	var id: String = run.prophecy_offers[slot]
	if hand_full(run):
		return { "ok": false, "reason": "Your hand is full - discard a prophecy first." }
	if run.currency < price(id):
		return { "ok": false, "reason": "Not enough gold (%s costs %d)." % [ProphecyDefs.display_name(id), price(id)] }
	run.currency -= price(id)
	run.hand.append({ "id": id, "armed": false })
	run.prophecy_offers[slot] = ""
	return { "ok": true, "reason": "", "id": id }

static func hand_full(run: RunState) -> bool:
	return run.hand.size() >= RunConfig.HAND_SIZE

static func discard(run: RunState, index: int) -> Dictionary:
	if index < 0 or index >= run.hand.size():
		return { "ok": false, "reason": "You don't hold that card." }
	var id: String = run.hand[index].id
	run.hand.remove_at(index)
	return { "ok": true, "reason": "", "id": id }

## Called when you leave the shop: this-visit boosts end.
static func end_shop(run: RunState) -> void:
	run.shop_effects.erase("haggle")

## Removes the first armed copy of `id` from your hand, if you hold one. Used for cards that
## are consumed outside a running match (Broaden the Realm, Reinforcements at zone/deployment
## setup time). Returns whether one was found and removed.
static func consume_armed(run: RunState, id: String) -> bool:
	for i in run.hand.size():
		if run.hand[i].id == id and run.hand[i].armed:
			run.hand.remove_at(i)
			return true
	return false

# ---- arming ------------------------------------------------------------------------------------

## Arms (or disarms) a card that fires on its own during the next match.
static func set_armed(run: RunState, index: int, armed: bool) -> Dictionary:
	if index < 0 or index >= run.hand.size():
		return { "ok": false, "reason": "You don't hold that card." }
	if ProphecyDefs.timing(run.hand[index].id) != "armed":
		return { "ok": false, "reason": "That card isn't armed - it's played." }
	run.hand[index].armed = armed
	return { "ok": true, "reason": "" }

## At the start of a match: armed cards that work on scoring, or that watch for a moment
## during the match (Second Chance), become effects for it.
static func begin_match(state: GameState) -> void:
	for entry in state.run.hand:
		if entry.armed and (entry.id == "final_blow" or entry.id == "second_chance"):
			var effect := ProphecyEffect.make(entry.id)
			effect.armed_card = true
			state.current_match.prophecies.append(effect)

## After a match: armed cards whose moment came are used up.
static func finish_match(run: RunState, current: MatchState) -> void:
	for effect in current.prophecies:
		if effect.armed_card and effect.spent:
			for i in run.hand.size():
				if run.hand[i].id == effect.id and run.hand[i].armed:
					run.hand.remove_at(i)
					break

## Golden Tithe: an armed one raises this win's payout. Returns the payout (with the bonus in
## `tithe`), and uses the card up.
static func apply_payout(run: RunState, payout: Dictionary) -> Dictionary:
	for i in run.hand.size():
		if run.hand[i].id == "golden_tithe" and run.hand[i].armed:
			run.hand.remove_at(i)
			var bonus := int(round(payout.total * TITHE_BONUS))
			payout["tithe"] = bonus
			payout["total"] = payout.total + bonus
			break
	return payout

# ---- playing in the shop -----------------------------------------------------------------------

## Plays the shop card at `index`. Returns { ok, reason, note, waiting }: `waiting` when it needs a
## choice first (Merlin's Bargain), in which case the card is used up once you choose.
static func play_in_shop(run: RunState, index: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var guard := _playable(run, index)
	if not guard.ok:
		return guard
	var id: String = run.hand[index].id
	if ProphecyDefs.timing(id) != "shop":
		return _no("%s is %s." % [ProphecyDefs.display_name(id), "played during a match" if ProphecyDefs.timing(id) == "match" else "armed before a match"])
	var effects := run.shop_effects
	var note := ""
	match id:
		"purse_of_gold":
			run.currency += PURSE_GOLD
			note = "+%d gold." % PURSE_GOLD
		"lucky_draw":
			if effects.get("free_pull", false):
				return _no("You already have a free pull waiting.")
			effects["free_pull"] = true
			note = "Your next pull is free."
		"loaded_dice":
			if effects.has("min_tier"):
				return _no("The dice are already loaded.")
			effects["min_tier"] = Piece.Tier.UNCOMMON
			note = "Your next pull will be at least Uncommon."
		"wider_net":
			if effects.get("wide_offer", false):
				return _no("Your net is already cast wide.")
			effects["wide_offer"] = true
			note = "Your next offer shows %d cards." % WIDE_OFFER_CARDS
		"fair_trade":
			if effects.has("fair_trade"):
				return _no("A fair trade is already waiting.")
			effects["fair_trade"] = 2
			note = "Your next trade-up costs 2 fewer pieces."
		"hagglers_charm":
			if effects.get("haggle", false):
				return _no("You're already haggling.")
			effects["haggle"] = true
			note = "Upgrades are half price until you leave the shop."
		"queens_favor":
			if effects.get("queens_favor", false):
				return _no("The queen already favours you.")
			effects["queens_favor"] = true
			note = "Your next 7-rare upgrade costs 5 rares."
		"second_sight":
			if not Lottery.reroll(run, rng):
				return _no("Play Second Sight while you're choosing from an offer.")
			note = "The cards are dealt again."
		"unsealed_tomb":
			var sealed: Array = RunConfig.BOSSES.filter(func(t): return not run.unlocked_legendaries.has(t))
			if sealed.is_empty():
				return _no("Every boss legendary is already unlocked.")
			var rolled: Piece.Type = sealed[(rng if rng != null else RandomNumberGenerator.new()).randi_range(0, sealed.size() - 1)]
			run.unlocked_legendaries.append(rolled)
			note = "The %s is unlocked: you can upgrade into it." % Piece.display_name(rolled)
		"merlins_bargain":
			if run.roster.is_empty():
				return _no("You have no pieces to give up.")
			run.pending = { "kind": "bargain" }
			return { "ok": true, "reason": "", "note": "Choose a piece to give up.", "waiting": true }
		_:
			return _no("That prophecy isn't available yet.")
	run.hand.remove_at(index)
	return { "ok": true, "reason": "", "note": note, "waiting": false }

## Merlin's Bargain: the piece you chose is destroyed for 3x its points in gold and the card is used.
static func resolve_bargain(run: RunState, roster_id: int) -> Dictionary:
	if run.pending.get("kind") != "bargain":
		return _no("Nothing to decide right now.")
	var entry := run.roster_entry(roster_id)
	if entry.is_empty():
		return _no("You don't own that piece.")
	var gold: int = Piece.value(entry.type) * BARGAIN_MULTIPLIER
	run.remove_from_roster(roster_id)
	run.currency += gold
	for i in run.hand.size():
		if run.hand[i].id == "merlins_bargain":
			run.hand.remove_at(i)
			break
	run.pending = {}
	return { "ok": true, "reason": "", "gold": gold, "piece": entry.type }

static func cancel_bargain(run: RunState) -> void:
	if run.pending.get("kind") == "bargain":
		run.pending = {}

# ---- playing in a match --------------------------------------------------------------------------

## Plays the match card at `index` on your turn. Returns { ok, reason, note, needs_choice, options }:
## a card that needs a choice (Blessing of the Blade) comes back with `needs_choice` and the
## `options`; play it again with `choice` to finish.
static func play_in_match(state: GameState, index: int, choice: Variant = null) -> Dictionary:
	var run := state.run
	var guard := _playable(run, index)
	if not guard.ok:
		return guard
	var current := state.current_match
	if not current.active:
		return _no("Prophecies are played during a match.")
	if current.turn_side != current.player_side and not state.debug_mode:
		return _no("Wait for your turn.")
	if not state.pending_promotion.is_empty() or not current.bonus.is_empty():
		return _no("Finish your move first.")
	var id: String = run.hand[index].id
	match ProphecyDefs.timing(id):
		"armed":
			return _no("%s must be armed before a match." % ProphecyDefs.display_name(id))
		"shop":
			return _no("%s is played in the shop." % ProphecyDefs.display_name(id))
	if choice == null or current.prophecy_pick.get("id", "") != id:
		current.prophecy_pick = {}      # a fresh Play, or a switch to a different card, restarts any multi-step pick
	match id:
		"omen_of_plunder":
			current.prophecies.append(ProphecyEffect.make(id, 1))
		"rising_tide", "song_of_the_small", "giant_slayer":
			current.prophecies.append(ProphecyEffect.make(id))
		"blood_moon":
			current.prophecies.append(ProphecyEffect.make(id, 3))
		"chain_of_fate":
			current.prophecies.append(ProphecyEffect.make(id, -1, { "streak": 0 }))
		"blessing_of_the_blade":
			var options := _piece_types_on_board(state, current.player_side)
			if choice == null:
				return { "ok": true, "reason": "", "note": "", "needs_choice": true, "options": options }
			if not options.has(choice):
				return _no("Pick a piece type you have on the board.")
			current.prophecies.append(ProphecyEffect.make(id, -1, { "type": choice }))
		"prophecy_of_ruin":
			current.target_score = maxi(int(round(current.target_score * (1.0 - RUIN_CUT))), 1)
		"gilded_ledger":
			current.scores[current.player_side] += int(round(current.target_score * LEDGER_SHARE))
		"quickening":
			current.moves_left += QUICKENING_MOVES
		"haste":
			current.free_moves += HASTE_MOVES
		"frozen_moment":
			current.frozen_enemy_turns += 1
		"borrowed_hour", "twin_sun":
			# Both simply grant one free move with any piece; see docs/PROPHECIES.md for the
			# simplification (Twin Sun doesn't insist the second piece differs from the first).
			current.bonus = { "kind": "any", "side": current.player_side, "label": "%s: move any piece for free" % ProphecyDefs.display_name(id) }
		"turning_tide":
			if current.history.is_empty() or current.history.back().side == current.player_side:
				return _no("There's no enemy move to turn back yet.")
			var rewind_note := MoveEffects.rewind(state)
			run.hand.remove_at(index)
			current.last_event = "You played %s. %s" % [ProphecyDefs.display_name(id), rewind_note]
			return { "ok": true, "reason": "", "note": rewind_note, "needs_choice": false }
		"sanctuary":
			var refs := _piece_refs_on_board(state, current.player_side)
			if choice == null:
				return { "ok": true, "reason": "", "prompt": "Pick a piece to protect:", "needs_choice": true, "options": refs }
			if not _refs_has(refs, choice):
				return _no("Pick one of your pieces.")
			choice.board.pieces[choice.square]["shielded"] = SANCTUARY_TURNS
		"stone_ward":
			var ward_refs := _piece_refs_on_board(state, current.player_side)
			if choice == null:
				return { "ok": true, "reason": "", "prompt": "Pick a square of yours to ward:", "needs_choice": true, "options": ward_refs }
			if not _refs_has(ward_refs, choice):
				return _no("Pick a square one of your pieces stands on.")
			choice.board.warded_squares[choice.square] = WARD_TURNS
		"wings":
			var wing_refs := _piece_refs_on_board(state, current.player_side)
			if choice == null:
				return { "ok": true, "reason": "", "prompt": "Pick a piece to give wings:", "needs_choice": true, "options": wing_refs }
			if not _refs_has(wing_refs, choice):
				return _no("Pick one of your pieces.")
			choice.board.pieces[choice.square]["wings"] = true
		"swap_fates":
			var swap_options := _piece_refs_on_board(state, current.player_side)
			if swap_options.size() < 2:
				return _no("You need at least two pieces to swap.")
			if current.prophecy_pick.has("first"):
				var first: Dictionary = current.prophecy_pick.first
				if choice == null or not _refs_has(swap_options, choice) or (choice.board == first.board and choice.square == first.square):
					return _no("Pick a second, different piece of yours.")
				var a: Dictionary = first.board.pieces[first.square]
				var b: Dictionary = choice.board.pieces[choice.square]
				first.board.pieces[first.square] = b
				choice.board.pieces[choice.square] = a
				if PawnMovement.reached_promotion(b, first.board, first.square):
					state.pending_promotion = { "piece": b, "board": first.board, "square": first.square }
				elif PawnMovement.reached_promotion(a, choice.board, choice.square):
					state.pending_promotion = { "piece": a, "board": choice.board, "square": choice.square }
				first.board.queue_redraw()
				choice.board.queue_redraw()
				current.prophecy_pick = {}
			elif choice == null:
				return { "ok": true, "reason": "", "prompt": "Pick a piece to swap:", "needs_choice": true, "options": swap_options }
			elif not _refs_has(swap_options, choice):
				return _no("Pick one of your pieces.")
			else:
				current.prophecy_pick = { "id": "swap_fates", "first": choice }
				var remaining := swap_options.filter(func(o): return not (o.board == choice.board and o.square == choice.square))
				return { "ok": true, "reason": "", "prompt": "Pick the piece to swap it with:", "needs_choice": true, "options": remaining }
		"waypoint":
			var move_options := _piece_refs_on_board(state, current.player_side)
			if current.prophecy_pick.has("piece"):
				var piece_ref: Dictionary = current.prophecy_pick.piece
				var empties := Roster.free_squares(state.boards, current.player_side)
				if choice == null or not empties.any(func(e): return e.board == choice.board and e.square == choice.square):
					return _no("Pick an empty square in your zone.")
				# Destinations are always inside your own zone (Roster.free_squares), so a pawn
				# sent here can never land in the enemy zone: this never promotes.
				var moved: Dictionary = piece_ref.board.pieces[piece_ref.square]
				piece_ref.board.pieces.erase(piece_ref.square)
				choice.board.pieces[choice.square] = moved
				piece_ref.board.queue_redraw()
				choice.board.queue_redraw()
				current.prophecy_pick = {}
			elif choice == null:
				if move_options.is_empty():
					return _no("You have no pieces to move.")
				return { "ok": true, "reason": "", "prompt": "Pick a piece to move:", "needs_choice": true, "options": move_options }
			elif not _refs_has(move_options, choice):
				return _no("Pick one of your pieces.")
			else:
				var destinations := Roster.free_squares(state.boards, current.player_side)
				if destinations.is_empty():
					return _no("There's no empty square in your zone.")
				current.prophecy_pick = { "id": "waypoint", "piece": choice }
				return { "ok": true, "reason": "", "prompt": "Pick where to send it:", "needs_choice": true, "options": destinations }
		_:
			return _no("That prophecy isn't available yet.")
	run.hand.remove_at(index)
	current.last_event = "You played %s." % ProphecyDefs.display_name(id)
	MatchController.check_target(state)
	return { "ok": true, "reason": "", "note": ProphecyDefs.text(id), "needs_choice": false }

static func _piece_types_on_board(state: GameState, side: Piece.Side) -> Array:
	var types: Array = []
	for board in state.boards:
		for piece in board.pieces.values():
			if piece.side == side and piece.type != Piece.Type.KING and not types.has(piece.type):
				types.append(piece.type)
	return types

## Every one of `side`'s pieces (never the king), as [{ board, square }].
static func _piece_refs_on_board(state: GameState, side: Piece.Side) -> Array:
	var refs: Array = []
	for board in state.boards:
		for square in board.pieces:
			var piece: Dictionary = board.pieces[square]
			if piece.side == side and piece.type != Piece.Type.KING:
				refs.append({ "board": board, "square": square })
	return refs

static func _refs_has(refs: Array, ref: Variant) -> bool:
	return ref is Dictionary and refs.any(func(r): return r.board == ref.board and r.square == ref.square)

## Cancels any multi-step prophecy pick in progress (called when a choice is abandoned).
static func cancel_choice(state: GameState) -> void:
	state.current_match.prophecy_pick = {}

# ---- helpers -------------------------------------------------------------------------------------

static func _playable(run: RunState, index: int) -> Dictionary:
	if index < 0 or index >= run.hand.size():
		return _no("You don't hold that card.")
	if not ProphecyDefs.is_ready(run.hand[index].id):
		return _no("That prophecy isn't available yet.")
	return { "ok": true, "reason": "" }

static func _no(reason: String) -> Dictionary:
	return { "ok": false, "reason": reason }
