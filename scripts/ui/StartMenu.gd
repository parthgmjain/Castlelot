class_name StartMenu
extends Control

signal start_pressed
signal quit_pressed

@onready var panel: PanelContainer = $Center/Panel
@onready var start_button: Button = $Center/Panel/Margin/VBox/StartButton
@onready var quit_button: Button = $Center/Panel/Margin/VBox/QuitButton

func _ready() -> void:
	panel.add_theme_stylebox_override("panel", ModalStyle.panel())
	start_button.pressed.connect(func(): start_pressed.emit())
	quit_button.pressed.connect(func(): quit_pressed.emit())
