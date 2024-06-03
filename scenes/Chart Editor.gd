extends Node2D

const tempo_list_preload = preload("res://scenes/instances/tempo_list_node.tscn")
const meter_list_preload = preload("res://scenes/instances/meters_list_node.tscn")
const chart_arrow_preload = preload("res://scenes/instances/arrow.tscn")
const event_preload = preload("res://scenes/instances/event.tscn")
const divider_preload = preload("res://scenes/instances/divider.tscn")
const tempo_marker_preload = preload( "res://scenes/instances/tempo_marker.tscn" )

# Popup preloads
const new_file_popup_preload = preload("res://scenes/instances/new_file_popup.tscn")
const open_file_popup_preload = preload("res://scenes/instances/open_file_popup.tscn")
const convert_chart_popup_preload = preload("res://scenes/instances/convert_chart_popup.tscn")

const edit_metadata_popup_preload = preload("res://scenes/instances/edit_metadata_popup.tscn")
const timings_editor_popup_preload = preload("res://scenes/instances/timings_editor.tscn")
const meter_editor_popup_preload = preload("res://scenes/instances/meters_editor.tscn")
const event_editor_popup_preload = preload("res://scenes/instances/event_editor.tscn")
const toggle_strums_popup_preload = preload("res://scenes/instances/toggle_strums_popup.tscn")

@export var chart = Chart.new()
@export var chart_zoom = Vector2(1, 1)
@export var offset = 0.0 

@onready var beat_sounds = true
@onready var step_sounds = false

@export var strum_count = 4
@export var highlight_color = Color( 1, 1, 1, 0.5 )

var playback_speed = 1.0

var vocals_length = 0.0
var instrumental_length = 0.0

var tempo_list = []
var meter_list = []
var measure_marker_list = []
var events_dict = {}

var note_instances: Array = []
var passed_note_instances: Array = []
var event_instances: Array = []
var divider_instances: Array = []
var tempo_marker_instances: Array = []

var chart_grid = Vector2( 32, 32 )
var chart_snap = 4

var follow_marker = true
var can_add_note = true

var old_tempo = 0.0
var old_time = -1.0

var dragging_time = false
var pressing_ctrl = false
var placing_note = false

var layers = []
var selected_note = []
var lanes_disabled: PackedInt32Array

var brush_note_type: int = 0

var can_chart = false

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Layer Offset
	
	layers = get_tree().get_nodes_in_group("layer")
	for i in layers: i.layer -= layers.size()
	
	# Menu Bar Initialization
	%"File Button".get_popup().connect( "id_pressed", self.file_button_item_pressed )
	%"Edit Button".get_popup().connect( "id_pressed", self.edit_button_item_pressed )
	%"Strum Button".get_popup().connect( "id_pressed", self.strum_button_item_pressed )
	%"Audio Button".get_popup().connect( "id_pressed", self.audio_button_item_pressed )


