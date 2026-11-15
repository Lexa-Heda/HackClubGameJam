extends Node

class_name Constants
var SCROLL_SPEED = 200.0
enum ELEMENT {
	CHANGE_IN_HEIGHTS,
	WALLDASH,
	REVERSE_GRAVITY,
	DROP_IN_HEIGHT,
}

class Element:
	var name: ELEMENT
	var lenght: float
	var height: float
	
	func _init(name_: ELEMENT, lenght_: float, height_: float) -> void:
		self.name = name_
		self.height = height_
		self.lenght = lenght_

enum constants {
	SCROLL_SPEED = 200
}
