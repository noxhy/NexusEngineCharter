extends Window

# Event names for easy conversion to nexus engine
const event_names = {
	
	# Psych Engine Names
	"Add Camera Zoom": "camera_bop",
	"Change Scroll Speed": "scroll_speed",
	"Screen Shake": "psych_camera_shake",
	"Set Cam Zoom": "camera_zoom",
	
	# Vanilla FnF names
	"FocusCamera": "camera_position",
	"PlayAnimation": "play_animation",
	"SetCameraBop": "bop_delay",
	
}

signal file_created( path: String, chart: Chart )

func _ready():
	_on_chart_type_button_item_selected( %"Chart Type Button".selected )

# Creates a new file that will send out a signal to the chart editor
func new_file( dir: String ):
	
	# Creates the file base properties
	var file = Chart.new()
	file.artist = %"Artist Name".text
	file.song_title = %"Song Title".text
	file.difficulty = %"Song Difficulty".text
	
	file.vocals = %"Vocals File Location".text
	file.instrumental = %"Inst File Location".text
	
	# Converts chart data
	file.chart_data = convert_chart( %"Chart File Location".text, %"Chart Type Button".selected )
	
	# Emits signal to return to the chart editor
	emit_signal( "file_created", dir + "/" + file.song_title + " - " + file.difficulty + ".tres", file )


# Converts a chart at the given path
func convert_chart(path: String, chart_type: int) -> Dictionary:
	
	# Metadata chart data
	var json_file = FileAccess.open( path, FileAccess.READ )
	var json_data = json_file.get_as_text()
	var json = JSON.parse_string(json_data)
	
	var note_data = []
	var event_data = []
	var tempo_data = {}
	
	
	#
	## Vanilla FnF Chart
	#
	
	
	if chart_type == 0:
		
		# Getting the actual chart file
		var chart_path = path.replace( "-metadata", "-chart" )
		
		var chart_json_file = FileAccess.open( chart_path, FileAccess.READ )
		var chart_json_data = chart_json_file.get_as_text()
		var chart_json = JSON.parse_string(chart_json_data)
		
		# Adding tempo data
		for i in json.timeChanges: tempo_data.merge( { i.t: i.bpm }, true )
		
		# Adding Note Data
		var note_types = []
		var difficulty = %"Song Difficulty".text
		
		for i in chart_json.notes.get(difficulty):
			
			var time = i.t / 1000.0
			var lane = i.d
			
			var tempo = get_tempo_at( time, tempo_data )
			var seconds_per_beat = 60.0 / tempo
			
			var length = i.l / 1000.0 / seconds_per_beat
			
			var note_type = 0
			if i.has("k"):
				
				if !note_types.has( i.k ): note_types.append( i.k )
				note_type = note_types.find( i.k ) + 1
			
			note_data.append( [ time, lane, length, note_type ] )
		
		# Adding event data.
		for i in chart_json.events:
			
			var time = i.t / 1000.0
			
			var tempo = get_tempo_at( time, tempo_data )
			var seconds_per_beat = 60.0 / tempo
			
			time = snapped( time, seconds_per_beat )
			
			var event = i.e
			var parameters = []
			
			var event_name = event
			if event_names.has( event ): event_name = event
			
			if i.v is Dictionary:
				
				for j in i.v: parameters.append( str( i.v.get( j ) ))
			
			else: parameters.append( str( i.v ) )
			
			event_data.append( [ time, event_name, parameters ] )
	
	
	#
	## Psych Engine Chart
	#
	
	
	elif chart_type == 1:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge( {0.0: current_bpm}, true )
		var index = 0
		var note_types = []
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			# Checks if the tempo changes, then adds it to the tempos dictionary
			if i.has("changeBPM"):
				
				if i.changeBPM:
					
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			# Camera movement conversion
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				# Converts the ms length to how many beats the hold node lasts
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var note = []
				var lane = j[1]
				
				# Deals with the stupid FnF must hit section bullshit
				if camera_position == 0:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				# Creates the note
				note = [j[0] / 1000.0, int(lane), ms_to_notes]
				
				# Deals with note types
				if j.size() == 4:
					
					if !note_types.has(j[3]):
						note_types.append(j[3])
					
					note.append( note_types.find( j[3] ) + 1 )
				else:
					
					note.append(0)
				
				note_data.append(note)
			
			index += 1
			section_time += seconds_per_measure
		
		# Psych event conversion
		for i in json.song.events:
			
			var time = i[0]
			
			# Event name conversion
			for j in i[1]:
				
				if event_names.has( j[0] ):
					j[0] = event_names.get(j[0])
				
				# Creates the event
				## j[1] is the event name, j[2] is the event parameters
				event_data.append( [ time / 1000.0, j[0], [ j[1], j[2] ] ] )
	
	
	#
	## Andromeda Engine Chart
	#
	
	
	elif chart_type == 2:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge( {0.0: current_bpm}, true )
		var index = 0
		var note_types = []
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			# Checks if the tempo changes, then adds it to the tempos dictionary
			if i.has("changeBPM"):
				
				if i.changeBPM:
					
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			# Camera movement conversion
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				# Converts the ms length to how many beats the hold node lasts
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var note = []
				var lane = j[1]
				
				# Deals with the stupid FnF must hit section bullshit
				if camera_position == 0:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				# Creates the note
				note = [j[0] / 1000.0, int(lane), ms_to_notes, int(j[3])]
				note_data.append(note)
			
			# Andromeda event conversion
			for j in i.events: 
				
				for k in j.events:
					
					event_data.append( [ j.time / 1000.0, k.name, k.args ] )
			
			index += 1
			section_time += seconds_per_measure
	
	
	#
	## Forever Engine Chart
	#
	
	
	elif chart_type == 3:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge( {0.0: current_bpm}, true )
		var index = 0
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			# Checks if the tempo changes, then adds it to the tempos dictionary
			if i.has("changeBPM"):
				
				if i.changeBPM:
					
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			# Camera movement conversion
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				# Converts the ms length to how many beats the hold node lasts
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var note = []
				var lane = j[1]
				
				# Deals with the stupid FnF must hit section bullshit
				if camera_position == 0:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				# Creates the note
				note = [j[0] / 1000.0, int(lane), ms_to_notes]
				
				# Deals with note types
				if j.size() == 5: note.append( j[4] )
				else: note.append(0)
				
				note_data.append(note)
			
			index += 1
			section_time += seconds_per_measure
		
		# Psych event conversion
		for i in json.song.events:
			
			var time = i[0]
			
			# Event name conversion
			for j in i[1]:
				
				if event_names.has( j[0] ):
					j[0] = event_names.get(j[0])
				
				# Creates the event
				## j[1] is the event name, j[2] is the event parameters
				event_data.append( [ time / 1000.0, j[0], [ j[1], j[2] ] ] )
	
	return {
		
		"notes": note_data,
		"events": event_data,
		"tempos": tempo_data,
		"meters": {0.0: [4, 16]},
		
	}
	
	
	#
	## Vanilla FnF Chart ( OLd )
	#
	
	
	if chart_type == 4:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge( {0.0: current_bpm}, true )
		var index = 0
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			# Checks if the tempo changes, then adds it to the tempos dictionary
			if i.has("changeBPM"):
				
				if i.changeBPM:
					
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			# Camera movement conversion
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				# Converts the ms length to how many beats the hold node lasts
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var lane = j[1]
				
				# Deals with the stupid FnF must hit section bullshit
				if camera_position == 1:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				# Creates the note
				var note = [j[0] / 1000.0, int(lane), ms_to_notes, 0]
				note_data.append(note)
			
			index += 1
			section_time += seconds_per_measure