func _process(_delta):
	
	## Details
	
	$"UI/Conductor Stats/Details/Details".text = "Tempo: " + str( $Conductor.tempo )
	$"UI/Conductor Stats/Details/Details".text += "\n" + "Meter: " + str( $Conductor.beats_per_measure ) + " / " + str( $Conductor.steps_per_measure )
	$"UI/Conductor Stats/Details/Details".text += "\n\n" + "Beat Snap: " + str( 1 ) + " / " + str( chart_snap )
	$"UI/Conductor Stats/Details/Details".text += "\n" + "Playback Speed: " + str(playback_speed) + "x"
	
	$Music/Vocals.pitch_scale = playback_speed
	$Music/Instrumental.pitch_scale = playback_speed
	
	
	if $Music/Instrumental.playing:
		
		var song_position = $Music/Instrumental.get_playback_position()
		
		$"UI/Panel/Song Progress".value = song_position
		$"UI/Panel/Song Progress".max_value = instrumental_length
		$"UI/Panel/Song Progress/Time Display Progress".text = float_to_time( song_position )
		$"UI/Panel/Song Progress/Time Display Finish".text = "-" + float_to_time( instrumental_length - song_position )
		
		var tempo_at = get_tempo_at( song_position )[1]
		$Conductor.tempo = tempo_at
		$Conductor.seconds_per_beat = 60.0 / tempo_at
		
		if old_tempo != tempo_at:
			
			old_tempo = tempo_at
			render_notes()
			render_tempo_markers()
		
		var meter_at = get_meter_at( song_position )
		$Conductor.beats_per_measure = meter_at[1]
		$Conductor.steps_per_measure = meter_at[2]
		render_chart()
		
		check_notes( song_position )
	
	
	$"UI/Panel/Song Progress/Time Display Drag".visible = dragging_time
	
	if dragging_time:
		
		$"UI/Panel/Song Progress/Time Display Drag".text = float_to_time( $"UI/Panel/Song Progress".value )
		$"UI/Panel/Song Progress/Time Display Drag".position.x = (576 - 632) + (1280 - 8) * ( $"UI/Panel/Song Progress".value / $"UI/Panel/Song Progress".max_value )
	
	
	queue_redraw()
	
	$UI/Panel/ColorRect/ExtraLabel.text = "Notes Drawn: " + str(note_instances.size()) + "/" + str( chart.get_note_data().size() )
	$UI/Panel/ColorRect/ExtraLabel.text += " • " + "Events Drawn: " + str(event_instances.size()) + "/" + str( chart.get_events_data().size() )
	
	#
	## Inputs
	#
	
	
	if Input.is_action_just_pressed("toggle_song"):
		
		if can_chart:
			
			$Music/Vocals.stream_paused = !$Music/Vocals.stream_paused
			$Music/Instrumental.stream_paused = !$Music/Instrumental.stream_paused
			$"UI/Panel/ColorRect/HBoxContainer/Pause Button".button_pressed = $Music/Instrumental.stream_paused
	
	
	if Input.is_action_just_released("ui_cancel"):
		
		render_notes()
		render_events()
	
	
	if Input.is_action_just_released("debug"):
		check_notes()
	
	
	pressing_ctrl = Input.is_action_pressed("drag_enable")
	
	
	if Input.is_action_just_pressed("mouse_left"):
		
		if can_chart:
			
			var grid_position: Vector2 = grid_position_to_time( get_global_mouse_position() )
			
			var lane = grid_position.x
			var time = grid_position.y
			
			time = format_time(time)
			
			if ( lane >= 0 ) && lane <= ( strum_count - 1 ):
				
				var camera_offset = $Camera2D.position.y - 360
				
				if get_global_mouse_position().y >= 64 + camera_offset && get_global_mouse_position().y <= 640 + camera_offset:
					
					if is_slot_filled( time, lane ):
						
						if pressing_ctrl:
							
							for i in selected_note:
								
								if !lanes_disabled.has(lane):
									
									chart.chart_data.notes.remove_at(i)
									
									for j in selected_note:
										
										if j > i: selected_note[ selected_note.find(j) ] = j - 1
						
						else: chart.chart_data.notes.remove_at( find_note(time, lane) )
						
						selected_note = []
					
					else:
						
						if time > 0:
							
							placing_note = true
							chart.chart_data.notes.append( [ time, lane, 0, brush_note_type ] )
							chart.chart_data.notes.sort_custom(sort_ascending)
							selected_note = [ find_note( time, lane ) ]
					
					render_notes()
			
			elif lane == -1:
				
				var camera_offset = $Camera2D.position.y - 360
				
				if get_global_mouse_position().y >= 64 + camera_offset && get_global_mouse_position().y <= 640 + camera_offset:
					
					if is_slot_filled_event(time):
						
						can_chart = false
						popup_event_editor(time)
					else:
						
						can_chart = false
						popup_event_editor(time)
					
					render_events()
	
	
	## Long note dragging
	if Input.is_action_pressed("mouse_left"):
		
		if can_chart:
			
			if placing_note:
				
				for index in selected_note:
					
					var note: Array = chart.get_note_data()[index]
					
					var time: float = note[0]
					var lane: int = note[1]
					var note_type: int = note[3]
					
					var cursor_time = grid_position_to_time( get_global_mouse_position() ).y
					
					var distance = snappedf( clamp( cursor_time - time, 0.0, 16.0 ) / %Conductor.seconds_per_beat, 1.0 / chart_snap )
					chart.chart_data.notes[ index ] = [ time, lane, distance, note_type ]
					
					if distance > 0:
						
						for note_instance in note_instances:
							
							if note_instance.time == time && note_instance.lane == lane:
								
								note_instance.length = distance
								break
							
							else: continue
	
	
	if Input.is_action_just_released("mouse_left"): placing_note = false
	
	
	if Input.is_action_just_pressed("mouse_middle"):
		
		if can_chart:
			
			var grid_position: Vector2 = grid_position_to_time( get_global_mouse_position() )
			
			var lane = grid_position.x
			var time = grid_position.y
			
			time = format_time(time)
			
			if lane >= 0 && lane <= strum_count - 1:
				
				var camera_offset = $Camera2D.position.y - 360
				
				if get_global_mouse_position().y >= 64 + camera_offset && get_global_mouse_position().y <= 640 + camera_offset:
					
					if is_slot_filled(time, lane):
						
						selected_note.append( find_note(time, lane) )
					
					render_notes()
	
	
	if Input.is_action_just_released("scroll_up"):
		
		if pressing_ctrl: chart_snap = clamp( chart_snap + 1, 1, 64 )
		
		else:
			
			if $Music/Instrumental.stream_paused:
				
				if can_chart:
					
					passed_note_instances = []
					
					var song_position = $Music/Instrumental.get_playback_position()
					var snap = ( 60.0 / get_tempo_at( song_position )[1] ) / ( get_meter_at( song_position )[2] / get_meter_at( song_position )[1] )
					
					song_position = snappedf( song_position - snap, snap )
					song_position = clamp( song_position, 0, $Music/Instrumental.stream.get_length() )
					
					$Music/Vocals.play( song_position )
					$Music/Instrumental.play( song_position )
					
					$Music/Vocals.stream_paused = true
					$Music/Instrumental.stream_paused = true
					
					render_chart()
					render_notes( song_position )
					render_events( song_position )
	
	
	if Input.is_action_just_released("scroll_down"):
		
		if pressing_ctrl: chart_snap = clamp( chart_snap - 1, 1, 64 )
		
		else:
			
			if $Music/Instrumental.stream_paused:
				
				if can_chart:
					
					passed_note_instances = []
					
					var song_position = $Music/Instrumental.get_playback_position()
					var snap = ( 60.0 / get_tempo_at( song_position )[1] ) / ( get_meter_at( song_position )[2] / get_meter_at( song_position )[1] )
					
					song_position = snappedf( song_position + snap, snap )
					song_position = clamp( song_position, 0, $Music/Instrumental.stream.get_length() )
					
					$Music/Vocals.play( song_position )
					$Music/Instrumental.play( song_position )
					
					$Music/Vocals.stream_paused = true
					$Music/Instrumental.stream_paused = true
					
					render_chart()
					render_notes( song_position )
					render_events( song_position )
	
	
	if Input.is_action_just_pressed("zoom_in"):
		
		if pressing_ctrl:
			
			chart_zoom.y = clamp( chart_zoom.y + 0.1, 0.1, 2 )
			
			render_chart()
			render_notes()
			render_events()
	
	
	if Input.is_action_just_pressed("zoom_out"):
		
		if pressing_ctrl:
			
			chart_zoom.y = clamp( chart_zoom.y - 0.1, 0.1, 2 )
			
			render_chart()
			render_notes()
			render_events()
	


