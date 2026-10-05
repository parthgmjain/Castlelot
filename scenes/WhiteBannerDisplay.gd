extends Control

@onready var border: TextureRect = $BannerContainer/Border
@onready var banner: AnimatedSprite2D = $BannerContainer/Banner

func _ready() -> void:
	_load_border()
	_load_banner()

func _load_border() -> void:
	var image := Image.new()
	if image.load("res://assets/banners/banner_border.png") == OK:
		border.texture = ImageTexture.create_from_image(image)

func _load_banner() -> void:
	var image := Image.new()
	if image.load("res://assets/banners/white_banner.png") != OK:
		return

	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 2)

	var frame_width = image.get_width() / 2
	var frame_height = image.get_height()

	for i in range(2):
		var atlas_rect := Rect2(i * frame_width, 0, frame_width, frame_height)
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = texture
		frame_texture.region = atlas_rect
		frames.add_frame("default", frame_texture)

	banner.sprite_frames = frames
	banner.scale = Vector2(6, 6)
	banner.play("default")
