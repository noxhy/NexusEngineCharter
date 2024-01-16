extends Node2D

@export var tempo: float = 60.0

var on_screen = false

# Called when the node enters the scene tree for the first time.
func _ready():
	
	$Label.visible = on_screen
	$Label.text = str( tempo )


func _on_visible_on_screen_notifier_2d_screen_entered():
	
	on_screen = true
	
	$Label.visible = on_screen


func _on_visible_on_screen_notifier_2d_screen_exited():
	
	on_screen = false
	
	$Label.visible = on_screen
