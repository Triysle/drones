extends Node

# This helper script connects the instantiated ground drone to UI elements

var ground_drone = null
var cargo_ui = null
var progress_indicator = null
var resource_info_label = null

func _ready():
	# Find UI elements
	cargo_ui = get_node("/root/Main/GameUI/CargoUI")
	progress_indicator = get_node("/root/Main/GameUI/ProgressIndicator")
	resource_info_label = get_node("/root/Main/GameUI/ResourceInfoLabel")
	
	# Ensure they're initially hidden
	if cargo_ui:
		cargo_ui.visible = false
	if progress_indicator:
		progress_indicator.visible = false
	if resource_info_label:
		resource_info_label.visible = false

func connect_drone(drone):
	# Store reference
	ground_drone = drone
	
	# Show cargo UI
	if cargo_ui:
		cargo_ui.visible = true
	
	# Ensure drone has references to UI elements
	if ground_drone:
		# The drone will look for these nodes in the main scene hierarchy
		print("Ground drone UI connected")
	
func disconnect_drone():
	# Hide UI elements
	if cargo_ui:
		cargo_ui.visible = false
	if progress_indicator:
		progress_indicator.visible = false
	if resource_info_label:
		resource_info_label.visible = false
	
	ground_drone = null
	print("Ground drone UI disconnected")
