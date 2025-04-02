extends Label

# This is a simple script for the mission status label
# It just provides a convenient way to set the status text

func _ready():
	# Initialize with default text
	text = "Base Operations: Select Drone to Deploy"
	# Center the text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
