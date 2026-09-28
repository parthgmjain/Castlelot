extends "res://tests/TestCase.gd"
## The piece-value reference popup, opened from InfoSidebar's "Piece Values"
## button. See scripts/ui/PieceValuesPopup.gd.

func test_hidden_by_default() -> void:
	var main = await load_main()
	check(not main.piece_values_popup.visible, "closed until asked for")

func test_lists_every_non_king_piece_grouped_by_tier() -> void:
	var main = await load_main()
	var rows: Array = main.piece_values_popup.value_list.get_children()
	var everyone := Piece.types_in_tier(Piece.Tier.COMMON) + Piece.types_in_tier(Piece.Tier.UNCOMMON) \
		+ Piece.types_in_tier(Piece.Tier.RARE) + Piece.types_in_tier(Piece.Tier.LEGENDARY)
	check_eq(rows.size(), everyone.size() + 4, "one row per piece plus 4 tier headers")
	var text := rows.map(func(r): return r.text)
	check(text.has("Pawn - 1"), "pawn's value")
	check(text.has("Queen - 9"), "queen's value")
	check(not text.any(func(t): return t.begins_with("King")), "the king isn't a card, not listed")

func test_opens_via_open_and_closes_via_the_close_button() -> void:
	var main = await load_main()
	main.piece_values_popup.open()
	check(main.piece_values_popup.visible, "opened")
	main.piece_values_popup.close_button.pressed.emit()
	check(not main.piece_values_popup.visible, "closed again")
