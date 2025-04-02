extends Control

# Compass HUD Element
# This is a placeholder implementation that shows a simple directional compass

@export var compass_width: int = 400
@export var compass_height: int = 40
@export var marker_color: Color = Color(1, 1, 0, 0.8)  # Yellow markers
@export var compass_color: Color = Color(1, 1, 1, 0.6)  # White compass

# Reference to active drone
var active_drone = null

# Cardinal directions
var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

func _ready():
	# Set size
	custom_minimum_size = Vector2(compass_width, compass_height)

func _process(_delta):
	# Request redraw every frame to update compass orientation
	queue_redraw()

func _draw():
	# Draw compass background
	var bg_rect = Rect2(0, 0, compass_width, compass_height)
	draw_rect(bg_rect, Color(0, 0, 0, 0.3), true)
	draw_rect(bg_rect, Color(0.3, 0.3, 0.3, 0.5), false)
	
	# Get rotation from active drone if available
	var rotation_y = 0.0
	if active_drone:
		rotation_y = active_drone.rotation.y
	
	# Draw compass markers
	var center_x = compass_width / 2
	
	# Draw cardinal directions
	for i in range(directions.size()):
		var angle = (i * PI / 4) - rotation_y
		
		# Calculate position on compass
		var x_pos = center_x + cos(angle) * (compass_width / 2.5)
		
		# Check if it's within visible range
		if x_pos >= 0 and x_pos <= compass_width:
			# Draw direction text
			var direction = directions[i]
			draw_string(
				get_theme_default_font(),
				Vector2(x_pos - 5, compass_height / 2 + 5),
				direction,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				16,
				compass_color
			)
			
			# Draw tick mark
			var tick_top = Vector2(x_pos, 5)
			var tick_bottom = Vector2(x_pos, compass_height - 5)
			draw_line(tick_top, tick_bottom, compass_color, 1.0)
	
	# Draw center marker (current heading)
	var center_marker_width = 10
	var center_marker_height = compass_height - 10
	var center_marker = Rect2(
		center_x - center_marker_width/2,
		5,
		center_marker_width,
		center_marker_height
	)
	draw_rect(center_marker, marker_color, false, 2.0)
	
	# Draw heading text
	var heading_degrees = int(rad_to_deg(rotation_y)) % 360
	if heading_degrees < 0:
		heading_degrees += 360
	
	var heading_text = str(heading_degrees) + "°"
	draw_string(
		get_theme_default_font(),
		Vector2(center_x, compass_height - 10),
		heading_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14,
		marker_color
	)

# Set the active drone to get rotation from
func set_active_drone(drone):
	active_drone = drone
