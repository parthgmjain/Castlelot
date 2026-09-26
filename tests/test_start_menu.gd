extends "res://tests/TestCase.gd"
## The Start Menu screen and MenuFlow: Start and Quit are wired, Settings and
## Collections are not yet.

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

func test_settings_and_collections_do_nothing_yet() -> void:
	var main = await load_main_at_menu()
	main.start_menu.get_node("Center/Panel/Margin/VBox/SettingsButton").pressed.emit()
	main.start_menu.get_node("Center/Panel/Margin/VBox/CollectionsButton").pressed.emit()
	check_eq(main.state.screen, GameState.Screen.START_MENU, "still at the menu, nothing wired yet")

## Unit-level: MenuFlow.quit_pressed() asks to quit, without touching a real
## SceneTree (calling the real get_tree().quit() would kill the test runner).
## `requests` is an Array, not a bool, because GDScript lambdas capture local
## variables by value - a reassigned bool inside the lambda wouldn't be seen
## out here, but mutating a shared Array is.
func test_menu_flow_quit_pressed_emits_quit_requested() -> void:
	var flow: MenuFlow = track(MenuFlow.new())
	var requests := []
	flow.quit_requested.connect(func(): requests.append(true))
	flow.quit_pressed()
	check_eq(requests.size(), 1, "quit_pressed asks for a quit")

## The real button, through the real Main wiring, up to MenuFlow - but with
## Main's own get_tree().quit() handler swapped out first so the test runner
## survives the click.
func test_pressing_quit_on_the_menu_reaches_menu_flow() -> void:
	var main = await load_main_at_menu()
	main.menu_flow.quit_requested.disconnect(main._quit)
	var requests := []
	main.menu_flow.quit_requested.connect(func(): requests.append(true))
	main.start_menu.quit_button.pressed.emit()
	check_eq(requests.size(), 1, "the button's signal reached MenuFlow.quit_pressed")
