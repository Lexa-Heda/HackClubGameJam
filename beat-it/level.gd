extends Node2D

const START_POS := Vector2(0.0, 600.0)

const GRAVITY := 1800.0
const RUN_SPEED := 200.0
const MIN_RUN_SPEED := RUN_SPEED * 0.85
const JUMP_VELOCITY := -400.0
const WALL_JUMP_VELOCITY := -720.0
const BODY_HALF := Vector2(12.0, Player.HALF_HEIGHT)
const SOLID_MIN_ALPHA := 0.05

const COYOTE_TIME := 0.3
const WALL_COYOTE := 0.15

const PASS_DISTANCE := 80.0
const PENALTY := -50

const FLASH_FADE := 0.8
const BASE_ZOOM := 3.0
const PUNCH_DUR := 0.5
const PUNCH_AMP := 0.12

var _music: AudioStreamPlayer
var _player: Player
var _camera: Camera2D
var _generator := LevelGenerator.new()
var _elements: Array[LevelElement] = []

var _time := 0.0
var _pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _dir := 1.0
var _on_floor := false
var _touch_wall := false
var _kicked := false
var _coyote := 0.0
var _wall_coyote := 0.0

var _floors: Array[Rect2] = []
var _walls: Array[Rect2] = []
var _solids: Array[Rect2] = []

# Fahrplan: Hindernisse in zeitlicher Reihenfolge
var _obstacles: Array[LevelElement] = []
var _obs_i := 0
var _end_x := 0.0

# HUD
var _score := 0
var _score_label: Label
var _rating_label: Label
var _flash: ColorRect
var _flash_color := Color.WHITE
var _flash_a := 0.0

# Screen-Punch
var _poi_times: Array[float] = []
var _prev_time := 0.0
var _punch_t := -1.0


func _ready() -> void:
	_music = get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	_generate()
	_spawn_player()
	_setup_camera()
	_setup_hud()


# ---------- Level-Erzeugung ----------

func _generate() -> void:
	var pois: Array[LevelGenerator.Poi] = []
	var selected_timestamps: Array = []

	match Runtime.selected_level:
		1:
			_play_music("res://1.mp3")
			selected_timestamps = [
				1.451, 9.569, 17.642, 26.032, 34.422, 37.234, 38.685, 40.998,
				47.302, 51.202, 59.32, 65.805, 75.977, 84.412
			]
		2:
			_play_music("res://2.ogg")
			selected_timestamps = [
				2.250, 2.625, 4.250, 4.625, 6.250, 8.625, 10.250, 12.625, 13.500,
				14.250, 17.500, 18.250, 20.625, 22.250, 26.250, 28.625, 30.250,
				34.000, 34.500, 35.000, 35.500, 38.000, 38.250, 38.750, 39.250,
				39.500, 46.000, 46.250, 46.750, 47.250, 47.500, 52.000, 52.471,
				52.943, 54.250, 56.625, 57.500, 58.250, 62.250, 64.625, 66.250,
				70.250, 72.625, 74.250, 77.500, 78.000, 78.500, 79.000, 79.500,
				82.000, 82.250, 82.750, 83.250, 83.500, 90.000, 90.250, 90.750,
				91.250, 91.500, 96.000, 96.471, 96.943, 98.000, 98.500, 99.000,
				99.500, 100.000, 100.500, 101.000, 101.500, 102.000, 102.500,
				103.000, 103.500, 104.000, 104.500, 105.000, 105.500, 106.000,
				106.500, 107.000, 107.500, 108.000, 108.500, 109.000, 109.500,
				110.000, 110.500, 111.000, 111.500, 112.000, 112.500, 113.000,
				113.500, 130.000, 130.500, 134.000, 134.250, 134.750, 135.250,
				135.500, 142.000, 142.250, 142.750, 143.250, 143.500, 150.000,
				150.250, 150.750, 151.250, 151.500, 158.000, 158.250, 158.750,
				159.250, 159.500, 164.000, 165.000, 166.000, 167.000, 168.000,
				169.000, 172.000, 173.000, 174.000, 175.000, 176.000, 177.000,
				180.000, 180.471, 180.943, 181.500
			]
		3:
			_play_music("res://3.ogg")
			selected_timestamps = [
				7.229, 7.590, 8.133, 10.482, 11.024, 11.928, 12.470, 13.373,
				13.916, 16.265, 16.807, 17.711, 18.253, 20.241, 20.602, 23.133,
				23.494, 26.024, 26.386, 26.747, 27.108, 35.783, 41.566, 46.265,
				50.602, 50.964, 51.325, 51.687, 53.494, 53.855, 54.217, 54.578,
				54.940, 55.301, 55.663, 56.024, 56.386, 56.747, 57.108, 57.470,
				59.277, 59.639, 60.000, 60.361, 60.723, 61.084, 61.446, 61.807,
				63.614, 63.976, 66.506, 66.867, 69.398, 69.759, 70.120, 70.482,
				79.157, 84.940, 89.639, 94.880, 97.590, 99.036, 100.663, 103.373,
				105.542, 106.988, 107.349, 109.880, 110.241, 112.771, 113.133,
				113.494, 113.855, 122.530, 128.313, 133.012, 145.663, 151.446,
				160.120, 165.904, 171.687, 177.470
			]

	_poi_times.clear()
	for t: float in selected_timestamps:
		pois.append(LevelGenerator.Poi.new(t))
		_poi_times.append(t)

	_generator.seed_value = 1234
	_elements = _generator.generate(pois, START_POS)

	_obstacles.clear()
	for e in _elements:
		if e.type == LevelElement.Type.WALLJUMP \
				or e.type == LevelElement.Type.GAP \
				or e.type == LevelElement.Type.DROPDOWN:
			_obstacles.append(e)
	_obs_i = 0
	_end_x = 0.0
	for e in _elements:
		_end_x = maxf(_end_x, e.end_pos.x)
	_end_x += 150.0


