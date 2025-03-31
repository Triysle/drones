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

# Resource Collection
@export var max_cargo_capacity: int = 5
var current_cargo: int = 0
var collected_resources = {}  # Dictionary to track resource types and quantities

# State Management
enum DroneState {IDLE, DRIVING, COLLECTING, DOCKING}
var current_state: DroneState = DroneState.DRIVING

# References
@onready var camera = $Camera3D
@onready var cargo_indicator = $CanvasLayer/CargoIndicator
@onready var interaction_ray = $Camera3D/InteractionRay
@onready var crosshair = $CanvasLayer/Crosshair

# Navigation
var target_waypoint = null
var waypoints = []  # Will be populated from aerial drone's marked locations
var resource_in_sight = false  # Track if we're looking at a resource for crosshair

func _ready():
	# Initialize UI
	update_cargo_display()
	
	# Start directly in driving mode
	current_state = DroneState.DRIVING
	
	# Make sure the interaction ray is enabled and configured correctly
	interaction_ray.enabled = true
	interaction_ray.set_collision_mask_value(1, true)  # Layer 1 (ground)
	interaction_ray.set_collision_mask_value(2, true)  # Layer 2 (resources)
	
	# Initialize crosshair
	if !crosshair:
		print("ERROR: Crosshair not found. Add Crosshair to CanvasLayer.")
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Ground drone deployed - mouse captured for camera control")
	var mask_str = ""
	for i in range(1, 21):
		mask_str += "1" if interaction_ray.get_collision_mask_value(i) else "0"
	print("Interaction ray enabled: " + str(interaction_ray.enabled) + 
		", collision mask: " + mask_str + 
		", target position: " + str(interaction_ray.target_position))

func _physics_process(delta):
	# Update interaction ray
	update_interaction_ray()
	
	match current_state:
		DroneState.IDLE:
			process_idle(delta)
		DroneState.DRIVING:
			process_driving(delta)
		DroneState.COLLECTING:
			process_collecting(delta)
		DroneState.DOCKING:
			process_docking(delta)
	
	# Apply movement except when collecting
	if current_state != DroneState.COLLECTING:
		# Apply gravity
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
	
	# Check for resources in view and update crosshair
	check_resource_in_sight()
	update_crosshair()

func _input(event):
	# Mouse look when driving
	if current_state == DroneState.DRIVING and event is InputEventMouseMotion:
		# Rotate the drone horizontally based on mouse movement
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Limit vertical camera rotation without rotating the whole drone
		var current_tilt = camera.rotation.x
		current_tilt -= event.relative.y * mouse_sensitivity
		current_tilt = clamp(current_tilt, -PI/3, PI/3) # Limit to 45 degrees up/down
		camera.rotation.x = current_tilt

func update_interaction_ray():
	# Ray always points forward from camera
	interaction_ray.target_position = Vector3(0, 0, -detection_distance)

func check_resource_in_sight():
	resource_in_sight = false
	
	# First check with raycast
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("resource") and current_cargo < max_cargo_capacity:
			resource_in_sight = true
			return
	
	# If raycast didn't find a resource, try the direct method
	var forward = -camera.global_transform.basis.z.normalized()
	var resources = get_tree().get_nodes_in_group("resource")
	
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
				resource_in_sight = true
				return

func update_crosshair():
	if !crosshair:
		return
	
	if resource_in_sight and current_cargo < max_cargo_capacity:
		# Change crosshair to yellow and brighter when pointing at a collectable resource
		crosshair.modulate = Color(1.0, 1.0, 0.0, 1.0)  # Bright yellow
	else:
		# Keep crosshair white for anything else (including ground)
		crosshair.modulate = Color(1.0, 1.0, 1.0, 1.0)  # White

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
	
	# Check for resource interaction
	if Input.is_action_just_pressed("interact"):
		print("Interaction button pressed")
		check_for_resource()
	
	# Check for docking
	if Input.is_action_just_pressed("dock") and is_near_base():
		print("Docking initiated")
		current_state = DroneState.DOCKING

func process_collecting(_delta):
	# Resource collection animation/process
	velocity = Vector3.ZERO
	
	# Collection would have an animation and timing
	# For demo purposes, we'll use a timer
	await get_tree().create_timer(1.5).timeout
	
	# Return to driving state
	current_state = DroneState.DRIVING
	print("Collection complete, returning to driving mode")

func process_docking(_delta):
	# Docking logic - move toward docking point
	velocity = Vector3.ZERO
	print("Docking sequence in progress")
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	
	# Release mouse when returning to base
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	complete_docking()

func check_for_resource():
	# First, try the raycast approach
	if try_raycast_detection():
		return
	
	# If raycast fails, try alternative approach - direct detection
	try_direct_detection()

func try_raycast_detection():
	# Use raycast to detect resources
	print("Attempting raycast detection...")
	
	# Debug ray position and direction
	print("Ray origin: " + str(interaction_ray.global_position))
	print("Ray target: " + str(interaction_ray.global_position + interaction_ray.target_position))
	
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		var collider_class = collider.get_class()
		var collision_layer = collider.collision_layer
		var is_resource = collider.is_in_group("resource")
		
		print("Ray hit: " + str(collider.name) + " of type " + str(collider_class) + 
			", collision layer: " + str(collision_layer) + 
			", is in resource group: " + str(is_resource))
		
		if is_resource and current_cargo < max_cargo_capacity:
			print("Resource detected via raycast: ", collider.resource_type)
			collect_resource(collider)
			return true
		else:
			if is_resource:
				print("Hit a resource but cargo is full!")
				return true
			else:
				print("Hit object is not a resource: " + str(collider.name))
	else:
		print("Interaction ray did not hit anything")
	
	return false

func try_direct_detection():
	print("Attempting direct detection...")
	
	# Get camera forward direction
	var forward = -camera.global_transform.basis.z.normalized()
	
	# Check all nodes in the scene for resources
	var closest_resource = null
	var closest_distance = detection_distance
	
	# Get all resources in the scene
	var resources = get_tree().get_nodes_in_group("resource")
	print("Found " + str(resources.size()) + " resources in the scene")
	
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
				print("Found resource " + resource.name + " at distance " + str(distance_along_ray) + 
					", perpendicular distance " + str(perpendicular_distance))
				
				# Check if this is the closest resource so far
				if distance_along_ray < closest_distance:
					closest_resource = resource
					closest_distance = distance_along_ray
	
	# Collect the closest resource if found
	if closest_resource and current_cargo < max_cargo_capacity:
		print("Resource detected via direct detection: ", closest_resource.resource_type)
		collect_resource(closest_resource)
		return true
	
	print("No resources detected via direct detection")
	return false

func collect_resource(resource_node):
	# Check if there's space in cargo
	if current_cargo >= max_cargo_capacity:
		print("Cargo full!")
		return
	
	# Start collection process
	current_state = DroneState.COLLECTING
	
	# Get resource information
	var resource_type = resource_node.resource_type
	var resource_amount = resource_node.resource_amount
	
	# Add to cargo inventory
	if resource_type in collected_resources:
		collected_resources[resource_type] += resource_amount
	else:
		collected_resources[resource_type] = resource_amount
	
	current_cargo += resource_amount
	
	# Update UI
	update_cargo_display()
	
	# Remove resource from world
	resource_node.collect()
	
	print("Collected " + str(resource_amount) + " " + resource_type)

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
