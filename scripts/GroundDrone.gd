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
@export var collection_speed: float = 1.0  # Base collection speed (can be upgraded)

# Resource Collection
@export var max_cargo_capacity: int = 5
var current_cargo: int = 0
var collected_resources = {}  # Dictionary to track resource types and quantities

# State Management
enum DroneState {IDLE, DRIVING, COLLECTING_ACTIVE, DOCKING}
var current_state: DroneState = DroneState.DRIVING

# Collection Progress Tracking
var current_collection_target = null  # Reference to resource being collected
var previously_targeted_resource = null  # To track when targeting changes
var collection_progress: float = 0.0  # Progress from 0.0 to 1.0 (0 = not started, 1 = complete)
var collection_started: bool = false
var segments_collected: int = 0  # Track how many segments we've collected
var targeting_resources = {}  # Dictionary to track which resources we're targeting

# References
@onready var camera = $Camera3D
@onready var cargo_indicator = $CanvasLayer/CargoIndicator
@onready var interaction_ray = $Camera3D/InteractionRay
@onready var crosshair = $CanvasLayer/Crosshair
@onready var progress_indicator = $CanvasLayer/ProgressIndicator

# Navigation
var target_waypoint = null
var waypoints = []  # Will be populated from aerial drone's marked locations
var resource_in_sight: bool = false  # Track if we're looking at a resource

func _ready():
	# Initialize UI
	update_cargo_display()
	
	# Hide progress indicator initially
	progress_indicator.visible = false
	
	# Start directly in driving mode
	current_state = DroneState.DRIVING
	
	# Configure interaction ray
	interaction_ray.enabled = true
	interaction_ray.set_collision_mask_value(1, true)  # Layer 1 (ground)
	interaction_ray.set_collision_mask_value(2, true)  # Layer 2 (resources)
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Ground drone deployed - mouse captured for camera control")

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
	# Handle pause menu (ESC key)
	if event.is_action_pressed("pause_game"):
		# This should be handled by GameManager, but we'll make sure mouse is freed
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
		
	# Mouse look
	if event is InputEventMouseMotion:
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
		if event.pressed and resource_in_sight and current_cargo < max_cargo_capacity:
			# Start collection when left mouse button is pressed
			if current_state != DroneState.COLLECTING_ACTIVE:
				start_collection()
		elif !event.pressed and current_state == DroneState.COLLECTING_ACTIVE:
			# Cancel collection when left mouse button is released
			cancel_collection()

func check_resources_in_sight():
	var new_resource = get_resource_in_sight()
	
	# Update resource_in_sight flag
	resource_in_sight = (new_resource != null && current_cargo < max_cargo_capacity)
	
	# Update crosshair
	update_crosshair_and_targeting(new_resource)

func get_resource_in_sight():
	# First check with raycast
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("resource") and current_cargo < max_cargo_capacity:
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
		# Don't use highlight_as_targeted/unhighlight methods to avoid scan_highlight changes
		if was_targeting_resource(previously_targeted_resource):
			previously_targeted_resource = null
	
	# Update targeting
	if new_resource != null and current_cargo < max_cargo_capacity:
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

# Helper function to track which resources we're targeting
func was_targeting_resource(resource):
	return previously_targeted_resource == resource

func update_progress_indicator(progress_value: float, segments: int):
	if progress_indicator:
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
	
	# Initialize progress indicator with segments based on resource amount
	update_progress_indicator(collection_progress, resource.resource_amount)

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
	
	# Calculate progress increment based on collection speed and time
	var progress_increment = delta * collection_speed
	collection_progress += progress_increment
	
	# Calculate segment thresholds
	var segments_total = current_collection_target.resource_amount
	var segment_size = 1.0 / segments_total
	
	# Check if we've crossed a segment boundary
	var segment_to_collect = floor(collection_progress / segment_size)
	
	if segment_to_collect > segments_collected:
		# We've crossed a segment boundary - collect one unit
		add_resource_to_cargo(current_collection_target.resource_type, 1)
		segments_collected += 1
		
		print("Collected segment " + str(segments_collected) + "/" + str(segments_total) + 
			" of " + current_collection_target.resource_type)
		
		# Check if this depletes the resource
		if current_collection_target.deplete_one_unit():
			# Resource fully depleted
			complete_collection()
			return
	
	# Update progress indicator
	update_progress_indicator(collection_progress, segments_total)
	
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

func add_resource_to_cargo(resource_type, amount):
	# Add resource to inventory
	if resource_type in collected_resources:
		collected_resources[resource_type] += amount
	else:
		collected_resources[resource_type] = amount
	
	# Update cargo count
	current_cargo += amount
	
	# Update UI
	update_cargo_display()
	
	print("Added " + str(amount) + " " + resource_type + " to cargo (Total: " + str(current_cargo) + "/" + str(max_cargo_capacity) + ")")

func process_docking(_delta):
	# Docking logic
	velocity = Vector3.ZERO
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	
	# Release mouse when returning to base
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	complete_docking()

func update_cargo_display():
	# Update UI cargo indicator
	cargo_indicator.value = (float(current_cargo) / max_cargo_capacity) * 100.0

func is_near_base():
	# This would check distance to base in practice
	# For now, return true when the dock key is pressed
	return true

func complete_docking():
	# Process resources at base
	if current_cargo > 0:
		print("Unloading cargo:")
		for resource_type in collected_resources:
			print("- " + resource_type + ": " + str(collected_resources[resource_type]))
		
		# Signal resources have been delivered
		emit_signal("resources_delivered", collected_resources)
		
		# Reset cargo
		current_cargo = 0
		collected_resources.clear()
		update_cargo_display()
	
	# Reset state
	current_state = DroneState.IDLE
	
	print("Docking complete, cargo unloaded")

# Set waypoints from aerial drone's marked locations
func set_waypoints(points):
	waypoints = points
	print("Received " + str(waypoints.size()) + " waypoints from aerial drone")

# Signals
signal resources_delivered(resources)
