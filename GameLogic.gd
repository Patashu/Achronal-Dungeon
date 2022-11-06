extends Node
class_name GameLogic

onready var multipliermap : TileMap = get_node("/root/PlayingField/MultiplierMap");
onready var actormap : TileMap = get_node("/root/PlayingField/ActorMap");
onready var floormap : TileMap = get_node("/root/PlayingField/FloorMap");
onready var inventorymap : TileMap = get_node("/root/PlayingField/InventoryMap");
onready var heroinfo : Label = get_node("/root/PlayingField/HeroInfo");
onready var lastmessage : Label = get_node("/root/PlayingField/LastMessage");
onready var hoverinfo : Label = get_node("/root/PlayingField/HoverInfo");
onready var hoversprite : Sprite = get_node("/root/PlayingField/HoverSprite");
onready var hoversprite2 : Sprite = get_node("/root/PlayingField/HoverSprite2");
var hero_loc : Vector2 = Vector2.ZERO;
var hero_loc_start : Vector2 = Vector2.ZERO;
var hero_hp : int = 100;
var hero_hp_start : int = 100;
var hero_atk : int = 1;
var hero_atk_start : int = 1;
var hero_def : int = 0;
var hero_def_start : int = 0;
var hero_turn : int = 0;
var hero_keypresses : int = 0;
var has_won : bool = false;
var undo_buffer : Array = [];
var meta_undo_buffer : Array = [];
var greenality_max : int = 0;
var greenality_avail : int = 0;
var pickaxes : int = 0;
var warpwings : int = 0;
var keys : int = 0;
var green_tutorial_message_seen : bool = false;
var greenality_tutorial_message_seen : bool = false;
var inventory_width : int = 7;
var map_x_max : int = 0; # 31
var map_y_max : int = 0; # 20
var action_primed = false;
var greenality_timer = 0;
var green_hero = false;
var wallhack = false;

func _ready() -> void:
	# setup hero info
	var hero_id = actormap.tile_set.find_tile_by_name("Player");
	var hero_tile = actormap.get_used_cells_by_id(hero_id)[0];
	hero_loc = hero_tile;
	hero_loc_start = hero_loc;
	update_hero_info();
	calculate_map_size();
	print_message("Welcome to the Achronal Dungeon! wasd/arrows to move, z to undo, r to restart, mouse to inspect.")

func calculate_map_size() -> void:
	var tiles = floormap.get_used_cells();
	for tile in tiles:
		if tile.x > map_x_max:
			map_x_max = tile.x;
		if tile.y > map_y_max:
			map_y_max = tile.y;

func update_hero_info() -> void:
	heroinfo.text = "HP: " + str(hero_hp) + "\r\n";
	heroinfo.text += "ATK: " + str(hero_atk) + "\r\n";
	heroinfo.text += "DEF: " + str(hero_def) + "\r\n";
	if (hero_turn != hero_keypresses):
		heroinfo.text += "Turn: " + str(hero_turn) + " (" + str(hero_keypresses) + ")" + "\r\n";
	else:
		heroinfo.text += "Turn: " + str(hero_turn) + "\r\n";
	update_inventory();
	
func update_inventory() -> void:
	inventorymap.clear();
	var i = 0;
	for k in range(keys):
		inventorymap.set_cellv(Vector2(i % inventory_width, floor(i / inventory_width)),
		inventorymap.tile_set.find_tile_by_name("Key"));
		i += 1;
	for k in range(pickaxes):
		inventorymap.set_cellv(Vector2(i % inventory_width, floor(i / inventory_width)),
		inventorymap.tile_set.find_tile_by_name("Pickaxe"));
		i += 1;
	for k in range(warpwings):
		inventorymap.set_cellv(Vector2(i % inventory_width, floor(i / inventory_width)),
		inventorymap.tile_set.find_tile_by_name("Warpwings"));
		i += 1;
	for k in range(greenality_avail):
		inventorymap.set_cellv(Vector2(i % inventory_width, floor(i / inventory_width)),
		inventorymap.tile_set.find_tile_by_name("Greenality"));
		i += 1;