func _play_music(path: String) -> void:
	if _music and ResourceLoader.exists(path):
		_music.stream = load(path)
		_music.play()


func _finish_level() -> void:
	Runtime.last_score = _score
	get_tree().change_scene_to_file("res://homescreen.tscn")


# ---------- Setup ----------

func _spawn_player() -> void:
	_player = Player.new()
	add_child(_player)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_reset()


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	add_child(_camera)
	_camera.global_position = _player.global_position
	_camera.make_current()


func _reset() -> void:
	_time = 0.0
	_pos = START_POS + Vector2(BODY_HALF.x, -BODY_HALF.y - 1.0)
	_vel = Vector2.ZERO
	_dir = 1.0
	_on_floor = false
	_touch_wall = false
	_kicked = false
	_coyote = 0.0
	_wall_coyote = 0.0
	_prev_time = 0.0
	_punch_t = -1.0
	_obs_i = 0
	_score = 0
	for e in _elements:
		e.reset_prompts()
	if _player:
		_player.global_position = _pos
	if _camera:
		_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	if _score_label:
		_update_score_label()
	if _music and _music.stream:
		_music.play()


# ---------- Frame-Schleifen ----------

func _process(delta: float) -> void:
	_camera.global_position = _player.global_position

	if _punch_t >= 0.0:
		_punch_t += delta
		var p := _punch_t / PUNCH_DUR
		if p >= 1.0:
			_punch_t = -1.0
			_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
		else:
			var s := sin(p * PI * 4.0) * exp(-4.0 * p) * PUNCH_AMP
			_camera.zoom = Vector2(BASE_ZOOM * (1.0 + s), BASE_ZOOM * (1.0 + s))

	if _flash and _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - FLASH_FADE * delta)
		_flash.color = _flash_color
		_flash.modulate.a = _flash_a

	queue_redraw()


func _draw() -> void:
	for e in _elements:
		e.draw(self, e.alpha_at(_time), _time)


