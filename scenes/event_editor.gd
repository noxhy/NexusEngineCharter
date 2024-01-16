extends Node2D

const tempo_list_preload = preload("res://scenes/instances/tempo_list_node.tscn")
const meter_list_preload = preload("res://scenes/instances/meters_list_node.tscn")
const chart_arrow_preload = preload("res://scenes/instances/arrow.tscn")
const event_preload = preload("res://scenes/instances/event.tscn")

@export var chart = Chart.new()
@export var chart_zoom = Vector2(1, 1)
@export var offset = 0.0 

@onready var beat_sounds = true
@onready var step_sounds = false

@export var strum_count = 8
@export var highlight_color = Color(1, 1, 1, 0.5)

var playback_speed = 1.0

var vocals_length = 0.0
var instrumental_length = 0.0

var tempo_list = []
var meter_list = []
var measure_marker_list = []

var note_instances = []
var passed_note_instances = []
var event_instances = []

var chart_grid = Vector2(32, 32)
var chart_snap = 4

var follow_marker = true
var can_add_note = true

var old_tempo = 0.0
var old_time = -1.0

var dragging_time = false

var layers = []
var selected_note = []
var events_list: Array = []
var pressing_ctrl = false

var brush_event_name = ""
var brush_event_parameters = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Initialization of shit
	
	if Global.file != "res://":
		chart = load( Global.file )
	
	$Music/Vocals.stream = read_audio_file(chart.vocals)
	$Music/Instrumental.stream = read_audio_file(chart.instrumental)
	
	$Conductor.tempo = chart.get_tempos_data().get(0.0)
	
	$Conductor.beats_per_measure = chart.get_meters_data().get(0.0)[0]
	$Conductor.steps_per_measure = chart.get_meters_data().get(0.0)[1]
	
	$"UI/Charting Tabs/Chart/Song Title".text = chart.song_title
	$"UI/Charting Tabs/Chart/Song Artist".text = chart.artist
	$"UI/Charting Tabs/Chart/Difficulty".text = chart.difficulty
	$"UI/Charting Tabs/Chart/Offset".text = str(chart.offset)
	$"UI/Charting Tabs/Chart/Scroll Speed".text = str(chart.scroll_speed)
	
	$Music/Vocals.play()
	$Music/Instrumental.play()
	
	if( $Music/Vocals.stream != null ):
		vocals_length = $Music/Vocals.stream.get_length()
	
	instrumental_length = $Music/Instrumental.stream.get_length()
	
	update_tempo_list()
	update_meter_list()
	
	offset = chart.offset
	$Conductor.offset = chart.offset
	
	render_events()
	
	# Layer Offset
	
	layers = get_tree().get_nodes_in_group("layer")
	for i in layers: i.layer -= layers.size()


