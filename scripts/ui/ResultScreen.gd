class_name ResultScreen
extends Control

signal continue_pressed

@onready var panel: PanelContainer = $Center/Panel
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var reason_label: Label = $Center/Panel/Margin/VBox/Reason
@onready var details_label: Label = $Center/Panel/Margin/VBox/Details
@onready var wallet_label: Label = $Center/Panel/Margin/VBox/Wallet
@onready var continue_button: Button = $Center/Panel/Margin/VBox/Continue

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())
	continue_button.pressed.connect(_on_continue_pressed)

## `payout` is Payout.calculate's result for a win and {} for a loss.
## Its full-screen backdrop swallows clicks until the button is pressed.
func show_result(current: MatchState, payout: Dictionary, wallet: int) -> void:
	var won := current.result == "win"
	title_label.text = "VICTORY" if won else "DEFEAT"
	title_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55) if won else Color(0.95, 0.45, 0.45))
	reason_label.text = current.result_reason

	var lines := ["Score: %d / %d" % [current.scores[current.player_side], current.target_score]]
	if won:
		lines.append("Base reward: +%d" % payout.base)
		lines.append("Moves left (%d): +%d" % [payout.moves_left, payout.moves_bonus])
		lines.append("Interest (%d held): +%d" % [payout.held, payout.interest])
		lines.append("Total: +%d" % payout.total)
		wallet_label.text = "Gold: %d" % wallet
	else:
		lines.append("Your run is over.")
		wallet_label.text = "Gold lost: %d" % wallet
	details_label.text = "\n".join(lines)

	continue_button.text = "Continue" if won else "Restart Run"
	show()
	continue_button.grab_focus()

func _on_continue_pressed() -> void:
	hide()
	continue_pressed.emit()
