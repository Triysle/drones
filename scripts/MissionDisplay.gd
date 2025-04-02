extends Control

# Mission information display
@onready var mission_number_label = $MissionNumberLabel
@onready var resources_label = $ResourcesCollectedLabel
@onready var missions_completed_label = $MissionsCompletedLabel

# Status message label
@onready var status_label = $StatusLabel  # Make sure to add this node to your scene

func _ready():
	# Initialize display
	set_mission_number(1)
	set_resources_collected(0)
	set_missions_completed(0)

# Update mission number display
func set_mission_number(number):
	mission_number_label.text = "Current Mission: " + str(number)

# Update resources collected display
func set_resources_collected(count):
	resources_label.text = "Resources Collected: " + str(count)

# Update missions completed display
func set_missions_completed(count):
	missions_completed_label.text = "Missions Completed: " + str(count)

# Update status message display
func set_status_message(message):
	if status_label:
		status_label.text = message
	else:
		print("Status label not found in MissionDisplay")
