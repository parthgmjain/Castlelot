extends "res://tests/TestCase.gd"
## Tooltips on pieces (before they're on the board) and prophecies, so players know what
## something does before committing to it.

func V(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

# ---- the description data itself ------------------------------------------------------------

func test_every_piece_has_a_non_empty_description() -> void:
	for type in [KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN]:
		check(Piece.description(type).length() > 5, "%s has a description" % Piece.display_name(type))
	for type in PieceDefs.types():
		check(PieceDefs.description(type).length() > 5, "%s has a description" % Piece.display_name(type))
		check_eq(Piece.description(type), PieceDefs.description(type), "Piece.description defers to PieceDefs for extras")

func test_descriptions_are_reasonably_unique() -> void:
	var seen := {}
	for type in PieceDefs.types() + [KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN]:
		var text := Piece.description(type)
		check(not seen.has(text), "%s shares a description with %s" % [Piece.display_name(type), seen.get(text, "")])
		seen[text] = Piece.display_name(type)

func test_an_unknown_type_gets_no_description_rather_than_crashing() -> void:
	check_eq(Piece.description(9999 as Piece.Type), "", "no crash, just empty")

# ---- the sandbox picker ------------------------------------------------------------------------

func test_the_fixed_chess_buttons_have_tooltips() -> void:
	var main = await load_main()
	for pair in [[main.panel.king_button, KING], [main.panel.queen_button, QUEEN], [main.panel.rook_button, ROOK],
			[main.panel.bishop_button, BISHOP], [main.panel.knight_button, KNIGHT], [main.panel.pawn_button, PAWN]]:
		check_eq(pair[0].tooltip_text, Piece.description(pair[1]), "%s's tooltip" % Piece.display_name(pair[1]))

func test_the_more_pieces_dropdown_has_a_tooltip_per_item() -> void:
	var main = await load_main()
	var picker: OptionButton = main.panel.extra_piece_picker
	for index in range(1, picker.item_count):
		var type: Piece.Type = picker.get_item_metadata(index)
		check_eq(picker.get_popup().get_item_tooltip(index), PieceDefs.description(type), "%s's tooltip" % Piece.display_name(type))

# ---- the bench --------------------------------------------------------------------------------

func test_bench_buttons_show_what_the_piece_does() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	var bench: Array = main.panel.bench_box.get_children()
	check(not bench.is_empty(), "something is on the bench")
	for button in bench:
		var matching: Array = main.state.run.roster.filter(func(e): return "%s %s" % [Piece.symbol(e.type, WHITE), Piece.Type.find_key(e.type).capitalize()] == button.text)
		check(not matching.is_empty(), "found the roster entry for %s" % button.text)
		if not matching.is_empty():
			check_eq(button.tooltip_text, Piece.description(matching[0].type), "tooltip for %s" % button.text)

# ---- the promotion picker -----------------------------------------------------------------------

# Puts a lone pawn in white's zone and clicks it along its route until it reaches the enemy
# zone and the promotion picker opens (mirrors tests/test_promotion.gd's _march helper).
func _march_to_promotion(main: Node) -> void:
	var state: GameState = main.state
	for board in state.boards:
		board.pieces.clear()
	var start_board: Board = null
	var square := V(-1, -1)
	for board in state.boards:
		for sq in board.zone_owner:
			if board.zone_owner[sq] == WHITE and start_board == null:
				start_board = board
				square = sq
	put(start_board, square, PAWN, WHITE)
	var board := start_board
	for step in 80:
		main._on_square_selected(square, board)
		var next = null
		for m in state.current_moves:
			if not m.capture:
				next = m
				break
		if next == null:
			return
		main._on_square_selected(next.square, next.board)
		board = next.board
		square = next.square
		if not state.pending_promotion.is_empty():
			return

func test_promotion_picker_buttons_have_tooltips() -> void:
	var main = await load_main()
	await new_world(main)
	_march_to_promotion(main)
	check(main.promotion_picker.visible, "opened")
	for type in PawnMovement.PROMOTION_CHOICES:
		check_eq(main.promotion_picker._buttons[type].tooltip_text, Piece.description(type), "%s's tooltip" % Piece.display_name(type))

# ---- the shop ---------------------------------------------------------------------------------

func _to_shop(main: Node, gold: int = 100) -> ShopScreen:
	main.panel.start_run_button.pressed.emit()
	main.panel.auto_deploy_button.pressed.emit()
	main.panel.ready_button.pressed.emit()
	var current: MatchState = main.state.current_match
	current.active = false
	current.result = "win"
	current.result_reason = "Test"
	current.moves_left = 6
	main._refresh_view()
	main.result_screen.continue_button.pressed.emit()
	main.state.run.currency = gold
	main.shop_screen.refresh()
	return main.shop_screen

func test_the_shops_roster_buttons_have_tooltips() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var found := false
	for row in shop.roster_box.get_children():
		for child in row.get_children():
			if child is Button:
				found = true
				var matching: Array = main.state.run.roster.filter(func(e): return Piece.display_name(e.type) in child.text)
				check(not matching.is_empty(), "matched a roster entry for %s" % child.text)
				if not matching.is_empty():
					check_eq(child.tooltip_text, Piece.description(matching[0].type), "tooltip for %s" % child.text)
	check(found, "there was at least one piece button to check")

func test_lottery_card_buttons_have_tooltips() -> void:
	var main = await load_main()
	var shop := _to_shop(main, 50)
	shop.pull_button.pressed.emit()
	var buttons: Array = shop.choice_row.get_children().filter(func(c): return c is Button)
	check(not buttons.is_empty(), "cards are shown")
	for i in buttons.size():
		var type: Piece.Type = main.state.run.pending.cards[i].type
		check_eq(buttons[i].tooltip_text, Piece.description(type), "card %d's tooltip" % i)

func test_trade_up_reward_cards_have_tooltips() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	var run: RunState = main.state.run
	for i in 6:
		run.add_to_roster(ROOK)
	shop.refresh()
	var rare_row := shop.roster_box.get_child(2).get_children().filter(func(c): return c is Button)
	for b in rare_row:
		b.button_pressed = true
		b.pressed.emit()
	shop.trade_up_button.pressed.emit()
	var buttons: Array = shop.choice_row.get_children().filter(func(c): return c is Button)
	check(not buttons.is_empty(), "a legendary choice is offered")
	for b in buttons:
		check(not b.tooltip_text.is_empty(), "%s has a tooltip" % b.text)

# ---- prophecies through the strip and shop -------------------------------------------------------

func test_hand_row_title_has_a_tooltip_matching_its_description() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "rising_tide", "armed": false })
	main._refresh_view()
	var title: Label = main.prophecy_strip.get_child(0).get_child(1).get_child(0).get_child(0)
	check_eq(title.tooltip_text, ProphecyDefs.text("rising_tide"), "the strip's card title has a tooltip")

