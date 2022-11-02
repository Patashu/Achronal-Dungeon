extends Node
class_name GameLogic

onready var multipliermap = get_node("/root/PlayingField/MultiplierMap");
onready var actormap = get_node("/root/PlayingField/ActorMap");
onready var floormap = get_node("/root/PlayingField/FloorMap");
onready var heroinfo = get_node("/root/PlayingField/HeroInfo");
var hero_loc = Vector2.ZERO;
var hero_hp = 100;
var hero_atk = 1;
var hero_def = 0;
var hero_turn = 0;
var has_won = false;

func _ready() -> void:
	# setup hero info
	var hero_id = actormap.tile_set.find_tile_by_name("Player");
	var hero_tile = actormap.get_used_cells_by_id(hero_id)[0];
	hero_loc = hero_tile;
	update_hero_info();

func update_hero_info() -> void:
	heroinfo.text = "HP: " + str(hero_hp) + "\r\n";
	heroinfo.text += "ATK: " + str(hero_atk) + "\r\n";
	heroinfo.text += "DEF: " + str(hero_def) + "\r\n";
	heroinfo.text += "Turn: " + str(hero_turn) + "\r\n";
	if (has_won):
		heroinfo.text += "You have won!";

func move_hero(dir: Vector2) -> void:
	# check multiplier, actor and floor at destination
	var multiplier_dest = multipliermap.get_cellv(hero_loc + dir);
	var actor_dest = actormap.get_cellv(hero_loc + dir);
	var floor_dest = floormap.get_cellv(hero_loc + dir);
	var can_move = false;
	# empty tile's fine to move into
	if (actor_dest == -1 && floor_dest == -1):
		can_move = true;
	if (floor_dest == floormap.tile_set.find_tile_by_name("Win")):
		can_move = true;
		has_won = true;
	if (can_move):
		move_hero_commit(dir);
		
func move_hero_commit(dir: Vector2) -> void:
	actormap.set_cellv(hero_loc, -1);
	hero_loc += dir;
	actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("Player"));
	hero_turn += 1;
	update_hero_info();

func _process(delta: float) -> void:
	# 2) check for input, move hero around, process interactions, create undo buffer
	if (has_won):
		return;
	if (Input.is_action_just_pressed("ui_left")):
		move_hero(Vector2.LEFT);
	if (Input.is_action_just_pressed("ui_right")):
		move_hero(Vector2.RIGHT);
	if (Input.is_action_just_pressed("ui_up")):
		move_hero(Vector2.UP);
	if (Input.is_action_just_pressed("ui_down")):
		move_hero(Vector2.DOWN);
