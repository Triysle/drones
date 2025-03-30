extends Node3D

# Base Station Properties
@export var aerial_drone_scen = load("res://scenes/AerialDrone.tscn")
@export var ground_drone_scene = load("res://scenes/GroundDrone.tscn")

# Drone References
var aerial_drone = null
var ground_drone = null
var active_drone = null

# Resource Management
var stored_resources = {
	"ScrapMetal": 0,
	"PowerCell": 0,
	"ElectronicParts": 0,
	"RareMetal": 0
}

# Upgrade tracking
var aerial_drone_upgrades = {
	"battery_capacity": 1,
	"scan_range": 1,
	"speed": 1
}

var ground_drone_upgrades = {
	"cargo_capacity": 1,
	"speed": 1,
	"terrain_handling": 1
}

# Spawn points for drones
@export var aerial_spawn_point: Node3D
@export var ground_spawn_point: Node3D

# UI References
@onready var resource_display = $UI/ResourceDisplay
@onready var upgrade_panel = $UI/UpgradePanel
@onready var deployment_panel = $UI/DeploymentPanel
@onready var mission_status = $UI/MissionStatus

# Game State
enum GameState {BASE_MANAGEMENT, AERIAL_DEPLOYMENT, GROUND_DEPLOYMENT}
var current_state = GameState.BASE_MANAGEMENT

func _ready():
	# Initialize UI
	update_resource_display()
	
	# Hide upgrade panel initially
	upgrade_panel.visible = false
	
	# Connect UI signals
	deployment_panel.connect("deploy_aerial", Callable(self, "_on_deploy_aerial"))
	deployment_panel.connect("deploy_ground", Callable(self, "_on_deploy_ground"))
	upgrade_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))
	
	# Start in base management
	enter_base_management()

func _input(event):
	# Tab between management modes in base
	if event.is_action_pressed("toggle_management_mode") and current_state == GameState.BASE_MANAGEMENT:
		upgrade_panel.visible = !upgrade_panel.visible
	
	# Emergency recall drone
	if event.is_action_pressed("recall_drone") and current_state != GameState.BASE_MANAGEMENT:
		recall_active_drone()

func enter_base_management():
	current_state = GameState.BASE_MANAGEMENT
	
	# Enable base UI
	deployment_panel.visible = true
	
	# Update status
	mission_status.text = "Base Operations: Select Drone to Deploy"
	
	# Free any existing drones
	if aerial_drone:
		aerial_drone.queue_free()
		aerial_drone = null
	
	if ground_drone:
		ground_drone.queue_free()
		ground_drone = null
	
	# Reset active drone reference
	active_drone = null

func deploy_aerial_drone():
	current_state = GameState.AERIAL_DEPLOYMENT
	
	# Hide base UI
	deployment_panel.visible = false
	upgrade_panel.visible = false
	
	# Instantiate aerial drone
	aerial_drone = aerial_drone_scene.instantiate()
	add_child(aerial_drone)
	
	# Position at spawn point
	aerial_drone.global_transform = aerial_spawn_point.global_transform
	
	# Apply upgrades
	apply_aerial_upgrades(aerial_drone)
	
	# Connect signals
	aerial_drone.connect("docking_completed", Callable(self, "_on_aerial_drone_docked"))
	
	# Set as active drone
	active_drone = aerial_drone
	
	# Update status
	mission_status.text = "Aerial Drone Deployed: Scan for Resources"

func deploy_ground_drone():
	current_state = GameState.GROUND_DEPLOYMENT
	
	# Hide base UI
	deployment_panel.visible = false
	upgrade_panel.visible = false
	
	# Instantiate ground drone
	ground_drone = ground_drone_scene.instantiate()
	add_child(ground_drone)
	
	# Position at spawn point
	ground_drone.global_transform = ground_spawn_point.global_transform
	
	# Apply upgrades
	apply_ground_upgrades(ground_drone)
	
	# Connect signals
	ground_drone.connect("resources_delivered", Callable(self, "_on_resources_delivered"))
	
	# Transfer waypoints from aerial drone if available
	if aerial_drone:
		ground_drone.set_waypoints(aerial_drone.marked_locations)
	
	# Set as active drone
	active_drone = ground_drone
	
	# Update status
	mission_status.text = "Ground Drone Deployed: Collect Resources"

