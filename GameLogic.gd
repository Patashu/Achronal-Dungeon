extends Node
class_name GameLogic

# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"

onready var tilemap = get_node("/root/PlayingField/TileMap");

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1) learn where the hero is.
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 2) check for input, move hero around, process interactions, create undo buffer
	pass
