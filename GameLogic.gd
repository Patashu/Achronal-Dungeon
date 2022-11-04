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
var meta_undo_buffer = [];
var greenality_max = 0;
var greenality_avail = 0;
var pickaxes = 0;
var warpwings = 0;

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
	# note: for now I'm putting only the player in the actor layer...
	# and ONLY because the player might overlap things (most notably the goal)
	var dest_loc = hero_loc + dir;
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var actor_dest = actormap.get_cellv(dest_loc);
	var floor_dest = floormap.get_cellv(dest_loc);
	var can_move = false;
	var dest_to_use = actor_dest;
	if (dest_to_use == -1):
		dest_to_use = floor_dest;
	var dest_name = "";
	if (dest_to_use > -1):
		dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
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
	if ("potion" in dest_name) or ("sword" in dest_name) or ("shield" in dest_name):
		can_move = true;
		consume_item(dest_loc);
	if ("win" in dest_name):
		can_move = true;
		has_won = true;
		add_undo_event(["win"]);
	if (can_move):
		move_hero_commit(dir);
		
func consume_item(dest_loc: Vector2) -> void:
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var multiplier_val = multiplier_id_to_number(multiplier_dest)
	var dest_to_use = floormap.get_cellv(dest_loc);
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	# TODO: handle green
	add_undo_event(["destroy", dest_loc, dest_name, multiplier_val]);
	floormap.set_cellv(dest_loc, -1);
	multipliermap.set_cellv(dest_loc, -1);
	if ("potion" in dest_name):
		add_undo_event(["gain_hp", multiplier_val]);
		hero_hp += multiplier_val;
		print_message("You drink the " + name_thing(dest_name, multiplier_val) + " and gain " + str(multiplier_val) + " HP!");
	if ("sword" in dest_name):
		add_undo_event(["gain_atk", multiplier_val]);
		hero_atk += multiplier_val;
		print_message("You take the " + name_thing(dest_name, multiplier_val) + " and gain " + str(multiplier_val) + " ATK!");
	if ("shield" in dest_name):
		add_undo_event(["gain_def", multiplier_val]);
		hero_def += multiplier_val;
		print_message("You take the " + name_thing(dest_name, multiplier_val) + " and gain " + str(multiplier_val) + " DEF!");
		
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
		elif (event[0] == "destroy"):
			var dest_loc = event[1];
			var dest_name = event[2];
			var multiplier_val = event[3];
			floormap.set_cellv(dest_loc, floormap.tile_set.find_tile_by_name(dest_name.capitalize()));
			if (multiplier_val > 1):
				multipliermap.set_cellv(dest_loc, multipliermap.tile_set.find_tile_by_name(str(multiplier_val)));
		elif (event[0] == "gain_hp"):
			hero_hp -= event[1];
		elif (event[0] == "gain_atk"):
			hero_atk -= event[1];
		elif (event[0] == "gain_def"):
			hero_def -= event[1];
		
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
	
	if (multiplier_val > 1):
		hoversprite2.texture = multipliermap.tile_set.tile_get_texture(multiplier_dest);
	
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	
	hoverinfo.text = name_thing(dest_name, multiplier_val);
	
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

func name_thing(dest_name: String, multiplier_val: int) -> String:
	var result = "";
	
	if (("green" in dest_name) and not ("greenality" in dest_name)):
		result = "Green ";
		
	if ("player" in dest_name):
		result += "Player";
		
	if ("win" == dest_name):
		result += "Goal";
		
	if ("wall" in dest_name):
		result += "Wall";
		
	if ("potion" in dest_name):
		result += "Potion";
		
	if ("sword" in dest_name):
		result += "Sword";
	
	if ("shield" in dest_name):
		result += "Shield";
		
	if ("enemy1" in dest_name):
		result += "Guard";
		
	if ("fire" in dest_name):
		result += "Fire";
		
	if ("slime" in dest_name):
		result += "Slime";
		
	if ("teeth" in dest_name):
		result += "Teeth";
		
	if ("greenality" in dest_name):
		result += "Greenality";
		
	if ("pickaxe" in dest_name):
		result += "Pickaxe";
		
	if ("warpwings" in dest_name):
		result += "Warp Wings";
		
	if ("magicmirror" in dest_name):
		result += "Magic Mirror";
	
	if (multiplier_val > 1):
		result += "(x" + str(multiplier_val) + ")"
	
	return result;

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
