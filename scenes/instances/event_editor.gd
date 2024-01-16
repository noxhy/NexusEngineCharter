extends Window

const event_button_preload = preload("res://scenes/instances/event_button.tscn")
const event_parameter_preload = preload("res://scenes/instances/event_parameter_node.tscn")

@export var events: Array
@export var time: float

var event_button_nodes = []
var event_parameter_nodes = []

var current_event: String
var current_parameter_id: int

signal event_added( event: Array )
signal event_removed( time: float, name: String )


# Called when the node enters the scene tree for the first time.
func _ready(): load_event_names()


func _on_close_requested(): self.queue_free()


func find_event(name: String) -> Array:
	
	for event in events:
		
		if event[1] != name: continue
		else: return event
	
	return []


func load_event_names():
	
	for i in event_button_nodes.size():
		
		event_button_nodes[0].queue_free()
		event_button_nodes.remove_at(0)
	
	for event in events:
		
		var event_button_instance = event_button_preload.instantiate()
		
		event_button_instance.event_name = event[1]
		
		$HBoxContainer/VBoxContainer/ScrollContainer/VBoxContainer.add_child(event_button_instance)
		event_button_nodes.append(event_button_instance)
		
		event_button_instance.connect( "event_selected", self.load_event_parameters )


func load_event_parameters(name: String):
	
	var parameters: Array = find_event(name)[2]
	
	current_event = name
	current_parameter_id = 0
	
	for i in event_parameter_nodes.size():
		
		event_parameter_nodes[0].queue_free()
		event_parameter_nodes.remove_at(0)
	
	for i in parameters:
		
		var event_parameter_instance = event_parameter_preload.instantiate()
		
		event_parameter_instance.parameter_id = parameters.find(i)
		event_parameter_instance.parameter_value = str(i)
		
		$HBoxContainer/VBoxContainer2/ScrollContainer/VBoxContainer.add_child(event_parameter_instance)
		event_parameter_nodes.append(event_parameter_instance)
		
		event_parameter_instance.connect( "parameter_changed", self.set_parameter )
		event_parameter_instance.connect( "parameter_removed", self.remove_parameter )


func _on_add_event_button_pressed():
	
	emit_signal( "event_added", [ time, %"Event Name".text , [] ] )
	queue_free()


func _on_add_parameter_pressed():
	
	if find_event( current_event ).size() != 0:
		
		find_event(current_event)[2].append("")
		load_event_parameters(current_event)


func _on_remove_event_button_pressed():
	
	if events.size() > 1:
		
		emit_signal( "event_removed", find_event(current_event)[0], find_event(current_event)[1] )
		events.remove_at( events.find( find_event(current_event) ) )
	
	queue_free()


func set_parameter( id: int, value: String ):
	
	find_event(current_event)[2][id] = value
	load_event_parameters(current_event)


func remove_parameter( id: int ):
	
	find_event(current_event)[2].remove_at(id)
	load_event_parameters(current_event)