func _physics_process(delta: float) -> void:
	_time += delta

	for t in _poi_times:
		if t > _prev_time and t <= _time:
			_punch_t = 0.0
			break
	_prev_time = _time

	_collect_solids()
	_control()
	_move(delta)

	if _on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if _touch_wall:
		_wall_coyote = WALL_COYOTE
	else:
		_wall_coyote = maxf(0.0, _wall_coyote - delta)

	_player.global_position = _pos
	_update_anim()

	if _pos.y > 1600.0:
		_reset()
		return

	if _pos.x > _end_x:
		_finish_level()
		return

	_check_missed()


func _update_anim() -> void:
	var state := "fall"
	if _on_floor:
		state = "run"
	elif _vel.y < 0.0:
		state = "jump"
	_player.set_state(state, _dir < 0.0)


# ---------- Physik ----------

func _body() -> Rect2:
	return Rect2(_pos - BODY_HALF, BODY_HALF * 2.0).grow(-0.01)


func _collect_solids() -> void:
	_floors.clear()
	_walls.clear()
	_solids.clear()
	for e in _elements:
		if e.alpha_at(_time) <= SOLID_MIN_ALPHA:
			continue
		_floors.append_array(e.floors)
		_walls.append_array(e.walls)
	_solids.append_array(_floors)
	_solids.append_array(_walls)


func _move(delta: float) -> void:
	_vel.y += GRAVITY * delta
	_touch_wall = false

	_pos.x += _vel.x * delta
	for r in _solids:
		if _body().intersects(r):
			if _vel.x > 0.0:
				_pos.x = r.position.x - BODY_HALF.x
			elif _vel.x < 0.0:
				_pos.x = r.end.x + BODY_HALF.x
			_vel.x = 0.0
			_touch_wall = true

	_pos.y += _vel.y * delta
	_on_floor = false
	for r in _solids:
		if _body().intersects(r):
			if _vel.y > 0.0:
				_pos.y = r.position.y - BODY_HALF.y
				_on_floor = true
			elif _vel.y < 0.0:
				_pos.y = r.end.y + BODY_HALF.y
			_vel.y = 0.0


# ---------- Autoplay-Bot ----------

# Laufgeschwindigkeit so, dass der Spieler zum poi_time an der Kante ist.
# Nie langsamer als MIN_RUN_SPEED, damit nach Landungen kein Schwung fehlt.
func _scheduled_speed() -> float:
	while _obs_i < _obstacles.size():
		var o := _obstacles[_obs_i]
		var tx := o.start_pos.x - float(o.corner) * BODY_HALF.x
		if (_pos.x - tx) * float(o.corner) > 0.0:
			_obs_i += 1
		else:
			break
	if _obs_i >= _obstacles.size():
		return RUN_SPEED

	var o2 := _obstacles[_obs_i]
	var target_x := o2.start_pos.x - float(o2.corner) * BODY_HALF.x
	var dist := (target_x - _pos.x) * _dir
	var remaining := o2.poi_time - _time
	if dist <= 1.0:
		return RUN_SPEED
	if remaining < 0.05:
		return 500.0
	return clampf(dist / remaining, MIN_RUN_SPEED, 500.0)


func _control() -> void:
	var feet := _pos.y + BODY_HALF.y
	var grounded := _on_floor or _coyote > 0.0

	if grounded:
		if _on_floor:
			_kicked = false
			_vel.x = _dir * maxf(_scheduled_speed(), MIN_RUN_SPEED)

		var probe := Vector2(_pos.x + _dir * (BODY_HALF.x + 1.0), feet + 4.0)
		if _solid_at(probe):
			return
		if _wall_ahead(feet) is Rect2:
			_do_jump(true)
		elif _landing_floor(feet) is Rect2 and not _ceiling_above():
			_do_jump(true)
		return

	if _wall_coyote > 0.0 and not _kicked:
		_do_jump(false)


