extends Node


var fullscreen = false
var file = "res://"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if Input.is_action_just_pressed("ui_cancel"):
		
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
	if Input.is_action_just_pressed("fullscreen"):
		fullscreen = !fullscreen
		
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	
	$CanvasLayer/Performance.text = "NE CE v1.1"
	$CanvasLayer/Performance.text += "\nFPS: " + str(Engine.get_frames_per_second())
	$CanvasLayer/Performance.text += "\nMEM: " + str( snapped( OS.get_static_memory_usage() / 1024.0 / 1024.0, 0.1 ) ) + " MB"
