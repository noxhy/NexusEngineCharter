extends Button

@export var strum_id: int
@export var enabled: bool

signal strumline_changed( id: int, enabled: bool )

# Called when the node enters the scene tree for the first time.
func _ready():
	
	text = "Strumline: " + str( strum_id + 1 )
	button_pressed = enabled


func _process(_delta):
	
	var display = "Enabled" if enabled else "Disabled"
	text = "Strumline " + str( strum_id + 1 ) + ": " + display


func _on_toggled(toggled_on):
	
	enabled = toggled_on
	emit_signal( "strumline_changed", strum_id, enabled )