func _on_conductor_new_beat(_current_beat, measure_relative):
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	
	if measure_relative == 0:
		
		if beat_sounds:
			$"Conductor/Measure Sound".play(0.56)
		
		tween.tween_property($Background/Background, "scale", Vector2(1.05, 1.05), 0.0125)
		
		render_notes()
		render_events()
		
	else:
		
		if beat_sounds:
			$"Conductor/Beat Sound".play(0.56)
		
		tween.tween_property($Background/Background, "scale", Vector2(1.015, 1.015), 0.0125)
	
	
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property($Background/Background, "scale", Vector2(1, 1), 0.2).set_delay(0.0125)


func _on_conductor_new_step(_current_step, _measure_relative):
	
	if step_sounds:
		$"Conductor/Step Sound".play(0.56)


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
	
	render_notes()
	render_events()


func _on_pause_button_toggled(button_pressed):
	
	$Music/Vocals.stream_paused = button_pressed
	$Music/Instrumental.stream_paused = button_pressed


func read_audio_file(path: String):
	
	var file = FileAccess.open(path, FileAccess.READ)
	
	var content = null
	
	print(path)
	
	print("File type: ", path.get_extension())
	
	if ( path.get_extension() == "mp3" ):
		
		content = AudioStreamMP3.new()
		content.data = file.get_buffer(file.get_length())
	
	elif ( path.get_extension() == "ogg" ):
		
		content = AudioStreamOggVorbis.load_from_file( path )
	
	return content


func _on_speed_slider_value_changed(value): playback_speed = value
func _on_hit_sound_volume_value_changed(value): $"Hit Sound".volume_db = value

func _on_rewind_button_pressed():
	
	var vocals_seek = clamp($Music/Vocals.get_playback_position() - 10, 0, vocals_length)
	var instrumental_seek = clamp($Music/Instrumental.get_playback_position() - 10, 0, instrumental_length)
	
	$Music/Vocals.seek(vocals_seek)
	$Music/Instrumental.seek(instrumental_seek)
	passed_note_instances = []
	
	render_notes()
	render_events()


func _on_fast_forward_button_pressed():
	
	var vocals_seek = clamp($Music/Vocals.get_playback_position() + 10, 0, vocals_length)
	var instrumental_seek = clamp($Music/Instrumental.get_playback_position() + 10, 0, instrumental_length)
	
	$Music/Vocals.seek(vocals_seek)
	$Music/Instrumental.seek(instrumental_seek)
	passed_note_instances = []
	
	render_notes()
	render_events()


func _on_restart_button_pressed():
	
	$Music/Vocals.seek(0)
	$Music/Instrumental.seek(0)
	passed_note_instances = []
	
	render_notes()
	render_events()


func _on_skip_button_pressed():
	
	$Music/Vocals.seek(vocals_length)
	$Music/Instrumental.seek(instrumental_length - 0.1)
	passed_note_instances = []
	
	render_notes()
	render_events()


# Save Chart


func _on_save_button_pressed():
	ResourceSaver.save(chart, chart.resource_path)


# Tempo List Shit


func delete_tempo_at(time: float): chart.chart_data.tempos.erase(time)


# Meter List Shit

func delete_meter_at(time: float): chart.chart_data.meters.erase(time)


# Grid Stuff


@warning_ignore("shadowed_variable")
func snap_to_grid(pos: Vector2, grid: Vector2 = Vector2(8, 8), offset: Vector2 = Vector2(0, 0)) -> Vector2:
	
	pos.x = int( ( pos.x + offset.x ) / grid.x )
	pos.y = int( ( pos.y + offset.y ) / grid.y )
	
	return pos


func _draw():
	
	var grid_scale = ( 16.0 / ( %Conductor.steps_per_measure ) )
	var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale * ( 4.0 / chart_snap ) )
	var meter_multi = %Conductor.steps_per_measure / %Conductor.beats_per_measure
	
	var rectangle_position = grid_position_to_time( get_global_mouse_position() )
	
	var lane = rectangle_position.x
	var time = rectangle_position.y + chart.offset
	
	rectangle_position.x = ( ( strum_count * scaler.x ) * -0.5 ) + ( lane * ( scaler.x ) ) + 640
	rectangle_position.y = 64 + ( ( chart_grid.y * chart_zoom.y * meter_multi * grid_scale ) * ( time / %Conductor.seconds_per_beat ) ) 
	
	if ( ( lane >= -1 ) && ( lane < strum_count ) ): draw_rect( Rect2( rectangle_position, scaler ), highlight_color )