func _process(delta):
	
	## Details
	
	$"UI/Conductor Stats/Details/Details".text = "Tempo: " + str( $Conductor.tempo )
	$"UI/Conductor Stats/Details/Details".text += "\n" + "Beat Snap: " + str( 1 ) + " / " + str( chart_snap )
	$"UI/Conductor Stats/Details/Details".text += "\n" + "Playback Speed: " + str(playback_speed) + "x"
	
	## Conductor Stats String
	
	$"UI/Conductor Stats/Conductor/Conductor Stats".text = "Tempo: " + str( $Conductor.tempo )
	$"UI/Conductor Stats/Conductor/Conductor Stats".text += "\n" + "Meter: " + str( $Conductor.beats_per_measure ) + " / " + str( $Conductor.steps_per_measure )
	$"UI/Conductor Stats/Conductor/Conductor Stats".text += "\n"
	
	$"UI/Conductor Stats/Conductor/Conductor Stats".text += "\n" + "Current: (" + str( $Conductor.current_beat + 1 ) + ", " + str( $Conductor.current_step + 1 ) + ")"
	$"UI/Conductor Stats/Conductor/Conductor Stats".text += "\n" + "Measure Relative: (" + str( $Conductor.measure_relative_beat + 1 ) + ", " + str( $Conductor.measure_relative_step + 1 ) + ")"
	
	
	$Music/Vocals.pitch_scale = playback_speed
	$Music/Instrumental.pitch_scale = playback_speed
	
	if $Music/Instrumental.playing:
		
		var song_position = $Music/Instrumental.get_playback_position()
		
		$"UI/Panel/Song Progress".value = song_position
		$"UI/Panel/Song Progress".max_value = instrumental_length
		$"UI/Panel/Song Progress/Time Display Progress".text = float_to_time( song_position )
		$"UI/Panel/Song Progress/Time Display Finish".text = "-" + float_to_time( instrumental_length - song_position )
		
		var tempo_at = get_tempo_at( song_position )
		$Conductor.tempo = tempo_at
		$Conductor.seconds_per_beat = 60.0 / tempo_at
		
		if old_tempo != tempo_at:
			old_tempo = tempo_at
		
		var meter_at = get_meter_at( song_position )
		$Conductor.beats_per_measure = meter_at[0]
		$Conductor.steps_per_measure = meter_at[1]
		chart_render(delta)
		
		check_notes( song_position )
	
	
	$"UI/Panel/Song Progress/Time Display Drag".visible = dragging_time
	
	
	if dragging_time:
		
		$"UI/Panel/Song Progress/Time Display Drag".text = float_to_time( $"UI/Panel/Song Progress".value )
		$"UI/Panel/Song Progress/Time Display Drag".position.x = (576 - 632) + (1280 - 8) * ( $"UI/Panel/Song Progress".value / $"UI/Panel/Song Progress".max_value )
	
	
	queue_redraw()
	
	$UI/Panel/ColorRect/ExtraLabel.text = "Chart Zoom: " + str(chart_zoom)
	$UI/Panel/ColorRect/ExtraLabel.text += "\n" + "Events List: " + str( events_list )
	$UI/Panel/ColorRect/ExtraLabel.text += " • " + "Events Drawn: " + str(event_instances.size()) + "/" + str( chart.get_events_data().size() )
	
	
	if Input.is_action_just_pressed("toggle_song"):
		
		$Music/Vocals.stream_paused = !$Music/Vocals.stream_paused
		$Music/Instrumental.stream_paused = !$Music/Instrumental.stream_paused
		$"UI/Panel/ColorRect/HBoxContainer/Pause Button".button_pressed = $Music/Instrumental.stream_paused
	
	
	if Input.is_action_just_released("ui_cancel"):
		
		render_events()
	
	
	if Input.is_action_just_released("debug"):
		check_notes()
	
	pressing_ctrl = Input.is_action_pressed("drag_enable")
	
	if Input.is_action_just_pressed("mouse_left"):
		
		@warning_ignore("integer_division")
		var lane = grid_position_to_time( get_global_mouse_position() ).x + ( strum_count / 2 ) - 1
		var time = grid_position_to_time( get_global_mouse_position() ).y
		
		time = format_time(time)
		
		if lane >= 0 && lane <= strum_count - 1:
			
			var camera_offset = $Camera2D.position.y - 360
			
			if get_global_mouse_position().y >= 64 + camera_offset && get_global_mouse_position().y <= 640 + camera_offset:
				
				if is_slot_filled_event( time, lane ):
					
					if pressing_ctrl:
						
						if find_event( time, events_list.find( brush_event_name ) ) == -1:
							chart.chart_data.events.append( [time, brush_event_name, brush_event_parameters.split("\n")] )
					else:
						
						if find_event( time, lane ) != -1:
							chart.chart_data.events.remove_at( find_event( time, lane ) )
				else:
					
					if find_event( time, events_list.find( brush_event_name ) ) == -1:
						chart.chart_data.events.append( [time, brush_event_name, brush_event_parameters.split("\n")] )
				
				render_events()
	
	
	if Input.is_action_just_pressed("mouse_middle"):
		
		var lane = grid_position_to_time( get_global_mouse_position() ).x
		var time = grid_position_to_time( get_global_mouse_position() ).y
		
		time = format_time(time)
		
		if lane >= 0 && lane <= strum_count - 1:
			
			var camera_offset = $Camera2D.position.y - 360
			
			if get_global_mouse_position().y >= 64 + camera_offset && get_global_mouse_position().y <= 640 + camera_offset:
				
				if is_slot_filled(time, lane):
					
					selected_note.appenprd( find_note(time, lane) )
	
	
	if Input.is_action_just_released("scroll_up"):
		
		if pressing_ctrl:
			
			chart_snap += 1
		else:
			if $Music/Instrumental.stream_paused:
				
				passed_note_instances = []
				
				var song_position = $Music/Instrumental.get_playback_position()
				var snap = ( 60.0 / get_tempo_at( song_position ) ) / ( get_meter_at( song_position )[1] / get_meter_at( song_position )[0] )
				
				$Music/Vocals.play( song_position - snap )
				$Music/Instrumental.play( song_position - snap )
				
				$Music/Vocals.stream_paused = true
				$Music/Instrumental.stream_paused = true
				
				chart_render( delta )
				render_events( song_position )
	
	
	if Input.is_action_just_released("scroll_down"):
		
		if pressing_ctrl:
			
			chart_snap -= 1
		else:
			if $Music/Instrumental.stream_paused:
				
				passed_note_instances = []
				
				var song_position = $Music/Instrumental.get_playback_position()
				var snap = ( 60.0 / get_tempo_at( song_position ) ) / ( get_meter_at( song_position )[1] / get_meter_at( song_position )[0] )
				
				$Music/Vocals.play( song_position + snap )
				$Music/Instrumental.play( song_position + snap )
				
				$Music/Vocals.stream_paused = true
				$Music/Instrumental.stream_paused = true
				
				chart_render( delta )
				render_events( song_position )


