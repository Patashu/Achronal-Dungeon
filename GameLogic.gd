extends Node
class_name GameLogic

onready var multipliermap = get_node("/root/PlayingField/MultiplierMap");
onready var actormap = get_node("/root/PlayingField/ActorMap");
onready var floormap = get_node("/root/PlayingField/FloorMap");
onready var heroinfo = get_node("/root/PlayingField/HeroInfo");
onready var lastmessage = get_node("/root/PlayingField/LastMessage");
onready var hoverinfo = get_node("/root/PlayingField/HoverInfo");
onready var hoversprite = get_node("/root/PlayingField/HoverSprite");
onready var hoversprite2 = get_node("/root/PlayingField/HoverSprite2");
var hero_loc = Vector2.ZERO;
var hero_hp = 100;
var hero_atk = 1;
var hero_def = 0;
var hero_turn = 0;
var hero_keypresses = 0;
var has_won = false;
var undo_buffer = [];

func _ready() -> void:
	# setup hero info
	var hero_id = actormap.tile_set.find_tile_by_name("Player");
	var hero_tile = actormap.get_used_cells_by_id(hero_id)[0];
	hero_loc = hero_tile;
	update_hero_info();
	print_message("Welcome to the Achronal Dungeon! wasd/arrows to move, z to undo, r to restart, mouse to inspect.")

func update_hero_info() -> void:
	heroinfo.text = "HP: " + str(hero_hp) + "\r\n";
	heroinfo.text += "ATK: " + str(hero_atk) + "\r\n";
	heroinfo.text += "DEF: " + str(hero_def) + "\r\n";
	if (hero_turn != hero_keypresses):
		heroinfo.text += "Turn: " + str(hero_turn) + " (" + str(hero_keypresses) + ")" + "\r\n";
	else:
		heroinfo.text += "Turn: " + str(hero_turn) + "\r\n";
	if (has_won):
		heroinfo.text += "You have won!";

func move_hero(dir: Vector2) -> void:
	# check multiplier, actor and floor at destination
	var dest_loc = hero_loc + dir;
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var actor_dest = actormap.get_cellv(dest_loc);
	var floor_dest = floormap.get_cellv(dest_loc);
	var can_move = false;
	# no going out of bounds, please
	if (dest_loc.x < 0 || dest_loc.x > 31 || dest_loc.y < 0 || dest_loc.y > 20):
		print_message("Space and time don't exist out of bounds, sorry.")
		return;
	if (floor_dest == floormap.tile_set.find_tile_by_name("Wall") || floor_dest ==  floormap.tile_set.find_tile_by_name("Greenwall")):
		# TODO: pickaxe check
		print_message("You bump into the wall.");
		can_move = false;
	# empty tile's fine to move into
	if (actor_dest == -1 && floor_dest == -1):
		can_move = true;
	if (floor_dest == floormap.tile_set.find_tile_by_name("Win")):
		can_move = true;
		has_won = true;
		add_undo_event(["win"]);
	if (can_move):
		move_hero_commit(dir);
		
func move_hero_commit(dir: Vector2) -> void:
	add_undo_event(["move", hero_loc]);
	move_hero_silently(dir);
	hero_turn += 1;
	hero_keypresses += 1;
	update_hero_info();

func move_hero_silently(dir: Vector2) -> void:
	actormap.set_cellv(hero_loc, -1);
	hero_loc += dir;
	actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("Player"));

func add_undo_event(event: Array) -> void:
	if (undo_buffer.size() <= hero_turn):
		undo_buffer.append([]);
	undo_buffer[hero_turn].append(event);

func print_message(message: String)-> void:
	lastmessage.text = message;

func undo() -> void:
	if (hero_turn <= 0):
		return
	var events = undo_buffer.pop_back();
	for event in events:
		if (event[0] == "move"):
			move_hero_silently(event[1] - hero_loc);
		elif (event[0] == "win"):
			has_won = false;
	hero_turn -= 1;
	hero_keypresses += 1;
	update_hero_info();

