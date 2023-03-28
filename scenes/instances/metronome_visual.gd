extends Node2D


# Declare member variables here. Examples:
@onready var spectrum = AudioServer.get_bus_effect_instance(1, 0)

@export var definition = 20
@export var totalWidth = 400
@export var totalHeight = 200

var minFrequency = 20
var maxFrequency = 20000

@export var minDb = -55
@export var maxDb = -16

@export var barWidth = 4.0

@export var accel = 5
@export var slope = 0.3

@export var color = Color(1,1,1,1)

var histogram = []

# Called when the node enters the scene tree for the first time.
func _ready():
	
	minDb += 0
	maxDb += 0
	
# warning-ignore:unused_variable
	for i in range(definition):
		histogram.append(0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var frequency = minFrequency
	@warning_ignore(integer_division)
	var interval = (maxFrequency - minFrequency) / definition
	
	for i in range(definition):
		
		
		var frequencyRangeLow = float(frequency - minFrequency) / float(maxFrequency - minFrequency)
		frequencyRangeLow = pow(frequencyRangeLow, 4)
		frequencyRangeLow = lerp(minFrequency, maxFrequency, frequencyRangeLow)
		
		frequency += interval
		
		
		var frequencyRangeHigh = float(frequency - minFrequency) / float(maxFrequency - minFrequency)
		frequencyRangeHigh *= pow(frequencyRangeHigh, 4)
		frequencyRangeHigh = lerp(minFrequency, maxFrequency, frequencyRangeHigh)
		
		
		var mag = spectrum.get_magnitude_for_frequency_range(frequencyRangeLow, frequencyRangeHigh)
		mag = linear_to_db(mag.length())
		mag = (mag - minDb) / (maxDb - minDb)
		
		mag += slope * (frequency - minFrequency) / (maxFrequency - minFrequency)
		mag = clamp(mag, 0.01, 1)
		
		histogram[i] = fake_lerp(histogram[i], mag, accel * delta)
	
	queue_redraw()

func _draw():
	var drawPos = Vector2(0, 0)
	@warning_ignore(integer_division)
	var widthInterval = totalWidth / definition
	
	for i in range(definition):
		draw_line(drawPos, drawPos + Vector2(0, -histogram[i] * totalHeight), color, barWidth, false)
		drawPos.x += widthInterval

func fake_lerp(value: float, next_value: float, progress: float) -> float:
	
	var distance = next_value - value
	return value + (distance * progress)