func _on_conductor_new_beat(_current_beat, measure_relative):
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	
	if measure_relative == 0:
		
		if beat_sounds:
			$"Conductor/Measure Sound".play(0.56)
		
		tween.tween_property($Background/Background, "scale", Vector2(1.05, 1.05), 0.0125)
		
		render_events()
		
	else:
		
		if beat_sounds:
			$"Conductor/Beat Sound".play(0.56)
		
		tween.tween_property($Background/Background, "scale", Vector2(1.015, 1.015), 0.0125)
	
	
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property($Background/Background, "scale", Vector2(1, 1), 0.2).set_delay(0.0125)


func _on_conductor_new_step(_current_step, _measure_relative): if step_sounds: $"Conductor/Step Sound".play(0.56)


func _on_beat_sounds_check_box_toggled(button_pressed): beat_sounds = button_pressed
func _on_step_sounds_check_box_toggled(button_pressed): step_sounds = button_pressed

func _on_vocals_slider_value_changed(value): $Music/Vocals.volume_db = value
func _on_instrumental_slider_value_changed(value): $Music/Instrumental.volume_db = value

func _on_song_progress_drag_started(): dragging_time = true

func _on_song_progress_drag_ended(_value_changed):
	
	
	$Music/Vocals.play($"UI/Panel/Song Progress".value)
	$Music/Instrumental.play($"UI/Panel/Song Progress".value)
	passed_note_instances = []
	
	$"UI/Panel/ColorRect/HBoxContainer/Pause Button".button_pressed = false
	dragging_time = false
	
	render_events()


func _on_pause_button_toggled(button_pressed):
	
	$Music/Vocals.stream_paused = button_pressed
	$Music/Instrumental.stream_paused = button_pressed


func read_audio_file(path: String):
	
	var file = FileAccess.open(path, FileAccess.READ)
	
	var content = null
	
	print(path)
	
	print("File type: ", path.get_extension())
	
	if (path.get_extension() == "mp3"):
		
		
		content = AudioStreamMP3.new()
		content.data = file.get_buffer(file.get_length())
		
	
	return content


func _on_speed_slider_value_changed(value): playback_speed = value

