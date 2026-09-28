class_name BossBanner
extends Control
## Top-of-screen "enemy" banner: shown throughout an active run, not just
## boss matches - named for the actual boss on a boss match, a generic
## fallback the rest of the time (2 of every 3 matches have no boss, just an
## ordinary AI army with no character). `Art` is an empty TextureRect: a
## reserved slot for the enemy's portrait, not drawn here.

const NO_BOSS_LABEL := "Enemy"

@onready var art: TextureRect = $Art
@onready var name_label: Label = $NameLabel

## Relabels itself for the run's current match; hidden only outside a run.
func update(run: RunState) -> void:
	visible = run.active
	if not visible:
		return
	name_label.text = run.boss_name() if run.is_boss() else NO_BOSS_LABEL
