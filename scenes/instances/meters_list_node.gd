extends PanelContainer

@export var time = 0.0
@export var beats = 4
@export var steps = 16
@export var host = Node2D


func _on_delete_buttom_pressed():
	delete_time()

func _process(delta):
	
	$Time.text = float_to_time(time)
	$Tempo.text = str(beats) + " / " + str(steps)

func float_to_time(time: float) -> String:
	
	var minutes = int( time / 60 )
	var seconds = int( time ) % 60
	var milliseconds = (time - int(time))
	
	if seconds < 10:
		return str( minutes ) + ":0" + str( int( seconds ) % 60 ) + str( milliseconds ).trim_prefix("0")
	else:
		return str( minutes ) + ":" + str( int( seconds ) % 60 ) + str( milliseconds ).trim_prefix("0")

func delete_time():
	
	host.delete_meter_at(time)
	host.update_meter_list()
