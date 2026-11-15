extends CharacterBody2D
class_name Player


# Visueller Avatar: Animations-Sprites (run/jump/fall). Die Bewegung wird von
# level.gd (Autoplay) gesteuert; hier nur Darstellung + set_state().

const HALF_HEIGHT := 10.0

const ANIM_SCALE := 0.22
const ANIM_OFFSET := Vector2(0.0, -69.0) # wird mit ANIM_SCALE skaliert (~-20px effektiv)
const RUN_FPS := 24.0
const JUMP_FPS := 24.0
const FALL_FPS := 16.0

const RUN_FILES := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "11", "12", "15"]
const SHEET_CELL := 300.0

var _anim: AnimatedSprite2D
var _state := ""


func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _build_frames()
	_anim.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
	_anim.offset = ANIM_OFFSET
	_anim.animation = "run"
	_anim.play("run")
	add_child(_anim)


func set_state(state: String, flip: bool) -> void:
	if state != _state:
		_state = state
		_anim.play(state)
	_anim.scale = Vector2(-ANIM_SCALE if flip else ANIM_SCALE, ANIM_SCALE)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	sf.add_animation("run")
	sf.set_animation_speed("run", RUN_FPS)
	sf.set_animation_loop("run", true)
	for f in RUN_FILES:
		sf.add_frame("run", load("res://assets/run-pngs/%s.png" % f))

	sf.add_animation("jump")
	sf.set_animation_speed("jump", JUMP_FPS)
	sf.set_animation_loop("jump", true)
	var jump_tex: Texture2D = load("res://assets/jump/Jump.png")
	for row in 3:
		for col in 8:
			sf.add_frame("jump", _atlas(jump_tex, col, row))

	sf.add_animation("fall")
	sf.set_animation_speed("fall", FALL_FPS)
	sf.set_animation_loop("fall", true)
	var fall_tex: Texture2D = load("res://assets/fall/Fall.png")
	for col in 4:
		sf.add_frame("fall", _atlas(fall_tex, col, 0))

	return sf


func _atlas(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * SHEET_CELL, row * SHEET_CELL, SHEET_CELL, SHEET_CELL)
	return at
