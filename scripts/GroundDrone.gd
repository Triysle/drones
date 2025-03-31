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
var collection_progress: float = 0.0  # Progress from 0.0 to 1.0
var collection_started: bool = false

# References
@onready var camera = $Camera3D
@onready var cargo_indicator = $CanvasLayer/CargoIndicator
@onready var interaction_ray = $Camera3D/InteractionRay
@onready var crosshair = $CanvasLayer/Crosshair
@onready var progress_indicator = $CanvasLayer/ProgressIndicator

# Navigation
var target_waypoint = null
var waypoints = []  # Will be populated from aerial drone's marked locations
var resource_in_sight = false  # Track if we're looking at a resource for crosshair

func _ready():
	# Initialize UI
	update_cargo_display()
	
	# Hide progress indicator initially
	progress_indicator.visible = false
	
	# Start directly in driving mode
	current_state = DroneState.DRIVING
	
	# Make sure the interaction ray is enabled and configured correctly
	interaction_ray.enabled = true
	interaction_ray.set_collision_mask_value(1, true)  # Layer 1 (ground)
	interaction_ray.set_collision_mask_value(2, true)  # Layer 2 (resources)
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Ground drone deployed - mouse captured for camera control")

func _physics_process(delta):
	# Update interaction ray
	update_interaction_ray()
	
	match current_state:
		DroneState.IDLE:
			process_idle(delta)
		DroneState.DRIVING:
			process_driving(delta)
		DroneState.COLLECTING_ACTIVE:
			process_collecting_active(delta)
		DroneState.DOCKING:
			process_docking(delta)
	
	# Apply movement for all states
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Apply movement with reduced speed during collection
	if current_state == DroneState.COLLECTING_ACTIVE:
		# Apply a movement speed penalty while collecting
		velocity.x *= 0.7
		velocity.z *= 0.7
	
	move_and_slide()
	
	# Check if left mouse button is still held during collection
	if current_state == DroneState.COLLECTING_ACTIVE and !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		cancel_collection()
	
	# Check for resources in view and update crosshair
	check_resource_in_sight()
	update_crosshair()

func _input(event):
	# Mouse look when in any state except COLLECTING_ACTIVE
	if event is InputEventMouseMotion and current_state != DroneState.COLLECTING_ACTIVE:
		# Rotate the drone horizontally based on mouse movement
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Limit vertical camera rotation without rotating the whole drone
		var current_tilt = camera.rotation.x
		current_tilt -= event.relative.y * mouse_sensitivity
		current_tilt = clamp(current_tilt, -PI/3, PI/3) # Limit to 45 degrees up/down
		camera.rotation.x = current_tilt
	
	# Mouse look during COLLECTING_ACTIVE - slower but still allowed
	elif event is InputEventMouseMotion and current_state == DroneState.COLLECTING_ACTIVE:
		# Slower rotation during collection
		rotate_y(-event.relative.x * mouse_sensitivity * 0.5)
		
		var current_tilt = camera.rotation.x
		current_tilt -= event.relative.y * mouse_sensitivity * 0.5
		current_tilt = clamp(current_tilt, -PI/3, PI/3)
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

func update_interaction_ray():
	# Ray always points forward from camera
	interaction_ray.target_position = Vector3(0, 0, -detection_distance)

func check_resource_in_sight():
	resource_in_sight = false
	var resource = get_resource_in_sight()
	
	if resource != null and current_cargo < max_cargo_capacity:
		resource_in_sight = true
		return resource
	
	return null

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

func update_crosshair():
	if !crosshair:
		return
	
	if resource_in_sight and current_cargo < max_cargo_capacity:
		# Change crosshair to yellow when pointing at a collectable resource
		crosshair.modulate = Color(1.0, 1.0, 0.0, 1.0)  # Yellow
	else:
		# Keep crosshair white for anything else (including ground)
		crosshair.modulate = Color(1.0, 1.0, 1.0, 1.0)  # White

func update_progress_indicator(progress: float, max_segments: int):
	if !progress_indicator:
		print("Progress indicator not found!")
		return
	
	# Ensure progress indicator is visible
	progress_indicator.visible = true
	
	# Check if the methods exist before calling them
	if progress_indicator.has_method("set_progress_value"):
		progress_indicator.set_progress_value(progress * 100.0)
	else:
		# Direct property assignment as fallback
		if "value" in progress_indicator:
			progress_indicator.value = progress * 100.0
	
	if progress_indicator.has_method("set_segment_count"):
		progress_indicator.set_segment_count(max_segments)
	elif progress_indicator.has_method("set_segments"):
		progress_indicator.set_segments(max_segments)
	
	# Update color based on progress (yellow to green)
	var green_component = 1.0  # Always max
	var red_component = 1.0 - (progress * 0.5)  # Reduces from 1.0 to 0.5
	
	# Safe property access
	if progress_indicator.has_method("set_tint_progress"):
		progress_indicator.set_tint_progress(Color(red_component, green_component, 0.0, 1.0))
	elif "tint_progress" in progress_indicator:
		progress_indicator.tint_progress = Color(red_component, green_component, 0.0, 1.0)

