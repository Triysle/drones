extends Node

# Game Manager - Coordinates overall gameplay systems

# Scene references
@export var test_environment_scene = load("res://scenes/TestEnvironment.tscn")
@export var base_station_scene = load("res://scenes/BaseStation.tscn") 
@export var resource_scene = load("res://scenes/Resource.tscn")

# Current environment
var current_environment = null
var base_station = null

# Game state tracking
var current_mission_number = 1
var total_resources_collected = 0
var missions_completed = 0

# UI References
@onready var mission_display = $CanvasLayer/MissionDisplay
@onready var help_panel = $CanvasLayer/HelpPanel
@onready var pause_menu = $CanvasLayer/PauseMenu

# Mouse capture state
var mouse_was_captured = false

func _ready():
	# Setup initial game state
	initialize_game()
	
	# Connect UI signals
	pause_menu.connect("resume_game", Callable(self, "_on_resume_game"))
	pause_menu.connect("quit_game", Callable(self, "_on_quit_game"))
	
	# Hide pause menu initially
	pause_menu.visible = false

func _input(event):
	# Toggle pause menu
	if event.is_action_pressed("pause_game"):
		toggle_pause_menu()
	
	# Toggle help panel
	if event.is_action_pressed("show_help"):
		toggle_help_panel()

func initialize_game():
	# Load test environment
	load_environment()
	
	# Create base station
	spawn_base_station()
	
	# Generate initial resources
	spawn_resources()
	
	# Show initial mission info
	update_mission_display()
	
	print("Game initialized")

func load_environment():
	# Instantiate environment scene
	current_environment = test_environment_scene.instantiate()
	add_child(current_environment)
	
	print("Environment loaded")

func spawn_base_station():
	# Instantiate base station at specified position
	base_station = base_station_scene.instantiate()
	add_child(base_station)
	
	# Position base station
	# In a full implementation, this would use a marker from the environment
	base_station.global_position = Vector3(0, 0, 0)
	
	print("Base station spawned")

func spawn_resources():
	# Get resource spawn points from environment
	var spawn_points = get_resource_spawn_points()
	
	# Spawn different resource types
	var resource_types = ["ScrapMetal", "PowerCell", "ElectronicParts", "RareMetal"]
	var rarity_weights = [0.6, 0.25, 0.1, 0.05]  # Higher number = more common
	
	print("Spawning resources:")
	
	for point in spawn_points:
		# Select resource type based on rarity
		var resource_type = weighted_random_choice(resource_types, rarity_weights)
		
		# Instantiate resource
		var resource = resource_scene.instantiate()
		current_environment.add_child(resource)
		
		# Set resource properties
		resource.global_position = point
		resource.resource_type = resource_type
		
		# Set amount based on type
		match resource_type:
			"ScrapMetal":
				resource.resource_amount = randi_range(2, 5)
			"PowerCell":
				resource.resource_amount = randi_range(1, 3)
			"ElectronicParts":
				resource.resource_amount = randi_range(1, 2)
			"RareMetal":
				resource.resource_amount = 1
		
		print("- Spawned " + resource_type + " at " + str(point))

func get_resource_spawn_points():
	# In full implementation, this would get points from the environment
	# For prototype, generate random positions
	var points = []
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Generate 15-20 resource points
	var num_points = rng.randi_range(15, 20)
	
	# Exclusion zone around base (no resources too close to base)
	var min_distance_from_base = 15.0
	var max_distance_from_base = 150.0
	
	for i in range(num_points):
		var valid_point = false
		var point = Vector3.ZERO
		
		while !valid_point:
			# Generate random point
			var distance = rng.randf_range(min_distance_from_base, max_distance_from_base)
			var angle = rng.randf() * 2.0 * PI
			
			# Calculate position
			point = Vector3(
				cos(angle) * distance,
				0,  # At ground level
				sin(angle) * distance
			)
			
			# Check distance from other points (no resources too close together)
			valid_point = true
			for existing_point in points:
				if point.distance_to(existing_point) < 10.0:
					valid_point = false
					break
		
		# Add valid point
		points.append(point)
	
	return points

func weighted_random_choice(options, weights):
	# Choose a random option based on weights
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	var rnd = randf() * total_weight
	var current = 0.0
	
	for i in range(options.size()):
		current += weights[i]
		if rnd <= current:
			return options[i]
	
	# Fallback to first option
	return options[0]

func update_mission_display():
	# Update mission info in UI
	mission_display.set_mission_number(current_mission_number)
	mission_display.set_resources_collected(total_resources_collected)
	mission_display.set_missions_completed(missions_completed)

func toggle_pause_menu():
	# Show/hide pause menu
	pause_menu.visible = !pause_menu.visible
	
	# Pause game when menu is visible
	get_tree().paused = pause_menu.visible
	
	# Handle mouse capture
	if pause_menu.visible:
		# Store current mouse mode before freeing it
		mouse_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		# Free the mouse when paused
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Restore mouse capture state when unpausing
		if mouse_was_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func toggle_help_panel():
	# Show/hide help panel
	help_panel.visible = !help_panel.visible
	
	# Optionally free the mouse when help is visible
	if help_panel.visible:
		mouse_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if mouse_was_captured and !pause_menu.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Signal handlers
func _on_resume_game():
	pause_menu.visible = false
	get_tree().paused = false
	
	# Restore mouse capture state
	if mouse_was_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_quit_game():
	# Return to title screen or quit game
	get_tree().quit()
