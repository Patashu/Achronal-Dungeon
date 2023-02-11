extends Node
class_name GameLogic

onready var playingfield : Node2D = get_node("/root/PlayingField");
onready var multipliermap : TileMap = get_node("/root/PlayingField/MultiplierMap");
onready var actormap : TileMap = get_node("/root/PlayingField/ActorMap");
onready var floormap : TileMap = get_node("/root/PlayingField/FloorMap");
onready var residuemap : TileMap = get_node("/root/PlayingField/ResidueMap");
onready var inventorymap : TileMap = get_node("/root/PlayingField/InventoryMap");
onready var heroinfo : Label = get_node("/root/PlayingField/HeroInfo");
onready var lastmessage : Label = get_node("/root/PlayingField/LastMessage");
onready var hoverinfo : Label = get_node("/root/PlayingField/HoverInfo");
onready var hoverinfo2 : Label = get_node("/root/PlayingField/HoverInfo2");
onready var hoversprite : Sprite = get_node("/root/PlayingField/HoverSprite");
onready var hoversprite2 : Sprite = get_node("/root/PlayingField/HoverSprite2");
onready var locationinfo : Label = get_node("/root/PlayingField/LocationInfo");
onready var youareheresign : Label = get_node("/root/PlayingField/YouAreHereSign");
onready var soundon : Sprite = get_node("/root/PlayingField/Soundon");
onready var pauseon : Sprite = get_node("/root/PlayingField/Pauseon");
onready var warpwingspreview1 : Sprite = get_node("/root/PlayingField/WarpWingsPreview1");
onready var warpwingspreview2 : Sprite = get_node("/root/PlayingField/WarpWingsPreview2");
onready var greenalitypreview1 : Sprite = get_node("/root/PlayingField/GreenalityPreview1");
onready var greenalitypreview2 : Sprite = get_node("/root/PlayingField/GreenalityPreview2");
onready var greenalitypreview3 : Sprite = get_node("/root/PlayingField/GreenalityPreview3");
onready var greenalitypreview4 : Sprite = get_node("/root/PlayingField/GreenalityPreview4");
onready var greenalitypreview5 : Sprite = get_node("/root/PlayingField/GreenalityPreview5");
var hero_loc : Vector2 = Vector2.ZERO;
var hero_loc_start : Vector2 = Vector2.ZERO;
var hero_hp : int = 80;
var hero_hp_start : int = 80;
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
var headbands: int = 0;
var green_tutorial_message_seen : bool = false;
var greenality_tutorial_message_seen : bool = false;
var inventory_width : int = 7;
var map_x_max : int = 0; # 31
var map_y_max : int = 0; # 20
var action_primed = false;
var action_primed_time = 0;
var timer = 0;
var greenality_timer = 0;
var winning_timer = 0;
var green_hero = false;
var wallhack = false;
var sounds = {}
var speakers = [];
var muted = false;
var paused = false;
var last_info_loc = Vector2(99, 99);
var tutorial_substate = 0;
var astar := AStar2D.new()
var step_sfx_played_this_frame = false;
var secret_endings = {};
var ever_used_warp_wings = false;
var pickaxe_this_meta_restart = false;
var greenalities_acquired = [];

func _ready() -> void:
	# setup hero info
	var hero_id = actormap.tile_set.find_tile_by_name("Player");
	var hero_tile = actormap.get_used_cells_by_id(hero_id)[0];
	hero_loc = hero_tile;
	hero_loc_start = hero_loc;
	update_hero_info();
	calculate_map_size();
	prepare_audio();
	controls_tutorial();
	var how_many = how_many_greenalities_saved();
	if (how_many > 0):
		var loadsaveprompt = preload("res://LoadSavePrompt.tscn").instance()
		self.add_child(loadsaveprompt);
		loadsaveprompt.position = Vector2(112, 130);
		loadsaveprompt.amount = how_many;
		loadsaveprompt.connect("confirm_pressed", self, "load_game");
	print_message("Welcome to the Achronal Dungeon! You won't escape this time.")

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
	# unless the player is mousing over a monster or winning, 'fall off' the hover info to the controls
	if (!has_won and !("would lose" in hoverinfo.text)):
		controls_tutorial();
	else:
		last_info_loc = Vector2(99, 99); # to un-cache it
	
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
	for k in range(headbands):
		inventorymap.set_cellv(Vector2(i % inventory_width, floor(i / inventory_width)),
		inventorymap.tile_set.find_tile_by_name("Headband"));
		i += 1;
	for k in range(greenality_avail):
		inventorymap.set_cellv(Vector2(i % inventory_width, floor(i / inventory_width)),
		inventorymap.tile_set.find_tile_by_name("Greenality"));
		i += 1;

