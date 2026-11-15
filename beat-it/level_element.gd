class_name LevelElement
extends RefCounted

enum Type { FLOOR, WALL, WALLJUMP, DROPDOWN, GAP, CONNECTION }
enum Corner { BOTTOM_LEFT = 1, BOTTOM_RIGHT = -1 }

const FLOOR_COLOR := Color("#182d3b")
const FLOOR_EDGE_COLOR := Color("#56e6bf")
const WALL_COLOR := Color("#49351e")
const WALL_EDGE_COLOR := Color("#ffc36a")

const FLOOR_THICKNESS := 24.0
const WALL_THICKNESS := 16.0
const WALL_HEIGHT := 140.0
const FADE_TIME := 0.5

var type: int
var corner: int
var out_corner: int
var start_pos: Vector2
var end_pos: Vector2

var poi_time := 0.0
var appear_time := 0.0
var disappear_time := 0.0

var floors: Array[Rect2] = []
var walls: Array[Rect2] = []
var blockers: Array[Rect2] = []
var prompts: Array[Vector2] = []  # Weltpositionen der "SPACE"-Hinweise
var prompt_done: Array[bool] = []
var prompt_missed: Array[bool] = []
var prompt_times: Array[float] = []  # Soll-Zeit relativ zu poi_time
var prompt_texts: Array[String] = []  # Ergebnis-Text pro Prompt (PERFECT/GOOD/OK/WRONG)

static func create(
		p_type: int,
		p_start: Vector2,
		p_corner: int,
		params: Dictionary = {}
) -> LevelElement:
	var e := LevelElement.new()
	e.type = p_type
	e.corner = p_corner
	e.out_corner = p_corner
	e.start_pos = p_start
	e.end_pos = p_start
	var dir := float(p_corner)

	match p_type:
		Type.FLOOR:
			var w: float = params.get("width", 100.0)
			e.floors.append(_floor_rect(p_start, w, dir))
			e.end_pos = p_start + Vector2(w * dir, 0.0)

		Type.CONNECTION:
			# Wie draw_connection: gleiche Höhe, Ziel in Laufrichtung.
			var target: Vector2 = params.get("end_pos", p_start)
			var width := (target.x - p_start.x) * dir
			if not is_equal_approx(p_start.y, target.y) or width < 0.0:
				return null
			e.floors.append(_floor_rect(p_start, width, dir))
			e.end_pos = target

		Type.WALL:
			var h: float = params.get("height", WALL_HEIGHT)
			e.walls.append(_wall_rect(p_start, h, dir))
			e.end_pos = p_start + Vector2(0.0, -h)

		Type.WALLJUMP:
			var approach: float = params.get("approach_gap", 50.0)
			var landing: float = params.get("landing_gap", 100.0)
			var bottom := p_start + Vector2(approach * dir, 0.0)
			e.walls.append(_wall_rect(bottom, WALL_HEIGHT, dir))
			e.end_pos = bottom + Vector2(-landing * dir, -WALL_HEIGHT)
			if p_corner == Corner.BOTTOM_LEFT:
				e.out_corner = Corner.BOTTOM_RIGHT
			else:
				e.out_corner = Corner.BOTTOM_LEFT
			e.add_prompt(p_start + Vector2(0.0, -50.0))
			e.add_prompt(bottom + Vector2(0.0, -WALL_HEIGHT - 30.0), 0.3)
		Type.DROPDOWN:
			var w2: float = params.get("width", 100.0)
			var landing_start := p_start + Vector2(50.0 * dir, 200.0)
			e.floors.append(_floor_rect(landing_start, w2, dir))
			e.blockers.append(
				Rect2(p_start, Vector2(50.0 * dir, 200.0 + FLOOR_THICKNESS)).abs()
			)
			e.end_pos = landing_start + Vector2(w2 * dir, 0.0)

		Type.GAP:
			var landing_start2 := p_start + Vector2(75.0 * dir, 0.0)
			e.floors.append(_floor_rect(landing_start2, 20.0, dir))
			e.blockers.append(
				Rect2(p_start, Vector2(75.0 * dir, FLOOR_THICKNESS)).abs()
			)
			e.end_pos = landing_start2 + Vector2(20.0 * dir, 0.0)
			e.add_prompt(p_start + Vector2(0.0, -50.0))
	return e