func _on_rewind_button_pressed():
	
	var vocals_seek = clamp($Music/Vocals.get_playback_position() - 10, 0, vocals_length)
	var instrumental_seek = clamp($Music/Instrumental.get_playback_position() - 10, 0, instrumental_length)
	
	$Music/Vocals.seek(vocals_seek)
	$Music/Instrumental.seek(instrumental_seek)
	passed_note_instances = []
	
	render_events()


func _on_fast_forward_button_pressed():
	
	var vocals_seek = clamp($Music/Vocals.get_playback_position() + 10, 0, vocals_length)
	var instrumental_seek = clamp($Music/Instrumental.get_playback_position() + 10, 0, instrumental_length)
	
	$Music/Vocals.seek(vocals_seek)
	$Music/Instrumental.seek(instrumental_seek)
	passed_note_instances = []
	
	render_events()


func _on_restart_button_pressed():
	
	$Music/Vocals.seek(0)
	$Music/Instrumental.seek(0)
	passed_note_instances = []
	
	render_events()


func _on_skip_button_pressed():
	
	$Music/Vocals.seek(vocals_length)
	$Music/Instrumental.seek(instrumental_length - 0.1)
	passed_note_instances = []
	
	render_events()


# Save Chart


func _on_save_button_pressed():
	ResourceSaver.save(chart, chart.resource_path)


# Tempo List Shit


func update_tempo_list():
	
	
	# Clear List
	
	for i in tempo_list.size():
		
		tempo_list[0].queue_free()
		tempo_list.remove_at(0)
	
	var tempo_dict = chart.get_tempos_data()
	var keys = tempo_dict.keys()
	
	
	for i in keys.size():
		
		var dict_time = keys[i]
		var dict_tempo = tempo_dict.get(keys[i])
		
		var tempo_node_instance = tempo_list_preload.instantiate()
		
		tempo_node_instance.time = dict_time
		tempo_node_instance.tempo = dict_tempo
		tempo_node_instance.host = self
		get_node("UI/Charting Tabs/Tempo/ScrollContainer/VBoxContainer").add_child(tempo_node_instance)
		
		tempo_list.append(tempo_node_instance)


func delete_tempo_at(time: float):
	
	chart.chart_data.tempos.erase(time)


func _on_add_tempo_pressed():
	
	var time_add = $"UI/Charting Tabs/Tempo/Time Edit".text.to_float()
	var tempo_add = $"UI/Charting Tabs/Tempo/Tempo Edit".text.to_float()
	
	var tempo_dict = chart.get_tempos_data()
	tempo_dict.merge({time_add: tempo_add}, true)
	
	update_tempo_list()
	
	$"UI/Charting Tabs/Tempo/Time Edit".text = ""
	$"UI/Charting Tabs/Tempo/Tempo Edit".text = ""


# Meter List Shit


func _on_add_meter_pressed():
	
	var time_add = $"UI/Charting Tabs/Meter/Time Edit".text.to_float()
	var raw_meter_string = $"UI/Charting Tabs/Meter/Beat Edit".text.split("/")
	
	var beats_int = raw_meter_string[0].to_int()
	var steps_int = raw_meter_string[1].to_int()
	
	var meter_add = [beats_int, steps_int]
	
	var meter_dict = chart.get_meters_data()
	meter_dict.merge({time_add: meter_add}, true)
	
	update_meter_list()
	
	$"UI/Charting Tabs/Meter/Time Edit".text = ""
	$"UI/Charting Tabs/Meter/Beat Edit".text = ""


func update_meter_list():
	
	
	# Clear List
	
	for i in meter_list.size():
		
		meter_list[0].queue_free()
		meter_list.remove_at(0)
	
	var meter_dict = chart.get_meters_data()
	var keys = meter_dict.keys()
	
	
	for i in keys.size():
		
		var dict_time = keys[i]
		var dict_beats = meter_dict.get(keys[i])[0]
		var dict_steps = meter_dict.get(keys[i])[1]
		
		var meter_node_instance = meter_list_preload.instantiate()
		
		meter_node_instance.time = dict_time
		meter_node_instance.beats = dict_beats
		meter_node_instance.steps = dict_steps
		meter_node_instance.host = self
		$"UI/Charting Tabs/Meter/ScrollContainer/VBoxContainer".add_child(meter_node_instance)
		
		meter_list.append(meter_node_instance)