func prepare_audio() -> void:
	sounds["bump"] = preload("res://sfx/bump.ogg");
	sounds["dig"] = preload("res://sfx/dig.ogg");
	sounds["fly"] = preload("res://sfx/fly.ogg");
	sounds["getgreenality"] = preload("res://sfx/getgreenality.ogg");
	sounds["greeninteract"] = preload("res://sfx/greeninteract.ogg");
	sounds["greenplayer"] = preload("res://sfx/greenplayer.ogg");
	sounds["greensmall"] = preload("res://sfx/greensmall.ogg");
	sounds["key"] = preload("res://sfx/key.ogg");
	sounds["kill"] = preload("res://sfx/kill.ogg");
	sounds["metarestart"] = preload("res://sfx/metarestart.ogg");
	sounds["pickup"] = preload("res://sfx/pickup.ogg");
	sounds["restart"] = preload("res://sfx/restart.ogg");
	sounds["step"] = preload("res://sfx/step.ogg");
	sounds["undo"] = preload("res://sfx/undo.ogg");
	sounds["unlock"] = preload("res://sfx/unlock.ogg");
	sounds["usegreenality"] = preload("res://sfx/usegreenality.ogg");
	sounds["wingreen"] = preload("res://sfx/wingreen.ogg");
	sounds["winnormal"] = preload("res://sfx/winnormal.ogg");
	sounds["winpickaxe"] = preload("res://sfx/winpickaxe.ogg");
	sounds["winwings"] = preload("res://sfx/winwings.ogg");
	
	for i in range (8):
		var speaker = AudioStreamPlayer.new();
		self.add_child(speaker);
		speakers.append(speaker);

func cut_sound() -> void:
	for speaker in speakers:
		speaker.stop();

func play_sound(sound: String) -> void:
	if muted:
		return;
	for speaker in speakers:
		if !speaker.playing:
			speaker.stream = sounds[sound];
			speaker.play();
			return;

func toggle_mute() -> void:
	muted = !muted;
	cut_sound();
	soundon.visible = !soundon.visible;
	
func toggle_pause() -> void:
	paused = !paused;
	pauseon.visible = !pauseon.visible;
	var fps = 1;
	if (paused):
		fps = 0;
	var tile_ids = floormap.tile_set.get_tiles_ids();
	for tile_id in tile_ids:
		var texture = floormap.tile_set.tile_get_texture(tile_id);
		if texture is AnimatedTexture:
			var animtex = texture as AnimatedTexture;
			animtex.fps = fps;

