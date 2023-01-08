extends Node2D
class_name LoadSavePrompt

onready var label = get_node("Label");
onready var confirm = get_node("ButtonConfirm");
onready var cancel = get_node("ButtonCancel");
export var amount = 1;
var last_amount = 0;
signal confirm_pressed;
signal cancel_pressed;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	confirm.connect("pressed", self, "_confirm_pressed");
	cancel.connect("pressed", self, "_cancel_pressed");

func _confirm_pressed() -> void:
	emit_signal("confirm_pressed");
	self.queue_free();

func _cancel_pressed() -> void:
	emit_signal("cancel_pressed");
	self.queue_free();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if amount != last_amount:
		label.text = "You've collected " + str(amount) + " Greenalities before.\nContinue from there?"
		last_amount = amount;
	if (Input.is_action_just_pressed("action")):
		_confirm_pressed();
	if (Input.is_action_just_pressed("undo")):
		_cancel_pressed();

func _draw() -> void:
	draw_rect(Rect2(-get_viewport().size.x, -get_viewport().size.y,
	get_viewport().size.x*2, get_viewport().size.y*2), Color(0, 0, 0, 0.5), true);