func delete_meter_at(time: float):
	
	chart.chart_data.meters.erase(time)


# Grid Stuff


@warning_ignore("shadowed_variable")
func snap_to_grid(pos: Vector2, grid: Vector2 = Vector2(8, 8), offset: Vector2 = Vector2(0, 0)) -> Vector2:
	
	pos.x = int( ( pos.x + offset.x ) / grid.x)
	pos.y = int( ( pos.y + offset.y ) / grid.y)
	
	return pos


func _draw():
	
	var grid_scale = ( 16.0 / ( get_meter_at( $Music/Instrumental.get_playback_position() )[1] ) )
	var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale * ( 4.0 / chart_snap ) )
	# var offset = Vector2( scaler.x / ( 1 + ( ( strum_count + 1 ) % 2 ) ), -scaler.y / chart_zoom.y )
	@warning_ignore("shadowed_variable")
	var offset = Vector2(0, 0)
	
	draw_rect( Rect2( snap_to_grid(get_global_mouse_position(), scaler, offset ) * scaler - offset, scaler ), highlight_color )


@warning_ignore("shadowed_variable")
func get_grid_position( pos: Vector2, offset: Vector2 = Vector2(0, 0) ) -> Vector2:
	
	var grid_scale = ( 16.0 / ( get_meter_at( $Music/Instrumental.get_playback_position() )[1] ) )
	
	var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale * ( 4.0 / chart_snap ) )
	
	var grid_position = pos - ( Vector2(640, 64) - offset ) + ( scaler * ( strum_count / 2.0 ) * Vector2(1, 0) )
	
	grid_position = grid_position / scaler
	grid_position = Vector2( floor( grid_position.x - 1 ), floor( grid_position.y )  )
	
	return Vector2( grid_position.x, grid_position.y )


# Chart Rendering


func chart_render(_delta: float):
	
	%Grid.columns = strum_count
	
	var song_position = $Music/Instrumental.get_playback_position()
	
	%Grid.position.x = 0
	
	
	%Grid.rows = get_meter_at( song_position )[1] 
	
	var grid_scale = ( 16.0 / get_meter_at( song_position )[1] )
	
	$ParallaxBackground/ParallaxLayer.motion_mirroring = Vector2(0, chart_grid.y * %Grid.rows * chart_zoom.y * grid_scale)
	%Grid.zoom = Vector2( grid_scale, grid_scale ) * chart_zoom
	
	var grid_height = %Grid/TextureRect.size.y * %Grid/TextureRect.scale.y
	
	$ParallaxBackground/ParallaxLayer/Grid/ColorRect.size = Vector2( %Grid/TextureRect.size.x * %Grid/TextureRect.scale.x, grid_scale * chart_zoom.y * chart_grid.y )
	$ParallaxBackground/ParallaxLayer/Grid/ColorRect.position = %Grid/TextureRect.position
	
	var seconds_per_beat = 60.0 / get_tempo_at( song_position )
	var speed = ( grid_height / ( seconds_per_beat * get_meter_at( song_position )[0] ) )
	
	
	$"Chart Editor UI/Song Pos Marker".size.x = %Grid/TextureRect.size.x * %Grid/TextureRect.scale.x * 1.1
	$"Chart Editor UI/Song Pos Marker".position.x = $"Chart Editor UI/Song Pos Marker".size.x * -0.5
	$"Chart Editor UI/Song Pos Marker".position.y = %Grid.position.y - ($"Chart Editor UI/Song Pos Marker".size.y * 0.5)
	$"Chart Editor UI/Song Pos Marker".position.y += ( speed * song_position )
	
	if follow_marker: $Camera2D.position.y = 360 + %Grid.position.y + ( speed * song_position )