@warning_ignore("shadowed_variable")
func get_grid_position( pos: Vector2, offset: Vector2 = Vector2(0, 0) ) -> Vector2:
	
	var grid_scale = ( 16.0 / ( get_meter_at( $Music/Instrumental.get_playback_position() )[2] ) )
	
	var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale * ( 4.0 / chart_snap ) )
	
	var grid_position = pos - ( Vector2(640, 64) - offset ) + ( scaler * ( strum_count / 2.0 ) * Vector2(1, 0) )
	
	grid_position = grid_position / scaler
	grid_position = Vector2( floor( grid_position.x - 1 ), floor( grid_position.y )  )
	
	return Vector2( grid_position.x, grid_position.y )

#
## Chart Rendering
#

func render_chart():
	
	%Grid.columns = strum_count
	
	var song_position = $Music/Instrumental.get_playback_position()
	var meter = get_meter_at( song_position )
	
	%Grid.position.x = 0
	
	%Grid.rows = meter[2] 
	
	var grid_scale = ( 16.0 / meter[2] )
	var scaler: float = chart_grid.y * chart_zoom.y * grid_scale
	
	$ParallaxBackground/ParallaxLayer.motion_mirroring = Vector2( 0, scaler * %Grid.rows )
	%Grid.zoom = Vector2( grid_scale, grid_scale ) * chart_zoom
	
	var grid_height = %Grid/TextureRect.size.y * %Grid/TextureRect.scale.y
	
	var seconds_per_beat = 60.0 / get_tempo_at( song_position )[1]
	var speed = ( grid_height / ( seconds_per_beat * meter[1] ) )
	
	#
	## Divider placement
	#
	
	for i in divider_instances.size():
		
		divider_instances[0].queue_free()
		divider_instances.remove_at(0)
	
	
	# Disabled highlights
	for lane in lanes_disabled:
		
		var divider_instance = divider_preload.instantiate()
		
		var gridspace_length = %Grid/TextureRect.size.x * %Grid/TextureRect.scale.x / strum_count
		
		divider_instance.size.x = gridspace_length
		divider_instance.size.y = %Grid/TextureRect.size.y * %Grid/TextureRect.scale.y
		divider_instance.color = Color(0.075, 0.075, 0.075, 0.5)
		
		divider_instance.position.x = %Grid/TextureRect.position.x + ( gridspace_length * lane )
		
		%Grid.add_child( divider_instance )
		divider_instances.append( divider_instance )
	
	
	# Horizontal Dividers
	for i in meter[1]:
		
		var divider_instance = divider_preload.instantiate()
		
		var meter_multi = meter[2] / meter[1]
		
		divider_instance.size.x = %Grid/TextureRect.size.x * %Grid/TextureRect.scale.x
		
		if i == 0: divider_instance.size.y = 4
		else: divider_instance.size.y = 2
		
		divider_instance.position.x = %Grid/TextureRect.position.x
		divider_instance.position.y = %Grid/TextureRect.position.y + ( scaler * i * meter_multi )
		divider_instance.position.y -= divider_instance.size.y / 2
		
		%Grid.add_child( divider_instance )
		divider_instances.append( divider_instance )
	
	
	# Vertical Dividers
	for i in ( strum_count / 4 ) + 1:
		
		var divider_instance = divider_preload.instantiate()
		
		var gridspace_length = %Grid/TextureRect.size.x * %Grid/TextureRect.scale.x / strum_count
		
		divider_instance.size.x = 2
		divider_instance.size.y = %Grid/TextureRect.size.y * %Grid/TextureRect.scale.y
		
		divider_instance.position.x = %Grid/TextureRect.position.x + ( gridspace_length * 4 * i )
		divider_instance.position.x -= divider_instance.size.x / 2.0
		
		%Grid.add_child( divider_instance )
		divider_instances.append( divider_instance )
	
	
	%"Song Pos Marker".size.x = %Grid/TextureRect.size.x * %Grid/TextureRect.scale.x * 1.1
	%"Song Pos Marker".position.x = %"Song Pos Marker".size.x * -0.5
	
	%"Song Pos Marker".position.y = %Grid.position.y - ( %"Song Pos Marker".size.y * 0.5 )
	%"Song Pos Marker".position.y += ( speed * song_position )
	
	if follow_marker: $Camera2D.position.y = 360 + %Grid.position.y + ( speed * song_position )


func update_measure_markers():
	
	for i in measure_marker_list.size():
		
		measure_marker_list[0].queue_free()
		measure_marker_list.remove_at(0)

#
# Utilities
#

## Loads chart file
func load_file( path: String ):
	
	chart = load( path )
	events_dict = {}
	
	$Music/Vocals.stream = read_audio_file(chart.vocals)
	$Music/Instrumental.stream = read_audio_file(chart.instrumental)
	
	$Conductor.tempo = chart.get_tempos_data().get(0.0)
	
	$Conductor.beats_per_measure = chart.get_meters_data().get(0.0)[0]
	$Conductor.steps_per_measure = chart.get_meters_data().get(0.0)[1]
	
	$Music/Vocals.play()
	$Music/Instrumental.play()
	
	%"Pause Button".button_pressed = $Music/Instrumental.stream_paused
	
	if( $Music/Vocals.stream != null ): vocals_length = $Music/Vocals.stream.get_length()
	
	instrumental_length = $Music/Instrumental.stream.get_length()
	
	offset = chart.offset
	$Conductor.offset = chart.offset
	
	chart.chart_data.notes.sort_custom(sort_ascending)
	chart.chart_data.events.sort_custom(sort_ascending)
	
	render_events()
	render_tempo_markers()


