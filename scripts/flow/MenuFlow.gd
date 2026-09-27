class_name MenuFlow
extends Node
## Owns the top-level screen (GameState.screen). Start leads to the Banner
## Select screen, not straight into the game - see Main._on_banner_chosen for
## where a run actually begins. Settings/Collections are still inert buttons
## on the Start Menu for now.

signal view_changed
signal quit_requested

var state: GameState

func start_pressed() -> void:
	state.screen = GameState.Screen.BANNER_SELECT
	view_changed.emit()

func quit_pressed() -> void:
	quit_requested.emit()
