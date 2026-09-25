extends "res://tests/TestCase.gd"
## The scoring prophecies, through real captures: what each one adds and when it stops.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# A match with `pieces` = [[square, type, side], ...] plus both kings, and `hand` cards
# ("id" or ["id", armed]). White is the player.
func _game(pieces: Array, hand: Array = [], moves: int = 10, target: int = 100000) -> GameState:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE]] + pieces)
	state.run = RunState.new()
	state.run.begin()
	for card in hand:
		state.run.hand.append({ "id": card, "armed": false } if card is String else { "id": card[0], "armed": card[1] })
	check_eq(MatchController.start(state, moves, target), "", "the match started")
	return state

func _score(state: GameState) -> int:
	return state.current_match.scores[WHITE]

func _move(state: GameState, from: Vector2i, to: Vector2i) -> Dictionary:
	var board: Board = state.boards[0]
	state.active_board = board
	state.active_square = from
	MoveController.refresh(state)
	var result := MoveController.click(state, board, to)
	MatchController.record_move(state, result)
	return result

# The score gained by the move.
func _gain(state: GameState, from: Vector2i, to: Vector2i) -> int:
	var before := _score(state)
	_move(state, from, to)
	return _score(state) - before

func _play(state: GameState, index: int = 0, choice: Variant = null) -> Dictionary:
	return Prophecies.play_in_match(state, index, choice)

# ---- capture multipliers ------------------------------------------------------------------------

func test_omen_of_plunder_doubles_only_the_next_capture() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 4), PAWN, BLACK], [V(0, 2), PAWN, BLACK], [V(0, 1), PAWN, BLACK]], ["omen_of_plunder"])
	check(_play(state).ok, "played")
	check(state.run.hand.is_empty(), "the card is used up")
	check_eq(_gain(state, V(0, 7), V(0, 4)), 20, "the next capture: 10 x 2")
	check_eq(_gain(state, V(0, 4), V(0, 2)), 10, "the one after is ordinary")
	check(state.current_match.prophecies.is_empty(), "and the effect has gone")

func test_rising_tide_adds_ten_to_every_capture() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 4), PAWN, BLACK], [V(0, 2), ROOK, BLACK]], ["rising_tide"])
	_play(state)
	check_eq(_gain(state, V(0, 7), V(0, 4)), 20, "a pawn: 10 + 10")
	check_eq(_gain(state, V(0, 4), V(0, 2)), 60, "a rook: 50 + 10")
	check_eq(state.current_match.prophecies.size(), 1, "and it lasts the whole match")

func test_blood_moon_boosts_the_next_three_captures() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 6), PAWN, BLACK], [V(0, 5), PAWN, BLACK], [V(0, 4), PAWN, BLACK], [V(0, 3), PAWN, BLACK]], ["blood_moon"])
	_play(state)
	var gains := []
	for target in [V(0, 6), V(0, 5), V(0, 4), V(0, 3)]:
		gains.append(_gain(state, V(0, target.y + 1), target))
	check_eq(gains, [15, 15, 15, 10], "x1.5 three times, then ordinary")

func test_song_of_the_small_helps_only_common_tier_attackers() -> void:
	var state := _game([[V(3, 4), PAWN, WHITE], [V(2, 3), PAWN, BLACK], [V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK]], ["song_of_the_small"])
	_play(state)
	check_eq(_gain(state, V(3, 4), V(2, 3)), 15, "a pawn (common) x1.5")
	check_eq(_gain(state, V(0, 7), V(0, 5)), 10, "a rook (rare) is unchanged")

func test_giant_slayer_rewards_taking_something_worth_more_than_your_capturer() -> void:
	var state := _game([[V(3, 4), PAWN, WHITE], [V(2, 3), ROOK, BLACK], [V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK]], ["giant_slayer"])
	_play(state)
	check_eq(_gain(state, V(0, 7), V(0, 5)), 10, "a rook taking a pawn: nothing")
	check_eq(_gain(state, V(3, 4), V(2, 3)), 75, "a pawn taking a rook: 50 x 1.5")

