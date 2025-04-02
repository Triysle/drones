extends Node3D

# Base Station Properties
@export var aerial_drone_scene = preload("res://scenes/AerialDrone.tscn") 
@export var ground_drone_scene = preload("res://scenes/GroundDrone.tscn")
@export var docking_distance: float = 15.0  # How close drones need to be to dock

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

# Spawn points
@onready var aerial_spawn_point = $"../DroneSpawnPoints/AerialSpawnPoint"
@onready var ground_spawn_point = $"../DroneSpawnPoints/GroundSpawnPoint"

# UI Reference - now we just need a single reference to GameUI
@onready var game_ui = $"../GameUI"

# Game State
enum GameState {BASE_MANAGEMENT, AERIAL_DEPLOYMENT, GROUND_DEPLOYMENT}
var current_state = GameState.BASE_MANAGEMENT

func _ready():
	# Initialize UI
	update_resource_display()
	
	# Start in base management
	enter_base_management()
	
	print("Base station initialized")

func _process(_delta):
	# Check if drones are within docking range
	if current_state != GameState.BASE_MANAGEMENT:
		update_docking_status()

func update_docking_status():
	# Update status message based on drone proximity to base
	if active_drone:
		var distance = active_drone.global_position.distance_to(global_position)
		
		if distance <= docking_distance:
			if current_state == GameState.AERIAL_DEPLOYMENT:
				game_ui.set_status_message("Press O to dock aerial drone")
			elif current_state == GameState.GROUND_DEPLOYMENT:
				game_ui.set_status_message("Press O to dock ground drone")
		else:
			if current_state == GameState.AERIAL_DEPLOYMENT:
				game_ui.set_status_message("Aerial Drone Deployed: Return to base to dock")
			elif current_state == GameState.GROUND_DEPLOYMENT:
				game_ui.set_status_message("Ground Drone Deployed: Return to base to dock")

func _input(event):
	# Tab between management modes in base
	if event.is_action_pressed("toggle_management_mode") and current_state == GameState.BASE_MANAGEMENT:
		game_ui.toggle_upgrade_panel(!game_ui.upgrade_panel.visible)
	
	# Emergency recall drone
	if event.is_action_pressed("recall_drone") and current_state != GameState.BASE_MANAGEMENT:
		recall_active_drone()

func enter_base_management():
	current_state = GameState.BASE_MANAGEMENT
	
	# Update UI for base management
	game_ui.set_active_drone("none")
	game_ui.show_deployment_panel(true)
	game_ui.set_status_message("Base Operations: Select Drone to Deploy")
	
	# Free any existing drones
	if aerial_drone:
		aerial_drone.queue_free()
		aerial_drone = null
	
	if ground_drone:
		ground_drone.queue_free()
		ground_drone = null
	
	# Reset active drone reference
	active_drone = null
	
	print("Entered base management mode")

func deploy_aerial_drone():
	current_state = GameState.AERIAL_DEPLOYMENT
	
	# Hide base UI elements
	game_ui.show_deployment_panel(false)
	game_ui.toggle_upgrade_panel(false)
	
	# Instantiate aerial drone
	aerial_drone = aerial_drone_scene.instantiate()
	get_node("../ActiveDrones").add_child(aerial_drone)
	
	# Position at spawn point
	aerial_drone.global_transform = aerial_spawn_point.global_transform
	
	# Apply upgrades
	apply_aerial_upgrades(aerial_drone)
	
	# Connect signals
	aerial_drone.connect("docking_completed", Callable(self, "_on_aerial_drone_docked"))
	
	# Pass base station reference to drone
	aerial_drone.base_station = self
	
	# Set as active drone
	active_drone = aerial_drone
	
	# Update UI for aerial drone
	game_ui.set_active_drone("aerial")
	game_ui.set_status_message("Aerial Drone Deployed: Scan for Resources")
	
	print("Aerial drone deployed - use WASD, Space/Shift to ascend/descend, F to scan")

func deploy_ground_drone():
	current_state = GameState.GROUND_DEPLOYMENT
	
	# Hide base UI elements
	game_ui.show_deployment_panel(false)
	game_ui.toggle_upgrade_panel(false)
	
	# Instantiate ground drone
	ground_drone = ground_drone_scene.instantiate()
	get_node("../ActiveDrones").add_child(ground_drone)
	
	# Position at spawn point
	ground_drone.global_transform = ground_spawn_point.global_transform
	
	# Apply upgrades
	apply_ground_upgrades(ground_drone)
	
	# Connect signals
	ground_drone.connect("resources_delivered", Callable(self, "_on_resources_delivered"))
	
	# Pass base station reference to drone
	ground_drone.base_station = self
	
	# Transfer waypoints from aerial drone if available
	if aerial_drone:
		ground_drone.set_waypoints(aerial_drone.marked_locations)
	
	# Set as active drone
	active_drone = ground_drone
	
	# Update UI for ground drone
	game_ui.set_active_drone("ground")
	game_ui.set_status_message("Ground Drone Deployed: Collect Resources")
	
	print("Ground drone deployed - use WASD, F to interact with resources")

func is_drone_in_docking_range(drone):
	if drone:
		return drone.global_position.distance_to(global_position) <= docking_distance
	return false

func recall_active_drone():
	# Emergency recall function
	if active_drone:
		# In a full implementation, this would handle returning to base
		# For now, we'll just return to base management
		enter_base_management()
		print("Emergency recall activated - returning to base")

func apply_aerial_upgrades(drone):
	# Apply upgrade levels to drone properties
	drone.max_battery = 100.0 * aerial_drone_upgrades["battery_capacity"]
	drone.current_battery = drone.max_battery
	
	drone.scan_range = 20.0 * aerial_drone_upgrades["scan_range"]
	drone.max_speed = 10.0 * aerial_drone_upgrades["speed"]

func apply_ground_upgrades(drone):
	# Apply upgrade levels to drone properties
	# Update the cargo capacity - now using slots
	drone.expand_cargo_capacity(5 * ground_drone_upgrades["cargo_capacity"])
	
	drone.max_speed = 7.0 * ground_drone_upgrades["speed"]
	
	# Terrain handling would affect physics properties
	var _terrain_level = ground_drone_upgrades["terrain_handling"]
	# For example: drone.terrain_check_height = base_height * _terrain_level

func update_resource_display():
	# Update UI with current resource counts
	game_ui.update_resources(stored_resources)

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

# Helper functions
func get_active_drone():
	# Return the currently active drone
	return active_drone

# Signal handlers
func _on_deploy_aerial():
	deploy_aerial_drone()

func _on_deploy_ground():
	deploy_ground_drone()

func _on_aerial_drone_docked():
	# Return to base management when aerial drone docks
	print("Aerial drone docked successfully")
	enter_base_management()

func _on_resources_delivered(resources):
	# Process delivered resources
	print("Resources delivered to base:")
	for resource_type in resources:
		if resource_type in stored_resources:
			stored_resources[resource_type] += resources[resource_type]
			print("- " + resource_type + ": " + str(resources[resource_type]))
	
	# Update UI
	update_resource_display()
	
	# Return to base management
	enter_base_management()

func _on_upgrade_selected(drone_type, upgrade_type):
	process_upgrade(drone_type, upgrade_type)
