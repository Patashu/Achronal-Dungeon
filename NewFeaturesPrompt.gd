extends Node2D
class_name NewFeaturesPrompt

onready var label = get_node("Label");
onready var confirm = get_node("ButtonConfirm");
signal confirm_pressed;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	confirm.connect("pressed", self, "_confirm_pressed");

func _confirm_pressed() -> void:
	emit_signal("confirm_pressed");
	self.queue_free();

func _cancel_pressed() -> void:
	emit_signal("cancel_pressed");
	self.queue_free();

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (Input.is_action_just_pressed("action")):
		_confirm_pressed();

func _draw() -> void:
	draw_rect(Rect2(-get_viewport().size.x, -get_viewport().size.y,
	get_viewport().size.x*2, get_viewport().size.y*2), Color(0, 0, 0, 0.5), true);
