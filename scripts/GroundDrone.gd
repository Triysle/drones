extends CharacterBody3D

# Ground Drone Properties
@export var max_speed: float = 7.0
@export var acceleration: float = 4.0
@export var deceleration: float = 7.0
@export var rotation_speed: float = 1.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var traction: float = 0.6
@export var detection_distance: float = 5.0  # How far to check for resources

# Collection Properties
@export var seconds_per_segment: float = 2.0  # Time in seconds to collect one resource
@export var collection_speed: float = 1.0  # Base collection speed multiplier (can be upgraded)

# Resource Collection - Slot-based inventory
@export var max_cargo_slots: int = 5  # Initial capacity (5 slots)
var cargo_slots = []  # Array of resource types, empty string "" means empty slot
var current_cargo_count: int = 0  # How many slots are filled

# State Management
enum DroneState {IDLE, DRIVING, COLLECTING_ACTIVE, DOCKING}
var current_state: DroneState = DroneState.DRIVING

# Collection Progress Tracking
var current_collection_target = null  # Reference to resource being collected
var previously_targeted_resource = null  # To track when targeting changes
var collection_progress: float = 0.0  # Progress from 0.0 to 1.0 (0 = not started, 1 = complete)
var collection_started: bool = false
var segments_collected: int = 0  # Track how many segments we've collected

# References
@onready var camera = $Camera3D
@onready var interaction_ray = $Camera3D/InteractionRay
@onready var crosshair = get_node("/root/Main/GameUI/Crosshair")

# UI references - these will be updated to point to nodes in the main scene
var progress_indicator
var cargo_slots_ui
var resource_info_label

# Navigation
var target_waypoint = null
var waypoints = []  # Will be populated from aerial drone's marked locations
var resource_in_sight: bool = false  # Track if we're looking at a resource
var base_station = null

func _ready():
	# Initialize slot-based inventory
	initialize_cargo_slots(max_cargo_slots)
	
	# Find UI elements in the main scene
	progress_indicator = get_node("/root/Main/GameUI/ProgressIndicator")
	cargo_slots_ui = get_node("/root/Main/GameUI/CargoUI")
	resource_info_label = get_node("/root/Main/GameUI/ResourceInfoLabel")
	
	# Show the cargo UI
	cargo_slots_ui.visible = true
	
	# Hide progress indicator initially
	progress_indicator.visible = false
	
	# Initialize resource info label
	resource_info_label.visible = false
	
	# Start directly in driving mode
	current_state = DroneState.DRIVING
	
	# Configure interaction ray
	interaction_ray.enabled = true
	interaction_ray.set_collision_mask_value(1, true)  # Layer 1 (ground)
	interaction_ray.set_collision_mask_value(2, true)  # Layer 2 (resources)
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Ground drone deployed - mouse captured for camera control")

# Initialize the cargo slots array
func initialize_cargo_slots(num_slots: int):
	cargo_slots.clear()
	for i in range(num_slots):
		cargo_slots.append("")  # Empty slots
	
	# Update UI
	update_cargo_ui()

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Process state-specific behavior
	match current_state:
		DroneState.IDLE:
			process_idle(delta)
		DroneState.DRIVING:
			process_driving(delta)
		DroneState.COLLECTING_ACTIVE:
			process_collecting_active(delta)
		DroneState.DOCKING:
			process_docking(delta)
	
	# Apply reduced movement during collection
	if current_state == DroneState.COLLECTING_ACTIVE:
		velocity.x *= 0.7
		velocity.z *= 0.7
	
	move_and_slide()
	
	# Check resources in sight and update targeting
	check_resources_in_sight()
	
	# Check if left mouse button is still held during collection
	if current_state == DroneState.COLLECTING_ACTIVE and !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		cancel_collection()

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Slower rotation during collection
		var sensitivity_modifier = 1.0
		if current_state == DroneState.COLLECTING_ACTIVE:
			sensitivity_modifier = 0.5
			
		# Rotate the drone horizontally based on mouse movement
		rotate_y(-event.relative.x * mouse_sensitivity * sensitivity_modifier)
		
		# Limit vertical camera rotation without rotating the whole drone
		var current_tilt = camera.rotation.x
		current_tilt -= event.relative.y * mouse_sensitivity * sensitivity_modifier
		current_tilt = clamp(current_tilt, -PI/3, PI/3) # Limit to 60 degrees up/down
		camera.rotation.x = current_tilt
	
	# Resource collection input (left mouse button)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and resource_in_sight and current_cargo_count < max_cargo_slots:
			# Start collection when left mouse button is pressed
			if current_state != DroneState.COLLECTING_ACTIVE:
				start_collection()
		elif !event.pressed and current_state == DroneState.COLLECTING_ACTIVE:
			# Cancel collection when left mouse button is released
			cancel_collection()

