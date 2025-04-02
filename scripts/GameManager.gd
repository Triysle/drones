extends Node

# Game Manager - Coordinates overall gameplay systems

# Scene references - now using preload for resource scene only
@export var resource_scene = preload("res://scenes/Resource.tscn") 

# Node path references (new)
@onready var environment = $Environment
@onready var base_station = $BaseStation
@onready var resources_container = $Resources
@onready var resource_spawn_points = $Environment/ResourceSpawnPoints

# Game state tracking
var current_mission_number = 1
var total_resources_collected = 0
var missions_completed = 0
var active_drone = null  # Reference to currently active drone (aerial or ground)

# UI References (updated paths)
@onready var mission_display = $GameUI/MissionDisplay
@onready var help_panel = $GameUI/HelpPanel
@onready var pause_menu = $GameUI/PauseMenu

# Game state
var is_game_paused = false
var mouse_was_captured = false

func _ready():
	# Setup initial game state
	initialize_game()
	
	# Setup pause menu signals
	connect_pause_menu()

func _input(event):
	# Toggle pause menu
	if event.is_action_pressed("pause_game"):
		toggle_pause()
	
	# Toggle help panel
	if event.is_action_pressed("show_help"):
		toggle_help_panel()

func initialize_game():
	# Generate initial resources
	spawn_resources()
	
	# Show initial mission info
	update_mission_display()
	
	print("Game initialized")

# Connect signals for the pause menu
func connect_pause_menu():
	# Pause menu is already in the scene hierarchy, just need to connect signals
	pause_menu.connect("resume_game", Callable(self, "_on_resume_game"))
	pause_menu.connect("quit_game", Callable(self, "_on_quit_game"))
	
	print("Pause menu signals connected")

# Pause/unpause the game
func toggle_pause():
	is_game_paused = !is_game_paused
	
	if is_game_paused:
		# Pause the game
		get_tree().paused = true
		
		# Store mouse capture state and free the mouse
		mouse_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Show the pause menu
		pause_menu.visible = true
		pause_menu.show_menu()
		
		print("Game paused. Mouse was captured: " + str(mouse_was_captured))
	else:
		# Hide the pause menu
		pause_menu.hide_menu()
		pause_menu.visible = false
		
		# Unpause the game
		get_tree().paused = false
		
		# Restore mouse capture if it was captured before
		if mouse_was_captured:
			# Use a tween to delay recapturing the mouse slightly
			# This ensures proper operation after unpausing
			create_tween().tween_callback(func(): 
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				print("Mouse recaptured after unpausing")
			).set_delay(0.05)
		
		print("Game unpaused. Restoring mouse capture: " + str(mouse_was_captured))

# Signal handlers for pause menu
func _on_resume_game():
	print("Resume game signal received")
	toggle_pause() # This will handle unpausing

func _on_quit_game():
	print("Quit game signal received, exiting...")
	get_tree().quit()

func spawn_resources():
	# Get resource spawn points from the scene
	var spawn_points = []
	for point in resource_spawn_points.get_children():
		spawn_points.append(point.global_position)
	
	# Remove any pre-existing resource instances used for testing
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
	mission_display.set_mission_number(current_mission_number)
	mission_display.set_resources_collected(total_resources_collected)
	mission_display.set_missions_completed(missions_completed)

func toggle_help_panel():
	# Show/hide help panel
	help_panel.visible = !help_panel.visible
	
	# Optionally free the mouse when help is visible
	if help_panel.visible:
		mouse_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if mouse_was_captured and !is_game_paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