func move_hero(dir: Vector2, warp: bool = false, is_running: bool = false) -> bool:
	youareheresign.visible = false;
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
		play_sound("bump");
		return false;
	if ("wall" in dest_name and !is_running):
		if (pickaxes >= multiplier_val):
			print_message("You dig through the wall.");
			pickaxe_this_meta_restart = true;
			var is_green = "green" in dest_name;
			if (is_green): 
				play_sound("greeninteract");
			add_undo_event(["gain_pickaxe", -multiplier_val], false);
			pickaxes -= multiplier_val;
			add_undo_event(["destroy", dest_loc, dest_name, multiplier_val], is_green);
			floormap.set_cellv(dest_loc, -1);
			multipliermap.set_cellv(dest_loc, -1);
			can_move = true;
			play_sound("dig");
		elif wallhack:
			print_message("DEBUG: Wallhack is on.");
			can_move = true;
		else:
			print_message("You bump into the wall.");
			can_move = false;
	if ("steel" in dest_name and !is_running):
		print_message("The steel wall is impervious to your efforts.");
		can_move = false;
	if ("lock" in dest_name and !is_running):
		if (keys >= multiplier_val):
			print_message("You open the lock.");
			play_sound("unlock");
			var is_green = "green" in dest_name;
			if (is_green): 
				play_sound("greeninteract");
			add_undo_event(["gain_key", -multiplier_val], false);
			keys -= multiplier_val;
			add_undo_event(["destroy", dest_loc, dest_name, multiplier_val], is_green);
			floormap.set_cellv(dest_loc, -1);
			multipliermap.set_cellv(dest_loc, -1);
			can_move = true;
		else:
			if multiplier_val > 1:
				print_message("You need " + str(multiplier_val) + " keys to open this lock.");
			else:
				print_message("You need a key to open this lock.");
			can_move = false;
	if ("magicmirror" in dest_name):
		print_message("You see your reflection in the mirror!")
		can_move = false;
	# empty tile's fine to move into
	if (actor_dest == -1 && floor_dest == -1):
		can_move = true;
	if ("potion" in dest_name) or ("sword" in dest_name) or ("shield" in dest_name) or ("pickaxe" in dest_name) or ("warpwings" in dest_name) or ("key" in dest_name) or ("headband" in dest_name):
		can_move = true;
		consume_item(dest_loc);
		if ("key" in dest_name):
			play_sound("key");
		else:
			play_sound("pickup");
	if ("greenality" in dest_name):
		can_move = true;
		consume_greenality(dest_loc);
		play_sound("getgreenality");
	if ("enemy" in dest_name and !is_running):
		var enemy_stats = monster_helper(dest_name, multiplier_val);
		if (enemy_stats[2] >= hero_hp):
			can_move = false;
			if (tutorial_substate == 1):
				print_message("You're not strong enough to win this fight without undoing (Z) or restarting (R)!");
			else:
				print_message("Fighting this " + name_thing(dest_name, multiplier_val) + " costs " + str(enemy_stats[2]) + " HP.");
		else:
			can_move = true;
			consume_item(dest_loc);
			play_sound("kill");
	if ("win" == dest_name):
		can_move = true;
		win(dest_loc);
	if (can_move):
		if (warp):
			tutorial_substate = max(tutorial_substate, 6);
			add_undo_event(["gain_warpwings", -1], false);
			warpwings -= 1;
			ever_used_warp_wings = true;
			if (!has_won):
				print_message("Warped!");
			play_sound("fly");
		elif (!is_running):
			if (!step_sfx_played_this_frame):
				play_sound("step");
				step_sfx_played_this_frame = true;
		move_hero_commit(dir);
	elif (!is_running):
		play_sound("bump");
	return can_move;
		
func win(dest_loc: Vector2) -> void:
	cut_sound();
	winning_timer = 5;
	if (green_hero):
		actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("GreenplayerWin"));
	else:
		actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("PlayerWin"));
	var west = floormap.get_cellv(dest_loc + Vector2.LEFT);
	var north = floormap.get_cellv(dest_loc + Vector2.UP);
	var south = floormap.get_cellv(dest_loc + Vector2.DOWN);
	var message = "You have won! "
	if (green_hero):
		message += "GREEN ENDING."
		play_sound("wingreen");
	elif west == -1:
		message += "HEROIC ENDING."
		play_sound("winnormal");
	elif north == -1 or south == -1:
		message += "TUNNEL ENDING."
		play_sound("winpickaxe");
	else:
		message += "ASCENT ENDING."
		play_sound("winwings");
	message += " (There are 4 endings.) Undo, restart or meta-restart to continue playing."
	print_message(message)
	has_won = true;
	add_undo_event(["win"]);
	check_secret_endings();
	
func check_secret_endings() -> void:
	if (hero_turn < 1):
		secret_endings["TELEPORT"] = true;
	if (hero_turn < 60 and !green_hero):
		secret_endings["SPEEDRUN"] = true;
	if (hero_keypresses < 196):
		secret_endings["TIMERUN"] = true;
	var greenality_used = greenality_max - greenality_avail;
	if (greenality_used <= 2):
		secret_endings["SMUGGLER"] = true;
	if (hero_hp <= 1):
		secret_endings["OUCH"] = true;
	if (hero_hp >= 1796 and !green_hero):
		secret_endings["MAX HP"] = true;
	if (hero_atk >= 94 and !green_hero):
		secret_endings["MAX ATK"] = true;
	if (hero_def >= 73 and !green_hero):
		secret_endings["MAX DEF"] = true;
	if (!ever_used_warp_wings):
		secret_endings["GROUNDED"] = true;
	if (!pickaxe_this_meta_restart):
		secret_endings["INBOUNDS"] = true;
	var tiles = floormap.get_used_cells();
	var found_enemy = false;
	for tile in tiles:
		var name = floormap.tile_set.tile_get_name(floormap.get_cellv(tile)).to_lower();
		if ("enemy" in name):
			found_enemy = true;
			break;
	if (!found_enemy):
		secret_endings["CATACLYSM"] = true;
		
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
	tutorial_substate = max(tutorial_substate, 3);
	greenalities_acquired.append(dest_loc);
	if (how_many_greenalities_saved() < greenalities_acquired.size()):
		save_game();
		
