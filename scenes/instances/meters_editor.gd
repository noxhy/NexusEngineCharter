extends Window

const meter_list_preload = preload("res://scenes/instances/meters_list_node.tscn")

@export var meter_list: Dictionary

var meter_node_list: Array

signal meter_data_changed( meter_list: Dictionary )

# Called when the node enters the scene tree for the first time.
func _ready():
	
	load_meters()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func load_meters():
	
	# Clear List
	
	for i in meter_node_list.size():
		
		meter_node_list[0].queue_free()
		meter_node_list.remove_at(0)
	
	var meter_dict = meter_list
	var keys = meter_dict.keys()
	
	
	for i in keys.size():
		
		var dict_time = keys[i]
		var dict_meter = meter_dict.get(keys[i])
		
		var meter_node_instance = meter_list_preload.instantiate()
		
		meter_node_instance.time = dict_time
		meter_node_instance.beats = int( dict_meter[0] )
		meter_node_instance.steps = int( dict_meter[1] )
		$VBoxContainer/ScrollContainer/VBoxContainer.add_child( meter_node_instance )
		
		meter_node_instance.connect( "meter_deleted", self.delete_meter )
		
		meter_node_list.append( meter_node_instance )


func _on_close_requested(): self.queue_free()


func _on_add_tempo_pressed():
	
	meter_list.merge( { %Time.value: [ int( %Beats.value ), int( %Steps.value ) ] }, true )
	emit_signal( "meter_data_changed", meter_list )
	load_meters()


func delete_meter( time: float ):
	
	meter_list.erase( time )
	
	if meter_list.keys().size() == 0: meter_list = { 0.0: [ 4, 16 ] }
	
	emit_signal( "meter_data_changed", meter_list )
	load_meters()