# Called when the drone resumes from pause
func resume_from_pause():
	# Make sure mouse is captured when we're in control of this drone
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Ground drone: Recaptured mouse after resuming from pause")

func check_resources_in_sight():
	var new_resource = get_resource_in_sight()
	
	# Update resource_in_sight flag
	resource_in_sight = (new_resource != null && current_cargo_count < max_cargo_slots)
	
	# Update crosshair
	update_crosshair_and_targeting(new_resource)
	
	# Update resource info label
	if new_resource != null && current_cargo_count < max_cargo_slots:
		resource_info_label.text = new_resource.resource_type
		resource_info_label.visible = true
	else:
		resource_info_label.visible = false

func get_resource_in_sight():
	# First check with raycast
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("resource") and current_cargo_count < max_cargo_slots:
			return collider
	
	# If raycast didn't find a resource, try the direct method
	var forward = -camera.global_transform.basis.z.normalized()
	var resources = get_tree().get_nodes_in_group("resource")
	
	var closest_resource = null
	var closest_distance = detection_distance
	
	for resource in resources:
		# Calculate vector to resource
		var to_resource = resource.global_position - camera.global_position
		
		# Project vector onto forward direction to get distance along ray
		var distance_along_ray = to_resource.dot(forward)
		
		# Check if resource is in front of us and within detection range
		if distance_along_ray > 0 and distance_along_ray < detection_distance:
			# Calculate perpendicular distance from ray to resource
			var projected_point = camera.global_position + forward * distance_along_ray
			var perpendicular_distance = resource.global_position.distance_to(projected_point)
			
			# If within a reasonable cone angle (1.0 meter radius at detection_distance)
			if perpendicular_distance < 1.0 * (distance_along_ray / detection_distance):
				# Check if this is the closest resource so far
				if distance_along_ray < closest_distance:
					closest_resource = resource
					closest_distance = distance_along_ray
	
	return closest_resource

func update_crosshair_and_targeting(new_resource):
	# If we're actively collecting, don't change targeting
	if current_state == DroneState.COLLECTING_ACTIVE:
		return
		
	# Clear previous targeting
	if previously_targeted_resource != null and is_instance_valid(previously_targeted_resource):
		previously_targeted_resource = null
	
	# Update targeting
	if new_resource != null and current_cargo_count < max_cargo_slots:
		# Change crosshair to yellow when pointing at a collectable resource
		crosshair.modulate = Color(1.0, 1.0, 0.0, 1.0)  # Yellow
		
		# Show progress indicator when targeting a resource
		update_progress_indicator(
			new_resource.collection_progress, 
			new_resource.resource_amount
		)
		progress_indicator.visible = true
		
		# Remember current targeted resource
		previously_targeted_resource = new_resource
	else:
		# Keep crosshair white for anything else
		crosshair.modulate = Color(1.0, 1.0, 1.0, 1.0)  # White
		
		# Hide progress indicator when not targeting a resource
		progress_indicator.visible = false
		
		# Clear targeted resource
		previously_targeted_resource = null

func update_progress_indicator(progress_value: float, segments: int):
	if progress_indicator:
		# Store original segment count for the resource when we first encounter it
		if previously_targeted_resource != null and is_instance_valid(previously_targeted_resource):
			if not previously_targeted_resource.has_meta("original_segments"):
				previously_targeted_resource.set_meta("original_segments", segments)
			
			# Always use the original segment count
			var original_segments = previously_targeted_resource.get_meta("original_segments")
			progress_indicator.set_segment_count(original_segments)
		else:
			progress_indicator.set_segment_count(segments)
			
		progress_indicator.set_progress_value(progress_value * 100.0)
		
		# Set green color
		progress_indicator.set_fill_color(Color(0.0, 1.0, 0.0, 1.0))
	else:
		print("Warning: Progress indicator not found!")

func process_idle(_delta):
	# Placeholder state
	pass