func move_hero(dir: Vector2, warp = false) -> bool:
	# check multiplier, actor and floor at destination
	# note: for now I'm putting only the player in the actor layer...
	# and ONLY because the player might overlap things (most notably the goal)
	var dest_loc = hero_loc + dir;
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var actor_dest = actormap.get_cellv(dest_loc);
	var floor_dest = floormap.get_cellv(dest_loc);
	var multiplier_val = multiplier_id_to_number(multiplier_dest);
	var can_move = false;
	var dest_to_use = actor_dest;
	if (dest_to_use == -1):
		dest_to_use = floor_dest;
	var dest_name = "";
	if (dest_to_use > -1):
		dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	# no going out of bounds, please
	if (dest_loc.x < 0 || dest_loc.x > map_x_max || dest_loc.y < 0 || dest_loc.y > map_y_max):
		print_message("Space and time don't exist out of bounds, sorry.")
		return false;
	if ("wall" in dest_name):
		if (pickaxes > 0):
			print_message("You dig through the wall.");
			var is_green = "green" in dest_name;
			add_undo_event(["gain_pickaxe", -1], false);
			pickaxes -= 1;
			add_undo_event(["destroy", dest_loc, dest_name, multiplier_val], is_green);
			floormap.set_cellv(dest_loc, -1);
			multipliermap.set_cellv(dest_loc, -1);
			can_move = true;
		elif wallhack:
			print_message("DEBUG: Wallhack is on.");
			can_move = true;
		else:
			print_message("You bump into the wall.");
			can_move = false;
	if ("lock" in dest_name):
		if (keys > 0):
			print_message("You open the lock.");
			var is_green = "green" in dest_name;
			add_undo_event(["gain_key", -1], false);
			keys -= 1;
			add_undo_event(["destroy", dest_loc, dest_name, multiplier_val], is_green);
			floormap.set_cellv(dest_loc, -1);
			multipliermap.set_cellv(dest_loc, -1);
			can_move = true;
		else:
			print_message("You need a key to open this lock.");
			can_move = false;
	if ("magicmirror" in dest_name):
		print_message("You see your reflection in the mirror!")
		can_move = false;
	# empty tile's fine to move into
	if (actor_dest == -1 && floor_dest == -1):
		can_move = true;
	if ("potion" in dest_name) or ("sword" in dest_name) or ("shield" in dest_name) or ("pickaxe" in dest_name) or ("warpwings" in dest_name) or ("key" in dest_name):
		can_move = true;
		consume_item(dest_loc);
	if ("greenality" in dest_name):
		can_move = true;
		consume_greenality(dest_loc);
	if ("enemy" in dest_name):
		var enemy_stats = monster_helper(dest_name, multiplier_val);
		if (enemy_stats[2] > hero_hp):
			can_move = false;
			print_message("Fighting this " + name_thing(dest_name, multiplier_val) + " costs " + str(enemy_stats[2]) + " HP.");
		else:
			can_move = true;
			consume_item(dest_loc);
	if ("win" == dest_name):
		can_move = true;
		win(dest_loc);
	if (can_move):
		if (warp):
			add_undo_event(["gain_warpwings", -1], false);
			warpwings -= 1;
			print_message("Warped!");
		move_hero_commit(dir);
	return can_move;
		
func win(dest_loc: Vector2) -> void:
	var west = floormap.get_cellv(dest_loc + Vector2.LEFT);
	var north = floormap.get_cellv(dest_loc + Vector2.UP);
	var south = floormap.get_cellv(dest_loc + Vector2.DOWN);
	var message = "You have won! "
	if (green_hero):
		message += "GREEN ENDING."
	elif west == -1:
		message += "HEROIC ENDING."
	elif north == -1 or south == -1:
		message += "TUNNEL ENDING."
	else:
		message += "ASCENT ENDING."
	message += " (There are 4 endings.) Undo, restart or meta-restart to continue playing."
	print_message(message)
	has_won = true;
	add_undo_event(["win"]);
		
func consume_greenality(dest_loc: Vector2) -> void:
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var multiplier_val = multiplier_id_to_number(multiplier_dest);
	var dest_to_use = floormap.get_cellv(dest_loc);
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	# so meta it doesn't even make a meta undo event
	floormap.set_cellv(dest_loc, -1);
	multipliermap.set_cellv(dest_loc, -1);
	greenality_avail += 1;
	greenality_max += 1;
	greenality_timer += 1;
	print_message("Use X+dir to turn something GREEN forever. Meta restart with ESC to refund Greenalities.");
		
