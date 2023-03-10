extends Node2D

var chart_file = "res://"
var pressed = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	$ParallaxBackground.scroll_base_offset.x -= 32 * delta
	
	if !pressed:
		$UI/PopupMenu.visible = true


func _on_popup_menu_id_pressed(id):
	
	pressed = true
	
	if id == 0:
		
		get_tree().change_scene_to_file("res://scenes/create_chart.tscn")
	elif id == 1:
		
		$"UI/Open Chart File".visible = true
	elif id == 2:
		
		get_tree().change_scene_to_file("res://scenes/convert_chart.tscn")


func _on_open_chart_file_file_selected(path):
	
	Global.file = path
	get_tree().change_scene_to_file("res://scenes/chart_editor.tscn")