func process_driving(delta):
	# Get movement input - WASD controls
	var input_forward = Input.get_axis("move_forward", "move_backward")  # Forward/backward
	var input_right = Input.get_axis("move_left", "move_right")          # Left/right
	
	# Calculate movement direction (relative to drone orientation)
	var direction = Vector3.ZERO
	direction += transform.basis.z * input_forward  # Forward/backward
	direction += transform.basis.x * input_right    # Left/right
	
	# Apply movement
	if direction.length_squared() > 0:
		direction = direction.normalized()
		var target_velocity = Vector3(direction.x * max_speed, 0, direction.z * max_speed)
		
		# Apply acceleration but allow for some drift
		velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)
	else:
		# Apply gentler deceleration when no input to allow for drift
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta * traction)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta * traction)
		
		# Only fully stop at very low speeds
		if abs(velocity.x) < 0.05 and abs(velocity.z) < 0.05:
			velocity.x = 0.0
			velocity.z = 0.0
	
	# Check for docking
	if Input.is_action_just_pressed("dock") and is_near_base():
		current_state = DroneState.DOCKING
		print("Docking initiated")

func start_collection():
	# Get the resource we're looking at
	var resource = get_resource_in_sight()
	if !resource:
		return
	
	print("Starting collection of " + resource.resource_type)
	
	# Set up collection state
	current_state = DroneState.COLLECTING_ACTIVE
	current_collection_target = resource
	collection_started = true
	
	# Get saved progress from resource
	collection_progress = resource.collection_progress
	segments_collected = 0
	
	# Make sure progress indicator is visible
	progress_indicator.visible = true
	
	# Save original segment count if not already saved
	if not resource.has_meta("original_segments"):
		resource.set_meta("original_segments", resource.resource_amount)
	
	# Initialize progress indicator with original segment count
	var original_segments = resource.get_meta("original_segments")
	update_progress_indicator(collection_progress, original_segments)

func process_collecting_active(delta):
	if !current_collection_target or !collection_started:
		cancel_collection()
		return
	
	# Ensure resource is still valid
	if !is_instance_valid(current_collection_target):
		cancel_collection()
		return
	
	# Check if resource is still in sight while collecting
	var resource_still_in_sight = false
	var current_resource_in_sight = get_resource_in_sight()
	
	if current_resource_in_sight == current_collection_target:
		resource_still_in_sight = true
	
	if !resource_still_in_sight:
		# If resource is no longer in sight, pause collection but don't cancel
		return
	
	# Get original segment count (from first encounter with this resource)
	var original_segments = current_collection_target.get_meta("original_segments")
	
	# Calculate progress increment based on collection speed, time, and segment count
	# (1.0 / original_segments) is the size of one segment
	# We divide this by seconds_per_segment to get how much progress to make per second
	var progress_rate = (1.0 / original_segments) / seconds_per_segment
	
	# Apply the collection speed multiplier (for upgrades) and delta time
	var progress_increment = progress_rate * collection_speed * delta
	collection_progress += progress_increment
	
	# Calculate segment thresholds
	var segment_size = 1.0 / original_segments
	
	# Check if we've crossed a segment boundary
	var segment_to_collect = floor(collection_progress / segment_size)
	
	if segment_to_collect > segments_collected:
		# We've crossed a segment boundary - collect one unit
		if has_empty_cargo_slot():
			add_resource_to_cargo(current_collection_target.resource_type)
			segments_collected += 1
			
			print("Collected segment " + str(segments_collected) + "/" + str(original_segments) + 
				" of " + current_collection_target.resource_type)
			
			# Check if this depletes the resource
			if current_collection_target.deplete_one_unit():
				# Resource fully depleted
				complete_collection()
				return
		else:
			# No empty slots - cancel collection
			cancel_collection()
			return
	
	# Update progress indicator - use original segment count
	update_progress_indicator(collection_progress, original_segments)
	
	# Save progress to resource
	current_collection_target.collection_progress = collection_progress

func cancel_collection():
	print("Collection paused")
	
	# Save current progress to resource if it exists
	if current_collection_target and is_instance_valid(current_collection_target):
		current_collection_target.collection_progress = collection_progress
	
	# Reset collection state
	collection_started = false
	
	# Return to driving state
	current_state = DroneState.DRIVING
	
	# Don't hide progress indicator here - it will update based on targeting

func complete_collection():
	print("Collection complete")
	
	# Reset collection variables
	collection_started = false
	current_collection_target = null
	collection_progress = 0.0
	segments_collected = 0
	
	# Hide progress indicator
	progress_indicator.visible = false
	
	# Return to driving state
	current_state = DroneState.DRIVING

