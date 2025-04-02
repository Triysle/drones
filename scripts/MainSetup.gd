extends Node3D

# Main scene setup script
# This script handles setting up the integrated Main scene

func _ready():
	# Ensure all cross-node references are properly initialized
	setup_ui_references()
	
	# Set initial UI states
	setup_initial_ui_states()
	
	# Ensure scripts have the correct node paths
	verify_node_paths()
	
	# Set up the resource interaction system
	setup_resource_system()
	
	print("Main scene setup complete")

func setup_ui_references():
	# Get nodes
	var mission_status = $GameUI/MissionStatus
	var mission_display = $GameUI/MissionDisplay
	var deployment_panel = $GameUI/DeploymentPanel
	var upgrade_panel = $GameUI/UpgradePanel
	var resource_display = $GameUI/ResourceDisplay
	var progress_indicator = $GameUI/ProgressIndicator
	var cargo_ui = $GameUI/CargoUI
	var resource_info_label = $GameUI/ResourceInfoLabel
	var help_panel = $GameUI/HelpPanel
	var pause_menu = $GameUI/PauseMenu
	var minimap = $GameUI/MinimapDisplay
	
	# Ensure node references are valid
	if !mission_status or !mission_display or !deployment_panel or !upgrade_panel or \
	   !resource_display or !progress_indicator or !cargo_ui or !resource_info_label or \
	   !help_panel or !pause_menu:
		push_error("Missing UI nodes in Main scene!")
		return
	
	print("UI references verified")

func setup_initial_ui_states():
	# Set initial visibility for UI elements
	$GameUI/DeploymentPanel.visible = true
	$GameUI/UpgradePanel.visible = false
	$GameUI/MissionDisplay.visible = true
	$GameUI/ResourceDisplay.visible = true
	$GameUI/ProgressIndicator.visible = false
	$GameUI/CargoUI.visible = false
	$GameUI/ResourceInfoLabel.visible = false
	$GameUI/HelpPanel.visible = false
	$GameUI/PauseMenu.visible = false
	$GameUI/MinimapDisplay.visible = true
	
	# Set process mode for pause menu
	$GameUI/PauseMenu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	print("Initial UI states configured")

func verify_node_paths():
	# Verify base station node has referenced the drone spawn points
	var base_station = $BaseStation
	if !base_station:
		push_error("BaseStation node not found!")
		return
	
	# Verify game manager references
	var game_manager = $GameManager
	if !game_manager:
		push_error("GameManager node not found!")
		return
	
	# Verify resource spawn points exist
	var resource_spawn_points = $Environment/ResourceSpawnPoints
	if !resource_spawn_points:
		push_error("Resource spawn points not found!")
		return
	
	# Verify resources container exists
	var resources_container = $Resources
	if !resources_container:
		push_error("Resources container not found!")
		return
	
	# Verify waypoint system exists
	var waypoint_system = $Waypoints
	if !waypoint_system:
		push_error("Waypoint system not found!")
		return
	
	print("Node paths verified")

func setup_resource_system():
	# Ensure resources are set up to work with the new structure
	# This function would be called by GameManager, but we're checking it's ready
	
	# Add collision exception for drone and base
	var drone_spawn_points = $DroneSpawnPoints
	if drone_spawn_points:
		drone_spawn_points.global_position = $BaseStation.global_position
	
	# Make sure resource spawners are children of Environment
	var resource_spawners = $Environment/ResourceSpawnPoints
	if resource_spawners and resource_spawners.get_child_count() == 0:
		push_warning("No resource spawn points found! Add some in the editor.")
	
	print("Resource system configured")
