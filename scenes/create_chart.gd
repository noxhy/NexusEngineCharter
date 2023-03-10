extends Node2D

var chart_save_loc = "res://"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$ParallaxBackground.scroll_base_offset.x -= 32 * delta


# Vocals File Code


func _on_get_file_button_pressed():
	
	var file_dialogue_node = $"UI/Vocals Container/VBoxContainer/HFlowContainer/FileDialog"
	
	file_dialogue_node.position = clamp_file_dialogue(file_dialogue_node)
	file_dialogue_node.popup()

func _on_file_dialog_file_selected(path):
	
	$"UI/Vocals Container/VBoxContainer/HFlowContainer/Label".text = "Vocals: " + path
	$Music/Vocals.stream = read_audio_file(path)
	



# Instrumental Files Code



func _on_get_file_button_pressed2():
	
	var file_dialogue_node = $"UI/Instrumental Container/VBoxContainer/HFlowContainer/FileDialog"
	
	file_dialogue_node.position = clamp_file_dialogue(file_dialogue_node)
	file_dialogue_node.popup()

func _on_file_dialog_file_selected2(path):
	
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
	
	$"UI/Chart File Container/VBoxContainer/HFlowContainer/Label".text = "Chart File: " + dir
	chart_save_loc = dir
	print(dir)


func _on_save_chart_button_2_pressed():
	
	var file = Chart.new()
	file.artist = $"UI/Artist Container/VBoxContainer/HBoxContainer/LineEdit".text
	file.song_title = $"UI/Song Title Container/VBoxContainer/HBoxContainer/LineEdit".text
	file.difficulty = $"UI/Difficulty Container/VBoxContainer/HBoxContainer/LineEdit".text
	
	file.vocals = $"UI/Vocals Container/VBoxContainer/HFlowContainer/Label".text.trim_prefix("Vocals: ")
	file.instrumental = $"UI/Instrumental Container/VBoxContainer/HFlowContainer/Label".text.trim_prefix("Instrumental: ")
	
	file.chart_data = {
		
		"notes": [],
		"events": [],
		"tempos": {0.0: 60},
		"meters": {0.0: [4, 16]},
		
	}
	
	
	ResourceSaver.save(file, chart_save_loc + "/" + file.song_title + " - " + file.difficulty + ".tres")
	
	Global.file = chart_save_loc + "/" + file.song_title + " - " + file.difficulty + ".tres"
	get_tree().change_scene_to_file("res://scenes/chart_editor.tscn")


func _on_pause_button_toggled(button_pressed):
	
	$Music/Vocals.playing = button_pressed
	$Music/Instrumental.playing = button_pressed
	
	$Music/Vocals.seek(0)
	$Music/Instrumental.seek(0)