func _do_jump(on_floor: bool) -> void:
	var feet := _pos.y + BODY_HALF.y

	if on_floor:
		_coyote = 0.0  # verhindert Mehrfachsprünge
		if _wall_ahead(feet) is Rect2:
			_vel.y = JUMP_VELOCITY
			return
		var land = _landing_floor(feet)
		if land is Rect2:
			# Flugzeit aus Höhendifferenz (Dropdowns liegen ~200px tiefer)
			var dy: float = land.position.y - feet
			var t: float = (-JUMP_VELOCITY + sqrt(JUMP_VELOCITY * JUMP_VELOCITY + 2.0 * GRAVITY * dy)) / GRAVITY
			var target_x: float = land.get_center().x
			_vel.x = clampf((target_x - _pos.x) / t, -2.0 * RUN_SPEED, 2.0 * RUN_SPEED)
		_vel.y = JUMP_VELOCITY
	elif _wall_coyote > 0.0 and not _kicked:
		_wall_kick()


func _wall_kick() -> void:
	var feet := _pos.y + BODY_HALF.y
	var old := _dir
	var vx := -old * RUN_SPEED * 1.5
	var target = _upper_floor(feet, old)
	if target is Rect2:
		var near_x: float = target.end.x if old > 0.0 else target.position.x
		var tx: float = near_x - old * minf(24.0, target.size.x * 0.5)
		var disc: float = WALL_JUMP_VELOCITY * WALL_JUMP_VELOCITY \
			- 2.0 * GRAVITY * (feet - target.position.y)
		if disc > 0.0:
			var t := (-WALL_JUMP_VELOCITY + sqrt(disc)) / GRAVITY
			vx = clampf((tx - _pos.x) / t, -400.0, 400.0)
	_vel = Vector2(vx, WALL_JUMP_VELOCITY)
	_dir = -old
	_kicked = true
	_wall_coyote = 0.0
	_coyote = 0.0


func _solid_at(p: Vector2) -> bool:
	for r in _solids:
		if r.has_point(p):
			return true
	return false


func _ceiling_above() -> bool:
	var head := _pos.y - BODY_HALF.y
	for r in _floors:
		if r.end.y >= head - 2.0 or r.position.y <= head - 90.0:
			continue
		if r.position.x < _pos.x + BODY_HALF.x and r.end.x > _pos.x - BODY_HALF.x:
			return true
	return false


func _wall_ahead(feet: float):
	for r in _walls:
		var covers := r.position.y < feet - 30.0 and r.end.y > feet - 30.0
		var dx := r.get_center().x - _pos.x
		if covers and dx * _dir > 0.0 and absf(dx) < 120.0:
			return r
	return null


func _landing_floor(feet: float):
	var cur = null
	for r in _floors:
		if absf(r.position.y - feet) < 1.5 \
				and r.position.x < _pos.x + BODY_HALF.x \
				and r.end.x > _pos.x - BODY_HALF.x:
			cur = r
			break

	for allow_contiguous in [false, true]:
		var best = null
		var best_d := INF
		for r in _floors:
			if r == cur:
				continue
			if not allow_contiguous and cur is Rect2 \
					and absf(r.position.y - feet) < 1.5 \
					and (absf(r.position.x - cur.end.x) < 2.0 \
						or absf(r.end.x - cur.position.x) < 2.0):
				continue
			var dx := r.get_center().x - _pos.x
			var dy := r.position.y - feet
			var same_level := absf(dy) < 1.5
			var below := dy > 1.5 and dy < 230.0  # Dropdown-Landeplatte
			if (same_level or below) and dx * _dir > 0.0 and absf(dx) < 250.0:
				if absf(dx) < best_d:
					best_d = absf(dx)
					best = r
		if best != null:
			return best
	return null


func _upper_floor(feet: float, old_dir: float):
	var best = null
	var best_d := INF
	for r in _floors:
		var dx := r.get_center().x - _pos.x
		var above := r.position.y < feet - 10.0 and r.position.y > feet - 200.0
		if above and dx * -old_dir > 0.0 and absf(dx) < 400.0:
			if absf(dx) < best_d:
				best_d = absf(dx)
				best = r
	return best


