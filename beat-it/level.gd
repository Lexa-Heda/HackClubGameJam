extends Node2D

const START_POS := Vector2(0.0, 600.0)

const GRAVITY := 1800.0
const RUN_SPEED := 200.0
const JUMP_VELOCITY := -500.0
const BODY_HALF := Vector2(12.0, Player.HALF_HEIGHT)
const SOLID_MIN_ALPHA := 0.05

var _player: Player
var _camera: Camera2D
var _generator := LevelGenerator.new()
var _elements: Array[LevelElement] = []

var _time := 0.0
var _pos := Vector2.ZERO  # Mittelpunkt des Körpers
var _vel := Vector2.ZERO
var _dir := 1.0
var _on_floor := false
var _touch_wall := false
var _kicked := false

var _floors: Array[Rect2] = []
var _walls: Array[Rect2] = []
var _solids: Array[Rect2] = []
# HUD
var _score := 0
var _score_label: Label
var _scored: Dictionary = {}  
var _rating_label: Label
const PASS_DISTANCE := 80.0  # entspricht dem Drück-Fenster
const PENALTY := -50

const DEBOUNCE := 0.2  # Sekunden Sperre nach einem ausgewerteten Druck

var _space_down := false
var _space_locked_until := 0.0

# Screen-Bounce (Zoom-Punch) bei POI-Timestamps
var _poi_times: Array[float] = []
var _prev_time := 0.0
var _punch_t := -1.0  # -1 = inaktiv, sonst Sekunden seit Punch-Start
const BASE_ZOOM := 1.5
const PUNCH_DUR := 0.5
const PUNCH_AMP := 0.12  # +12% Zoom-Spitze

func _ready() -> void:
	_generate()
	_spawn_player()
	_setup_camera()
	_setup_hud()

func _debug_prompts() -> void:
	for e in _elements:
		print("type=%d poi=%.2f appear=%.2f prompts=%s" % [
			e.type, e.poi_time, e.appear_time, e.prompts
		])

func _generate() -> void: # fast: [2.0, 3.0, 3.5, 4.0, 5.0, 5.5, 6.0] slow: [6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0]
	var pois: Array[LevelGenerator.Poi] = []
	for t in [6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0]:
		var p := LevelGenerator.Poi.new(t)
		p.timestamp = t
		pois.append(p)
		_poi_times.append(t)

	_generator.seed_value = 1234
	_elements = _generator.generate(pois, START_POS)
	_debug_prompts()

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
	_kicked = false
	_player.global_position = _pos
	_space_down = false
	_space_locked_until = 0.0
	_prev_time = 0.0
	_punch_t = -1.0
	if _camera:
		_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)


func _process(delta: float) -> void:
	_camera.global_position = _player.global_position
	if _punch_t >= 0.0:
		_punch_t += delta
		var p := _punch_t / PUNCH_DUR
		if p >= 1.0:
			_punch_t = -1.0
			_camera.zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
		else:
			# abklingende Schwingung um die Basis-Zoom (Bounce nach innen)
			var s := sin(p * PI * 4.0) * exp(-4.0 * p) * PUNCH_AMP
			_camera.zoom = Vector2(BASE_ZOOM * (1.0 + s), BASE_ZOOM * (1.0 + s))
	queue_redraw()


func _draw() -> void:
	for e in _elements:
		e.draw(self, e.alpha_at(_time), _time)


func _physics_process(delta: float) -> void:
	_time += delta
	# Punch an den POI-Timestamps (Quelle der Wahrheit), unabhaengig davon,
	# ob der Generator fuer diesen POI ein Element platzieren konnte.
	for t in _poi_times:
		if t > _prev_time and t <= _time:
			_punch_t = 0.0
			break
	_prev_time = _time
	_collect_solids()
	_control()
	_move(delta)
	_player.global_position = _pos
	_update_anim()
	if _pos.y > 1600.0:
		_reset()
	_check_missed()

func _update_anim() -> void:
	var state := "fall"
	if _on_floor:
		state = "run"
	elif _vel.y < 0.0:
		state = "jump"
	_player.set_state(state, _dir < 0.0)


func _check_missed() -> void:
	for e in _elements:
		if _time < e.poi_time - 2.0 or e.alpha_at(_time) <= SOLID_MIN_ALPHA:
			continue
		for i in e.prompts.size():
			if e.prompt_done[i] or e.prompt_missed[i]:
				continue
			var p: Vector2 = e.prompts[i]
			# _dir statt e.corner: nach Walljump laeuft der Spieler zurueck
			var passed := (_pos.x - p.x) * _dir > PASS_DISTANCE \
				and absf(_pos.y - p.y) < 120.0
			if passed:
				e.prompt_missed[i] = true
				print("MISS  t=%.2f  prompt=%s  player=%s" % [_time, p, _pos])
				_add_score(PENALTY)
				_show_rating("MISS %d" % PENALTY, false)

# Physik

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


# Bot

