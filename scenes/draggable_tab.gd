extends TabContainer

@export var offset = Vector2(640, 360)

var can_drag = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func _process(delta):
	
	if Input.is_action_pressed("drag_enable"):
		can_drag = true
	
	if Input.is_action_just_released("drag_enable"):
		can_drag = false

func _gui_input(event):
	
	if event is InputEventScreenDrag:
		if can_drag:
			self.global_position += event.relative
			self.global_position = self.global_position.clamp(Vector2(0 - offset.x, 0 - offset.y), Vector2(1280 - size.x - offset.x, 720 - size.y - offset.y))