func save_game() -> void:
	var save_game = File.new()
	save_game.open("user://achronaldungeon.sav", File.WRITE)
	save_game.store_64(tutorial_substate);
	save_game.store_64(greenalities_acquired.size());
	for i in range(greenalities_acquired.size()):
		save_game.store_64(greenalities_acquired[i].x);
		save_game.store_64(greenalities_acquired[i].y);
	
func how_many_greenalities_saved() -> int:
	var save_game = File.new()
	save_game.open("user://achronaldungeon.sav", File.READ)
	var dummy = save_game.get_64();
	return save_game.get_64();
	
func load_game() -> void:
	var save_game = File.new()
	save_game.open("user://achronaldungeon.sav", File.READ)
	tutorial_substate = save_game.get_64();
	var amount = save_game.get_64();
	for i in range(amount):
		consume_greenality(Vector2(save_game.get_64(), save_game.get_64()));
	ever_used_warp_wings = true; # TODO: or just save it
	if greenality_timer >= 1:
		greenality_timer = 1;
		play_sound("getgreenality");
	update_hero_info();
		
func consume_item(dest_loc: Vector2) -> void:
	var multiplier_dest = multipliermap.get_cellv(dest_loc);
	var multiplier_val = multiplier_id_to_number(multiplier_dest);
	var dest_to_use = floormap.get_cellv(dest_loc);
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	var is_green = "green" in dest_name;
	if (is_green): 
		play_sound("greeninteract");
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
	elif ("headband" in dest_name):
		add_undo_event(["gain_headband", multiplier_val], is_green);
		headbands += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + " and prepare to train.";
	elif ("warpwings" in dest_name):
		add_undo_event(["gain_warpwings", multiplier_val], is_green);
		warpwings += multiplier_val;
		message = "You take the " + name_thing(dest_name, multiplier_val) + "! X to use.";
		tutorial_substate = max(tutorial_substate, 5);
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
		message = "You kill the " + name_thing(dest_name, multiplier_val) + ", losing " + str(enemy_stats[2]) + " HP";
		if (headbands > 0):
			if (hero_atk < enemy_stats[0]):
				add_undo_event(["gain_atk", headbands], false);
				hero_atk += headbands;
				message += ", gaining " + str(headbands) + " ATK"
				if (hero_def < enemy_stats[1]):
					add_undo_event(["gain_def", headbands], false);
					hero_def += headbands;
					message += " and " + str(headbands) + " DEF"
		message += ".";
	if (is_green and !green_tutorial_message_seen):
		green_tutorial_message_seen = true;
		tutorial_substate = max(tutorial_substate, 1);
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
		
	if ("steel" in dest_name):
		print_message("You can't turn steel walls GREEN.");
		return;
	
	var is_green = "green" in dest_name;
	if (is_green):
		print_message("It's already as GREEN as it gets.");
		return;
	
	if ("magicmirror" in dest_name):
		if (green_hero):
			print_message("You FEAR what might happen if you become any more GREEN...");
			return;
		else:
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
			play_sound("greenplayer");
			tutorial_substate = max(tutorial_substate, 4);
			return;
		
	if ("win" == dest_name):
		print_message("You can't make the Goal GREEN. (You CAN get a secret ending though!)")
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
	play_sound("usegreenality");
	tutorial_substate = max(tutorial_substate, 4);

func add_undo_event(event: Array, is_green = false) -> void:
	if (!is_green):
		if (undo_buffer.size() <= hero_turn):
			undo_buffer.append([]);
		undo_buffer[hero_turn].push_front(event);
	else:
		if (event[0] == "destroy"):
			residuemap.set_cellv(event[1], residuemap.tile_set.find_tile_by_name("Residue"));
		meta_undo_buffer.push_front(event);

