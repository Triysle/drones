extends Control

# Progress Indicator for Resource Collection
# This creates a circular progress indicator with segments

@export var radius: float = 40.0
@export var thickness: float = 8.0
@export var bg_color: Color = Color(0.2, 0.2, 0.2, 0.5)
@export var tint_progress: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var max_value: float = 100.0
@export var value: float = 0.0

var num_segments: int = 1
var segment_angles = []  # Array to store segment boundaries

func _ready():
	# Hide initially
	visible = false
	
	# Set up segments
	set_segments(1)

func _draw():
	var center = Vector2(0, 0)
	
	# Draw background circle
	draw_arc(center, radius, 0, TAU, 32, bg_color, thickness)
	
	# Calculate progress angle
	var progress_angle = (value / max_value) * TAU
	
	# Draw progress arc
	if progress_angle > 0:
		draw_arc(center, radius, 0, progress_angle, 32, tint_progress, thickness)
	
	# Draw segment dividers if we have more than one segment
	if num_segments > 1:
		for angle in segment_angles:
			var start_point = center + Vector2(cos(angle), sin(angle)) * (radius - thickness/2)
			var end_point = center + Vector2(cos(angle), sin(angle)) * (radius + thickness/2)
			draw_line(start_point, end_point, Color(0.0, 0.0, 0.0, 0.8), 2.0)

func set_segments(num):
	num_segments = max(1, num)
	segment_angles = []
	
	# Calculate segment angles
	for i in range(1, num_segments):
		var angle = (float(i) / num_segments) * TAU
		segment_angles.append(angle)
	
	# Force redraw
	queue_redraw()

func set_value(val):
	value = clamp(val, 0, max_value)
	queue_redraw()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		# Center the indicator in its parent control
		position = Vector2(size.x / 2, size.y / 2)

# This is what we want to call from the ground drone
func set_progress_value(val):
	value = clamp(val, 0, max_value)
	queue_redraw()

# This is what we want to call to set segments
func set_segment_count(num):
	num_segments = max(1, num)
	segment_angles = []
	
	# Calculate segment angles
	for i in range(1, num_segments):
		var angle = (float(i) / num_segments) * TAU
		segment_angles.append(angle)
	
	# Force redraw
	queue_redraw()
