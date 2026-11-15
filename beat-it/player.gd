extends CharacterBody2D
class_name Player


# Test-Spieler: freie Bewegung mit WASD/Pfeilen. Kamera folgt in level.gd.
# Hindernis-Trigger sind deaktiviert (setup() wird noch aufgerufen, aber nicht ausgewertet).

const SPEED := 200.0
const HALF_HEIGHT := 10.0

var _visual: Polygon2D


func _ready() -> void:
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-HALF_HEIGHT, -HALF_HEIGHT),
		Vector2(HALF_HEIGHT, -HALF_HEIGHT),
		Vector2(HALF_HEIGHT, HALF_HEIGHT),
		Vector2(-HALF_HEIGHT, HALF_HEIGHT),
	])
	_visual.color = Color(1.0, 0.4, 0.2) # orange
	add_child(_visual)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)


func _handle_movement(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * SPEED * delta