func recall_active_drone():
	# Emergency recall function
	if active_drone:
		# In a full implementation, this would handle returning to base
		# For now, we'll just return to base management
		enter_base_management()
		print("Emergency recall activated")

func apply_aerial_upgrades(drone):
	# Apply upgrade levels to drone properties
	drone.max_battery = 100.0 * aerial_drone_upgrades["battery_capacity"]
	drone.current_battery = drone.max_battery
	
	drone.scan_range = 20.0 * aerial_drone_upgrades["scan_range"]
	drone.max_speed = 10.0 * aerial_drone_upgrades["speed"]
	
	print("Applied aerial drone upgrades")

func apply_ground_upgrades(drone):
	# Apply upgrade levels to drone properties
	drone.max_cargo_capacity = 5 * ground_drone_upgrades["cargo_capacity"]
	drone.max_speed = 7.0 * ground_drone_upgrades["speed"]
	
	# Terrain handling would affect physics properties
	var terrain_level = ground_drone_upgrades["terrain_handling"]
	# For example: drone.terrain_check_height = base_height * terrain_level
	
	print("Applied ground drone upgrades")

func update_resource_display():
	# Update UI with current resource counts
	for resource_type in stored_resources:
		resource_display.update_resource(resource_type, stored_resources[resource_type])

func process_upgrade(drone_type, upgrade_type):
	# Check if we have resources for the upgrade
	var cost = calculate_upgrade_cost(drone_type, upgrade_type)
	
	if can_afford_upgrade(cost):
		# Apply the upgrade
		if drone_type == "aerial":
			aerial_drone_upgrades[upgrade_type] += 1
			print("Upgraded aerial drone's " + upgrade_type)
		else:
			ground_drone_upgrades[upgrade_type] += 1
			print("Upgraded ground drone's " + upgrade_type)
		
		# Deduct resources
		deduct_resources(cost)
		
		# Update UI
		update_resource_display()
		return true
	else:
		print("Cannot afford upgrade")
		return false

func calculate_upgrade_cost(drone_type, upgrade_type):
	# Calculate cost based on current level
	var level = 1
	var cost = {}
	
	if drone_type == "aerial":
		level = aerial_drone_upgrades[upgrade_type]
	else:
		level = ground_drone_upgrades[upgrade_type]
	
	# Base cost increases with level
	cost["ScrapMetal"] = level * 5
	
	# Different upgrades need different resources
	match upgrade_type:
		"battery_capacity", "cargo_capacity":
			cost["PowerCell"] = level * 2
		"scan_range":
			cost["ElectronicParts"] = level * 3
		"speed":
			cost["RareMetal"] = level
		"terrain_handling":
			cost["PowerCell"] = level
			cost["RareMetal"] = floor(level / 2.0)
	
	return cost

func can_afford_upgrade(cost):
	# Check if we have enough resources
	for resource_type in cost:
		if stored_resources.get(resource_type, 0) < cost[resource_type]:
			return false
	return true

func deduct_resources(cost):
	# Remove resources used for upgrade
	for resource_type in cost:
		stored_resources[resource_type] -= cost[resource_type]

# Signal handlers
func _on_deploy_aerial():
	deploy_aerial_drone()

func _on_deploy_ground():
	deploy_ground_drone()

func _on_aerial_drone_docked():
	# Return to base management when aerial drone docks
	enter_base_management()

func _on_resources_delivered(resources):
	# Process delivered resources
	for resource_type in resources:
		if resource_type in stored_resources:
			stored_resources[resource_type] += resources[resource_type]
	
	# Update UI
	update_resource_display()
	
	# Return to base management
	enter_base_management()

func _on_upgrade_selected(drone_type, upgrade_type):
	process_upgrade(drone_type, upgrade_type)