func print_message(message: String)-> void:
	lastmessage.text = message;

func meta_restart() -> void:
	residuemap.clear();
	pickaxe_this_meta_restart = false;
	restart(true);
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
	play_sound("metarestart");

func restart(is_silent: bool = false) -> void:
	var hero_keypresses_temp = hero_keypresses;
	while (hero_turn > 0):
		undo(true);
	hero_keypresses = hero_keypresses_temp + 1;
	update_hero_info();
	if (!is_silent):
		play_sound("restart");

func undo(is_silent: bool = false) -> bool:
	if (hero_turn <= 0):
		return true;
	var events = undo_buffer.pop_back();
	var stateful = false;
	for event in events:
		var dummy = undo_one_event(event);
		stateful = stateful or dummy;
		
	hero_turn -= 1;
	hero_keypresses += 1;
	update_hero_info();
	if (!is_silent):
		play_sound("undo");
	return stateful;

func undo_one_event(event: Array) -> bool:
	var stateful = true;
	if (event[0] == "move"):
		stateful = false;
		if !green_hero:
			move_hero_silently(event[1] - hero_loc);
		else:
			play_sound("greensmall");
	elif (event[0] == "win"):
		has_won = false;
		secret_endings.clear();
		winning_timer = 0;
		actormap.modulate = Color(1, 1, 1, 1);
		if (green_hero):
			actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("Greenplayer"));
		else:
			actormap.set_cellv(hero_loc, actormap.tile_set.find_tile_by_name("Player"));
		cut_sound();
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
	elif (event[0] == "gain_hp"):
		if !green_hero:
			hero_hp -= event[1];
		else:
			play_sound("greensmall");
	elif (event[0] == "gain_atk"):
		if !green_hero:
			hero_atk -= event[1];
		else:
			play_sound("greensmall");
	elif (event[0] == "gain_def"):
		if !green_hero:
			hero_def -= event[1];
		else:
			play_sound("greensmall");
	elif (event[0] == "gain_pickaxe"):
		pickaxes -= event[1];
	elif (event[0] == "gain_headband"):
		headbands -= event[1];
	elif (event[0] == "gain_warpwings"):
		warpwings -= event[1];
	elif (event[0] == "gain_key"):
		keys -= event[1];
	return stateful;

func controls_tutorial() -> void:
	if (has_won):
		return;
	# 0: start of game
	# 1: just picked up green sword
	# 2: has used undo or restart
	# 3: has picked up greenality
	# 4: has used greenality
	# 5: has picked up warp wings
	# 6: has used warp wings
	hoverinfo.text = "Controls:\n"
	hoverinfo.text += "WASD or Mouse to Move\n"
	hoverinfo.text += "Mouse Over to Inspect\n"
	hoverinfo2.text = hoverinfo.text;
	if (tutorial_substate >= 1):
		hoverinfo2.text += "Z to Undo\n"
		hoverinfo2.text += "R to Restart\n"
	if (tutorial_substate >= 2):
		hoverinfo.text += "Z to Undo\n"
		hoverinfo.text += "R to Restart\n"
	if (tutorial_substate >= 3):
		hoverinfo2.text += "X+Dir to Use Greenality\n"
		hoverinfo2.text += "Esc to Meta-Restart (refunding Greenalities)\n"
	if (tutorial_substate >= 4):
		hoverinfo.text += "X+Dir to Use Greenality\n"
		hoverinfo.text += "Esc to Meta-Restart (refunding Greenalities)\n"
	if (tutorial_substate >= 5):
		hoverinfo2.text += "X to Use Warp Wings\n"
	if (tutorial_substate >= 6):
		hoverinfo.text += "X to Use Warp Wings\n"

func credits_and_secret_endings() -> void:
	hoverinfo.text = "CREDITS:\n\nPatashu: Concept, programming, level design, SFX\n\nArt: RoxxyRobofox#6767\n\nPlaytesters: VoxSomniator"
	hoverinfo2.text = "\n\n\n\n\n\n\n\n\n\n\n\n";
	var first_printed = false;
	for secret in secret_endings.keys():
		if (!first_printed):
			hoverinfo2.text += "SECRET ENDING: "
			first_printed = true;
		else:
			hoverinfo2.text += ", "
		hoverinfo2.text += secret;

