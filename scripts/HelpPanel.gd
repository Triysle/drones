extends Control

func _ready():
	# Hide initially
	visible = false
	
	# Add help text
	var help_label = Label.new()
	help_label.text = """
	DRONE CONTROL GUIDE
	
	Movement Controls:
	- WASD: Move drone (forward/backward/strafe left/right)
	- Mouse: Look/steer
	
	Aerial Drone Specific:
	- Space: Ascend
	- Shift: Descend
	- F: Scan for resources
	
	Ground Drone Specific:
	- F: Interact with resources
	
	General Controls:
	- O: Dock drone at base
	- R: Emergency recall drone
	- Tab: Toggle upgrade panel (in base)
	- ESC: Pause game
	- H: Show/hide this help
	
	When a drone is active, the mouse is captured for camera control.
	Press ESC to pause and free the cursor.
	"""
	add_child(help_label)
	
	# Set label position
	help_label.position = Vector2(20, 20)
	help_label.size = Vector2(400, 400)