func update_hover_info() -> void:
	var dest_loc = floormap.world_to_map(get_viewport().get_mouse_position());
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var actor_dest = actormap.get_cellv(dest_loc);
	var floor_dest = floormap.get_cellv(dest_loc);
	var dest_to_use = actor_dest;
	if (dest_to_use == -1):
		dest_to_use = floor_dest;
	var multiplier_val = multiplier_id_to_number(multiplier_dest);
	
	hoversprite2.texture = null;
	hoversprite.texture = null;
	hoverinfo.text = "";
	
	if (dest_to_use >= 0):
		hoversprite.texture = floormap.tile_set.tile_get_texture(dest_to_use);
	else:
		return;
	
	# this is all gross. I guess I 'should' use json and helper functions and whatnot.
	
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	if (("green" in dest_name) and not ("greenality" in dest_name)):
		hoverinfo.text = "Green ";
		
	if ("player" in dest_name):
		hoverinfo.text += "Player";
		
	if ("win" == dest_name):
		hoverinfo.text += "Goal";
		
	if ("wall" in dest_name):
		hoverinfo.text += "Wall";
		
	if ("potion" in dest_name):
		hoverinfo.text += "Potion";
		
	if ("sword" in dest_name):
		hoverinfo.text += "Sword";
	
	if ("shield" in dest_name):
		hoverinfo.text += "Shield";
		
	if ("enemy1" in dest_name):
		hoverinfo.text += "Guard";
		
	if ("fire" in dest_name):
		hoverinfo.text += "Fire";
		
	if ("slime" in dest_name):
		hoverinfo.text += "Slime";
		
	if ("teeth" in dest_name):
		hoverinfo.text += "Teeth";
		
	if ("greenality" in dest_name):
		hoverinfo.text += "Greenality";
		
	if ("pickaxe" in dest_name):
		hoverinfo.text += "Pickaxe";
		
	if ("warpwings" in dest_name):
		hoverinfo.text += "Warp Wings";
		
	if ("magicmirror" in dest_name):
		hoverinfo.text += "Magic Mirror";
	
	if (multiplier_val > 1):
		hoversprite2.texture = multipliermap.tile_set.tile_get_texture(multiplier_dest);
		hoverinfo.text += "(x" + str(multiplier_val) + ")"
		
	if ("player" in dest_name):
		hoverinfo.text += "\nIt's you! wasd/arrows to move, z to undo, r to restart.";
		
	if ("win" == dest_name):
		hoverinfo.text += "\nGet the Player here to escape the Achronal Dungeon!";
	
	if ("wall" in dest_name):
		hoverinfo.text += "\nImpervious without a Pickaxe.";
		
	if ("potion" in dest_name):
		hoverinfo.text += "\nIncreases your HP by " + str(multiplier_val);
		
	if ("sword" in dest_name):
		hoverinfo.text += "\nIncreases your ATK by " + str(multiplier_val);
	
	if ("shield" in dest_name):
		hoverinfo.text += "\nIncreases your DEF by " + str(multiplier_val);
		
	if ("enemy" in dest_name):
		var enemy_stats = monster_helper(dest_name, multiplier_val);
		hoverinfo.text += "\nHP: " + str(enemy_stats[0]);
		hoverinfo.text += "\nATK: " + str(enemy_stats[1]);
		hoverinfo.text += "\nYou would lose " + str(enemy_stats[2]) + " HP killing this.";
		
	if ("greenality" in dest_name):
		hoverinfo.text += "\nAllows you to permanently make something GREEN.";
		
	if ("pickaxe" in dest_name):
		hoverinfo.text += "\nAllows you to destroy one wall.";
		
	if ("warpwings" in dest_name):
		hoverinfo.text += "\nActivate to warp to the opposite tile of the map.";
		
	if ("magicmirror" in dest_name):
		hoverinfo.text += "\nYou can see your reflection in this!";
	
	if (("green" in dest_name) and not ("greenality" in dest_name)):
		add_green_reminder();

func add_green_reminder() -> void:
	hoverinfo.text += "\n\nInteracting with a Green thing persists through UNDO (z) and RESTART (r)."

func monster_helper(name: String, multiplier_val: int) -> Array:
	var result = [0, 0, 0]
	if "slime" in name:
		result[0] = 10*multiplier_val;
		result[1] = 1*multiplier_val;
	elif "enemy1" in name:
		result[0] = 5*multiplier_val;
		result[1] = 2*multiplier_val;
	elif "teeth" in name:
		result[0] = 3*multiplier_val;
		result[1] = 3*multiplier_val;
	elif "fire" in name:
		result[0] = 2*multiplier_val;
		result[1] = 5*multiplier_val;
	
	# special case: take no damage
	if (hero_def >= result[1]):
		return result;
	# special case: we can't hurt the enemy
	if (hero_atk <= 0):
		result[2] = INF;
		return result;
	# fight time!
	var enemy_hp_temp = result[0];
	var hero_hp_temp = hero_hp;
	# TODO: could accelerate this with SIMPLE MATH but let's do it the easy way for now
	enemy_hp_temp -= hero_atk;
	while (enemy_hp_temp > 0):
		hero_hp_temp -= (result[1] - hero_def);
		enemy_hp_temp -= hero_atk;
	result[2] = hero_hp - hero_hp_temp;
	return result;

func multiplier_id_to_number(id: int) -> int:
	if (id == -1):
		return 1;
	var string_result = multipliermap.tile_set.tile_get_name(id);
	return int(string_result);

func _process(delta: float) -> void:
	update_hover_info();
	if (Input.is_action_just_pressed("undo")):
		undo();
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