func update_hover_info() -> void:
	# for the first second of the game, don't show anything but the controls
	if (timer < 1):
		controls_tutorial();
		return;
	
	var dest_loc = floormap.world_to_map(get_viewport().get_mouse_position());
	if (dest_loc == last_info_loc):
		return
	else:
		last_info_loc = dest_loc;
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
	hoverinfo2.text = "";
	
	if !(dest_loc.x < 0 || dest_loc.x > map_x_max || dest_loc.y < 0 || dest_loc.y > map_y_max):
		locationinfo.text = "(" + str(dest_loc.x) + ", " + str(dest_loc.y) + ")";
	else:
		locationinfo.text = ""
	
	if (has_won):
		credits_and_secret_endings();
	
	if (dest_to_use >= 0):
		hoversprite.texture = floormap.tile_set.tile_get_texture(dest_to_use);
	else:
		controls_tutorial();
		return;
	
	# this is all gross. I guess I 'should' use json and helper functions and whatnot.
	
	if (multiplier_val > 1):
		hoversprite2.texture = multipliermap.tile_set.tile_get_texture(multiplier_dest);
	
	var dest_name = floormap.tile_set.tile_get_name(dest_to_use).to_lower();
	
	hoverinfo.text = name_thing(dest_name, multiplier_val);
	
	if ("player" in dest_name):
		hoverinfo.text += "\nIt's you!";
		
	if ("win" == dest_name):
		hoverinfo.text += "\nGet the Player here to escape the Achronal Dungeon!";
	
	if ("wall" in dest_name):
		if multiplier_val > 1:
			hoverinfo.text += "\nImpervious without *" + str(multiplier_val) + "* Pickaxes. (Sorry!)";
		else:
			hoverinfo.text += "\nImpervious without a Pickaxe.";
		
	if ("steel" in dest_name):
		hoverinfo.text += "\nA wall that can't be Pickaxed. (Sorry!)";
		
	if ("potion" in dest_name):
		hoverinfo.text += "\nIncreases your HP by " + str(multiplier_val) + ".";
		
	if ("sword" in dest_name):
		hoverinfo.text += "\nIncreases your ATK by " + str(multiplier_val) + ".";
	
	if ("shield" in dest_name):
		hoverinfo.text += "\nIncreases your DEF by " + str(multiplier_val) + ".";
		
	if ("enemy" in dest_name):
		var enemy_stats = monster_helper(dest_name, multiplier_val);
		hoverinfo.text += "\nHP: " + str(enemy_stats[0]);
		hoverinfo.text += "\nATK: " + str(enemy_stats[1]);
		hoverinfo.text += "\nYou would lose " + str(enemy_stats[2]) + " HP killing this.";
		if (enemy_stats[3] > 0):
			hoverinfo.text += "\n+" + str(enemy_stats[3]) + " ATK or +1 DEF would help!";
		
	if ("greenality" in dest_name):
		hoverinfo.text += "\nAllows you to permanently make something GREEN.";
		
	if ("pickaxe" in dest_name):
		hoverinfo.text += "\nAllows you to destroy one wall.";
		
	if ("headband" in dest_name):
		hoverinfo.text += "\nAfter combat, gain 1 ATK if you didn't win in one attack, and gain 1 DEF if you took damage.";
		
	if ("warpwings" in dest_name):
		hoverinfo.text += "\nActivate to warp to the opposite tile of the map.";
		
	if ("magicmirror" in dest_name):
		hoverinfo.text += "\nYou can see your reflection in this!";
		
	if ("key" in dest_name):
		hoverinfo.text += "\nAllows you to open one lock.";
		
	if ("lock" in dest_name):
		if multiplier_val > 1:
			hoverinfo.text += "\nTakes *" + str(multiplier_val) + "* keys to open.";
		else:
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
		
	if ("steel" in dest_name):
		result += "Steel Wall";
		
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
		
	if ("headband" in dest_name):
		result += "Headband";
		
	if ("warpwings" in dest_name):
		result += "Warp Wings";
		
	if ("magicmirror" in dest_name):
		result += "Magic Mirror";
		
	if ("key" in dest_name):
		result += "Key";
		
	if ("lock" in dest_name):
		result += "Lock";
	
	if (multiplier_val > 1):
		result += " (x" + str(multiplier_val) + ")"
	
	return result;