func update_measure_markers():
	
	for i in measure_marker_list.size():
		
		measure_marker_list[0].queue_free()
		measure_marker_list.remove_at(0)


# Utilities


## Converts a float of seconds into a time format of MM:SS.mmm
func float_to_time(time: float) -> String:
	
	var minutes = int( time / 60 )
	var seconds = int( time ) % 60
	var milliseconds = (time - int(time))
	milliseconds = snapped(milliseconds, 0.001)
	
	if seconds < 10:
		return str( minutes ) + ":0" + str( int( seconds ) % 60 ) + str( milliseconds ).trim_prefix("0")
	else:
		return str( minutes ) + ":" + str( int( seconds ) % 60 ) + str( milliseconds ).trim_prefix("0")


##  Gets the tempo at a certain time in seconds
func get_tempo_at(time: float) -> float:
	
	var tempo_dict = chart.get_tempos_data()
	var keys = tempo_dict.keys()
	
	var tempo_output = 0.0
	
	for i in keys.size():
		var dict_time = keys[i]
		
		if time >= dict_time:
			tempo_output = tempo_dict.get(keys[i])
	
	return tempo_output


##  Gets the meter at a certain time in seconds
func get_meter_at(time: float) -> Array:
	
	var meter_dict = chart.get_meters_data()
	var keys = meter_dict.keys()
	
	var meter_output = [1, 1]
	
	for i in keys.size():
		var dict_time = keys[i]
		
		if time >= dict_time:
			meter_output[0] = meter_dict.get(keys[i])[0]
			meter_output[1] = meter_dict.get(keys[i])[1]
		else:
			break
	
	return meter_output


## Returns the measure at a certain time
func get_measure_at(time: float, song_length: float) -> int:
	
	var measure = 0
	
	var time_temp = time
	var meter_dict = chart.get_meters_data()
	var keys = meter_dict.keys()
	
	for i in keys.size():
		var dict_time = keys[i]
		
		
		if dict_time > time:
			break
		
		
		var tempo_at = get_tempo_at(dict_time)
		var meter_at = get_meter_at(dict_time)
		
		var seconds_per_beat = 60.0 / tempo_at
		
		var seconds_per_measure = seconds_per_beat * meter_at[0]
		
		var measure_add = 0
		
		measure_add = int( time_temp / seconds_per_measure )
		
		var clamp = clamp(i + 1, 0, keys.size() - 1)
		
		time_temp -= keys[clamp]
		measure += measure_add
		
	
	return measure


func _on_set_song_title_pressed(): chart.song_title = $"UI/Charting Tabs/Chart/Song Title".text
func _on_set_artist_pressed(): chart.artist = $"UI/Charting Tabs/Chart/Song Artist".text
func _on_set_difficulty_pressed(): chart.difficulty = $"UI/Charting Tabs/Chart/Difficulty".text
func _on_set_scroll_speed_pressed(): chart.scroll_speed = $"UI/Charting Tabs/Chart/Scroll Speed".text.to_float()

func _on_offset_button_pressed():
	chart.offset = $"UI/Charting Tabs/Chart/Offset".text.to_float()
	offset = chart.offset
	$Conductor.offset = chart.offset
	render_events()

func _on_set_strum_pressed(): 
	strum_count = $"UI/Charting Tabs/Chart/Strum Text".text.to_int()
	render_events()


# Chart Rendering Fuckery