# Check if we have an empty cargo slot
func has_empty_cargo_slot() -> bool:
	return current_cargo_count < max_cargo_slots

# Find the first empty cargo slot
func find_empty_cargo_slot() -> int:
	for i in range(cargo_slots.size()):
		if cargo_slots[i] == "":
			return i
	return -1  # No empty slots

# Add resource to first available cargo slot
func add_resource_to_cargo(resource_type: String):
	var slot_index = find_empty_cargo_slot()
	if slot_index >= 0:
		cargo_slots[slot_index] = resource_type
		current_cargo_count += 1
		update_cargo_ui()
		print("Added " + resource_type + " to cargo slot " + str(slot_index) + 
			" (Total: " + str(current_cargo_count) + "/" + str(max_cargo_slots) + ")")
		return true
	else:
		print("Cannot add to cargo - all slots full")
		return false

func update_cargo_ui():
	# Try to update through the GameUI first
	var game_ui = get_node_or_null("/root/Main/GameUI")
	if game_ui and game_ui.has_method("update_cargo_slots"):
		game_ui.update_cargo_slots(cargo_slots)
		return
		
	# Fall back to direct update if available
	if cargo_slots_ui and cargo_slots_ui.has_method("update_slots"):
		cargo_slots_ui.update_slots(cargo_slots)
		return
		
	# Debug info if neither method works
	print("Warning: Cannot update cargo UI - interface not found")

func process_docking(_delta):
	# Docking logic
	velocity = Vector3.ZERO
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	
	# Release mouse when returning to base
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	complete_docking()

func is_near_base():
	# Check if drone is near base station
	if base_station:
		var distance = global_position.distance_to(base_station.global_position)
		return distance < 15.0  # Same as the docking_distance in BaseStation.gd
	return false

func complete_docking():
	# Only process once - change state immediately to prevent multiple calls
	current_state = DroneState.IDLE
	
	# Process resources at base
	if current_cargo_count > 0:
		print("Unloading cargo:")
		
		# Convert cargo slots to resource counts
		var delivered_resources = {}
		for resource_type in cargo_slots:
			if resource_type != "":
				if resource_type in delivered_resources:
					delivered_resources[resource_type] += 1
				else:
					delivered_resources[resource_type] = 1
		
		# Display what we're delivering
		for resource_type in delivered_resources:
			print("- " + resource_type + ": " + str(delivered_resources[resource_type]))
		
		# Signal resources have been delivered
		emit_signal("resources_delivered", delivered_resources)
		
		# Reset cargo
		initialize_cargo_slots(max_cargo_slots)
		current_cargo_count = 0
	
	print("Docking complete, cargo unloaded")

# Expand cargo capacity (called when upgrading)
func expand_cargo_capacity(new_capacity: int):
	if new_capacity > max_cargo_slots:
		max_cargo_slots = new_capacity
		
		# Add new empty slots
		while cargo_slots.size() < max_cargo_slots:
			cargo_slots.append("")
			
		# Update UI
		cargo_slots_ui.expand_capacity(max_cargo_slots)
		print("Cargo capacity expanded to " + str(max_cargo_slots) + " slots")

# Set waypoints from aerial drone's marked locations
func set_waypoints(points):
	waypoints = points
	
	# Connect to the waypoint system
	var waypoint_system = get_node("/root/Main/Waypoints")
	if waypoint_system:
		# We don't need to do anything specific here since the waypoint system 
		# already has the visual markers created by the aerial drone
		
		# Just update our local copy of waypoints
		waypoints = waypoint_system.get_all_waypoints()
	
	print("Received " + str(waypoints.size()) + " waypoints from aerial drone")
	
# Find the closest waypoint to current position
func find_closest_waypoint():
	var waypoint_system = get_node("/root/Main/Waypoints")
	if waypoint_system:
		var closest_idx = waypoint_system.get_closest_waypoint(global_position)
		if closest_idx >= 0:
			return waypoint_system.get_all_waypoints()[closest_idx]
	return null

# Calculate total resources by type
func get_resources_by_type():
	var resources = {}
	
	for resource_type in cargo_slots:
		if resource_type != "":
			if resource_type in resources:
				resources[resource_type] += 1
			else:
				resources[resource_type] = 1
	
	return resources

# Signals
signal resources_delivered(resources)
