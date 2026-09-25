extends "res://tests/TestCase.gd"
## What a won match pays: base + leftover moves + interest.

func _match(moves_left: int) -> MatchState:
	var m := MatchState.new()
	m.moves_left = moves_left
	return m

func test_payout_is_base_plus_leftover_moves_plus_interest() -> void:
	var payout := Payout.calculate(_match(7), 12)
	check_eq(payout.base, Payout.BASE, "base")
	check_eq(payout.moves_left, 7, "moves left")
	check_eq(payout.moves_bonus, 7 * Payout.PER_LEFTOVER_MOVE, "leftover-move bonus")
	check_eq(payout.interest, 12 / Payout.INTEREST_STEP, "interest on 12 held")
	check_eq(payout.total, payout.base + payout.moves_bonus + payout.interest, "total adds up")

func test_no_leftover_moves_and_no_savings_pays_just_the_base() -> void:
	var payout := Payout.calculate(_match(0), 0)
	check_eq(payout.total, Payout.BASE, "base only")
	check_eq(payout.interest, 0, "no interest")

func test_interest_steps_up_and_is_capped() -> void:
	check_eq(Payout.calculate(_match(0), Payout.INTEREST_STEP - 1).interest, 0, "just under a step")
	check_eq(Payout.calculate(_match(0), Payout.INTEREST_STEP).interest, 1, "one step")
	check_eq(Payout.calculate(_match(0), Payout.INTEREST_STEP * 3).interest, 3, "three steps")
	check_eq(Payout.calculate(_match(0), 100000).interest, Payout.INTEREST_CAP, "capped")

func test_faster_wins_pay_more() -> void:
	check(Payout.calculate(_match(9), 0).total > Payout.calculate(_match(2), 0).total, "more moves left, more gold")

func test_a_negative_move_count_never_pays_a_penalty() -> void:
	check_eq(Payout.calculate(_match(-3), 0).total, Payout.BASE, "clamped to zero")
