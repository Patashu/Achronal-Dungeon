extends Node2D

onready var gamelogic : GameLogic = get_node("/root/PlayingField/GameLogic");

func _process(delta: float) -> void:
	update();

func _draw():
	if (gamelogic.timer < 3):
		draw_arc(gamelogic.floormap.map_to_world(gamelogic.hero_loc)+Vector2(8,8),
		(3 - gamelogic.timer)*100,
		0,
		TAU,
		16,
		Color("#FCEBB6"));
	else:
		queue_free();
