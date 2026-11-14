extends Node



class_name Generator

class Poi:
	var timestamp: float # seconds

class ObstacleData:
	var x: float
	var y: float
	var timestamp: float
	var element_name: String
	var direction: float # -1.0 = down, 1.0 = up; for WALLDASH the wall to dash toward
	func _init(x_: float, y_: float, timestamp_: float, element_name_: String, direction_: float) -> void:
		self.x = x_
		self.y = y_
		self.timestamp = timestamp_
		self.element_name = element_name_
		self.direction = direction_
		
		
	
class DecisionReturn:
	var x: float
	var y: float
	var element_name: String
	var direction: float



class generator:
	const scroll_speed: int = Constants.constants.SCROLL_SPEED # pixels per second, player runs right constantly
	
	func _init() -> void:
		pass
	
	func generate_level(poi: Array[Poi]) -> Array[ObstacleData]:
		var obstacles: Array[ObstacleData] = []

		for point in poi:
			var decision: DecisionReturn
			if obstacles.is_empty():
				decision = decision_tree([], point.timestamp, point.timestamp)
			else:
				var delta := point.timestamp - obstacles[-1].timestamp
				decision = decision_tree(obstacles, delta, point.timestamp)
			obstacles.append(ObstacleData.new(decision.x, decision.y, point.timestamp, decision.element_name, decision.direction))
			

		return obstacles
	func decision_tree(obstacles: Array[ObstacleData], delta_timestamp: float, timestamp: float) -> DecisionReturn:
		var result := DecisionReturn.new()
		# x is purely time-based: the player scrolls right at a constant speed
		result.x = timestamp * scroll_speed
		result.direction = 1.0

		# Branch 1: first obstacle of the level 
		if obstacles.is_empty():
			result.element_name = Constants.ELEMENT.keys()[Constants.ELEMENT.CHANGE_IN_HEIGHTS]
			result.y = 0.0
			return result

		var last: ObstacleData = obstacles[-1]
		var last_element: int = _element_from_name(last.element_name)

		# Branch 2: very tight spacing -> simple height change, no gimmick 
		if delta_timestamp < 0.25:
			result.element_name = Constants.ELEMENT.keys()[Constants.ELEMENT.CHANGE_IN_HEIGHTS]
			var dy := _pick([-1.0, 1.0]) * 2.0
			result.y = _clamp_height(last.y + dy)
			result.direction = signf(dy)
			return result

		# Branch 3: avoid repeating the same gimmick twice in a row 
		var avoid: int = last_element

		#  Branch 4: pick element by tempo bucket 
		var chosen: int
		if delta_timestamp < 0.6:
			# fast section: walldash is cheap to react to
			chosen = _pick_element_excluding([avoid])
		elif delta_timestamp < 1.2:
			# mid tempo: alternate heights and walldash
			chosen = _pick_element_excluding([Constants.ELEMENT.REVERSE_GRAVITY, avoid])
		else:
			# slow section: gravity flips are readable here
			chosen = _pick_element_excluding([Constants.ELEMENT.WALLDASH, avoid])

		result.element_name = Constants.ELEMENT.keys()[chosen]

		# Branch 5: position depends on chosen element
		match chosen:
			Constants.ELEMENT.CHANGE_IN_HEIGHTS:
				var dy := _pick([-1.0, 1.0]) * 4.0
				result.y = _clamp_height(last.y + dy)
				result.direction = signf(dy)
			Constants.ELEMENT.WALLDASH:
				# Wall-Dash: eine Ebene hoeher springen und Richtung wechseln
				result.y = _clamp_height(last.y + LEVEL_STEP)
				result.direction = -last.direction
			Constants.ELEMENT.DROP_IN_HEIGHT:
				# Drop: eine Ebene tiefer fallen
				result.y = _clamp_height(last.y - LEVEL_STEP)
				result.direction = -1.0
			Constants.ELEMENT.REVERSE_GRAVITY:
				result.y = _clamp_height(-last.y)
				result.direction = -last.direction

		return result

	func _element_from_name(element_name: String) -> int:
		match element_name:
			"CHANGE_IN_HEIGHTS":
				return Constants.ELEMENT.CHANGE_IN_HEIGHTS
			"WALLDASH":
				return Constants.ELEMENT.WALLDASH
			"REVERSE_GRAVITY":
				return Constants.ELEMENT.REVERSE_GRAVITY
			"DROP_IN_HEIGHT":
				return Constants.ELEMENT.DROP_IN_HEIGHT
		return Constants.ELEMENT.CHANGE_IN_HEIGHTS

	func _pick_element_excluding(excluded: Array) -> int:
		var pool: Array[int] = [
			Constants.ELEMENT.CHANGE_IN_HEIGHTS,
			Constants.ELEMENT.WALLDASH,
			Constants.ELEMENT.REVERSE_GRAVITY,
			Constants.ELEMENT.DROP_IN_HEIGHT,
		]
		var candidates: Array[int] = []
		for e in pool:
			if e not in excluded:
				candidates.append(e)
		if candidates.is_empty():
			candidates = pool
		return candidates[randi() % candidates.size()]

	func _pick(values: Array) -> float:
		return values[randi() % values.size()]

	const HEIGHT_LIMIT := 40.0
	const LEVEL_STEP := 20.0 # eine "Ebene" = 20 Einheiten (Levels: -40, -20, 0, 20, 40)

	func _clamp_height(y: float) -> float:
		return clampf(y, -HEIGHT_LIMIT, HEIGHT_LIMIT)