func add_green_reminder() -> void:
	hoverinfo.text += "\n\nInteracting with a Green thing persists through UNDO (z) and RESTART (r)."

func monster_helper(name: String, multiplier_val: int) -> Array:
	var result = [0, 0, 0, 0] # the fourth number is 'atk required to take less damage'
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
	var fractional_attacks = float(result[0])/float(hero_atk);
	var rounded_attacks = ceil(fractional_attacks);
	var hero_injury_per_counterattack = result[1]-hero_def;
	result[2] = max(0, (hero_injury_per_counterattack)*(rounded_attacks-1));
	if (result[2] > 0):
		# calculate next atk threshold
		# TODO: probably a one liner to do this but no need
		for i in range (100):
			var try_next_atk = hero_atk + i;
			var try_frac_attack = float(result[0])/float(try_next_atk);
			var try_round_attack = ceil(try_frac_attack);
			if (try_round_attack < rounded_attacks):
				result[3] = i;
				break;
		pass
	return result;

func multiplier_id_to_number(id: int) -> int:
	if (id == -1):
		return 1;
	var string_result = multipliermap.tile_set.tile_get_name(id);
	return int(string_result);

func try_greenality_mouse() -> void:
	var dest_loc = floormap.world_to_map(get_viewport().get_mouse_position());
	var dir = dest_loc - hero_loc;
	if (dir == Vector2.UP || dir == Vector2.DOWN || dir == Vector2.LEFT || dir == Vector2.RIGHT):
		try_greenality(dir);

func try_pathfind() -> void:
	var dest_loc = floormap.world_to_map(get_viewport().get_mouse_position());
	if (dest_loc.x < 0 || dest_loc.x > map_x_max || dest_loc.y < 0 || dest_loc.y > map_y_max):
		return
	astar.clear();
	# whee temporarily pretend the map is larger hack
	map_x_max = map_x_max + 1;
	map_y_max = map_y_max + 1;
	for j in range(map_y_max):
		for i in range(map_x_max):
			var pos = Vector2(i, j);
			var floor_pos = floormap.get_cellv(pos);
			if (floor_pos == -1 or pos == dest_loc or pos == hero_loc):
				astar.add_point(i + j*map_x_max, pos);
				# connect to the points 1 west and 1 north of us, if relevant
				if astar.has_point((i-1) + j*map_x_max):
					astar.connect_points(i + j*map_x_max, (i-1) + j*map_x_max);
				if astar.has_point(i + (j-1)*map_x_max):
					astar.connect_points(i + j*map_x_max, i + (j-1)*map_x_max);
	var hero_id = hero_loc.x + hero_loc.y*map_x_max;
	var dest_id = dest_loc.x + dest_loc.y*map_x_max;
	var id_array = astar.get_id_path(hero_id, dest_id);
	if (id_array.size() > 0):
		for ix in range(id_array.size()):
			var id = id_array[ix];
			dest_loc = Vector2(id % map_x_max, floor(id / map_x_max));
			var dir = dest_loc - hero_loc;
			if (dir != Vector2.ZERO):
				move_hero(dir, false, false);
	else:
		print_message("Couldn't pathfind to there.");
		play_sound("bump");
	map_x_max = map_x_max - 1;
	map_y_max = map_y_max - 1;

