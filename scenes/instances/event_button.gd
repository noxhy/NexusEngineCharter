extends Button

@export var event_name: String

signal event_selected(event_name: String)


# Called when the node enters the scene tree for the first time.
func _ready(): text = event_name


func _on_pressed(): emit_signal( "event_selected", event_name )