static func _floor_rect(pos: Vector2, width: float, dir: float) -> Rect2:
	return Rect2(pos, Vector2(width * dir, FLOOR_THICKNESS)).abs()


static func _wall_rect(bottom: Vector2, height: float, dir: float) -> Rect2:
	var x := bottom.x if dir > 0.0 else bottom.x - WALL_THICKNESS
	return Rect2(Vector2(x, bottom.y - height), Vector2(WALL_THICKNESS, height))


func path_length() -> float:
	return absf(end_pos.x - start_pos.x) + absf(end_pos.y - start_pos.y)


func set_timing(p_poi_time: float, lead: float, visible_time: float) -> void:
	poi_time = p_poi_time
	appear_time = p_poi_time - lead
	disappear_time = appear_time + visible_time

func add_prompt(pos: Vector2, time_offset: float = 0.0) -> void:
	prompts.append(pos)
	prompt_done.append(false)
	prompt_missed.append(false)
	prompt_times.append(time_offset)
	prompt_texts.append("")


func reset_prompts() -> void:
	for i in prompts.size():
		prompt_done[i] = false
		prompt_missed[i] = false
		prompt_texts[i] = ""

func overlaps_time(from_t: float, to_t: float) -> bool:
	return appear_time < to_t and from_t < disappear_time


func alpha_at(t: float) -> float:
	var fade_in := clampf((t - appear_time) / FADE_TIME, 0.0, 1.0)
	var fade_out := clampf((disappear_time - t) / FADE_TIME, 0.0, 1.0)
	return minf(fade_in, fade_out)


func collision_rects() -> Array[Rect2]:
	var all: Array[Rect2] = []
	all.append_array(floors)
	all.append_array(walls)
	all.append_array(blockers)
	return all


func draw(canvas: CanvasItem, alpha: float, time: float = 0.0) -> void:
	if alpha <= 0.0:
		return

	for r in floors:
		canvas.draw_rect(r, _with_alpha(FLOOR_COLOR, alpha))
		canvas.draw_line(
			r.position,
			Vector2(r.end.x, r.position.y),
			_with_alpha(FLOOR_EDGE_COLOR, alpha),
			3.0
		)

	for r in walls:
		canvas.draw_rect(r, _with_alpha(WALL_COLOR, alpha))
		var edge_x := r.position.x if corner == Corner.BOTTOM_LEFT else r.end.x
		canvas.draw_line(
			Vector2(edge_x, r.end.y),
			Vector2(edge_x, r.position.y),
			_with_alpha(WALL_EDGE_COLOR, alpha),
			3.0
		)

	for i in prompts.size():
		_draw_prompt(canvas, prompts[i], alpha, time, prompt_done[i], prompt_missed[i], prompt_texts[i])


func _draw_prompt(canvas: CanvasItem, center: Vector2, alpha: float, time: float, done: bool, missed: bool, custom_text: String = "") -> void:
	var pulse := 1.0 - clampf(absf(time - poi_time) / 1.0, 0.0, 1.0)
	if done or missed:
		pulse = 0.0

	var size := Vector2(56.0, 22.0)
	var rect := Rect2(center - size * 0.5, size).grow(pulse * 3.0)

	var fill := Color("#0d1a22").lerp(Color("#1f4a3f"), pulse)
	var line := FLOOR_EDGE_COLOR.lerp(Color.WHITE, pulse)
	var text := "SPACE"
	if not custom_text.is_empty():
		text = custom_text
	elif done:
		fill = Color("#1f6a3a")
		line = Color("#7dff9a")
		text = "NICE"
	elif missed:
		fill = Color("#5a1f26")
		line = Color("#ff6b7a")
		text = "MISS"

	canvas.draw_rect(rect, _with_alpha(fill, alpha * 0.9))
	canvas.draw_rect(rect, _with_alpha(line, alpha), false, 2.0)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + 4.5),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		12,
		_with_alpha(Color.WHITE, alpha)
	)


func _with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)
