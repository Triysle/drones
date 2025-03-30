extends CharacterBody3D

# Aerial Drone Properties
@export var max_speed: float = 10.0
@export var acceleration: float = 5.0
@export var deceleration: float = 8.0
@export var rotation_speed: float = 2.0
@export var vertical_speed: float = 5.0
@export var max_altitude: float = 50.0
@export var min_altitude: float = 1.5

# Battery System
@export var max_battery: float = 100.0
@export var battery_drain_rate: float = 2.0  # Points per second
@export var low_battery_threshold: float = 25.0
var current_battery: float = max_battery
var is_battery_depleted: bool = false

# Scanning & Marking
@export var scan_range: float = 20.0
@export var scan_energy_cost: float = 5.0
var marked_locations = []
var is_scanning: bool = false

# State Management
enum DroneState {IDLE, FLYING, SCANNING, DOCKING, DEPLETED}
var current_state: DroneState = DroneState.IDLE

# Camera and visuals
@onready var camera = $Camera3D
@onready var scan_effect = $ScanEffect
@onready var battery_indicator = $UI/BatteryIndicator

# Movement variables
var input_dir: Vector2 = Vector2.ZERO
var velocity_target: Vector3 = Vector3.ZERO

func _ready():
	# Initialize
	scan_effect.visible = false
	update_battery_display()

func _physics_process(delta):
	match current_state:
		DroneState.IDLE:
			process_idle(delta)
		DroneState.FLYING:
			process_flying(delta)
		DroneState.SCANNING:
			process_scanning(delta)
		DroneState.DOCKING:
			process_docking(delta)
		DroneState.DEPLETED:
			process_depleted(delta)
	
	# Apply movement if not depleted
	if current_state != DroneState.DEPLETED:
		move_and_slide()

func process_idle(delta):
	# Handle transition to flying
	if Input.is_action_just_pressed("deploy_drone"):
		current_state = DroneState.FLYING

func process_flying(delta):
	# Apply battery drain
	drain_battery(delta)
	
	# Process movement input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Rotation based on input direction
	if input_dir != Vector2.ZERO:
		var target_rotation = Vector3(0, atan2(-input_dir.x, -input_dir.y), 0)
		rotation.y = lerp_angle(rotation.y, target_rotation.y, rotation_speed * delta)
	
	# Forward/backward movement based on input
	var direction = (transform.basis.z * -input_dir.y + transform.basis.x * -input_dir.x).normalized()
	if direction:
		velocity_target.x = direction.x * max_speed
		velocity_target.z = direction.z * max_speed
	else:
		velocity_target.x = move_toward(velocity_target.x, 0, deceleration * delta)
		velocity_target.z = move_toward(velocity_target.z, 0, deceleration * delta)
	
	# Vertical movement
	if Input.is_action_pressed("ascend") and global_position.y < max_altitude:
		velocity_target.y = vertical_speed
	elif Input.is_action_pressed("descend") and global_position.y > min_altitude:
		velocity_target.y = -vertical_speed
	else:
		velocity_target.y = move_toward(velocity_target.y, 0, deceleration * delta)
	
	# Apply smoothing to movement
	velocity.x = lerp(velocity.x, velocity_target.x, acceleration * delta)
	velocity.z = lerp(velocity.z, velocity_target.z, acceleration * delta)
	velocity.y = lerp(velocity.y, velocity_target.y, acceleration * delta)
	
	# Handle scanning
	if Input.is_action_just_pressed("scan") and current_battery > scan_energy_cost:
		begin_scan()
	
	# Check for docking zone
	check_docking_zone()

func process_scanning(delta):
	# Continue draining battery
	drain_battery(delta)
	
	# Apply a small hover movement
	velocity = Vector3.ZERO
	
	# Scanning animation/effect logic
	if !is_scanning:
		is_scanning = true
		scan_effect.visible = true
		# Start scan animation
		await get_tree().create_timer(1.5).timeout
		
		# Perform the actual scan
		perform_scan()
		
		# End scanning state
		scan_effect.visible = false
		is_scanning = false
		current_state = DroneState.FLYING

func process_docking(delta):
	# Docking logic - move toward docking point
	# This would be expanded with actual path following to dock
	velocity = Vector3.ZERO
	print("Docking sequence")
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	complete_docking()

func process_depleted(delta):
	# Drone slowly descends when battery depleted
	velocity.x = 0
	velocity.z = 0
	velocity.y = -2.0  # Slow descent
	
	# Could add visual effects for emergency landing

func drain_battery(delta):
	# Reduce battery over time
	current_battery -= battery_drain_rate * delta
	update_battery_display()
	
	# Check for low/depleted battery
	if current_battery <= 0 and !is_battery_depleted:
		current_battery = 0
		is_battery_depleted = true
		current_state = DroneState.DEPLETED
	elif current_battery <= low_battery_threshold:
		# Visual/audio warning could be triggered here
		pass

func update_battery_display():
	# Update UI battery indicator
	battery_indicator.value = current_battery

func begin_scan():
	current_state = DroneState.SCANNING
	current_battery -= scan_energy_cost

func perform_scan():
	# Detect resources and points of interest in range
	var scan_results = get_scannable_objects_in_range()
	
	for object in scan_results:
		if object.is_in_group("resource"):
			mark_location(object.global_position)

func get_scannable_objects_in_range():
	# This would use physics overlaps or raycasts in practice
	# For now we'll return a dummy array
	var dummy_results = []
	
	# In a real implementation, you'd do something like:
	# var space_state = get_world_3d().direct_space_state
	# var query = PhysicsShapeQueryParameters3D.new()
	# query.set_transform(Transform3D(Basis(), global_position))
	# query.set_shape(scan_shape)
	# dummy_results = space_state.intersect_shape(query)
	
	print("Scanning for objects...")
	return dummy_results

func mark_location(position):
	# Add to marked locations
	marked_locations.append(position)
	
	# In practice, you'd also create a visual marker in the world
	# and add it to the minimap
	print("Marked location at: ", position)

func check_docking_zone():
	# Check if the drone is in docking zone
	# This would use area detection in practice
	if Input.is_action_just_pressed("dock") and is_near_base():
		current_state = DroneState.DOCKING

func is_near_base():
	# This would check distance to base in practice
	# For now, we'll just return true when a key is pressed
	return true

func complete_docking():
	# Recharge battery
	current_battery = max_battery
	is_battery_depleted = false
	update_battery_display()
	
	# Reset state
	current_state = DroneState.IDLE
	
	# Signal to game controller that docking is complete
	# This would switch to ground drone in the full game
	print("Docking complete, battery recharged")
	emit_signal("docking_completed")

# Signal for docking completion
signal docking_completed
