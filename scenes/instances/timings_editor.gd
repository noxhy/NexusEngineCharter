extends Window

const tempo_list_preload = preload("res://scenes/instances/tempo_list_node.tscn")

@export var tempo_list: Dictionary

var tempo_node_list: Array

signal timings_data_changed( tempo_list: Dictionary )

# Called when the node enters the scene tree for the first time.
func _ready():
	
	load_tempos()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func load_tempos():
	
	# Clear List
	
	for i in tempo_node_list.size():
		
		tempo_node_list[0].queue_free()
		tempo_node_list.remove_at(0)
	
	var tempo_dict = tempo_list
	var keys = tempo_dict.keys()
	
	
	for i in keys.size():
		
		var dict_time = keys[i]
		var dict_tempo = tempo_dict.get(keys[i])
		
		var tempo_node_instance = tempo_list_preload.instantiate()
		
		tempo_node_instance.time = dict_time
		tempo_node_instance.tempo = dict_tempo
		tempo_node_instance.host = self
		$VBoxContainer/ScrollContainer/VBoxContainer.add_child( tempo_node_instance )
		
		tempo_node_instance.connect( "tempo_deleted", self.delete_tempo )
		
		tempo_node_list.append( tempo_node_instance )


func _on_close_requested(): self.queue_free()


func _on_add_tempo_pressed():
	
	tempo_list.merge( { %Time.value: %Tempo.value }, true )
	load_tempos()
	emit_signal( "timings_data_changed", tempo_list )


func delete_tempo( time: float ):
	
	tempo_list.erase( time )
	
	if tempo_list.keys().size() == 0: tempo_list = { 0.0: 60 }
	
	load_tempos()
	emit_signal( "timings_data_changed", tempo_list )
