extends PanelContainer

@export var time = 0.0
@export var tempo = 60.0
@export var host = Node2D


func _on_delete_buttom_pressed():
	delete_time()

func _process(delta):
	
	$Time.text = float_to_time(time)
	$Tempo.text = str(tempo)

func float_to_time(time: float) -> String:
	
	var minutes = int( time / 60 )
	var seconds = int( time ) % 60
	var milliseconds = (time - int(time))
	
	if seconds < 10:
		return str( minutes ) + ":0" + str( int( seconds ) % 60 ) + str( milliseconds ).trim_prefix("0")
	else:
		return str( minutes ) + ":" + str( int( seconds ) % 60 ) + str( milliseconds ).trim_prefix("0")

func delete_time():
	
	host.delete_tempo_at(time)
	host.update_tempo_list()
