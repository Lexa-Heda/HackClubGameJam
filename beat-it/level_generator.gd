class_name LevelGenerator
extends RefCounted

class Poi:
	var timestamp: float

	func _init(p_timestamp: float = 0.0) -> void:
		timestamp = p_timestamp

const SCROLL_SPEED := 200.0  # ggf. Constants.constants.SCROLL_SPEED
const LEAD_TIME := 2.0
const VISIBLE_TIME := 5.0
const MIN_POI_GAP := 1.5
const MIN_CONNECTION := 40.0
const MARGIN := 4.0
const FIRST_FLOOR_WIDTH := 300.0

const Y_MIN := 300.0
const Y_MAX := 800.0
const MAX_REPEATS := 2  # gleicher Typ höchstens so oft hintereinander

# Basisgewichte der Hindernisse
const WEIGHTS := {
	LevelElement.Type.GAP: 3.0,
	LevelElement.Type.WALLJUMP: 2.0,
	LevelElement.Type.DROPDOWN: 2.0,
}

var seed_value := 0  # 0 = zufällig, sonst reproduzierbar


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

	var sorted: Array[Poi] = []
	sorted.append_array(pois)
	sorted.sort_custom(func(a: Poi, b: Poi) -> bool: return a.timestamp < b.timestamp)

	for poi in sorted:
		var delta := poi.timestamp - last_time
		if delta < MIN_POI_GAP:
			continue

		var width := maxf(MIN_CONNECTION, delta * SCROLL_SPEED - consumed)
		var order := _weighted_order(cursor, history, rng)

		var pair: Array[LevelElement] = []
		for t in order:
			pair = _place(elements, poi.timestamp, t, width, cursor, corner)
			if not pair.is_empty():
				history.append(t)
				break

		if pair.is_empty():
			# Fallback: schlichter Boden, damit kein POI ausfaellt.
			pair = _place(elements, poi.timestamp, LevelElement.Type.FLOOR, width, cursor, corner)

		if pair.is_empty():
			push_warning("POI bei %.2fs übersprungen: kein freier Platz." % poi.timestamp)
			continue

		for e in pair:
			elements.append(e)
		var obstacle: LevelElement = pair[1]
		cursor = obstacle.end_pos
		corner = obstacle.out_corner
		last_time = poi.timestamp
		consumed = obstacle.path_length()

	return elements


# Gewichtete Zufallsreihenfolge: erster Eintrag = bevorzugter Typ.
func _weighted_order(cursor: Vector2, history: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var pool: Dictionary = {}

	for t in WEIGHTS:
		var w: float = WEIGHTS[t]

		if t == LevelElement.Type.WALLJUMP and cursor.y - LevelElement.WALL_HEIGHT < Y_MIN:
			continue
		if t == LevelElement.Type.DROPDOWN and cursor.y + 200.0 > Y_MAX:
			continue

		# Höhenausgleich: tief -> Walljump bevorzugen, hoch -> Dropdown.
		var mid := (Y_MIN + Y_MAX) * 0.5
		if t == LevelElement.Type.WALLJUMP and cursor.y > mid:
			w *= 2.0
		if t == LevelElement.Type.DROPDOWN and cursor.y < mid:
			w *= 2.0

		# Zu viele Wiederholungen vermeiden.
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

	return order


func _repeat_count(history: Array[int], t: int) -> int:
	var n := 0
	for i in range(history.size() - 1, -1, -1):
		if history[i] != t:
			break
		n += 1
	return n


# Gibt [connection, obstacle] zurück oder [] bei Kollision.
func _place(
		elements: Array[LevelElement],
		timestamp: float,
		type: int,
		width: float,
		cursor: Vector2,
		corner: int
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

	if _collides(connection, elements, previous) or _collides(obstacle, elements, previous):
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
