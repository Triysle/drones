extends Control

# Button references
@onready var aerial_battery_button = $AerialUpgrades/BatteryButton
@onready var aerial_scan_button = $AerialUpgrades/ScanButton
@onready var aerial_speed_button = $AerialUpgrades/SpeedButton

@onready var ground_cargo_button = $GroundUpgrades/CargoButton
@onready var ground_speed_button = $GroundUpgrades/SpeedButton
@onready var ground_terrain_button = $GroundUpgrades/TerrainButton

# Label references - we'll try different paths to find this
var resource_labels

# Signals
signal upgrade_selected(drone_type, upgrade_type)

func _ready():
	# Find resource labels - try different paths
	resource_labels = find_resource_labels()
	
	# Connect button signals - check for null first
	if aerial_battery_button:
		aerial_battery_button.connect("pressed", Callable(self, "_on_aerial_battery_pressed"))
	
	if aerial_scan_button:
		aerial_scan_button.connect("pressed", Callable(self, "_on_aerial_scan_pressed"))
		
	if aerial_speed_button:
		aerial_speed_button.connect("pressed", Callable(self, "_on_aerial_speed_pressed"))
	
	if ground_cargo_button:
		ground_cargo_button.connect("pressed", Callable(self, "_on_ground_cargo_pressed"))
		
	if ground_speed_button:
		ground_speed_button.connect("pressed", Callable(self, "_on_ground_speed_pressed"))
		
	if ground_terrain_button:
		ground_terrain_button.connect("pressed", Callable(self, "_on_ground_terrain_pressed"))

# Helper to find resource labels using different possible paths
func find_resource_labels():
	var labels
	
	# Try different paths
	labels = get_node_or_null("../ResourceDisplay/ResourceCounts")
	if labels:
		return labels
		
	labels = get_node_or_null("/root/Main/GameUI/ResourceDisplay/ResourceCounts")
	if labels:
		return labels
	
	# If we still can't find it, create a fallback
	print("Warning: Resource labels not found, creating a fallback")
	labels = Label.new()
	labels.text = "Resources:"
	add_child(labels)
	return labels

# Update upgrade button states based on available resources
func update_button_states(resources, aerial_levels, ground_levels):
	# For each upgrade button, check if player can afford it
	# Use null checks before accessing each button
	if aerial_battery_button:
		update_button(aerial_battery_button, "aerial", "battery_capacity", aerial_levels["battery_capacity"], resources)
	
	if aerial_scan_button:
		update_button(aerial_scan_button, "aerial", "scan_range", aerial_levels["scan_range"], resources)
	
	if aerial_speed_button:
		update_button(aerial_speed_button, "aerial", "speed", aerial_levels["speed"], resources)
	
	if ground_cargo_button:
		update_button(ground_cargo_button, "ground", "cargo_capacity", ground_levels["cargo_capacity"], resources)
	
	if ground_speed_button:
		update_button(ground_speed_button, "ground", "speed", ground_levels["speed"], resources)
	
	if ground_terrain_button:
		update_button(ground_terrain_button, "ground", "terrain_handling", ground_levels["terrain_handling"], resources)

# Update a single button's state and tooltip
func update_button(button, _drone_type, upgrade_type, current_level, resources):
	# Safety check
	if button == null:
		print("Warning: Button for upgrade " + upgrade_type + " is null")
		return
		
	# Calculate cost for next level
	var cost = calculate_upgrade_cost(_drone_type, upgrade_type, current_level)
	
	# Check if affordable
	var can_afford = can_afford_upgrade(cost, resources)
	button.disabled = !can_afford
	
	# Update tooltip with cost and effect
	button.tooltip_text = get_upgrade_tooltip(_drone_type, upgrade_type, current_level, cost)
	
	# Update button text to show current level
	button.text = get_upgrade_name(upgrade_type) + " (Lv. " + str(current_level) + ")"

# Calculate upgrade cost (should match BaseStation.gd)
func calculate_upgrade_cost(_drone_type, upgrade_type, level):
	# Calculate cost based on current level
	var cost = {}
	
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

# Check if player can afford upgrade
func can_afford_upgrade(cost, resources):
	# Check if we have enough resources
	for resource_type in cost:
		if resources.get(resource_type, 0) < cost[resource_type]:
			return false
	return true

# Get friendly name for upgrade type
func get_upgrade_name(upgrade_type):
	match upgrade_type:
		"battery_capacity":
			return "Battery Capacity"
		"scan_range":
			return "Scan Range"
		"speed":
			return "Movement Speed"
		"cargo_capacity":
			return "Cargo Capacity"
		"terrain_handling":
			return "Terrain Handling"
		_:
			return upgrade_type.capitalize()

# Generate tooltip showing upgrade effects and costs
func get_upgrade_tooltip(_drone_type, upgrade_type, _current_level, cost):
	var tooltip = ""
	
	# Describe upgrade effect
	match upgrade_type:
		"battery_capacity":
			tooltip = "Increases max battery by 100 points"
		"scan_range":
			tooltip = "Increases scan radius by 20 units"
		"speed":
			tooltip = "Increases maximum speed"
		"cargo_capacity":
			tooltip = "Add 5 more cargo slots"
		"terrain_handling":
			tooltip = "Improves ability to navigate difficult terrain"
	
	# Add cost information
	tooltip += "\n\nCost:"
	for resource in cost:
		tooltip += "\n- " + resource + ": " + str(cost[resource])
	
	return tooltip

# Update resource display
func update_resources(resources):
	# Update resource count display
	var text = "Resources:"
	for resource_type in resources:
		text += "\n" + resource_type + ": " + str(resources[resource_type])
	
	if resource_labels:
		resource_labels.text = text

# Signal handlers for buttons
func _on_aerial_battery_pressed():
	emit_signal("upgrade_selected", "aerial", "battery_capacity")

func _on_aerial_scan_pressed():
	emit_signal("upgrade_selected", "aerial", "scan_range")

func _on_aerial_speed_pressed():
	emit_signal("upgrade_selected", "aerial", "speed")

func _on_ground_cargo_pressed():
	emit_signal("upgrade_selected", "ground", "cargo_capacity")

func _on_ground_speed_pressed():
	emit_signal("upgrade_selected", "ground", "speed")

func _on_ground_terrain_pressed():
	emit_signal("upgrade_selected", "ground", "terrain_handling")
