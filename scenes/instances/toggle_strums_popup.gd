extends Window

const lane_disabled_node_preload = preload("res://scenes/instances/lane_disabled_node.tscn")

@export var strum_count: int
@export var lanes_disabled: PackedInt32Array

signal lanes_disabled_change( lanes: PackedInt32Array )

# Called when the node enters the scene tree for the first time.
func _ready(): load_strumlines()


func _on_update_button_pressed(): self.emit_signal( "lanes_disabled_change", lanes_disabled )


func load_strumlines():
	
	@warning_ignore("integer_division")
	for i in int( strum_count / 4 ):
		
		var lane_disabled_node_instance = lane_disabled_node_preload.instantiate()
		
		lane_disabled_node_instance.strum_id = i
		lane_disabled_node_instance.enabled = !lanes_disabled.has( i * 4 )
		
		$VBoxContainer/ScrollContainer/HBoxContainer/VBoxContainer.add_child(lane_disabled_node_instance)
		lane_disabled_node_instance.connect( "strumline_changed", self.set_strumline_status )


func set_strumline_status( id: int, enabled: bool ):
	
	for i in range( id * 4, id * 4 + 4 ):
		
		if enabled:
			
			if lanes_disabled.has(i):
				
				lanes_disabled.remove_at( lanes_disabled.find( i ) )
		
		else:
			
			if !lanes_disabled.has(i):
				
				lanes_disabled.append(i)

func _on_close_requested(): self.queue_free()