func test_shop_prophecy_offers_have_tooltips() -> void:
	var main = await load_main()
	var shop := _to_shop(main)
	shop._run.prophecy_offers = ["rising_tide", "final_blow", "purse_of_gold", "sanctuary"]
	shop.refresh()
	var offers := shop.cards_row.get_child(0).get_child(1).get_children()
	for i in offers.size():
		var id: String = shop._run.prophecy_offers[i]
		check(offers[i].tooltip_text.contains(ProphecyDefs.text(id)), "%s: %s" % [id, offers[i].tooltip_text])

func test_debug_prophecy_picker_has_a_tooltip_per_item() -> void:
	var main = await load_main()
	var picker: OptionButton = main.panel.debug_prophecy_picker
	for index in range(1, picker.item_count):
		var id: String = picker.get_item_metadata(index)
		check_eq(picker.get_popup().get_item_tooltip(index), ProphecyDefs.text(id), "%s's tooltip" % id)

# ---- a prophecy's own piece-choice buttons show what the piece does -------------------------------

func test_sanctuary_choice_buttons_are_tooltipped_with_the_piece() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "sanctuary", "armed": false })
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	put(board, V(3, 4), Piece.Type.GHOST, WHITE)
	main.panel.ready_button.pressed.emit()
	main._refresh_view()
	main.prophecy_flow.play(0)
	var buttons: Array = main.prophecy_strip._choice_row.get_children().filter(func(c): return c is Button)
	check(not buttons.is_empty(), "a piece choice is offered")
	check(buttons[0].tooltip_text.contains("passing through"), "the ghost's tooltip: %s" % buttons[0].tooltip_text)

func test_transmutation_second_step_options_are_tooltipped() -> void:
	var main = await load_main()
	main.panel.start_run_button.pressed.emit()
	main.state.run.hand.append({ "id": "transmutation", "armed": false })
	var board: Board = main.state.boards[0]
	for b in main.state.boards:
		b.set_portals({})
	board.pieces.clear()
	put(board, V(0, 0), KING, BLACK)
	put(board, V(7, 7), KING, WHITE)
	put(board, V(3, 4), KNIGHT, WHITE)
	main.panel.ready_button.pressed.emit()
	main._refresh_view()
	main.prophecy_flow.play(0)
	main.prophecy_strip._choice_row.get_children().filter(func(c): return c is Button)[0].pressed.emit()
	var buttons: Array = main.prophecy_strip._choice_row.get_children().filter(func(c): return c is Button)
	check(not buttons.is_empty(), "a piece type is offered")
	for b in buttons:
		check(not b.tooltip_text.is_empty(), "%s has a tooltip" % b.text)
