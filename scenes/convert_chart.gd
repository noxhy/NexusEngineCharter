extends Node2D

@export_enum("Vanilla", "Psych") var chart_type = 0

var chart_grab_loc = "res://"
var chart_save_loc = "res://"

var event_names = {
	
	"Add Camera Zoom": "camera_bop",
	"Change Scroll Speed": "scroll_speed",
	"Screen Shake": "psych_camera_shake",
	"Set Cam Zoom": "camera_zoom",
	
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	$ParallaxBackground.scroll_base_offset.x -= 32 * delta


# Chart File Code


func _on_get_file_button_pressed():
	
	var file_dialogue_node = $"UI/Chart Container/VBoxContainer/HFlowContainer/FileDialog"
	
	file_dialogue_node.position = clamp_file_dialogue(file_dialogue_node)
	file_dialogue_node.popup()


func _on_file_dialog_file_selected(path):
	
	$"UI/Chart Container/VBoxContainer/HFlowContainer/Label".text = "Chart File: " + path
	chart_grab_loc = path



# Vocals File Code


func _on_get_file_button_pressed2():
	
	var file_dialogue_node = $"UI/Vocals Container/VBoxContainer/HFlowContainer/FileDialog"
	
	file_dialogue_node.position = clamp_file_dialogue(file_dialogue_node)
	file_dialogue_node.popup()

func _on_file_dialog_file_selected2(path):
	
	$"UI/Vocals Container/VBoxContainer/HFlowContainer/Label".text = "Vocals: " + path
	$Music/Vocals.stream = read_audio_file(path)
	



# Instrumental Files Code



func _on_get_file_button_pressed3():
	
	var file_dialogue_node = $"UI/Instrumental Container/VBoxContainer/HFlowContainer/FileDialog"
	
	file_dialogue_node.position = clamp_file_dialogue(file_dialogue_node)
	file_dialogue_node.popup()

func _on_file_dialog_file_selected3(path):
	
	$"UI/Instrumental Container/VBoxContainer/HFlowContainer/Label".text = "Instrumental: " + path
	$Music/Instrumental.stream = read_audio_file(path)


# Clamp File Dialogue


func clamp_file_dialogue(file_dialogue_node: FileDialog) -> Vector2:
	
	return get_global_mouse_position().clamp(Vector2(0, 0), Vector2(1280 - file_dialogue_node.size.x, 720 - file_dialogue_node.size.y))



# Return sound content


func read_audio_file(path: String):
	
	var file = FileAccess.open(path, FileAccess.READ)
	
	var content = null
	
	print(path)
	
	print("File type: ", path.get_extension())
	
	if (path.get_extension() == "mp3"):
		
		content = AudioStreamMP3.new()
		content.data = file.get_buffer(file.get_length())
		
	
	return content


# Initializing Chart


func _on_save_chart_button_pressed():
	
	var file_dialogue_node = $"UI/Chart File Container/VBoxContainer/HFlowContainer/FileDialog"
	
	file_dialogue_node.position = clamp_file_dialogue(file_dialogue_node)
	file_dialogue_node.popup()

func _on_file_dialog_dir_selected(dir):
	
	$"UI/Chart File Container/VBoxContainer/HFlowContainer/Label".text = "Chart File: " + dir
	
	init_chart_file(dir)


func init_chart_file(dir: String):
	
	$"UI/Chart File Container/VBoxContainer/HFlowContainer/Label".text = "Save Path: " + dir
	chart_save_loc = dir
	print(dir)


func _on_save_chart_button_2_pressed():
	
	var file = Chart.new()
	file.artist = $"UI/Artist Container/VBoxContainer/HBoxContainer/LineEdit".text
	file.song_title = $"UI/Song Title Container/VBoxContainer/HBoxContainer/LineEdit".text
	file.difficulty = $"UI/Difficulty Container/VBoxContainer/HBoxContainer/LineEdit".text
	
	file.vocals = $"UI/Vocals Container/VBoxContainer/HFlowContainer/Label".text.trim_prefix("Vocals: ")
	file.instrumental = $"UI/Instrumental Container/VBoxContainer/HFlowContainer/Label".text.trim_prefix("Instrumental: ")
	file.scroll_speed = 1.0
	
	file.chart_data = convert_chart($"UI/Chart Type/VBoxContainer/HFlowContainer/OptionButton".selected)
	
	
	ResourceSaver.save(file, chart_save_loc + "/" + file.song_title + " - " + file.difficulty + ".tres")
	
	Global.file = chart_save_loc + "/" + file.song_title + " - " + file.difficulty + ".tres"
	get_tree().change_scene_to_file("res://scenes/chart_editor.tscn")


func convert_chart(mode: int) -> Dictionary:
	
	var json_file = FileAccess.open(chart_grab_loc, FileAccess.READ)
	var json_data = json_file.get_as_text()
	
	var json = JSON.parse_string(json_data)
	
	var note_data = []
	var event_data = []
	var tempo_data = {}
	
	
	#
	# Vanilla FnF Chart
	#
	
	
	if mode == 0:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge({0.0: current_bpm}, true)
		var index = 0
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			if i.has("changeBPM"):
				if i.changeBPM:
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var lane = j[1]
				
				if camera_position == 1:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				var note = [j[0] / 1000.0, int(lane), ms_to_notes, 0]
				note_data.append(note)
			
			index += 1
			section_time += seconds_per_measure
	
	
	#
	# Psych Engine Chart
	#
	
	
	elif mode == 1:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge({0.0: current_bpm}, true)
		var index = 0
		var note_types = []
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			
			if i.has("changeBPM"):
				if i.changeBPM:
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var note = []
				var lane = j[1]
				
				if camera_position == 0:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				note = [j[0] / 1000.0, int(lane), ms_to_notes]
				
				if j.size() == 4:
					
					if !note_types.has(j[3]):
						note_types.append(j[3])
					
					note.append( note_types.find( j[3] ) + 1 )
				else:
					
					note.append(0)
				
				note_data.append(note)
			
			index += 1
			section_time += seconds_per_measure
		
		for i in json.song.events:
			
			
			var time = i[0]
			
			for j in i[1]:
				
				if event_names.has( j[0] ):
					j[0] = event_names.get(j[0])
				
				event_data.append( [ time / 1000.0, j[0], [ j[1], j[2] ] ] )
	
	
	#
	# Andromeda Engine Chart
	#
	
	
	elif mode == 2:
		
		var section_time = 0.0
		var current_bpm = json.song.bpm
		tempo_data.merge({0.0: current_bpm}, true)
		var index = 0
		var note_types = []
		
		for i in json.song.notes:
			
			# Too lazy to make sure for BPM changes so
			var seconds_per_beat = 60.0 / current_bpm
			var seconds_per_measure = seconds_per_beat * 4
			
			
			if i.has("changeBPM"):
				if i.changeBPM:
					tempo_data.merge({section_time: i.bpm}, true)
					current_bpm = i.bpm
			
			var camera_position = 0 if i.mustHitSection else 1
			event_data.append([index * seconds_per_measure, "camera_position", [camera_position]])
			
			for j in i.sectionNotes:
				
				# Format: time, lane, length in notes, note type
				
				
				var ms_to_notes = (j[2] / 1000.0) / seconds_per_beat
				var note = []
				var lane = j[1]
				
				if camera_position == 0:
					
					if lane > 3:
						lane -= 4
					else:
						lane += 4
				
				note = [j[0] / 1000.0, int(lane), ms_to_notes, int(j[3])]
				note_data.append(note)
			
			
			for j in i.events: 
				
				for k in j.events:
					
					event_data.append( [ j.time / 1000.0, k.name, k.args ] )
			
			
			index += 1
			section_time += seconds_per_measure
	
	
	return {
		
		"notes": note_data,
		"events": event_data,
		"tempos": tempo_data,
		"meters": {0.0: [4, 16]},
		
	}
