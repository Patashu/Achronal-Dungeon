extends Node2D


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"
onready var gamelogic : GameLogic = get_node("/root/PlayingField/GameLogic");


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (gamelogic.greenality_timer > 0):
		update();

func _draw():
	if (gamelogic.greenality_timer > 0):
		draw_rect(Rect2(0, 0, get_viewport().size.x, get_viewport().size.y), Color(0.662, 0.941, 0.372, gamelogic.greenality_timer/2), true);
