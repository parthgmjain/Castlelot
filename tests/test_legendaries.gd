extends "res://tests/TestCase.gd"
## Legendaries: two slots, one of each, never drawn. They come from beating a boss or from
## trading up 7 rares (the queen, or any legendary you have unlocked).

const DRAGON := Piece.Type.DRAGON
const HYDRA := Piece.Type.HYDRA
const LICH := Piece.Type.LICH

func _run() -> RunState:
	var run := RunState.new()
	run.begin()
	run.currency = 100
	return run

func _legendaries(run: RunState) -> Array:
	return run.held_types(Piece.Tier.LEGENDARY)

func _seven_rares(run: RunState) -> Array:
	var ids: Array = []
	for i in 7:
		ids.append(run.add_to_roster(ROOK))
	return ids

func test_you_start_with_no_legendaries_and_can_only_upgrade_into_the_queen() -> void:
	var run := _run()
	check(_legendaries(run).is_empty(), "none held")
	check_eq(Legendaries.available_upgrades(run), [QUEEN], "the queen is the default")

func test_beating_a_boss_unlocks_its_piece_for_upgrades() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	check(run.unlocked_legendaries.has(DRAGON), "unlocked")
	check_eq(Legendaries.available_upgrades(run), [QUEEN], "but you hold it, so it isn't on offer")
	run.remove_all_of_type(DRAGON)
	check_eq(Legendaries.available_upgrades(run), [QUEEN, DRAGON], "once you lose it you can upgrade back into it")

func test_a_legendary_takes_a_free_slot() -> void:
	var run := _run()
	check_eq(Legendaries.grant(run, DRAGON), "added", "first")
	check_eq(Legendaries.grant(run, HYDRA), "added", "second")
	check_eq(_legendaries(run).size(), 2, "both slots used")
	check(run.pending.is_empty(), "no decision needed")

func test_you_can_only_hold_one_of_each_legendary() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	check_eq(Legendaries.grant(run, DRAGON), "owned", "the second copy is refused")
	check_eq(run.count_of(DRAGON), 1, "still one")
	check_eq(_legendaries(run).size(), 1, "one slot")

func test_a_third_legendary_asks_which_of_the_three_to_give_up() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	Legendaries.grant(run, HYDRA)
	check_eq(Legendaries.grant(run, LICH), "choose", "the slots are full")
	check(run.pending.kind == "legendary_full" and run.pending.incoming == LICH, "waiting for your decision")
	check(run.unlocked_legendaries.has(LICH), "it is unlocked regardless")
	check_eq(run.count_of(LICH), 0, "but not yours yet")

func test_giving_up_one_of_your_two_legendaries_takes_the_new_one() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	Legendaries.grant(run, HYDRA)
	Legendaries.grant(run, LICH)
	var result := Legendaries.resolve_full(run, DRAGON)
	check(result.ok and result.kept_incoming, "the lich replaced the dragon")
	check_eq(_legendaries(run), [HYDRA, LICH], "hydra and lich")
	check(run.pending.is_empty(), "decided")
	check(run.unlocked_legendaries.has(DRAGON), "the dragon stays unlocked for later")

func test_giving_up_the_new_one_is_declining_it() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	Legendaries.grant(run, HYDRA)
	Legendaries.grant(run, LICH)
	var result := Legendaries.resolve_full(run, LICH)
	check(result.ok and not result.kept_incoming, "declined")
	check_eq(_legendaries(run), [DRAGON, HYDRA], "you keep what you had")
	check(run.pending.is_empty(), "decided")

func test_you_cannot_give_up_a_piece_you_do_not_hold() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	Legendaries.grant(run, HYDRA)
	Legendaries.grant(run, LICH)
	check(not Legendaries.resolve_full(run, Piece.Type.TITAN).ok, "refused")
	check_eq(run.pending.kind, "legendary_full", "still waiting")
	check(not Legendaries.resolve_full(_run(), DRAGON).ok, "and nothing to decide when nothing is pending")

# ---- upgrading -----------------------------------------------------------------------------------

func test_seven_rares_lead_to_a_choice_of_the_queen() -> void:
	var run := _run()
	var rares := _seven_rares(run)
	var result := Shop.trade_up(run, rares)
	check(result.ok and result.to == Piece.Tier.LEGENDARY, "traded")
	check(run.pending.kind == "legendary_pick" and run.pending.options == [QUEEN], "only the queen is on offer")
	check_eq(run.roster.filter(func(e): return e.type == ROOK).size(), 1, "the seven new rares are gone (the starting rook is left)")
	var picked := Legendaries.pick_upgrade(run, QUEEN)
	check(picked.ok and picked.status == "added", "the queen is yours")
	check_eq(_legendaries(run), [QUEEN], "in a legendary slot")
	check(run.pending.is_empty(), "decided")

func test_unlocked_legendaries_join_the_choice() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	run.remove_all_of_type(DRAGON)                 # the dragon was lost in a later match
	var result := Shop.trade_up(run, _seven_rares(run))
	check(result.ok, "traded")
	check_eq(run.pending.options, [QUEEN, DRAGON], "the queen and the unlocked dragon")
	check(Legendaries.pick_upgrade(run, DRAGON).ok, "you may pick the dragon")
	check_eq(_legendaries(run), [DRAGON], "it is yours again")

func test_you_can_only_pick_what_is_on_offer() -> void:
	var run := _run()
	Shop.trade_up(run, _seven_rares(run))
	check(not Legendaries.pick_upgrade(run, HYDRA).ok, "a legendary you haven't unlocked")
	check_eq(run.pending.kind, "legendary_pick", "the choice stays open")

func test_an_upgrade_with_both_slots_full_asks_what_to_give_up() -> void:
	var run := _run()
	Legendaries.grant(run, DRAGON)
	Legendaries.grant(run, HYDRA)
	Shop.trade_up(run, _seven_rares(run))
	var picked := Legendaries.pick_upgrade(run, QUEEN)
	check_eq(picked.status, "choose", "slots are full")
	check(run.pending.kind == "legendary_full" and run.pending.incoming == QUEEN, "asks which to give up")
	Legendaries.resolve_full(run, HYDRA)
	check_eq(_legendaries(run), [DRAGON, QUEEN], "the queen replaced the hydra")

func test_no_upgrade_when_you_already_hold_everything_available() -> void:
	var run := _run()
	Legendaries.grant(run, QUEEN)
	var rares := _seven_rares(run)
	var check := Shop.check_trade_up(run, rares)
	check(not check.ok, "nothing new to upgrade into")
	check_eq(check.reason, "You hold every legendary you have unlocked", "with a reason")
	var before := run.roster.size()
	check(not Shop.trade_up(run, rares).ok, "the trade is refused")
	check_eq(run.roster.size(), before, "and your rares are safe")