func process_idle(_delta):
	# Just a placeholder state - we start in DRIVING now
	pass

func process_driving(delta):
	# Get movement input - WASD controls
	var input_forward = Input.get_axis("move_forward", "move_backward")
	var input_right = Input.get_axis("move_left", "move_right")
	
	# Calculate movement direction (relative to drone orientation)
	var direction = Vector3.ZERO
	direction += transform.basis.z * input_forward  # Forward/backward along drone's facing (flipped Z axis)
	direction += transform.basis.x * input_right     # Strafe left/right
	
	# Normalize for consistent speed in all directions
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
		print("Docking initiated")
		current_state = DroneState.DOCKING

func start_collection():
	# Get the resource we're looking at
	var resource = get_resource_in_sight()
	if !resource:
		return
	
	print("Starting collection of " + resource.resource_type)
	
	# If target has changed, reset progress
	if current_collection_target != resource:
		current_collection_target = resource
		collection_progress = resource.collection_progress  # Get saved progress
		
	# Set up collection state
	current_state = DroneState.COLLECTING_ACTIVE
	collection_started = true
	
	# Show progress indicator
	progress_indicator.visible = true
	
	# Update progress indicator with segments based on resource amount
	update_progress_indicator(collection_progress, resource.resource_amount)
	
	# We allow movement while collecting
	# velocity is not set to Vector3.ZERO so player can still move

func process_collecting_active(delta):
	if !current_collection_target or !collection_started:
		cancel_collection()
		return
	
	# Ensure resource is still valid and in range
	if !is_instance_valid(current_collection_target) or current_collection_target.resource_amount <= 0:
		complete_collection()
		return
	
	# Check if resource is still in sight while collecting
	var resource_still_in_sight = false
	var current_resource_in_sight = get_resource_in_sight()
	
	if current_resource_in_sight == current_collection_target:
		resource_still_in_sight = true
	
	if !resource_still_in_sight:
		# If resource is no longer in sight, pause the collection but don't cancel
		# This gives the player a chance to re-aim at the resource
		return
	
	# Calculate progress increment based on collection speed and time
	var progress_increment = delta * collection_speed / current_collection_target.resource_amount
	collection_progress += progress_increment
	
	# Update progress indicator
	update_progress_indicator(collection_progress, current_collection_target.resource_amount)
	
	# Check if a unit is collected (progress reaches or exceeds 1.0)
	if collection_progress >= 1.0:
		# Collect one unit
		add_resource_to_cargo(current_collection_target.resource_type, 1)
		
		# Reduce resource amount
		current_collection_target.resource_amount -= 1
		
		# Save progress to resource
		current_collection_target.collection_progress = 0.0
		
		# Reset progress for next unit
		collection_progress = 0.0
		
		print("Collected one unit of " + current_collection_target.resource_type)
		
		# Check if all resources are depleted
		if current_collection_target.resource_amount <= 0:
			print("Resource depleted completely")
			current_collection_target.collect()  # Trigger final collection animation
			complete_collection()
			return
	else:
		# Save current progress to resource
		current_collection_target.collection_progress = collection_progress

func cancel_collection():
	print("Collection canceled")
	
	# Save current progress to resource if it exists
	if current_collection_target and is_instance_valid(current_collection_target):
		current_collection_target.collection_progress = collection_progress
	
	# Reset collection variables
	collection_started = false
	
	# Hide progress indicator
	progress_indicator.visible = false
	
	# Return to driving state
	current_state = DroneState.DRIVING

func complete_collection():
	print("Collection complete")
	
	# Reset collection variables
	collection_started = false
	current_collection_target = null
	collection_progress = 0.0
	
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
	
	print("Added " + str(amount) + " " + resource_type + " to cargo")

func process_docking(_delta):
	# Docking logic - move toward docking point
	velocity = Vector3.ZERO
	print("Docking sequence in progress")
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	
	# Release mouse when returning to base
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	complete_docking()

func update_cargo_display():
	# Update UI cargo indicator
	cargo_indicator.value = (float(current_cargo) / max_cargo_capacity) * 100

func is_near_base():
	# This would check distance to base in practice
	# For now, we'll just return true when the dock key is pressed
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