# ---------- Eingabe & Wertung ----------

func _unhandled_input(event: InputEvent) -> void:
	# Bot steuert die Bewegung; Space wird nur auf Timing geprüft.
	if event.is_action_pressed("jump"):
		_press_space()


func _press_space() -> void:
	var best_e: LevelElement = null
	var best_i := -1
	var best_dx := INF

	for e in _elements:
		if e.alpha_at(_time) <= SOLID_MIN_ALPHA:
			continue
		for i in e.prompts.size():
			if e.prompt_done[i] or e.prompt_missed[i]:
				continue
			var p: Vector2 = e.prompts[i]
			var dx := absf(_pos.x - p.x)
			if dx < best_dx and absf(_pos.y - p.y) < 160.0:
				best_dx = dx
				best_e = e
				best_i = i

	if best_e == null or best_dx > 80.0:
		if best_e != null:
			best_e.prompt_texts[best_i] = "WRONG"
		_add_score(PENALTY)
		_show_rating("WRONG %d" % PENALTY, false)
		_flash_screen(Color("#ff3b4e"))
		return

	best_e.prompt_done[best_i] = true

	# Dichte Beat-Cluster: ein Druck wertet alle Prompts im Nahbereich.
	for e2 in _elements:
		if e2.alpha_at(_time) <= SOLID_MIN_ALPHA:
			continue
		for j in e2.prompts.size():
			if e2.prompt_done[j] or e2.prompt_missed[j]:
				continue
			var p2: Vector2 = e2.prompts[j]
			if absf(_pos.x - p2.x) <= 40.0 and absf(_pos.y - p2.y) < 160.0:
				e2.prompt_done[j] = true

	var pts := 25
	var rating := "OK"
	if best_dx <= 16.0:
		pts = 100
		rating = "PERFECT"
	elif best_dx <= 40.0:
		pts = 50
		rating = "GOOD"
	best_e.prompt_texts[best_i] = rating

	_add_score(pts)
	_show_rating("%s +%d" % [rating, pts])
	_flash_screen(Color("#3ddc78"))


func _check_missed() -> void:
	for e in _elements:
		if _time < e.poi_time - 2.0 or e.alpha_at(_time) <= SOLID_MIN_ALPHA:
			continue
		for i in e.prompts.size():
			if e.prompt_done[i] or e.prompt_missed[i]:
				continue
			var p: Vector2 = e.prompts[i]
			var passed := (_pos.x - p.x) * _dir > PASS_DISTANCE \
				and absf(_pos.y - p.y) < 120.0
			if passed:
				e.prompt_missed[i] = true
				_add_score(PENALTY)
				_show_rating("MISS %d" % PENALTY, false)
				_flash_screen(Color("#ff3b4e"))


# ---------- HUD ----------

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_score_label = Label.new()
	_score_label.position = Vector2(24.0, 16.0)
	_score_label.add_theme_font_size_override("font_size", 32)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_score_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_score_label)

	_rating_label = Label.new()
	_rating_label.position = Vector2(24.0, 64.0)
	_rating_label.add_theme_font_size_override("font_size", 24)
	_rating_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_rating_label.add_theme_constant_override("outline_size", 5)
	_rating_label.modulate.a = 0.0
	layer.add_child(_rating_label)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	_update_score_label()


func _update_score_label() -> void:
	_score_label.text = "Score: %d" % _score


func _add_score(amount: int) -> void:
	_score += amount
	_update_score_label()

	_score_label.pivot_offset = _score_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(_score_label, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.12)


func _flash_screen(color: Color) -> void:
	_flash_color = color
	_flash_a = 0.35


func _show_rating(text: String, good: bool = true) -> void:
	_rating_label.text = text
	_rating_label.add_theme_color_override(
		"font_color", Color("#7dff9a") if good else Color("#ff6b7a")
	)
	_rating_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_rating_label, "modulate:a", 0.0, 0.4)
