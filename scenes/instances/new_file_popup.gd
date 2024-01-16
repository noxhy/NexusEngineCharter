extends Window

signal file_created( path: String, chart: Chart )


# Creates a new file that will send out a signal to the chart editor
func new_file( dir: String ):
	
	# Creates the file base properties
	var file = Chart.new()
	file.artist = %"Artist Name".text
	file.song_title = %"Song Title".text
	file.difficulty = %"Song Difficulty".text
	
	file.vocals = %"Vocals File Location".text
	file.instrumental = %"Inst File Location".text
	
	# Barebones chart data
	file.chart_data = {
		
		"notes": [],
		"events": [],
		"tempos": {0.0: 60},
		"meters": {0.0: [4, 16]},
		
	}
	
	# Emits signal to return to the chart editor
	emit_signal( "file_created", dir + "/" + file.song_title + " - " + file.difficulty + ".tres", file )


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

func _on_close_requested(): self.queue_free()