func sort_ascending( a, b ):
	
	if a[0] < b[0]: return true
	return false

## Binary Searches of notes and events
func bsearch_left_range( value_set: Array, length: int, left_range: float ) -> int:
	
	if ( length == 0 ): return -1
	if ( value_set[ length - 1 ][0] < left_range ): return -1
	
	var low: int = 0
	var high: int = length - 1
	
	while ( low <= high ):
		
		@warning_ignore("integer_division")
		var mid: int = low + ( ( high - low ) / 2 )
		
		if ( value_set[mid][0] >= left_range ): high = mid - 1
		else: low = mid + 1
	
	return high + 1


func bsearch_right_range( value_set: Array, length: int, right_range: float ) -> int:
	
	if ( length == 0 ): return -1
	if ( value_set[0][0] > right_range ): return -1
	
	var low: int = 0
	var high: int = length - 1
	
	while ( low <= high ):
		
		@warning_ignore("integer_division")
		var mid: int = low + ( ( high - low ) / 2 )
		
		if ( value_set[mid][0] > right_range ): high = mid - 1
		else: low = mid + 1
	
	return low - 1


## Updates song metadata
@warning_ignore("shadowed_variable")
func set_metadata( artist: String, song_title: String, song_difficulty: String, offset: float, scroll_speed: float ):
	
	chart.artist = artist
	chart.song_title = song_title
	chart.difficulty = song_difficulty
	
	chart.offset = offset
	self.offset = offset
	chart.scroll_speed = scroll_speed
	
	can_chart = true

@warning_ignore("shadowed_variable")
func set_tempo_list( tempo_list: Dictionary ):
	
	chart.chart_data.tempos.merge( tempo_list, true )
	render_tempo_markers()

@warning_ignore("shadowed_variable")
func set_meter_list( meter_list: Dictionary ): chart.chart_data.meters.merge( meter_list, true )

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
func get_tempo_at(time: float) -> Array:
	
	var tempo_dict = chart.get_tempos_data()
	var keys = tempo_dict.keys()
	
	var tempo_output = [ 0.0, 0.0 ]  
	
	for i in keys.size():
		
		var dict_time = keys[i]
		
		if time >= dict_time: tempo_output = [ dict_time, tempo_dict.get(keys[i]) ]
	
	return tempo_output


##  Gets the meter at a certain time in seconds
func get_meter_at(time: float) -> Array:
	
	var meter_dict = chart.get_meters_data()
	var keys = meter_dict.keys()
	
	var meter_output = [ 0.0, 1, 1 ]
	
	for i in keys.size():
		var dict_time = keys[i]
		
		if time >= dict_time:
			
			meter_output[0] = dict_time
			meter_output[1] = meter_dict.get(keys[i])[0]
			meter_output[2] = meter_dict.get(keys[i])[1]
		
		else: break
	
	return meter_output


## Returns the measure at a certain time
func get_measure_at(time: float, _song_length: float) -> int:
	
	var measure = 0
	
	var time_temp = time
	var meter_dict = chart.get_meters_data()
	var keys = meter_dict.keys()
	
	for i in keys.size():
		
		var dict_time = keys[i]
		
		if dict_time > time: break
		
		var tempo_at = get_tempo_at(dict_time)
		var meter_at = get_meter_at(dict_time)
		
		var seconds_per_beat = 60.0 / tempo_at
		
		var seconds_per_measure = seconds_per_beat * meter_at[0]
		
		var measure_add = 0
		
		measure_add = int( time_temp / seconds_per_measure )
		
		time_temp -= keys[ clamp( i + 1, 0, keys.size() - 1 ) ]
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
	render_notes()
	render_events()


func _on_set_strum_pressed(): 
	
	strum_count = $"UI/Charting Tabs/Chart/Strum Text".text.to_int()
	render_notes()
	render_events()

#
# Chart Rendering Fuckery
#

func render_notes( song_time = $Music/Instrumental.get_playback_position() ):
	
	for i in note_instances.size():
		
		note_instances[0].queue_free()
		note_instances.remove_at(0)
	
	# Getting tempo and media data
	var tempo_data = get_tempo_at(song_time)
	var tempo = tempo_data[1]
	var meter = get_meter_at(song_time)
	
	var seconds_per_beat = 60.0 / tempo
	
	var note_data = chart.get_note_data()
	
	# Searching for notes within the given range
	@warning_ignore("shadowed_global_identifier")
	var range = seconds_per_beat * meter[1] * ( 1.0 / chart_zoom.y )
	var index_left = bsearch_left_range( note_data, note_data.size(), song_time - range * 4 )
	var index_right = bsearch_right_range( note_data, note_data.size(), song_time + range * 4 )
	
	if ( index_left == -1 ) || ( index_right == -1 ): return
	
	for index in range( index_left, index_right + 1 ): render_note(index)


