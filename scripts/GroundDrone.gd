extends CharacterBody3D

# Ground Drone Properties
@export var max_speed: float = 7.0
@export var acceleration: float = 3.0
@export var deceleration: float = 5.0
@export var rotation_speed: float = 1.5
@export var gravity: float = 20.0

# Resource Collection
@export var max_cargo_capacity: int = 5
var current_cargo: int = 0
var collected_resources = {}  # Dictionary to track resource types and quantities

# State Management
enum DroneState {IDLE, DRIVING, COLLECTING, DOCKING}
var current_state: DroneState = DroneState.IDLE

# References
@onready var camera = $Camera3D
@onready var cargo_indicator = $CanvasLayer/CargoIndicator
@onready var interaction_ray = $Camera3D/InteractionRay

# Navigation
var target_waypoint = null
var waypoints = []  # Will be populated from aerial drone's marked locations

func _ready():
	# Initialize UI
	update_cargo_display()

func _physics_process(delta):
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

func process_idle(_delta):
	# Handle transition to driving
	if Input.is_action_just_pressed("deploy_drone"):
		current_state = DroneState.DRIVING

func process_driving(delta):
	# Get movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Rotation based on input direction
	if input_dir != Vector2.ZERO:
		var target_rotation = Vector3(0, atan2(-input_dir.x, -input_dir.y), 0)
		rotation.y = lerp_angle(rotation.y, target_rotation.y, rotation_speed * delta)
	
	# Forward/backward movement based on input
	var direction = (transform.basis.z * -input_dir.y + transform.basis.x * -input_dir.x).normalized()
	if direction:
		velocity.x = direction.x * max_speed
		velocity.z = direction.z * max_speed
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
	
	# Check for resource interaction
	if Input.is_action_just_pressed("interact"):
		check_for_resource()
	
	# Check for docking
	if Input.is_action_just_pressed("dock") and is_near_base():
		current_state = DroneState.DOCKING

func process_collecting(_delta):
	# Resource collection animation/process
	velocity = Vector3.ZERO
	
	# Collection would have an animation and timing
	# For demo purposes, we'll use a timer
	await get_tree().create_timer(1.5).timeout
	
	# Return to driving state
	current_state = DroneState.DRIVING

func process_docking(_delta):
	# Docking logic - move toward docking point
	velocity = Vector3.ZERO
	print("Docking sequence")
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	complete_docking()

func check_for_resource():
	# Use raycast to detect resources
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("resource") and current_cargo < max_cargo_capacity:
			collect_resource(collider)

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
	# For now, we'll just return true when a key is pressed
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