func test_blessing_of_the_blade_asks_for_a_piece_type_and_boosts_it() -> void:
	var state := _game([[V(3, 4), KNIGHT, WHITE], [V(4, 2), PAWN, BLACK], [V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK]], ["blessing_of_the_blade"])
	var asked := _play(state)
	check(asked.ok and asked.needs_choice, "it wants a choice")
	check(asked.options.has(KNIGHT) and asked.options.has(ROOK) and not asked.options.has(KING), "your piece types on the board, never the king: %s" % str(asked.options))
	check_eq(state.run.hand.size(), 1, "the card isn't spent yet")
	var wrong := _play(state, 0, Piece.Type.DRAGON)
	check(not wrong.ok, "a type you don't have is refused")
	check_eq(state.run.hand.size(), 1, "still in your hand")
	check(_play(state, 0, KNIGHT).ok, "the knight it is")
	check(state.run.hand.is_empty(), "now it's used")
	check_eq(_gain(state, V(0, 7), V(0, 5)), 10, "the rook is not blessed")
	check_eq(_gain(state, V(3, 4), V(4, 2)), 15, "the knight is: 10 x 1.5")

func test_chain_of_fate_builds_a_multiplier_on_consecutive_captures_and_resets_on_a_miss() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK], [V(0, 3), PAWN, BLACK], [V(0, 1), PAWN, BLACK], [V(3, 1), PAWN, BLACK]], ["chain_of_fate"])
	_play(state)
	check_eq(_gain(state, V(0, 7), V(0, 5)), 10, "first capture: x1")
	check_eq(_gain(state, V(0, 5), V(0, 3)), 15, "second in a row: x1.5")
	check_eq(_gain(state, V(0, 3), V(0, 1)), 20, "third in a row: x2")
	check_eq(_gain(state, V(0, 1), V(1, 1)), 0, "a quiet move scores nothing...")
	check_eq(_gain(state, V(1, 1), V(3, 1)), 10, "...and starts the chain again at x1")

func test_effects_combine() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 4), PAWN, BLACK]], ["rising_tide", "omen_of_plunder"])
	_play(state)
	_play(state)
	check_eq(_gain(state, V(0, 7), V(0, 4)), 40, "(10 + 10) x 2")

func test_your_prophecies_never_help_the_ai() -> void:
	var state := _game([[V(4, 2), PAWN, WHITE], [V(3, 1), PAWN, BLACK], [V(0, 4), ROOK, BLACK], [V(0, 6), PAWN, WHITE]], ["omen_of_plunder", "rising_tide"])
	_play(state)
	_play(state)
	state.current_match.turn_side = BLACK
	_move(state, V(0, 4), V(0, 6))
	check_eq(state.current_match.scores[BLACK], 10, "black's capture is ordinary")
	check_eq(state.current_match.prophecies.size(), 2, "and your effects are still waiting")

func test_effects_are_used_only_for_the_match_they_were_played_in() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE]], ["rising_tide"])
	_play(state)
	check_eq(state.current_match.prophecies.size(), 1, "working")
	MatchController.start(state, 10, 100)
	check(state.current_match.prophecies.is_empty(), "a new match starts clean")

# ---- armed: Final Blow --------------------------------------------------------------------------

func test_final_blow_triples_the_capture_on_your_last_move() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK], [V(0, 3), PAWN, BLACK]], [["final_blow", true]], 2)
	check_eq(state.current_match.prophecies.size(), 1, "an armed Final Blow is working from the start")
	check_eq(_gain(state, V(0, 7), V(0, 5)), 10, "not on the first move")
	check_eq(_gain(state, V(0, 5), V(0, 3)), 30, "x3 on the last")
	check(state.current_match.prophecies[0].spent, "it fired")
	Prophecies.finish_match(state.run, state.current_match)
	check(state.run.hand.is_empty(), "and the card is used up")

func test_an_unarmed_final_blow_does_nothing() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK], [V(0, 3), PAWN, BLACK]], [["final_blow", false]], 2)
	check(state.current_match.prophecies.is_empty(), "nothing armed")
	_move(state, V(0, 7), V(0, 5))
	check_eq(_gain(state, V(0, 5), V(0, 3)), 10, "the last move is ordinary")
	Prophecies.finish_match(state.run, state.current_match)
	check_eq(state.run.hand.size(), 1, "and you keep the card")