func consume_item(dest_loc: Vector2) -> void:
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var multiplier_val = multiplier_id_to_number(multiplier_dest);
	var dest_to_use = floormap.get_cellv(dest_loc);
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	var is_green = "green" in dest_name;
	add_undo_event(["destroy", dest_loc, dest_name, multiplier_val], is_green);
	floormap.set_cellv(dest_loc, -1);
	multipliermap.set_cellv(dest_loc, -1);
	var message = "";
	if ("potion" in dest_name):
		add_undo_event(["gain_hp", multiplier_val], is_green);
		hero_hp += multiplier_val;
		message = "You drink the " + name_thing(dest_name, multiplier_val) + " and gain " + str(multiplier_val) + " HP!";
	elif ("sword" in dest_name):
		add_undo_event(["gain_atk", multiplier_val], is_green);
		hero_atk += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + " and gain " + str(multiplier_val) + " ATK!";
	elif ("shield" in dest_name):
		add_undo_event(["gain_def", multiplier_val], is_green);
		hero_def += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + " and gain " + str(multiplier_val) + " DEF!";
	elif ("pickaxe" in dest_name):
		add_undo_event(["gain_pickaxe", multiplier_val], is_green);
		pickaxes += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + "! Bump wall to use.";
	elif ("warpwings" in dest_name):
		add_undo_event(["gain_warpwings", multiplier_val], is_green);
		warpwings += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + "! X to use.";
	elif ("key" in dest_name):
		add_undo_event(["gain_key", multiplier_val], is_green);
		keys += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + "! Bump lock to use.";
	elif ("enemy" in dest_name):
		# only come here if we can win the fight
		var enemy_stats = monster_helper(dest_name, multiplier_val);
		# the wounds from fighting a green monster are NOT green
		add_undo_event(["gain_hp", -enemy_stats[2]], false);
		hero_hp -= enemy_stats[2];
		message = "You kill the " + name_thing(dest_name, multiplier_val) + ", losing " + str(enemy_stats[2]) + " HP.";
	if (is_green and !green_tutorial_message_seen):
		green_tutorial_message_seen = true;
		message += " GREEN changes persist through undo (z) and restart (r)."
		pass
	print_message(message);
		
func move_hero_commit(dir: Vector2) -> void:
	add_undo_event(["move", hero_loc]);
	move_hero_silently(dir);
	hero_turn += 1;
	hero_keypresses += 1;
	update_hero_info();

func move_hero_silently(dir: Vector2) -> void:
	var id = actormap.get_cellv(hero_loc);
	actormap.set_cellv(hero_loc, -1);
	hero_loc += dir;
	actormap.set_cellv(hero_loc, id);

func try_warp_wings() -> void:
	if (warpwings <= 0):
		return;
	# the formula is basically, mirror across the x axis, then mirror across the y axis.
	# 0 1 2 3 -> 0 becomes 3, 1 becomes 2
	# 0 1 2 3 4 -> 0 becomes 4, 1 becomes 3, 2 becomes 2
	var dest_loc = Vector2(map_x_max - hero_loc.x, map_y_max - hero_loc.y);
	var dir = dest_loc - hero_loc;
	move_hero(dir, true);

func try_greenality(dir: Vector2) -> void:
	if (greenality_avail <= 0):
		return;
	var dest_loc = hero_loc + dir;
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var actor_dest = actormap.get_cellv(dest_loc);
	var floor_dest = floormap.get_cellv(dest_loc);
	var multiplier_val = multiplier_id_to_number(multiplier_dest);
	var can_move = false;
	var dest_to_use = actor_dest;
	if (dest_to_use == -1):
		dest_to_use = floor_dest;
	var dest_name = "";
	if (dest_loc.x < 0 || dest_loc.x > map_x_max || dest_loc.y < 0 || dest_loc.y > map_y_max):
		print_message("You can't make the infinite void GREEN.")
		return;
	if (dest_to_use > -1):
		dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	else:
		print_message("You can't make the air GREEN.");
		return;
	
	if ("greenality" in dest_name):
		print_message("Sorry, that would tear a hole in spacetime, consuming you in the process.");
		return;
	
	var is_green = "green" in dest_name;
	if (is_green):
		print_message("It's already as GREEN as it gets.");
		return;
	
	if ("magicmirror" in dest_name):
		print_message("The GREEN bounces off the Magic Mirror and affects you!")
		add_undo_event(["dummy"], false);
		add_undo_event(["green_player"], true);
		actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("Greenplayer"));
		green_hero = true;
		greenality_timer += 1;
		greenality_avail -= 1;
		hero_turn += 1;
		hero_keypresses += 1;
		update_hero_info();
		return;
		
	if ("win" == dest_name):
		print_message("You can't make the Goal GREEN. (Good job taking a Greenality to it though!)")
		return;
	
	# Everything else? Fair game, and should be the same code.
	add_undo_event(["dummy"], false);
	add_undo_event(["greenify", dest_loc], true);
	floormap.set_cellv(dest_loc, floormap.tile_set.find_tile_by_name("Green" + dest_name));
	greenality_timer += 0.5;
	greenality_avail -= 1;
	print_message("The " + name_thing(dest_name, multiplier_val) + " is now GREEN.");
	hero_turn += 1;
	hero_keypresses += 1;
	update_hero_info();

