extends Node2D

@export_color_no_alpha var color = Color(1, 0, 0)
@export_range(0, 16, 0.1) var length = 0.0
@export var layer = 0
@export var time = 0.0

@export_group("Length Modifiers")
@export_range(0, 3, 0.1) var scroll_speed = 1.0
@export var grid_size = Vector2(64, 64)

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
	
	$Arrow.rotation = deg_to_rad(rotations.get(direction, 45))
	$Outline.rotation = deg_to_rad(rotations.get(direction, 45))
	
	$Arrow.modulate = color
	$Line2D.modulate = color
	
	if selected:
		$Arrow.modulate.s -= 0.15
		
		$Outline.modulate = $Arrow.modulate
		$Outline.modulate.s -= 0.5
	
	$Arrow.visible = on_screen
	$Outline.visible = on_screen
	$Line2D.visible = on_screen


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if on_screen:
		var seconds_per_beat = tempo / 60.0
		var meter_multi = meter[1] / meter[0]
		
		var line_length = (grid_size.y * meter_multi) * length
		line_length *= scroll_speed
		line_length *= zoom.y
		line_length = abs(line_length)
		
		$Arrow.scale = grid_size / ( Vector2( $Arrow.texture.get_width(), $Arrow.texture.get_height() ) )
		$Outline.scale = grid_size / ( Vector2( $Outline.texture.get_width(), $Outline.texture.get_height() ) )
		
		
		if length != 0:
			$Line2D.visible = true
			$"Line2D/Tail End".offset.y = $"Line2D/Tail End".texture.get_width() * -0.5
			line_length += $"Line2D/Tail End".offset.y * $Arrow.scale.y
			line_length -= grid_size.y / 2
			$"Line2D/Tail End".position.y = line_length
			
			$VisibleOnScreenNotifier2D.rect.size = grid_size + Vector2(0, grid_size.y * line_length)
			
			if $Line2D.points.size() == 0:
				$Line2D.add_point(Vector2(0, 0))
				$Line2D.add_point(Vector2(0, line_length))
			else:
				$Line2D.set_point_position(1, Vector2(0, line_length))
			
		else:
			$Line2D.visible = false
			$Line2D.clear_points()


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
