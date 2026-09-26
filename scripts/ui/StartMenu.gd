class_name StartMenu
extends Control

signal start_pressed

@onready var panel: PanelContainer = $Center/Panel
@onready var start_button: Button = $Center/Panel/Margin/VBox/StartButton

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())
	start_button.pressed.connect(func(): start_pressed.emit())
