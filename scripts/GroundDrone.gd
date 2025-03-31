extends CharacterBody3D

# Ground Drone Properties
@export var max_speed: float = 7.0
@export var acceleration: float = 4.0
@export var deceleration: float = 7.0
@export var rotation_speed: float = 1.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var traction: float = 0.6

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

func _ready():
	# Initialize UI
	update_cargo_display()
	
	# Start directly in driving mode
	current_state = DroneState.DRIVING
	
	# Make sure the interaction ray is enabled and set to the right collision mask
	interaction_ray.enabled = true
	interaction_ray.collision_mask = 3  # Layer 1 (ground) and Layer 2 (resources)
	
	# Initialize crosshair
	if !crosshair:
		print("ERROR: Crosshair not found. Add Crosshair to CanvasLayer.")
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Ground drone deployed - mouse captured for camera control")
	print("Interaction ray enabled: " + str(interaction_ray.enabled) + 
		", collision mask: " + str(interaction_ray.collision_mask) + 
		", target position: " + str(interaction_ray.target_position))

func _physics_process(delta):
	# Update raycast based on camera direction
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
	
	# Update crosshair based on what the ray is hitting
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
	interaction_ray.target_position = Vector3(0, 0, -5)  # 5 units forward

func update_crosshair():
	if !crosshair:
		return
		
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("resource") and current_cargo < max_cargo_capacity:
			# Change crosshair to green when pointing at a collectable resource
			crosshair.modulate = Color(0, 1, 0)  # Green
		else:
			# Change crosshair to yellow when pointing at a non-resource
			crosshair.modulate = Color(1, 1, 0)  # Yellow
	else:
		# Default crosshair color when not pointing at anything
		crosshair.modulate = Color(1, 1, 1)  # White

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
	# Use raycast to detect resources
	print("Checking for resources with interaction ray")
	
	# Debug ray position and direction
	print("Ray origin: " + str(interaction_ray.global_position))
	print("Ray target: " + str(interaction_ray.global_position + interaction_ray.target_position))
	
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		print("Ray hit: " + str(collider.name) + " of type " + str(collider.get_class()) + 
			", collision layer: " + str(collider.collision_layer))
		
		if collider.is_in_group("resource") and current_cargo < max_cargo_capacity:
			print("Resource detected: ", collider.resource_type)
			collect_resource(collider)
		else:
			if collider.is_in_group("resource"):
				print("Hit a resource but cargo is full!")
			else:
				print("Hit object is not a resource: " + str(collider.name))
	else:
		print("Interaction ray did not hit anything")

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
