extends Node2D

@export_color_no_alpha var color = Color(1, 0, 0)
@export_range(0, 16, 0.1) var length = 0.0
@export var layer = 0
@export var lane = 0
@export var time = 0.0

@export_group("Length Modifiers")
@export_range(0, 3, 0.1) var scroll_speed = 1.0
@export var grid_size = Vector2( 64, 64 )

var meter = [4, 16]
var meter_multi = 0.0
var direction = 0
var zoom = Vector2(1, 1)
var tempo = 60.0

var on_screen = false
var selected = false

# Rotation angles for different arrow direction
# 0 - left, 1 - down, 2 - up, 3 - right

var rotations = {
	
	0: 0.0,
	1: 270.0,
	2: 90.0,
	3: 180.0,
	
}


# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Rotates the arrow sprite properly
	$Arrow.rotation_degrees = rotations.get( direction, 45 )
	$Outline.rotation_degrees = rotations.get( direction, 45 )
	
	# Properly colors the arrow and the sustain for it
	$Arrow.modulate = color
	$Line2D.modulate = color
	
	# Glows the arrow when selected
	if selected:
		
		$Arrow.modulate.s -= 0.15
		
		$Outline.modulate = $Arrow.modulate
		$Outline.modulate.s -= 0.5
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	
	if on_screen:
		
		meter_multi = meter[1] / meter[0]
		
		# Calculates the line length based off the grid and meter
		var line_length = ( grid_size.y * meter_multi ) * length
		line_length *= scroll_speed
		line_length *= zoom.y
		line_length = abs(line_length)
		
		# Properly fits the arrow into the gridspace
		$Arrow.scale = grid_size / ( Vector2( $Arrow.texture.get_width(), $Arrow.texture.get_height() ) )
		$Outline.scale = grid_size / ( Vector2( $Outline.texture.get_width(), $Outline.texture.get_height() ) )
		
		# Line2D funkiness
		if length != 0.0:
			
			$Line2D.visible = true
			$"Line2D/Tail End".offset.y = $"Line2D/Tail End".texture.get_width() * -0.5
			
			$"Line2D/Tail End".position.y = line_length
			
			$VisibleOnScreenNotifier2D.rect.size = grid_size + Vector2( 0, line_length * 1.1 )
			$Line2D.points = PackedVector2Array( [ Vector2( 0, 0 ), Vector2( 0, line_length ) ] )
			
		else:
			
			$Line2D.visible = false
			$Line2D.clear_points()


# Checks if arrow is visible on screen
func _on_visible_on_screen_notifier_2d_screen_entered():
	
	on_screen = true
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen


# Checks if arrow is NOT visible on screen
func _on_visible_on_screen_notifier_2d_screen_exited():
	
	on_screen = false
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen
