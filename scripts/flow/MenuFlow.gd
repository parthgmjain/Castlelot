class_name MenuFlow
extends Node
## Owns the top-level screen (GameState.screen). Settings/Collections are
## still inert buttons on the Start Menu for now.

signal view_changed
signal quit_requested

var state: GameState

func start_pressed() -> void:
	state.screen = GameState.Screen.GAME
	view_changed.emit()

func quit_pressed() -> void:
	quit_requested.emit()
