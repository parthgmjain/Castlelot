extends "res://tests/TestCase.gd"
## The Start Menu screen and MenuFlow: only Start is wired so far.

## Loads the real Main scene WITHOUT pressing Start, unlike load_main().
func load_main_at_menu() -> Node:
	var main = MainScene.instantiate()
	tree.root.add_child(main)
	track(main)
	await pump(2)
	return main

func test_a_fresh_game_opens_on_the_start_menu() -> void:
	var main = await load_main_at_menu()
	check_eq(main.state.screen, GameState.Screen.START_MENU, "starts at the menu")
	check(main.start_menu.visible, "start menu shown")
	check(not main.panel.visible, "game panel hidden")
	check(not main.boards_container.visible, "boards hidden")

func test_pressing_start_switches_to_the_game() -> void:
	var main = await load_main_at_menu()
	main.start_menu.start_button.pressed.emit()
	check_eq(main.state.screen, GameState.Screen.GAME, "moved to the game screen")
	check(not main.start_menu.visible, "start menu hidden")
	check(main.panel.visible, "game panel shown")
	check(main.boards_container.visible, "boards shown")

func test_a_real_mouse_click_on_start_enters_the_game() -> void:
	var main = await load_main_at_menu()
	await click_control(main.start_menu.start_button)
	check_eq(main.state.screen, GameState.Screen.GAME, "click reached the button")

func test_quit_settings_and_collections_do_nothing_yet() -> void:
	var main = await load_main_at_menu()
	main.start_menu.get_node("Center/Panel/Margin/VBox/QuitButton").pressed.emit()
	main.start_menu.get_node("Center/Panel/Margin/VBox/SettingsButton").pressed.emit()
	main.start_menu.get_node("Center/Panel/Margin/VBox/CollectionsButton").pressed.emit()
	check_eq(main.state.screen, GameState.Screen.START_MENU, "still at the menu, nothing wired yet")