func add_undo_event(event: Array, is_green = false) -> void:
	if (!is_green):
		if (undo_buffer.size() <= hero_turn):
			undo_buffer.append([]);
		undo_buffer[hero_turn].push_front(event);
	else:
		meta_undo_buffer.push_front(event);

func print_message(message: String)-> void:
	lastmessage.text = message;

func meta_restart() -> void:
	restart();
	# fine as long as doing undo and meta undo events in arbitrary order commutes.
	# might get weird with Green Player, I'll have to test some things or maybe just hard code it.
	for event in meta_undo_buffer:
		undo_one_event(event);
	meta_undo_buffer = [];
	# post green player fixups
	move_hero_silently(hero_loc_start - hero_loc);
	hero_hp = hero_hp_start;
	hero_atk = hero_atk_start;
	hero_def = hero_def_start;
	hero_keypresses = 0;
	greenality_avail = greenality_max;
	update_hero_info();

func restart() -> void:
	var hero_keypresses_temp = hero_keypresses;
	while (hero_turn > 0):
		undo();
	hero_keypresses = hero_keypresses_temp + 1;
	update_hero_info();

func undo() -> void:
	if (hero_turn <= 0):
		return
	var events = undo_buffer.pop_back();
	for event in events:
		undo_one_event(event);
		
	hero_turn -= 1;
	hero_keypresses += 1;
	update_hero_info();

func undo_one_event(event: Array) -> void:
	if (event[0] == "move" and !green_hero):
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
	elif (event[0] == "greenify"):
		var dest_loc = event[1];
		var floor_dest = floormap.get_cellv(dest_loc);
		var dest_to_use = floor_dest;
		var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
		dest_name = dest_name.trim_prefix("green");
		floormap.set_cellv(dest_loc, floormap.tile_set.find_tile_by_name(dest_name.capitalize()));
	elif (event[0] == "green_player"):
		green_hero = false;
		actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("Player"));
	elif (event[0] == "gain_hp" and !green_hero):
		hero_hp -= event[1];
	elif (event[0] == "gain_atk" and !green_hero):
		hero_atk -= event[1];
	elif (event[0] == "gain_def" and !green_hero):
		hero_def -= event[1];
	elif (event[0] == "gain_pickaxe"):
		pickaxes -= event[1];
	elif (event[0] == "gain_warpwings"):
		warpwings -= event[1];
	elif (event[0] == "gain_key"):
		keys -= event[1];

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
		
	if ("key" in dest_name):
		hoverinfo.text += "\nAllows you to open one lock.";
		
	if ("lock" in dest_name):
		hoverinfo.text += "\nTakes one key to open.";
	
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
		
	if ("guard" in dest_name):
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
		
	if ("key" in dest_name):
		result += "Key";
		
	if ("lock" in dest_name):
		result += "Lock";
	
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
	elif "guard" in name:
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
	if (greenality_timer > 0):
		greenality_timer -= delta;
	update_hover_info();
	if (Input.is_action_just_pressed("wallhack")):
		print_message("DEBUG: Wallhack toggled.")
		wallhack = !wallhack;
	if (Input.is_action_just_pressed("undo")):
		undo();
	if (Input.is_action_just_pressed("restart")):
		restart();
	if (Input.is_action_just_pressed("meta_restart")):
		meta_restart();
	if (has_won):
		return;
		
	if (Input.is_action_just_pressed("action")):
		action_primed = true;
	if (Input.is_action_just_released("action")):
		if (action_primed):
			try_warp_wings();
			action_primed = false;
		else:
			pass
			# user did a greenality
	var dir = Vector2.ZERO;
	if (Input.is_action_just_pressed("ui_left")):
		dir = Vector2.LEFT;
	if (Input.is_action_just_pressed("ui_right")):
		dir = Vector2.RIGHT;
	if (Input.is_action_just_pressed("ui_up")):
		dir = Vector2.UP;
	if (Input.is_action_just_pressed("ui_down")):
		dir = Vector2.DOWN;
		
	if dir != Vector2.ZERO:
		if (action_primed):
			try_greenality(dir);
			action_primed = false;
		else:
			move_hero(dir);
