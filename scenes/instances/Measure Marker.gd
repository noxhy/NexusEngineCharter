extends Node2D

@export var line_length = 256
var measure = 0
var time = 0.0


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	$Line2D.clear_points()
	$Line2D.add_point( Vector2( line_length / -2, 0 ) )
	$Line2D.add_point( Vector2( line_length / 2, 0 ) )
	$Line2D/Label.size.x = line_length * 1.25
	$Line2D/Label.position.x = -$Line2D/Label.size.x / 2
	
	$Line2D/Label.text = str(measure) + " " + str(measure)


func _on_visible_on_screen_notifier_2d_screen_entered():
	visible = true


func _on_visible_on_screen_notifier_2d_screen_exited():
	visible = false