func render_notes( song_time = $Music/Instrumental.get_playback_position() ):
	
	for i in note_instances.size():
		
		note_instances[0].queue_free()
		note_instances.remove_at(0)
	
	var index = 0
	
	for i in chart.get_note_data():
		
		var time = i[0]
		var lane = i[1]
		var note_length = i[2]
		var note_type = i[3]
		
		
		var seconds_per_beat = 60.0 / get_tempo_at(time)
		var meter_multi = get_meter_at(time)[1] / get_meter_at(time)[0]
		var grid_scale = ( 16.0 / get_meter_at( time )[1] )
		
		var scaler = chart_grid * chart_zoom * Vector2(grid_scale, grid_scale)
		var range = seconds_per_beat * get_meter_at(time)[0]
		
		if time > (song_time + range * 2):
			index += 1
			continue
		
		
		if ( get_tempo_at(time) == get_tempo_at(song_time) ) && ( time >= (song_time - range) && time <= (song_time + range * 2) ):
			
			var chart_arrow_instance = chart_arrow_preload.instantiate()
			
			var arrow_x = ( ( strum_count * scaler.x ) * -0.5 + ( scaler.x ) ) + ( lane * ( scaler.x ) )
			var arrow_y = -296 + ( chart_grid.y * grid_scale / 2 ) + ( ( chart_grid.y * chart_zoom.y * meter_multi * grid_scale ) * ( ( time + offset ) / seconds_per_beat ) )
			
			chart_arrow_instance.position = Vector2(arrow_x, arrow_y)
			chart_arrow_instance.direction = int(lane) % 4
			chart_arrow_instance.length = note_length
			chart_arrow_instance.scale = ( chart_grid * grid_scale ) / Vector2(64, 64)
			chart_arrow_instance.color.h = 1 - 0.1 * note_type
			chart_arrow_instance.zoom = chart_zoom
			
			if selected_note.has(index):
				chart_arrow_instance.selected = true
			
			chart_arrow_instance.time = time
			chart_arrow_instance.tempo = get_tempo_at(time)
			chart_arrow_instance.meter = get_meter_at(time)
			
			note_instances.append( chart_arrow_instance )
			
			
			$"Chart Editor UI".add_child( chart_arrow_instance )
		
		index += 1


func check_notes( song_time = $Music/Instrumental.get_playback_position() ):
	
	
	for i in note_instances:
		
		if (i.time < song_time):
			i.modulate = Color(1, 1, 1, 0.5)
			
			if !passed_note_instances.has( i.time ):
				
				passed_note_instances.append( i.time )
				%"Hit Sound".play()
		else:
			i.modulate = Color(1, 1, 1, 1)


func render_events( song_time = $Music/Instrumental.get_playback_position() ):
	
	for i in event_instances.size():
		
		event_instances[0].queue_free()
		event_instances.remove_at(0)
	
	events_list = []
	
	
	for i in chart.get_events_data():
		
		var time = i[0]
		var event_name = i[1]
		var parameters = i[2]
		var lane = 0
		
		var seconds_per_beat = 60.0 / get_tempo_at(time)
		var meter_multi = get_meter_at(time)[1] / get_meter_at(time)[0]
		var grid_scale = ( 16.0 / get_meter_at( time )[1] )
		
		var scaler = chart_grid * chart_zoom * Vector2(grid_scale, grid_scale)
		var range = seconds_per_beat * get_meter_at(time)[0]
		
		if time > (song_time + range * 2):
			continue
		
		if ( ( get_tempo_at(time) == get_tempo_at(song_time) ) && ( time >= (song_time - range) && time <= (song_time + range * 2) ) ): 
			
			var event_instance = event_preload.instantiate()
			
			var arrow_x = ( ( strum_count * scaler.x ) * -0.5 + ( scaler.x / 2) ) + ( lane * ( scaler.x ) )
			var arrow_y = -296 + ( chart_grid.y * grid_scale / 2 ) + ( ( scaler.y * meter_multi ) * ( ( time + offset ) / seconds_per_beat ) )
			
			event_instance.position = Vector2(arrow_x, arrow_y)
			event_instance.scale = ( chart_grid * grid_scale ) / Vector2(64, 64)
			
			if !events_list.has(event_name):
				events_list.append(event_name)
			
			lane = events_list.find(event_name)
			arrow_x = ( ( strum_count * scaler.x ) * -0.5 + ( scaler.x / 2) ) + ( lane * ( scaler.x ) )
			event_instance.position = Vector2(arrow_x, arrow_y)
			
			event_instance.color.h = 1 - 0.1 * events_list.find(event_name)
			event_instance.zoom = chart_zoom
			event_instance.event_name = event_name
			event_instance.parameters = parameters
			event_instance.offset.x = ( -256 * ( events_list.find(event_name) ) )
			
			event_instances.append( event_instance )
			$"Chart Editor UI".add_child( event_instance )


