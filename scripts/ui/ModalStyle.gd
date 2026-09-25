class_name ModalStyle
extends RefCounted

## The opaque, bordered panel look shared by the modal dialogs.
static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.16)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
