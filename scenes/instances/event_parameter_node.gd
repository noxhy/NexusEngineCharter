extends HBoxContainer

@export var parameter_id: int
@export var parameter_value: String

signal parameter_changed( id: int, value: String )
signal parameter_removed( id: int )


# Called when the node enters the scene tree for the first time.
func _ready():
	
	$LineEdit.text = parameter_value


func _on_line_edit_text_submitted(new_text):
	
	parameter_value = new_text
	emit_signal( "parameter_changed", parameter_id, new_text )


func _on_button_pressed(): emit_signal( "parameter_removed", parameter_id )
