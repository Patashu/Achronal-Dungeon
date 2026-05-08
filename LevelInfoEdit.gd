extends Node2D
class_name LevelInfoEdit

onready var gamelogic = get_tree().get_root().find_node("GameLogic", true, false);
onready var holder : Control = get_node("Label");
onready var okbutton : Button = get_node("Label/ButtonConfirm");
onready var clearbutton : Button = get_node("Label/ButtonClear");
onready var hero_atk_start : SpinBox = get_node("Label/HeroAtkStart");
onready var hero_def_start : SpinBox = get_node("Label/HeroDefStart");
onready var hero_hp_start: SpinBox = get_node("Label/HeroHPStart");
onready var hero_loc_start : TextEdit = get_node("Label/HeroLocStart");
onready var level_name : TextEdit = get_node("Label/LevelName");
onready var level_author : TextEdit = get_node("Label/LevelAuthor");

func _ready() -> void:
	okbutton.connect("pressed", self, "destroy");
	clearbutton.connect("pressed", self, "clear");
	
	var parent = get_parent();
	
	hero_hp_start.value = parent.hero_hp_start;
	hero_atk_start.value = parent.hero_atk_start;
	hero_def_start.value = parent.hero_def_start;
	hero_loc_start.text = str(parent.hero_loc_start.x) + ", " + str(parent.hero_loc_start.y);
	level_name.text = parent.level_name;
	level_author.text = parent.level_author;

func clear() -> void:
	var parent = get_parent();
	parent.floormap.clear();
	parent.multipliermap.clear();
	parent.print_message("Dungeon bulldozed to make way for new development.")
	parent.meta_restart();

func destroy() -> void:
	var parent = get_parent();
	
	parent.hero_hp_start = int(hero_hp_start.value);
	parent.hero_atk_start = int(hero_atk_start.value);
	parent.hero_def_start = int(hero_def_start.value);
	var pos = hero_loc_start.text;
	pos = pos.trim_prefix("(");
	pos = pos.trim_suffix(")");
	pos = pos.split(",");
	var x = int(pos[0]);
	var y = int(pos[1]);
	parent.hero_loc_start = Vector2(x, y);
	parent.level_name = level_name.text;
	parent.level_author = level_author.text;
	parent.meta_restart();
	self.queue_free();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	draw_rect(Rect2(-get_viewport().size.x, -get_viewport().size.y,
	get_viewport().size.x*2, get_viewport().size.y*2), Color(0, 0, 0, 0.5), true);