func render_note( index: int ) :
	
	# Grabbing note data
	var note = chart.get_note_data()[index]
	
	var time = note[0]
	var lane = note[1]
	var note_length = note[2]
	var note_type = note[3]
	
	if lanes_disabled.has(lane): return
	
	var tempo_data = get_tempo_at(time)
	var tempo = tempo_data[1]
	var meter = get_meter_at(time)
	
	var seconds_per_beat = 60.0 / tempo
	# Adjusts the position to the grid
	var meter_multi = meter[2] / meter[1]
	var grid_scale = ( 16.0 / meter[2] )
	
	# Scales the grid with the zoom and and grid scale
	var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale )
	
	var chart_arrow_instance = chart_arrow_preload.instantiate()
	
	# var arrow_x = ( ( strum_count * scaler.x ) * -0.5 + ( scaler.x ) ) + ( lane * ( scaler.x ) )
	var arrow_x = ( ( strum_count * scaler.x ) * -0.5 + ( scaler.x / 2.0 ) ) + ( lane * ( scaler.x ) )
	var arrow_y = -296 + ( chart_grid.y * grid_scale / 2 ) + ( ( chart_grid.y * chart_zoom.y * meter_multi * grid_scale ) * ( ( time + offset ) / seconds_per_beat ) )
	
	chart_arrow_instance.position = Vector2( arrow_x, arrow_y )
	chart_arrow_instance.direction = int(lane) % 4
	chart_arrow_instance.length = note_length
	chart_arrow_instance.lane = lane
	chart_arrow_instance.scale = ( chart_grid * grid_scale ) / Vector2(64, 64)
	chart_arrow_instance.color.h = 1 - 0.1 * note_type
	chart_arrow_instance.zoom = chart_zoom
	
	chart_arrow_instance.selected = selected_note.has(index)
	
	chart_arrow_instance.time = time
	chart_arrow_instance.tempo = tempo
	chart_arrow_instance.meter = [ meter[1], meter[2] ]
	
	note_instances.append( chart_arrow_instance )
	
	$"Chart Editor UI".add_child( chart_arrow_instance )


func check_notes( song_time = $Music/Instrumental.get_playback_position() ):
	
	
	for i in note_instances:
		
		if (i.time < song_time):
			
			i.modulate = Color(1, 1, 1, 0.5)
			
			if !passed_note_instances.has( i.time ):
				
				passed_note_instances.append( i.time )
				%"Hit Sound".play()
		
		else: i.modulate = Color(1, 1, 1, 1)


func render_events( song_time = $Music/Instrumental.get_playback_position() ):
	
	for i in event_instances.size():
		
		event_instances[0].queue_free()
		event_instances.remove_at(0)
	
	events_dict = {}
	
	var tempo_data = get_tempo_at(song_time)
	var tempo = tempo_data[1]
	var meter = get_meter_at(song_time)
	
	var seconds_per_beat = 60.0 / tempo
	
	var events_data = chart.get_events_data()
	
	@warning_ignore("shadowed_global_identifier")
	var range = seconds_per_beat * meter[1] * ( 1.0 / chart_zoom.y )
	var index_left = bsearch_left_range( events_data, events_data.size(), song_time - range )
	var index_right = bsearch_right_range( events_data, events_data.size(), song_time + range * 3 )
	
	if index_left == -1: return
	
	for index in range( index_left, index_right + 1 ):
		
		var event = events_data[index]
		var time = event[0]
		
		if !events_dict.has( time ): events_dict.merge( { time: 1 } )
		else: continue
		
		render_event( index )


func render_event( index: int ):
	
	var event = chart.get_events_data()[index]
	var time = event[0]
	var lane = 0
	
	if lanes_disabled.has(lane): return
	
	var tempo_data = get_tempo_at(time)
	var tempo = tempo_data[1]
	var meter = get_meter_at(time)
	
	var seconds_per_beat = 60.0 / tempo
	# Adjusts the position to the grid
	var meter_multi = meter[2] / meter[1]
	var grid_scale = ( 16.0 / meter[2] )
	
	# Scales the grid with the zoom and and grid scale
	var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale )
	
	var event_instance = event_preload.instantiate()
	
	var arrow_x = ( ( strum_count * scaler.x ) * -0.5 + -( scaler.x / 2.0 ) ) + ( lane * ( scaler.x ) )
	var arrow_y = -296 + ( chart_grid.y * grid_scale / 2 ) + ( ( scaler.y * meter_multi ) * ( ( time + offset ) / seconds_per_beat ) )
	
	event_instance.position = Vector2( arrow_x, arrow_y )
	event_instance.scale = ( chart_grid * grid_scale ) / Vector2( 64, 64 )
	
	event_instance.color = Color( 0.494, 0.369, 1 )
	event_instance.zoom = chart_zoom
	
	event_instances.append( event_instance )
	$"Chart Editor UI".add_child( event_instance )


func render_tempo_markers():
	
	for i in tempo_marker_instances.size():
		
		tempo_marker_instances[0].queue_free()
		tempo_marker_instances.remove_at(0)
	
	for time in chart.get_tempos_data().keys():
		
		var tempo = get_tempo_at(time)[1]
		var meter = get_meter_at(time)
		
		var seconds_per_beat = 60.0 / tempo
		var meter_multi = meter[2] / meter[1]
		var grid_scale = ( 16.0 / meter[2] )
		
		var scaler = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale )
		
		var x = ( ( strum_count * scaler.x ) * -0.5 ) + ( ( strum_count ) * ( scaler.x ) ) + 2
		var y = -296 + ( ( scaler.y * meter_multi ) * ( ( time + offset ) / seconds_per_beat ) )
		
		var tempo_marker_instance = tempo_marker_preload.instantiate()
		
		tempo_marker_instance.position = Vector2( x, y )
		tempo_marker_instance.scale = ( chart_grid * chart_zoom * Vector2( grid_scale, grid_scale ) ) / Vector2( 32.0, 32.0 )
		tempo_marker_instance.tempo = tempo
		
		tempo_marker_instances.append(tempo_marker_instance)
		$"Chart Editor UI".add_child(tempo_marker_instance)
	
	can_chart = true


