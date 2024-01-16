extends Node2D

@export_color_no_alpha var color = Color(1, 0, 0)
@export_range(0, 16, 0.1) var length = 0.0
@export var layer = 0
@export var time = 0.0

@export_group("Length Modifiers")
@export_range(0, 3, 0.1) var scroll_speed = 1.0

@export_group("Event Data")
@export var event_name = ""
@export var parameters = []

var zoom = Vector2(1, 1)
var on_screen = false

var offset = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
	
	$Event.modulate = color
	
	$Label.position.x += offset.x
	
	$Event.visible = on_screen
	$Outline.visible = on_screen
	$Label.visible = on_screen


func _on_visible_on_screen_notifier_2d_screen_entered():
	on_screen = true
	
	$Event.visible = on_screen
	$Outline.visible = on_screen
	$Label.visible = on_screen


func _on_visible_on_screen_notifier_2d_screen_exited():
	on_screen = false
	
	$Event.visible = on_screen
	$Outline.visible = on_screen
	$Label.visible = on_screen
