extends CanvasLayer

# GameUI.gd - Central management for all UI elements in the game

# HUD Elements
@onready var mission_info = $MissionInfo
@onready var compass = $Compass
@onready var help_toggle = $HelpToggle
@onready var crosshair = $Crosshair
@onready var resource_indicator = $ResourceInfoLabel
@onready var battery_bar = $BatteryBar
@onready var cargo_slots = $CargoUI
@onready var progress_indicator = $ProgressIndicator

# Menus
@onready var pause_menu = $PauseMenu
@onready var help_panel = $HelpPanel
@onready var upgrade_panel = $UpgradePanel
@onready var deployment_panel = $DeploymentPanel

# State tracking
var active_drone_type = "none" # "none", "aerial", "ground"
var is_help_visible = false
var is_paused = false

func _ready():
	# Initialize UI state
	set_active_drone("none")
	hide_all_menus()
	
	# Connect signals
	if help_toggle:
		help_toggle.connect("pressed", Callable(self, "toggle_help"))
	if pause_menu:
		pause_menu.connect("resume_game", Callable(self, "_on_resume_game"))
	
	print("GameUI initialized")

# Set which drone is currently active and update UI accordingly
func set_active_drone(drone_type):
	active_drone_type = drone_type
	
	# Show/hide appropriate elements based on drone type
	match drone_type:
		"aerial":
			# Aerial drone HUD elements
			if battery_bar: battery_bar.visible = true
			if cargo_slots: cargo_slots.visible = false
			if crosshair: crosshair.visible = true
			if compass: compass.visible = true
		"ground":
			# Ground drone HUD elements
			if battery_bar: battery_bar.visible = false
			if cargo_slots: cargo_slots.visible = true
			if crosshair: crosshair.visible = true
			if compass: compass.visible = true
		"none":
			# Base station / no drone active
			if battery_bar: battery_bar.visible = false
			if cargo_slots: cargo_slots.visible = false
			if crosshair: crosshair.visible = false
			if compass: compass.visible = false
			
	# Always keep these visible when any drone is active
	var drone_active = drone_type != "none"
	if mission_info: mission_info.visible = true # Always visible
	if help_toggle: help_toggle.visible = true # Always visible
	if resource_indicator: resource_indicator.visible = drone_active
	if progress_indicator: progress_indicator.visible = false # Only visible when targeting resources
	
	print("UI updated for active drone: " + drone_type)

# Update the battery display for aerial drone
func update_battery(current, maximum):
	if battery_bar and active_drone_type == "aerial":
		battery_bar.value = current
		battery_bar.max_value = maximum

# Update cargo slots for ground drone
func update_cargo_slots(items):
	if cargo_slots and active_drone_type == "ground" and cargo_slots.has_method("update_slots"):
		cargo_slots.update_slots(items)

# Show resource being targeted
func show_resource_info(resource_name, should_show = true):
	if resource_indicator:
		resource_indicator.visible = should_show
		if should_show:
			resource_indicator.text = resource_name

# Show/hide the collection progress indicator
func show_progress_indicator(should_show, progress_value = 0.0, segments = 1):
	if progress_indicator:
		progress_indicator.visible = should_show
		if should_show:
			progress_indicator.set_progress_value(progress_value * 100.0)
			progress_indicator.set_segment_count(segments)

# Toggle help panel visibility
func toggle_help():
	is_help_visible = !is_help_visible
	if help_panel:
		help_panel.visible = is_help_visible

# Show/hide upgrade panel
func toggle_upgrade_panel(should_show):
	if upgrade_panel:
		upgrade_panel.visible = should_show

# Show/hide deployment panel for drone selection
func show_deployment_panel(should_show):
	if deployment_panel:
		deployment_panel.visible = should_show

# Update deployment panel - enable/disable ground drone button
func set_ground_drone_availability(available):
	if deployment_panel and deployment_panel.has_method("set_ground_drone_availability"):
		deployment_panel.set_ground_drone_availability(available)

# Show pause menu
func show_pause_menu():
	is_paused = true
	if pause_menu:
		pause_menu.visible = true
		if pause_menu.has_method("show_menu"):
			pause_menu.show_menu()

# Hide pause menu (called by signal)
func _on_resume_game():
	is_paused = false
	if pause_menu:
		if pause_menu.has_method("hide_menu"):
			pause_menu.hide_menu()
		pause_menu.visible = false

# Update mission info display
func update_mission_info(mission_num, resources_collected, missions_completed):
	if mission_info and mission_info.has_method("set_mission_number"):
		mission_info.set_mission_number(mission_num)
		mission_info.set_resources_collected(resources_collected)
		mission_info.set_missions_completed(missions_completed)

# Set status message
func set_status_message(message):
	if mission_info and mission_info.has_method("set_status_message"):
		mission_info.set_status_message(message)

# Update resource display
func update_resources(resource_counts):
	# Pass resource counts to upgrade panel to update button states
	if upgrade_panel and upgrade_panel.has_method("update_resources"):
		upgrade_panel.update_resources(resource_counts)

# Hide all menu panels
func hide_all_menus():
	if help_panel: help_panel.visible = false
	if pause_menu: pause_menu.visible = false
	if upgrade_panel: upgrade_panel.visible = false