# Grid Coniditonals


func is_slot_filled(time: float, lane: int) -> bool:
	
	for i in chart.get_note_data():
		
		if ( !is_equal_approx(i[0], time) ) || ( i[1] != lane ): continue
		
		elif ( is_equal_approx(i[0], time) ) || ( i[1] == lane ):
			
			i[0] = time
			return true
	
	return false


func is_slot_filled_event(time: float) -> bool:
	
	for i in chart.get_events_data():
		
		if ( !is_equal_approx(i[0], time ) ): continue
		
		elif ( is_equal_approx(i[0], time ) ):
			
			i[0] = time
			return true
	
	return false


func grid_position_to_time(pos: Vector2) -> Vector2:
	
	var seconds_per_beat: float = 60.0 / $Conductor.tempo
	var meter: Array = [ $Conductor.beats_per_measure, $Conductor.steps_per_measure ]
	
	var meter_multi: float = meter[1] / meter[0]
	var grid_scale: float = ( 16.0 / meter[1] )
	
	var scaler: Vector2 = chart_grid * chart_zoom * Vector2( grid_scale, grid_scale )
	
	var _snap_scale: float = ( 16.0 / ( meter[1] * chart_snap ) )
	
	@warning_ignore("narrowing_conversion")
	var lane: int = get_grid_position( pos, Vector2( scaler.x / ( 1 + ( ( strum_count ) % 2 ) ) , 0 ) ).x
	var note: float = get_grid_position( pos ).y * ( chart_snap / 4.0 )
	
	var time: float = ( ( ( scaler.y * meter_multi ) / chart_snap ) * note ) / scaler.y * ( seconds_per_beat / chart_snap ) - offset
	
	return Vector2( lane, time )


func find_note( time: float, lane: int ) -> int:
	
	var note_data = chart.get_note_data()
	var index_left: int = bsearch_left_range( note_data, note_data.size(), time )
	var index_right: int = bsearch_right_range( note_data, note_data.size(), time )
	
	for i in range( index_left, index_right + 1 ):
		
		if note_data[i][1] == lane:
			
			return i
	
	return -1


func find_event( time: float, event_name: String ) -> int:
	
	print( "finding event ", time )
	
	var event_data = chart.get_events_data()
	var index_left: int = bsearch_left_range( event_data, event_data.size(), time )
	var index_right: int = bsearch_right_range( event_data, event_data.size(), time )
	
	for i in range( index_left, index_right + 1 ):
		
		if event_data[i][1] == event_name:
			
			return i
	
	return -1


func find_events( time: float ) -> Array:
	
	var output = []
	
	var event_data = chart.get_events_data()
	var index_left: int = bsearch_left_range( event_data, event_data.size(), time )
	var index_right: int = bsearch_right_range( event_data, event_data.size(), time )
	
	for i in range( index_left, index_right + 1 ): output.append(event_data[i])
	
	return output


func count_events(time: float) -> int:
	
	var event_data = chart.get_events_data()
	var index_left: int = bsearch_left_range( event_data, event_data.size(), time )
	var index_right: int = bsearch_right_range( event_data, event_data.size(), time )
	
	print( index_right + 2 - index_left )
	
	return index_right + 2 - index_left


func find_last_event(time: float) -> int:
	
	var index = chart.get_events_data().size() - 1
	
	var events_data = chart.get_events_data()
	events_data.reverse()
	
	for i in events_data:
		
		if ( !is_equal_approx(i[0], time ) ):
			
			index -= 1
			continue
		
		elif ( is_equal_approx(i[0], time ) ):
			
			i[0] = time
			print(index)
			return index
		
	
	return -1


func popup_event_editor( time: float ):
	
	var event_editor_popup_instance = event_editor_popup_preload.instantiate()
	
	event_editor_popup_instance.events = find_events( time )
	event_editor_popup_instance.time = time
	
	add_child(event_editor_popup_instance)
	event_editor_popup_instance.popup()
	
	event_editor_popup_instance.connect( "event_added", self.add_event )
	event_editor_popup_instance.connect( "event_removed", self.remove_event )
	event_editor_popup_instance.connect( "close_requested", self.close_popup )


func add_event( event: Array ):
	
	chart.chart_data.events.append(event)
	chart.chart_data.events.sort_custom(sort_ascending)
	
	can_chart = false
	
	popup_event_editor(event[0])
	render_events()


func remove_event( time: float, event_name: String ):
	
	chart.chart_data.events.remove_at( find_event( time, event_name ) )
	
	can_chart = false
	if count_events(time) == 0: can_chart = true
	
	popup_event_editor(time)
	render_events()


func set_lanes_disabled( lanes: PackedInt32Array ):
	
	lanes_disabled = lanes
	
	render_chart()
	render_notes()


func _on_note_type_value_changed(value): brush_note_type = value


