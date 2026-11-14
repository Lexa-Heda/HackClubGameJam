extends Node2D


# Baut ein Level: generiert Obstacles aus POIs und spawned sie als Sprite2D.
# WALLDASH -> wall.png (Wand von oben/unten)
# CHANGE_IN_HEIGHTS / REVERSE_GRAVITY / DROP_IN_HEIGHT -> floor.png (Bodenstück)

const WALL_TEXTURE := preload("res://wall.png")
const FLOOR_TEXTURE := preload("res://floor.png")

# Zielgrößen in Game-Units (y-Spielbereich ist -40..+40)
const WALL_TARGET_HEIGHT := 80.0 # Wand haengt von der Decke bis zur Ziel-Ebene
const FLOOR_TARGET_HEIGHT := 80.0
# floor.png: begehbare Oberflaeche liegt bei ~60% der Texturhoehe (schwarz oben, weiss unten)
const FLOOR_SURFACE_FRAC := 0.6

var gen := Generator.generator.new()
var _cam: Camera2D
var _player: Player


func _ready() -> void:
	_setup_camera()
	_spawn_start_element()
	var poi := _make_pois()
	var obstacles := gen.generate_level(poi)
	for i in obstacles.size():
		if i == 0:
			continue # erstes Obstacle ist das Start-Element (x=0)
		_spawn_obstacle(obstacles[i])
	_spawn_player(obstacles)


func _process(_delta: float) -> void:
	# Kamera folgt dem Spieler (x und y)
	if _cam and _player:
		_cam.position = _player.position


# Kamera auf Spielerhoehe (Daten-y = 0) zentrieren, Zoom passt sich dem Fenster an
func _setup_camera() -> void:
	_cam = Camera2D.new()
	_cam.position = Vector2(200.0, 0.0)
	var view_h := get_viewport().get_visible_rect().size.y
	var z := view_h / 220.0 # 220 Units Hoehe sichtbar
	_cam.zoom = Vector2(z, z)
	add_child(_cam)
	_cam.make_current()


func _spawn_player(obstacles: Array[Generator.ObstacleData]) -> void:
	_player = Player.new()
	_player.position = Vector2(0.0, -Player.HALF_HEIGHT) # Fuss auf y = 0
	_player.setup(obstacles)
	add_child(_player)


# Startplattform: Bodenstück, dessen Oberflaeche auf y = 0 liegt (Spieler-Start bei x = 0)
func _spawn_start_element() -> void:
	var sprite := _make_floor_sprite()
	sprite.position = Vector2(0.0, _floor_surface_offset(0.0))
	add_child(sprite)


# Screen-y der Sprite-Mitte, damit die Bodenoberflaeche auf surface_y (Daten-y) liegt.
# Daten-y groesser = hoeher -> Screen-y = -Daten-y
func _floor_surface_offset(surface_y: float) -> float:
	return -surface_y + FLOOR_TARGET_HEIGHT * (0.5 - FLOOR_SURFACE_FRAC)


func _make_pois() -> Array[Generator.Poi]:
	var poi: Array[Generator.Poi] = []
	var timestamps: Array[float] = [
		0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0,
		5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
	]
	for ts in timestamps:
		var p := Generator.Poi.new()
		p.timestamp = ts
		poi.append(p)
	return poi


func _spawn_obstacle(o: Generator.ObstacleData) -> void:
	var sprite: Sprite2D
	if o.element_name == "WALLDASH":
		sprite = _make_wall_sprite()
		# Wandhaengung: unteres Ende der Wand liegt auf der Ziel-Ebene o.y
		sprite.position = Vector2(o.x, _wall_bottom_offset(o.y))
	else:
		sprite = _make_floor_sprite()
		# Bodenoberflaeche liegt auf o.y
		sprite.position = Vector2(o.x, _floor_surface_offset(o.y))
	add_child(sprite)


# Screen-y der Sprite-Mitte, damit das untere Wand-Ende auf level_y (Daten-y) liegt
func _wall_bottom_offset(level_y: float) -> float:
	return -level_y - WALL_TARGET_HEIGHT / 2.0


func _make_wall_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = WALL_TEXTURE
	var s := WALL_TARGET_HEIGHT / float(WALL_TEXTURE.get_height())
	sprite.scale = Vector2(s, s)
	return sprite


func _make_floor_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = FLOOR_TEXTURE
	var s := FLOOR_TARGET_HEIGHT / float(FLOOR_TEXTURE.get_height())
	sprite.scale = Vector2(s, s)
	return sprite
