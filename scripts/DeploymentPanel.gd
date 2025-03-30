extends Control

# Buttons for drone deployment
@onready var aerial_button = $AerialDroneButton
@onready var ground_button = $GroundDroneButton
@onready var status_label = $StatusLabel

# Signals
signal deploy_aerial
signal deploy_ground

func _ready():
	# Connect button signals
	aerial_button.connect("pressed", Callable(self, "_on_aerial_button_pressed"))
	ground_button.connect("pressed", Callable(self, "_on_ground_button_pressed"))
	
	# Set initial status
	status_label.text = "Select Drone to Deploy"

func _on_aerial_button_pressed():
	status_label.text = "Deploying Aerial Drone..."
	emit_signal("deploy_aerial")

func _on_ground_button_pressed():
	status_label.text = "Deploying Ground Drone..."
	emit_signal("deploy_ground")

# Disable ground drone if no waypoints have been marked
func set_ground_drone_availability(available):
	ground_button.disabled = !available
	
	if !available:
		ground_button.tooltip_text = "No waypoints marked by aerial drone"
	else:
		ground_button.tooltip_text = "Deploy ground drone to collect resources"
