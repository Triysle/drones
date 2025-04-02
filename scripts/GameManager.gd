extends Node

# Game Manager - Coordinates overall gameplay systems

# Scene references
@export var resource_scene = preload("res://scenes/Resource.tscn") 

# Node path references
@onready var environment = $"../Environment"
@onready var base_station = $"../BaseStation"
@onready var resources_container = $"../Resources"
@onready var resource_spawn_points = $"../Environment/ResourceSpawnPoints"
@onready var game_ui = $"../GameUI"

# Game state tracking
var current_mission_number = 1
var total_resources_collected = 0
var missions_completed = 0

# Game state
var is_game_paused = false
var mouse_was_captured = false

func _ready():
	# Setup initial game state
	initialize_game()
	
	# Connect signals to GameUI
	var deployment_panel = game_ui.get_node("DeploymentPanel")
	if deployment_panel:
		deployment_panel.connect("deploy_aerial", Callable(base_station, "_on_deploy_aerial"))
		deployment_panel.connect("deploy_ground", Callable(base_station, "_on_deploy_ground"))
	
	var upgrade_panel = game_ui.get_node("UpgradePanel")
	if upgrade_panel:
		upgrade_panel.connect("upgrade_selected", Callable(base_station, "_on_upgrade_selected"))
	
	print("Game initialized")

func _input(event):
	# Toggle pause menu
	if event.is_action_pressed("pause_game"):
		toggle_pause()
	
	# Toggle help panel
	if event.is_action_pressed("show_help"):
		game_ui.toggle_help()

func initialize_game():
	# Generate initial resources
	spawn_resources()
	
	# Show initial mission info
	update_mission_display()
	
	print("Game initialized")

# Pause/unpause the game
func toggle_pause():
	# Check if the game is already paused by the pause menu
	if is_game_paused && game_ui.is_paused:
		# Call resume directly instead of toggling
		is_game_paused = false
		game_ui._on_resume_game()
		get_tree().paused = false
		
		# Restore mouse capture if it was captured before
		if mouse_was_captured:
			create_tween().tween_callback(func(): 
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				print("Mouse recaptured after unpausing")
			).set_delay(0.05)
		return
	
	# Original toggle code for all other cases
	is_game_paused = !is_game_paused
	
	if is_game_paused:
		# Pause the game
		get_tree().paused = true
		
		# Store mouse capture state and free the mouse
		mouse_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Show the pause menu
		game_ui.show_pause_menu()
		
		print("Game paused. Mouse was captured: " + str(mouse_was_captured))
	else:
		# Hide the pause menu and unpause
		if game_ui.is_paused:
			game_ui._on_resume_game()
		
		# Unpause the game
		get_tree().paused = false
		
		# Restore mouse capture if it was captured before
		if mouse_was_captured:
			# Use a tween to delay recapturing the mouse slightly
			create_tween().tween_callback(func(): 
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				print("Mouse recaptured after unpausing")
			).set_delay(0.05)
		
		print("Game unpaused. Restoring mouse capture: " + str(mouse_was_captured))

# Function called from GameUI when resuming via button
func resume_from_pause():
	is_game_paused = false
	get_tree().paused = false
	
	# Restore mouse capture if it was captured before
	if mouse_was_captured:
		# Use a tween to delay recapturing the mouse slightly
		create_tween().tween_callback(func(): 
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			print("Mouse recaptured after unpausing")
		).set_delay(0.05)
		
	print("Game resumed from pause menu. Restoring mouse capture: " + str(mouse_was_captured))

# Function to quit the game
func quit_game():
	print("Quitting game...")
	# Perform any cleanup if needed
	
	# Quit the application
	get_tree().quit()

func spawn_resources():
	# Check if resource spawn points exist
	if !resource_spawn_points:
		push_error("Resource spawn points not found!")
		return
	
	# Get resource spawn points from the scene
	var spawn_points = []
	for point in resource_spawn_points.get_children():
		spawn_points.append(point.global_position)
	
	# Check if resources container exists
	if !resources_container:
		push_error("Resources container not found!")
		return
		
	# Remove any pre-existing resource instances
	for child in resources_container.get_children():
		child.queue_free()
	
	# Spawn different resource types
	var resource_types = ["ScrapMetal", "PowerCell", "ElectronicParts", "RareMetal"]
	var rarity_weights = [0.6, 0.25, 0.1, 0.05]  # Higher number = more common
	
	print("Spawning resources...")
	
	for point in spawn_points:
		# Select resource type based on rarity
		var resource_type = weighted_random_choice(resource_types, rarity_weights)
		
		# Instantiate resource
		var resource = resource_scene.instantiate()
		resources_container.add_child(resource)
		
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
	
	print("Spawned " + str(spawn_points.size()) + " resources")

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
	game_ui.update_mission_info(current_mission_number, total_resources_collected, missions_completed)

# Method called when resources are delivered to base
func add_resources(resource_dict):
	# Update total resources collected
	for resource_type in resource_dict:
		total_resources_collected += resource_dict[resource_type]
	
	# Update UI
	update_mission_display()
