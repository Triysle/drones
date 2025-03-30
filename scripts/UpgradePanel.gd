extends Control

# Button references
@onready var aerial_battery_button = $AerialUpgrades/BatteryButton
@onready var aerial_scan_button = $AerialUpgrades/ScanButton
@onready var aerial_speed_button = $AerialUpgrades/SpeedButton

@onready var ground_cargo_button = $GroundUpgrades/CargoButton
@onready var ground_speed_button = $GroundUpgrades/SpeedButton
@onready var ground_terrain_button = $GroundUpgrades/TerrainButton

# Label references
@onready var resource_labels = $"../ResourceDisplay/ResourceCounts"

# Signals
signal upgrade_selected(drone_type, upgrade_type)

func _ready():
	# Connect button signals
	aerial_battery_button.connect("pressed", Callable(self, "_on_aerial_battery_pressed"))
	aerial_scan_button.connect("pressed", Callable(self, "_on_aerial_scan_pressed"))
	aerial_speed_button.connect("pressed", Callable(self, "_on_aerial_speed_pressed"))
	
	ground_cargo_button.connect("pressed", Callable(self, "_on_ground_cargo_pressed"))
	ground_speed_button.connect("pressed", Callable(self, "_on_ground_speed_pressed"))
	ground_terrain_button.connect("pressed", Callable(self, "_on_ground_terrain_pressed"))

# Update upgrade button states based on available resources
func update_button_states(resources, aerial_levels, ground_levels):
	# For each upgrade button, check if player can afford it
	update_button(aerial_battery_button, "aerial", "battery_capacity", aerial_levels["battery_capacity"], resources)
	update_button(aerial_scan_button, "aerial", "scan_range", aerial_levels["scan_range"], resources)
	update_button(aerial_speed_button, "aerial", "speed", aerial_levels["speed"], resources)
	
	update_button(ground_cargo_button, "ground", "cargo_capacity", ground_levels["cargo_capacity"], resources)
	update_button(ground_speed_button, "ground", "speed", ground_levels["speed"], resources)
	update_button(ground_terrain_button, "ground", "terrain_handling", ground_levels["terrain_handling"], resources)

# Update a single button's state and tooltip
func update_button(button, _drone_type, upgrade_type, current_level, resources):
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