func format_time(time: float, digits: int = 6) -> float:
	
	var time_string = str(time)
	var planes = time_string.split(".")
	
	if planes[0] == "0": planes[0] = ""
	
	var output = snapped( time, pow( 10, -( digits - planes[0].length() ) ) )  
	
	return output


@warning_ignore("shadowed_variable")
func _on_save_folder_dialog_dir_selected( path: String, chart: Chart ):
	
	ResourceSaver.save(chart, path)
	load_file( path )

#
# Menu Bar Item Pressed
#

# file button item pressed
func file_button_item_pressed(id):
	
	var item_name: String = %"File Button".get_popup().get_item_text(id)
	
	if item_name == "New File":
		
		can_chart = false
		
		var new_file_popup_instance = new_file_popup_preload.instantiate()
		
		add_child( new_file_popup_instance )
		new_file_popup_instance.popup()
		new_file_popup_instance.connect( "file_created", self._on_save_folder_dialog_dir_selected )
		new_file_popup_instance.connect( "close_requested", self.close_popup )
	
	elif item_name == "Open File":
		
		can_chart = false
		
		var open_file_popup_instance = open_file_popup_preload.instantiate()
		
		add_child( open_file_popup_instance )
		open_file_popup_instance.popup()
		open_file_popup_instance.connect( "file_selected", self.load_file )
		open_file_popup_instance.connect( "close_requested", self.close_popup )
	
	elif item_name == "Save File": ResourceSaver.save(chart, chart.resource_path)
	
	elif item_name == "Convert Chart File":
		
		can_chart = false
		
		var convert_chart_popup_instance = convert_chart_popup_preload.instantiate()
		
		add_child( convert_chart_popup_instance )
		convert_chart_popup_instance.popup()
		convert_chart_popup_instance.connect( "file_created", self._on_save_folder_dialog_dir_selected )
		convert_chart_popup_instance.connect( "close_requested", self.close_popup )


# edit button item pressed
func edit_button_item_pressed(id):
	
	var item_name: String = %"Edit Button".get_popup().get_item_text(id)
	
	if item_name == "Edit Metadata":
		
		can_chart = false
		
		var edit_metadata_popup_instance = edit_metadata_popup_preload.instantiate()
		
		edit_metadata_popup_instance.artist = chart.artist
		edit_metadata_popup_instance.song_title = chart.song_title
		edit_metadata_popup_instance.song_difficulty = chart.difficulty
		
		edit_metadata_popup_instance.offset = chart.offset
		edit_metadata_popup_instance.scroll_speed = chart.scroll_speed
		
		add_child(edit_metadata_popup_instance)
		edit_metadata_popup_instance.popup()
		edit_metadata_popup_instance.connect( "metadata_changed", self.set_metadata )
		edit_metadata_popup_instance.connect( "close_requested", self.close_popup )
	
	elif item_name == "Edit Tempo Data":
		
		can_chart = false
		
		var timings_editor_popup_instance = timings_editor_popup_preload.instantiate()
		
		timings_editor_popup_instance.tempo_list = chart.get_tempos_data()
		
		add_child(timings_editor_popup_instance)
		timings_editor_popup_instance.popup()
		
		timings_editor_popup_instance.connect( "timings_data_changed", self.set_tempo_list )
		timings_editor_popup_instance.connect( "close_requested", self.close_popup )
	
	elif item_name == "Edit Meter Data":
		
		can_chart = false
		
		var meter_editor_popup_instance = meter_editor_popup_preload.instantiate()
		
		meter_editor_popup_instance.meter_list = chart.get_meters_data()
		
		add_child(meter_editor_popup_instance)
		meter_editor_popup_instance.popup()
		
		meter_editor_popup_instance.connect( "meter_data_changed", self.set_meter_list )
		meter_editor_popup_instance.connect( "close_requested", self.close_popup )


# edit button item pressed
func audio_button_item_pressed(id):
	
	var item_name: String = %"Audio Button".get_popup().get_item_text(id)
	
	if item_name == "Beat Sounds":
		
		beat_sounds = !beat_sounds
		%"Audio Button".get_popup().set_item_checked( id, beat_sounds )
	
	elif item_name == "Step Sounds":
		
		step_sounds = !step_sounds
		%"Audio Button".get_popup().set_item_checked( id, step_sounds )
	
	elif item_name == "Hit Sounds":
		pass


# strum button item pressed
func strum_button_item_pressed(id):
	
	var item_name: String = %"Strum Button".get_popup().get_item_text(id)
	
	if item_name == "Add Strumline":
		
		strum_count = clamp( strum_count + 4, 4, 16 )
		
		render_chart()
		render_events()
		render_notes()
	
	elif item_name == "Remove Strumline":
		
		strum_count = clamp( strum_count - 4, 4, 16 )
		
		render_chart()
		render_events()
		render_notes()
	
	elif item_name == "Toggle Strumlines":
		
		can_chart = false
		
		var toggle_strums_popup_instance = toggle_strums_popup_preload.instantiate()
		
		toggle_strums_popup_instance.strum_count = strum_count
		toggle_strums_popup_instance.lanes_disabled = lanes_disabled
		
		add_child(toggle_strums_popup_instance)
		toggle_strums_popup_instance.popup()
		
		toggle_strums_popup_instance.connect( "lanes_disbaled_changed", self.set_lanes_disabled )
		toggle_strums_popup_instance.connect( "close_requested", self.close_popup )

func close_popup(): can_chart = true