func action_previews_on() -> void:
	var offset = floormap.cell_size / 2;
	action_primed_time = timer;
	if (warpwings > 0):
		warpwingspreview1.visible = true;
		warpwingspreview2.visible = true;
		warpwingspreview1.texture = floormap.tile_set.tile_get_texture(floormap.tile_set.find_tile_by_name("Warpwings"));
		var tile = "Player";
		if (green_hero):
			tile = "Greenplayer";
		warpwingspreview2.texture = floormap.tile_set.tile_get_texture(floormap.tile_set.find_tile_by_name(tile));
		warpwingspreview1.position = floormap.map_to_world(hero_loc) + offset;
		var dest_loc = Vector2(map_x_max - hero_loc.x, map_y_max - hero_loc.y);
		warpwingspreview2.position = floormap.map_to_world(dest_loc) + offset;
	if (greenality_avail > 0):
		greenalitypreview1.visible = true;
		greenalitypreview1.texture = floormap.tile_set.tile_get_texture(floormap.tile_set.find_tile_by_name("Greenality"));
		greenalitypreview1.position = floormap.map_to_world(hero_loc) + offset;
		var previews = [greenalitypreview2, greenalitypreview3, greenalitypreview4, greenalitypreview5];
		var dirs = [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP];
		for i in range(4):
			var preview = previews[i];
			var dir = dirs[i];
			var dest_loc = hero_loc + dir;
			var floor_dest = floormap.get_cellv(dest_loc);
			if (floor_dest > -1):
				var dest_name = floormap.tile_set.tile_get_name(floor_dest).to_lower();
				if (dest_name == "magicmirror" and !green_hero):
					dest_name = "player";
				var green_result = floormap.tile_set.find_tile_by_name("Green" + dest_name);
				if (green_result > -1):
					preview.visible = true;
					preview.texture = floormap.tile_set.tile_get_texture(green_result);
					preview.position = floormap.map_to_world(hero_loc) + offset + dir*offset*2;

func action_previews_off() -> void:
	warpwingspreview1.visible = false;
	warpwingspreview2.visible = false;
	greenalitypreview1.visible = false;
	greenalitypreview2.visible = false;
	greenalitypreview3.visible = false;
	greenalitypreview4.visible = false;
	greenalitypreview5.visible = false;

func action_previews_modulate() -> void:
	if (action_primed):
		var t = (sin((timer-action_primed_time)*10)+1)/2;
		warpwingspreview1.modulate = Color(t, t, t, t);
		warpwingspreview2.modulate = Color(t, t, t, t);
		greenalitypreview1.modulate = Color(t, t, t, t);
		greenalitypreview2.modulate = Color(t, t, t, t);
		greenalitypreview3.modulate = Color(t, t, t, t);
		greenalitypreview4.modulate = Color(t, t, t, t);
		greenalitypreview5.modulate = Color(t, t, t, t);

func _process(delta: float) -> void:
	timer += delta;
	if (greenality_timer > 0):
		greenality_timer -= delta;
	if (winning_timer > 0):
		winning_timer -= delta;
		var t = min(1, max(0, winning_timer/3));
		actormap.modulate = Color(t, t, t, t);
	step_sfx_played_this_frame = false;
	action_previews_modulate();
	update_hover_info();
	if (get_node_or_null("LoadSavePrompt") != null):
		return
	if (Input.is_action_just_pressed("mute") or (Input.is_action_just_pressed("ui_accept") and soundon.get_rect().has_point(soundon.to_local(get_viewport().get_mouse_position())))):
		toggle_mute();
	if (Input.is_action_just_pressed("pause_animations") or (Input.is_action_just_pressed("ui_accept") and pauseon.get_rect().has_point(pauseon.to_local(get_viewport().get_mouse_position())))):
		toggle_pause();
	if (Input.is_action_just_pressed("wallhack") and OS.is_debug_build()):
		print_message("DEBUG: Wallhack toggled.")
		wallhack = !wallhack;
	if (Input.is_action_just_pressed("undo")):
		tutorial_substate = max(tutorial_substate, 2);
		if (!Input.is_action_pressed("run_modifier")):
			var stateful = false;
			var is_silent = false;
			while !stateful:
				stateful = undo(is_silent);
				is_silent = true;
		else:
			undo();
	if (Input.is_action_just_pressed("restart")):
		tutorial_substate = max(tutorial_substate, 2);
		restart();
	if (Input.is_action_just_pressed("meta_restart")):
		tutorial_substate = max(tutorial_substate, 4);
		meta_restart();
	if (has_won):
		return;
		
	if (Input.is_action_just_pressed("pathfind_to")):
		if (action_primed):
			try_greenality_mouse();
			action_primed = false;
			action_previews_off();
		else:
			try_pathfind();
		
	if (Input.is_action_just_pressed("action")):
		action_primed = true;
		action_previews_on();
	if (Input.is_action_just_released("action")):
		if (action_primed):
			try_warp_wings();
			action_primed = false;
			action_previews_off();
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
			action_previews_off();
		else:
			if (Input.is_action_pressed("run_modifier")):
				var is_running = false;
				var result = true;
				while result:
					result = move_hero(dir, false, is_running);
					is_running = true;
			else:
				move_hero(dir);
