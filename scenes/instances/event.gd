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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if on_screen:
		$Label.text = event_name
		$Label.text += "\n" + "{ "
		
		$Event.scale = Vector2(64, 64) / Vector2( $Event.texture.get_width(), $Event.texture.get_height() )
		$Outline.scale = Vector2(64, 64) / Vector2( $Outline.texture.get_width(), $Outline.texture.get_height() )
		
		var index = 0
		
		for i in parameters:
			
			var comma = "" if ( index == parameters.size() - 1) else ", "
			$Label.text += str(i) + comma
			index += 1
		
		$Label.text += " }"


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