# Get tempo at certain time
func get_tempo_at(time: float, tempo_dict: Dictionary) -> float:
	
	var keys = tempo_dict.keys()
	
	for i in keys.size(): return tempo_dict.get( keys[i] )
	
	return -1


# "Select File Location" button pressed
func _on_vocals_button_pressed(): %"Vocals File Dialog".popup()

# "Select File Location" button pressed
func _on_inst_button_pressed(): %"Inst File Dialog".popup()

# When the vocals file is selected
func _on_vocals_file_dialog_file_selected(path): %"Vocals File Location".text = path

# When the Inst file is selected
func _on_inst_file_dialog_file_selected(path): %"Inst File Location".text = path

# "Create New File" button pressed
func _on_save_button_pressed(): %SaveFolderDialog.popup()

# When the directory of the folder the chart will save in is selected
func _on_save_folder_dialog_dir_selected(dir):
	
	new_file( dir )
	self.queue_free()

# "Select File Location" button pressed
func _on_chart_button_pressed(): %"Chart File Dialog".popup()

# When the chart file is selected
func _on_chart_file_dialog_file_selected(path): %"Chart File Location".text = path

func _on_chart_type_button_item_selected(index):
	
	$"VBoxContainer/HBoxContainer5/Chart Type Label".text = " Chart Type: " + %"Chart Type Button".get_item_text( index )
	if index == 0: $"VBoxContainer/HBoxContainer5/Chart Type Label".text += " (Pick metadata file)"

func _on_close_requested(): self.queue_free()


