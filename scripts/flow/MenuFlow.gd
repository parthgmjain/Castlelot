class_name MenuFlow
extends Node
## Owns the top-level screen (GameState.screen). Only Start is wired yet -
## Quit/Settings/Collections are inert buttons on the Start Menu for now.

signal view_changed

var state: GameState

func start_pressed() -> void:
	state.screen = GameState.Screen.GAME
	view_changed.emit()