func is_slot_filled(time: float, lane: int) -> bool:
	
	var output = false
	
	for i in chart.get_note_data():
		
		if ( !is_equal_approx(i[0], time) ) || ( i[1] != lane ):
			continue
		elif ( is_equal_approx(i[0], time) ) || ( i[1] == lane ):
			output = true
			i[0] = time
			break
		
	
	return output

func is_slot_filled_event(time: float, lane: int) -> bool:
	
	var output = false
	var index = 0
	
	for i in chart.get_events_data():
		
		if ( !is_equal_approx(i[0], time ) ):
			continue
		elif ( is_equal_approx(i[0], time ) ):
			i[0] = time
			
			if lane == events_list.find( i[1] ):
				
				output = true
				break
		
	
	return output


func grid_position_to_time(pos: Vector2) -> Vector2:
	
	var seconds_per_beat = 60.0 / $Conductor.tempo
	var meter_multi = $Conductor.steps_per_measure / $Conductor.beats_per_measure
	var grid_scale = ( 16.0 / $Conductor.steps_per_measure )
	
	var scaler = chart_grid * chart_zoom * Vector2(grid_scale, grid_scale)
	
	var snap_scale = ( 16.0 / ( get_meter_at( $Music/Instrumental.get_playback_position() )[0] * chart_snap ) )
	
	# var lane = get_grid_position( pos, Vector2( scaler.x / ( 1 + ( ( strum_count + 1 ) % 2 ) ) , 0) ).x
	var lane = get_grid_position( pos, Vector2( 0 , 0) ).x
	var note = get_grid_position( pos ).y * ( chart_snap / 4.0 )
	
	var time = ( ( ( scaler.y * meter_multi ) / chart_snap ) * note ) / scaler.y * ( seconds_per_beat / chart_snap ) - offset
	
	return Vector2( lane, time )


func find_note(time: float, lane: int) -> int:
	
	var output = -1
	var index = 0
	
	for i in chart.get_note_data():
		
		if ( !is_equal_approx(i[0], time) ) || ( i[1] != lane ):
			index += 1
			continue
		elif ( is_equal_approx(i[0], time) ) || ( i[1] == lane ):
			output = index
			i[0] = time
			break
		
	
	return output

func find_event(time: float, lane: int) -> int:
	
	var output = -1
	var index = 0
	
	for i in chart.get_events_data():
		
		if ( !is_equal_approx(i[0], time) ):
			
			index += 1
			continue
		elif ( is_equal_approx(i[0], time) ):
			
			i[0] = time
			
			if ( lane == events_list.find( i[1] ) ):
				
				output = index
				break
			else:
				
				index += 1
		
	
	return output

func count_events(time: float) -> int:
	
	var output = -1
	
	for i in chart.get_events_data():
		
		if ( !is_equal_approx(i[0], time) ):
			continue
		elif ( is_equal_approx(i[0], time) ):
			output += 1
			i[0] = time
		
	
	return output

func find_last_event(time: float) -> int:
	
	var output = -1
	var index = chart.get_events_data().size() - 1
	
	var events_data = chart.get_events_data()
	events_data.reverse()
	
	for i in events_data:
		
		if ( !is_equal_approx(i[0], time) ):
			index -= 1
			continue
		elif ( is_equal_approx(i[0], time) ):
			output = index
			i[0] = time
			print(index)
			break
		
	
	return output


func _on_event_name_text_changed(new_text):
	
	brush_event_name = new_text

func _on_event_parameters_text_changed():
	
	brush_event_parameters = $"UI/Brush Settings/Event Brush/Event Parameters".text


func format_time(time: float, digits: int = 6) -> float:
	
	var time_string = str(time)
	var planes = time_string.split(".")
	
	if planes[0] == "0":
		planes[0] = ""
	
	var output = snapped( time, pow( 10, -( digits - planes[0].length() ) ) )  
	
	return output