func test_an_armed_final_blow_that_never_fired_stays_armed() -> void:
	var state := _game([[V(0, 7), ROOK, WHITE], [V(0, 5), PAWN, BLACK]], [["final_blow", true]], 5, 10)
	_move(state, V(0, 7), V(0, 5))                          # reaches the target on the first move
	check_eq(state.current_match.result, "win", "won early")
	Prophecies.finish_match(state.run, state.current_match)
	check(state.run.hand.size() == 1 and state.run.hand[0].armed, "the unused armed card carries on")

# ---- target and score -----------------------------------------------------------------------------

func test_prophecy_of_ruin_lowers_the_target_by_a_fifth() -> void:
	var state := _game([], ["prophecy_of_ruin"], 10, 100)
	check(_play(state).ok, "played")
	check_eq(state.current_match.target_score, 80, "100 -> 80")
	check(state.current_match.active and state.run.hand.is_empty(), "the match goes on and the card is used")

func test_prophecy_of_ruin_wins_at_once_if_you_are_already_past_the_new_target() -> void:
	var state := _game([], ["prophecy_of_ruin"], 10, 100)
	state.current_match.scores[WHITE] = 85
	_play(state)
	check_eq(state.current_match.result, "win", "85 >= 80")

func test_gilded_ledger_adds_fifteen_percent_of_the_target() -> void:
	var state := _game([], ["gilded_ledger"], 10, 200)
	check(_play(state).ok, "played")
	check_eq(_score(state), 30, "15% of 200")
	check(state.current_match.active, "not won yet")
	var almost := _game([], ["gilded_ledger"], 10, 200)
	almost.current_match.scores[WHITE] = 170
	_play(almost)
	check_eq(almost.current_match.result, "win", "170 + 30 reaches the target")

# ---- when a card can be played ----------------------------------------------------------------------

func test_a_match_card_is_refused_outside_a_match() -> void:
	var board := make_board(8, 8)
	var state := make_state(board, [[V(0, 0), KING, BLACK], [V(7, 7), KING, WHITE]])
	state.run = RunState.new()
	state.run.begin()
	state.run.hand.append({ "id": "rising_tide", "armed": false })
	var result := Prophecies.play_in_match(state, 0)
	check(not result.ok and result.reason.contains("during a match"), result.reason)
	check_eq(state.run.hand.size(), 1, "the card is kept")

func test_a_card_is_refused_on_the_ais_turn() -> void:
	var state := _game([], ["rising_tide"])
	state.current_match.turn_side = BLACK
	var result := _play(state)
	check(not result.ok and result.reason.contains("your turn"), result.reason)
	check_eq(state.run.hand.size(), 1, "kept")
	state.debug_mode = true
	check(_play(state).ok, "debug mode lets you play whenever")

func test_armed_and_shop_cards_cannot_be_played_in_a_match() -> void:
	var state := _game([], ["final_blow", "purse_of_gold", "frozen_moment"])
	for index in 3:
		var result := _play(state, index)
		check(not result.ok, "card %d is refused: %s" % [index, result.reason])
	check_eq(state.run.hand.size(), 3, "none were used")

func test_a_card_waits_while_a_promotion_or_bonus_move_is_pending() -> void:
	var state := _game([], ["rising_tide"])
	state.pending_promotion = { "piece": {}, "board": state.boards[0], "square": V(0, 0) }
	check(not _play(state).ok, "not during a promotion")
	state.pending_promotion = {}
	state.current_match.bonus = { "kind": "step", "side": WHITE, "label": "x" }
	check(not _play(state).ok, "not during a bonus move")
	state.current_match.bonus = {}
	check(_play(state).ok, "fine once it's clear")

func test_playing_a_card_is_free_and_shows_in_the_event_line() -> void:
	var state := _game([], ["rising_tide"], 10)
	_play(state)
	check_eq(state.current_match.moves_left, 10, "no move spent")
	check_eq(state.current_match.turn_side, WHITE, "still your turn")
	check(state.current_match.last_event.contains("Rising Tide"), state.current_match.last_event)

func test_every_built_match_card_is_playable() -> void:
	for id in ProphecyDefs.ready_ids().filter(func(c): return ProphecyDefs.timing(c) == "match"):
		var state := _game([[V(3, 4), KNIGHT, WHITE]], [id])
		var result := _play(state)
		check(result.ok, "%s can be played: %s" % [id, result.reason])