func _control() -> void:
	var feet := _pos.y + BODY_HALF.y

	if _on_floor:
		_kicked = false
		_vel.x = _dir * RUN_SPEED

		var probe := Vector2(_pos.x + _dir * (BODY_HALF.x + 1.0), feet + 4.0)
		if _solid_at(probe):
			return
		# Kante: nur springen, wenn Wand oder Landeplatte voraus (sonst Dropdown)
		if _wall_ahead(feet) is Rect2 or _landing_floor(feet) is Rect2:
			_do_jump()
		return

	if _touch_wall and not _kicked and _vel.y > -150.0:
		_do_jump()


# Gemeinsame Sprunglogik für Bot und Mensch.
func _do_jump() -> void:
	var feet := _pos.y + BODY_HALF.y

	if _on_floor:
		if _wall_ahead(feet) is Rect2:
			_vel.y = JUMP_VELOCITY  # Walljump: zur Wand springen
			return
		var land = _landing_floor(feet)
		if land is Rect2:  # Gap: Geschwindigkeit auf die Landeplatte zielen
			var air_time := 2.0 * -JUMP_VELOCITY / GRAVITY
			var target_x: float = land.get_center().x
			_vel.x = clampf((target_x - _pos.x) / air_time, -2.0 * RUN_SPEED, 2.0 * RUN_SPEED)
		_vel.y = JUMP_VELOCITY
	elif _touch_wall and not _kicked:
		_wall_kick()

func _wall_kick() -> void:
	var feet := _pos.y + BODY_HALF.y
	var old := _dir
	var vx := -old * RUN_SPEED * 1.5
	var target = _upper_floor(feet, old)
	if target is Rect2:
		var near_x: float = target.end.x if old > 0.0 else target.position.x
		var tx: float = near_x - old * minf(24.0, target.size.x * 0.5)
		var disc: float = JUMP_VELOCITY * JUMP_VELOCITY - 2.0 * GRAVITY * (feet - target.position.y)
		if disc > 0.0:
			var t := (-JUMP_VELOCITY + sqrt(disc)) / GRAVITY
			vx = clampf((tx - _pos.x) / t, -400.0, 400.0)
	_vel = Vector2(vx, JUMP_VELOCITY)
	_dir = -old
	_kicked = true

func _solid_at(p: Vector2) -> bool:
	for r in _solids:
		if r.has_point(p):
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
	var best = null
	var best_d := INF
	for r in _floors:
		var dx := r.get_center().x - _pos.x
		if absf(r.position.y - feet) < 1.5 and dx * _dir > 0.0 and absf(dx) < 250.0:
			if absf(dx) < best_d:
				best_d = absf(dx)
				best = r
	return best


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

	_update_score_label()
	_rating_label = Label.new()
	_rating_label.position = Vector2(24.0, 64.0)
	_rating_label.add_theme_font_size_override("font_size", 24)
	_rating_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_rating_label.add_theme_constant_override("outline_size", 5)
	_rating_label.modulate.a = 0.0
	layer.add_child(_rating_label)


func _update_score_label() -> void:
	_score_label.text = "Score: %d" % _score


func _add_score(amount: int) -> void:
	_score += amount
	_update_score_label()

	_score_label.pivot_offset = _score_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(_score_label, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.12)

# Einziger Ort für "Space gedrückt" – Bot und echter Input rufen ihn auf.
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
		var info := ""
		for e in _elements:
			if e.prompts.is_empty():
				continue
			info += "[t=%d poi=%.1f a=%.2f done=%s missed=%s] " % [
				e.type, e.poi_time, e.alpha_at(_time), e.prompt_done, e.prompt_missed
			]
		print("WRONG t=%.2f player=%s best_dx=%.1f  %s" % [_time, _pos, best_dx, info])
		if best_e != null:
			best_e.prompt_texts[best_i] = "WRONG"
		_add_score(PENALTY)
		_show_rating("WRONG %d" % PENALTY, false)
		return

	best_e.prompt_done[best_i] = true

	var pts := 25
	var rating := "OK"
	if best_dx <= 16.0:
		pts = 100
		rating = "PERFECT"
	elif best_dx <= 40.0:
		pts = 50
		rating = "GOOD"
	# dx <= 80 (valides Fenster) gibt mindestens OK +25, kein Minus
	best_e.prompt_texts[best_i] = rating

	_add_score(pts)
	_show_rating("%s +%d" % [rating, pts])

func _unhandled_input(event: InputEvent) -> void:
	# Autoplay steuert die Bewegung; Space wird nur auf Korrektheit geprueft.
	if event.is_action_pressed("jump"):
		_press_space()

func _space_event(is_down: bool) -> void:
	if not is_down:
		_space_down = false 
		return

	if _space_down:
		return  
	_space_down = true

	if _time < _space_locked_until:
		return  

	_space_locked_until = _time + DEBOUNCE
	_press_space()


# Für den Bot: Druck und sofortiges Loslassen.
func _tap_space() -> void:
	_space_event(true)
	_space_event(false)

func _show_rating(text: String, good: bool = true) -> void:
	_rating_label.text = text
	_rating_label.add_theme_color_override(
		"font_color", Color("#7dff9a") if good else Color("#ff6b7a")
	)
	_rating_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_rating_label, "modulate:a", 0.0, 0.4)
