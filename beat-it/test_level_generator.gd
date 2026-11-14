extends Node


# Test für den Level-Generator: erzeugt eine einfache Liste von POIs
# (z.B. Beat-Timestamps) und piped sie in generate_level().

func _ready() -> void:
	randomize()
	seed(12345) # reproduzierbar


	# --- POIs: einfache Liste von Timestamps (simulierte Beats) ---
	var poi: Array[Generator.Poi] = []
	var timestamps: Array[float] = [
		0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0,
		5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
	]
	for ts in timestamps:
		var p := Generator.Poi.new()
		p.timestamp = ts
		poi.append(p)

	print("Generierte POIs: %d" % poi.size())

	# --- Level generieren ---
	var obstacles: Array[Generator.ObstacleData] = Generator.generator.new().generate_level(poi)

	# --- Assertions ---
	_assert(obstacles.size() == poi.size(), "Anzahl Obstacles == Anzahl POIs")
	_assert(obstacles[0].element_name == "CHANGE_IN_HEIGHTS", "Erstes Hindernis ist CHANGE_IN_HEIGHTS")

	var prev_x := -1.0
	var prev_timestamp := -1.0
	for o in obstacles:
		_assert(o.x == o.timestamp * Constants.constants.SCROLL_SPEED, "x = timestamp * SCROLL_SPEED")
		_assert(o.x > prev_x, "x-Positionen sind monoton steigend")
		_assert(absf(o.y) <= 40.0, "y innerhalb HEIGHT_LIMIT")
		_assert(o.timestamp > prev_timestamp, "Timestamps sind monoton steigend")
		prev_x = o.x
		prev_timestamp = o.timestamp

	# Kein Element darf direkt auf sich selbst folgen (Generator-Regel)
	for i in range(1, obstacles.size()):
		_assert(obstacles[i].element_name != obstacles[i - 1].element_name,
			"Kein Element wiederholt sich direkt (Index %d)" % i)

	# --- Zusammenfassung ---
	print("\n--- Generiertes Level ---")
	for o in obstacles:
		print("t=%5.2fs  x=%6.0f  y=%6.1f  dir=%+.0f  %s" % [o.timestamp, o.x, o.y, o.direction, o.element_name])

	print("\nAlle Tests bestanden!")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FEHLGESCHLAGEN: " + message)
		get_tree().quit(1)
