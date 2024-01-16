extends Node2D

@export_group("Zoom")
@export var zoom = Vector2(1, 1)

@export_group("Grid Settings")
@export var grid_size = Vector2(16, 16)
@export var columns = 4
@export var rows = 16
@export var centered = true
@export var grid_color: Color = Color( 0, 0 )

@export_group("Colors")
@export var event_column_color = Color( 1, 1, 1, 0.5 )

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	
	$TextureRect.size = Vector2( 16, 16 ) * Vector2( columns, rows )
	$TextureRect.scale = grid_size / Vector2( 16, 16 )
	$TextureRect.scale *= zoom
	$TextureRect.self_modulate = grid_color
	
	if centered:
		$TextureRect.position.x = ( $TextureRect.size.x * $TextureRect.scale.x ) / -2.0
	else:
		$TextureRect.position = Vector2( 0, 0 )
	
	queue_redraw()


func _draw():
	pass
	# var rect = Rect2( $TextureRect.position , (grid_size) * Vector2(1.0, rows) * Vector2($TextureRect.scale.x / 2, $TextureRect.scale.y) )
	# draw_rect( rect, event_column_color )
