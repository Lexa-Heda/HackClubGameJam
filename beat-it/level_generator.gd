class_name LevelGenerator
extends RefCounted

class Poi:
	var timestamp: float

	func _init(p_timestamp: float = 0.0) -> void:
		timestamp = p_timestamp

const SCROLL_SPEED := 200.0
const LEAD_TIME := 5.0
const VISIBLE_TIME := 10.0
const MIN_POI_GAP := 1.5
const FORCE_GAP_GAP := 0.5
const MIN_CONNECTION := 40.0
const MARGIN := 4.0
const FIRST_FLOOR_WIDTH := 300.0

const Y_MIN := 300.0
const Y_MAX := 800.0
const MAX_REPEATS := 2

const WEIGHTS := {
	LevelElement.Type.GAP: 3.0,
	LevelElement.Type.WALLJUMP: 2.0,
	LevelElement.Type.DROPDOWN: 2.0,
}

var seed_value := 0


func generate(pois: Array[Poi], start_pos: Vector2) -> Array[LevelElement]:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var elements: Array[LevelElement] = []

	var first := LevelElement.create(
		LevelElement.Type.FLOOR, start_pos,
		LevelElement.Corner.BOTTOM_LEFT, {"width": FIRST_FLOOR_WIDTH}
	)
	first.set_timing(LEAD_TIME, LEAD_TIME + LevelElement.FADE_TIME, VISIBLE_TIME)
	elements.append(first)

	var cursor := first.end_pos
	var corner: int = first.out_corner
	var last_time := 0.0
	var consumed := FIRST_FLOOR_WIDTH
	var history: Array[int] = []
	var pending: Array[float] = []

	var sorted: Array[Poi] = []
	sorted.append_array(pois)
	sorted.sort_custom(func(a: Poi, b: Poi) -> bool: return a.timestamp < b.timestamp)

	for poi in sorted:
		var delta := poi.timestamp - last_time
		var min_conn := 8.0 if delta < MIN_POI_GAP else MIN_CONNECTION
		var width := maxf(min_conn, delta * SCROLL_SPEED - consumed)

		var order: Array[int] = []
		if delta < FORCE_GAP_GAP:
			order.append(LevelElement.Type.GAP)
		else:
			order = _weighted_order(cursor, history, rng)

		var pair: Array[LevelElement] = []
		for t in order:
			pair = _place(elements, poi.timestamp, t, width, cursor, corner)
			if not pair.is_empty():
				history.append(t)
				break

		if pair.is_empty():
			pair = _place(elements, poi.timestamp, LevelElement.Type.GAP, width, cursor, corner)
		if pair.is_empty():
			pair = _place(elements, poi.timestamp, LevelElement.Type.FLOOR, width, cursor, corner)
		if pair.is_empty():
			pair = _place(elements, poi.timestamp, LevelElement.Type.FLOOR, width, cursor, corner, true)

		if pair.is_empty():
			pending.append(poi.timestamp)
			continue

		for e in pair:
			elements.append(e)

		# Geparkte Sub-Beats: nur Soll-Zeit speichern, level.gd setzt die Position.
		if not pending.is_empty():
			var conn: LevelElement = pair[0]
			for ts in pending:
				conn.add_prompt(conn.start_pos + Vector2(0.0, -50.0), ts - poi.timestamp)
			pending.clear()

		var obstacle: LevelElement = pair[1]
		cursor = obstacle.end_pos
		corner = obstacle.out_corner
		last_time = poi.timestamp
		consumed = _consumed_for(obstacle)

	return elements


# Muss zu den Dauern in level.gd::_build_path() passen:
# Gap 0.5 s, Walljump 1.0 s, Dropdown 1.0 s (bei SCROLL_SPEED px/s).
func _consumed_for(o: LevelElement) -> float:
	match o.type:
		LevelElement.Type.GAP:
			return 0.5 * SCROLL_SPEED
		LevelElement.Type.WALLJUMP:
			return 1.0 * SCROLL_SPEED
		LevelElement.Type.DROPDOWN:
			return 1.0 * SCROLL_SPEED
	return o.path_length()


func _weighted_order(cursor: Vector2, history: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var pool: Dictionary = {}

	for t in WEIGHTS:
		var w: float = WEIGHTS[t]

		if t == LevelElement.Type.WALLJUMP and cursor.y - LevelElement.WALL_HEIGHT < Y_MIN:
			continue
		if t == LevelElement.Type.DROPDOWN and cursor.y + 200.0 > Y_MAX:
			continue

		var mid := (Y_MIN + Y_MAX) * 0.5
		if t == LevelElement.Type.WALLJUMP and cursor.y > mid:
			w *= 2.0
		if t == LevelElement.Type.DROPDOWN and cursor.y < mid:
			w *= 2.0

		if _repeat_count(history, t) >= MAX_REPEATS:
			w *= 0.05

		pool[t] = w

	var order: Array[int] = []
	while not pool.is_empty():
		var total := 0.0
		for t in pool:
			total += pool[t]
		var roll := rng.randf() * total
		var picked: int = pool.keys()[0]
		for t in pool:
			roll -= pool[t]
			if roll <= 0.0:
				picked = t
				break
		order.append(picked)
		pool.erase(picked)

	if order.is_empty():
		order.append(LevelElement.Type.GAP)
	return order


func _repeat_count(history: Array[int], t: int) -> int:
	var n := 0
	for i in range(history.size() - 1, -1, -1):
		if history[i] != t:
			break
		n += 1
	return n


func _place(
		elements: Array[LevelElement],
		timestamp: float,
		type: int,
		width: float,
		cursor: Vector2,
		corner: int,
		force: bool = false
) -> Array[LevelElement]:
	var previous: LevelElement = elements[-1]
	var obstacle_start := cursor + Vector2(width * float(corner), 0.0)

	var connection := LevelElement.create(
		LevelElement.Type.CONNECTION, cursor, corner, {"end_pos": obstacle_start}
	)
	if connection == null:
		return []
	var obstacle := LevelElement.create(type, obstacle_start, corner)

	connection.set_timing(timestamp, LEAD_TIME, VISIBLE_TIME)
	obstacle.set_timing(timestamp, LEAD_TIME, VISIBLE_TIME)
	connection.appear_time = minf(connection.appear_time, previous.appear_time)

	if not force and (
			_collides(connection, elements, previous)
			or _collides(obstacle, elements, previous)):
		return []

	var result: Array[LevelElement] = [connection, obstacle]
	return result


func _collides(
		candidate: LevelElement,
		elements: Array[LevelElement],
		ignore: LevelElement
) -> bool:
	var mine := candidate.collision_rects()
	for other in elements:
		if other == ignore:
			continue
		if not other.overlaps_time(candidate.appear_time, candidate.disappear_time):
			continue
		for rb in other.collision_rects():
			for ra in mine:
				if ra.grow(MARGIN).intersects(rb):
					return true
	return false
