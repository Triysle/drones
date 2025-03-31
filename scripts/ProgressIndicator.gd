extends Control

# Progress Indicator for Resource Collection
# This creates a circular progress indicator with segments

@export var radius: float = 40.0
@export var thickness: float = 8.0
@export var bg_color: Color = Color(0.2, 0.2, 0.2, 0.5)
@export var fill_color: Color = Color(0.0, 1.0, 0.0, 1.0)  # Green by default
@export var max_value: float = 100.0
@export var value: float = 0.0

var num_segments: int = 1
var segment_angles = []  # Array to store segment boundaries

func _ready():
	# Set default size to ensure visibility
	custom_minimum_size = Vector2(100, 100)
	
	# Setup initial segments
	set_segments(1)

func _draw():
	var center = Vector2(size.x / 2, size.y / 2)
	
	# Draw background circle
	draw_arc(center, radius, 0, TAU, 32, bg_color, thickness)
	
	# Start angle is -PI/2 (12 o'clock)
	var start_angle = -PI/2
	
	# We draw a full circle and subtract the progress
	# This makes it look like the circle is depleting as progress increases
	if value < max_value:
		var progress_ratio = value / max_value  # How much is completed (0.0 to 1.0)
		var remaining_ratio = 1.0 - progress_ratio  # How much is remaining (1.0 to 0.0)
		var end_angle = start_angle + (TAU * remaining_ratio)
		
		# Draw the filled arc (what's remaining)
		draw_arc(center, radius, start_angle, end_angle, 32, fill_color, thickness)
	else:
		# Draw nothing if fully depleted
		pass
	
	# Draw segment dividers
	if num_segments > 1:
		# Always draw a marker at 12 o'clock
		var top_marker_start = center + Vector2(0, -radius - thickness/2)
		var top_marker_end = center + Vector2(0, -radius + thickness/2)
		draw_line(top_marker_start, top_marker_end, Color(0.0, 0.0, 0.0, 0.8), 2.0)
		
		# Draw other segment markers
		for i in range(1, num_segments):
			var angle = start_angle + (float(i) / num_segments) * TAU
			var start_point = center + Vector2(cos(angle), sin(angle)) * (radius - thickness/2)
			var end_point = center + Vector2(cos(angle), sin(angle)) * (radius + thickness/2)
			draw_line(start_point, end_point, Color(0.0, 0.0, 0.0, 0.8), 2.0)

func set_segments(num):
	num_segments = max(1, num)
	segment_angles = []
	
	# Calculate segment angles
	for i in range(1, num_segments):
		var angle = (-PI/2) + (float(i) / num_segments) * TAU
		segment_angles.append(angle)
	
	# Force redraw
	queue_redraw()

func set_progress_value(val):
	value = clamp(val, 0, max_value)
	queue_redraw()

func set_segment_count(num):
	set_segments(num)

func set_fill_color(color):
	fill_color = color
	queue_redraw()
