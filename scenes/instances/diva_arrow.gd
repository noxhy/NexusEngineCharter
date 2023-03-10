extends Node2D

@export_color_no_alpha var color = Color(1, 0, 0)
@export_range(0, 16, 0.1) var length = 0.0
@export var layer = 0
@export var time = 0.0
@export_range(0, 1, 0.1) var note_progress = 0

@export_group("Length Modifiers")
@export_range(0, 3, 0.1) var scroll_speed = 1.0
@export var grid_size = Vector2(64, 64)

var meter = [4, 16]
var meter_multi = 0.0
var direction = 0
var velocity = Vector2(0, 0)
var zoom = Vector2(1, 1)
var tempo = 60.0

var lane = 0

var on_screen = false
var selected = false

var delta_total = 0.0

# Rotation angles for different arrow direction
# 0 - left, 1 - down, 2 - up, 3 - right

var rotations = {
	
	0: 0.0,
	1: 270.0,
	2: 90.0,
	3: 180.0,
	
}

var tail_rotations = {
	
	0: 90.0,
	1: 180.0,
	2: 0.0,
	3: 270.0,
	
}

var velocities = {
	
	0: Vector2(-1, 0),
	1: Vector2(0, -1),
	2: Vector2(0, 1),
	3: Vector2(1, 0),
	
}

# Called when the node enters the scene tree for the first time.
func _ready():
	
	$Arrow.rotation = deg_to_rad(rotations.get(direction, 45))
	$Outline.rotation = deg_to_rad(rotations.get(direction, 45))
	
	$Label.text = str( lane + 1 )
	
	$Arrow.modulate = color
	$Line2D.modulate = color
	$"Arrow Display/Arrow".self_modulate = color
	
	if selected:
		$Outline.modulate = $Arrow.modulate
		$Outline.modulate.s -= 0.5
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if on_screen:
		
		delta_total += delta
		
		var seconds_per_beat = tempo / 60.0
		var meter_multi = meter[1] / meter[0]
		
		var line_length = (grid_size.y * meter_multi) * length
		line_length *= scroll_speed
		line_length *= zoom.y
		line_length = abs(line_length)
		# line_length += (grid_size.y * zoom.y)
		# Only enable this for gameplay
		
		$Arrow.scale = grid_size / ( Vector2( $Arrow.texture.get_width(), $Arrow.texture.get_height() ) )
		$Outline.scale = grid_size / ( Vector2( $Outline.texture.get_width(), $Outline.texture.get_height() ) )
		
		
		if length != 0:
			$Line2D.visible = true
			
			$Line2D.position = $"Arrow Display".position
			
			$"Line2D/Tail End".offset.y = $"Line2D/Tail End".texture.get_width() * -0.5
			$"Line2D/Tail End".position.y = line_length
			
			if $Line2D.points.size() == 0:
				$Line2D.add_point(Vector2(0, 0))
				$Line2D.add_point(Vector2(0, line_length))
			else:
				$Line2D.set_point_position(1, Vector2(0, line_length))
			
		else:
			$Line2D.visible = false
			$Line2D.clear_points()
		
		
		var speed = 2000 / ( ( 60.0 / tempo ) * 4 )
		var velocity = velocities.get(direction, Vector2(0, 0))
		$"Arrow Display".position = Vector2(speed, speed) * velocity * Vector2(note_progress, note_progress)
		
		var sine_wave = 0 + sin( note_progress / ( seconds_per_beat * 0.25 )) * 200
		
		var tail_sine_wave = 0 + sin( note_progress / ( seconds_per_beat * 0.5 )) * 20
		
		
		if velocity.x != 0:
			
			$"Arrow Display".position.y = sine_wave
			$"Line2D".rotation = deg_to_rad( tail_rotations.get(direction, 45) ) + deg_to_rad( tail_sine_wave )
		elif velocity.y != 0:
			
			$"Arrow Display".position.x = sine_wave
			$"Line2D".rotation = deg_to_rad( tail_rotations.get(direction, 45) ) + deg_to_rad( tail_sine_wave )

func _on_visible_on_screen_notifier_2d_screen_entered():
	on_screen = true
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen


func _on_visible_on_screen_notifier_2d_screen_exited():
	on_screen = false
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen
