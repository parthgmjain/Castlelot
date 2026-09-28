class_name BossBanner
extends Control
## Top-of-screen banner shown only during a boss match (2 of every 3 matches
## have no boss - an ordinary AI army, no character - so this stays hidden
## then). `Art` is an empty TextureRect: a reserved slot for the boss's
## portrait, not drawn here.

@onready var art: TextureRect = $Art
@onready var name_label: Label = $NameLabel

## Shows/hides and relabels itself for the run's current match.
func update(run: RunState) -> void:
	visible = run.active and run.is_boss()
	if visible:
		name_label.text = run.boss_name()
