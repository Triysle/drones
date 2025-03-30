extends Control

func _ready():
	# Hide initially
	visible = false
	
	# Add help text
	var help_label = Label.new()
	help_label.text = """
	Controls:
	WASD - Move drone
	Space - Ascend (Aerial drone)
	Shift - Descend (Aerial drone)
	F - Scan/Interact
	E - Deploy drone from base
	O - Dock drone at base
	Tab - Toggle upgrade panel
	ESC - Pause game
	H - Show/hide this help
	"""
	add_child(help_label)
	
	# Set label position
	help_label.position = Vector2(20, 20)
	help_label.size = Vector2(400, 300)
