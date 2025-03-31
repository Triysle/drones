extends CharacterBody3D

# Aerial Drone Properties
@export var max_speed: float = 10.0
@export var acceleration: float = 5.0
@export var deceleration: float = 8.0
@export var rotation_speed: float = 2.0
@export var vertical_speed: float = 5.0
@export var max_altitude: float = 50.0
@export var min_altitude: float = 1.5
@export var mouse_sensitivity: float = 0.002

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
var current_state: DroneState = DroneState.FLYING

# Camera and visuals
@onready var camera = $Camera3D
@onready var scan_effect = $ScanEffect
@onready var battery_indicator = $CanvasLayer/BatteryIndicator

# Movement variables
var input_dir: Vector2 = Vector2.ZERO
var vertical_input: float = 0.0

func _ready():
	# Initialize
	$ScanEffect.connect("body_entered", Callable(self, "_on_scan_effect_body_entered"))
	scan_effect.visible = false
	update_battery_display()
	
	# Start directly in flying mode
	current_state = DroneState.FLYING
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Aerial drone deployed - mouse captured for camera control")

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

func _input(event):
	# Mouse look when flying
	if current_state == DroneState.FLYING and event is InputEventMouseMotion:
		# Rotate camera based on mouse movement
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Limit vertical camera rotation
		var current_tilt = camera.rotation.x
		current_tilt -= event.relative.y * mouse_sensitivity
		current_tilt = clamp(current_tilt, -PI/2, PI/5) # Limit to 45 degrees up/down
		camera.rotation.x = current_tilt

func process_idle(_delta):
	# Just a placeholder state - we start in FLYING now
	pass

func _on_scan_effect_body_entered(body):
	if body.is_in_group("resource") and body.scan_visible:
		print("Detected resource in scan zone: " + body.resource_type)
		body.highlight_as_scanned()

func process_flying(delta):
	# Apply battery drain
	drain_battery(delta)
	
	# Get input direction
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	
	# Get vertical input
	vertical_input = Input.get_axis("descend", "ascend")
	
	# Calculate movement direction (relative to drone orientation)
	var direction = Vector3.ZERO
	direction += transform.basis.z * input_dir.y  # Forward/back (flipped Z axis)
	direction += transform.basis.x * input_dir.x   # Left/right
	direction = direction.normalized()
	
	# Apply horizontal movement
	if direction != Vector3.ZERO:
		velocity.x = direction.x * max_speed
		velocity.z = direction.z * max_speed
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
	
	# Apply vertical movement
	if vertical_input != 0:
		# Check altitude limits
		if (vertical_input > 0 and global_position.y < max_altitude) or \
		   (vertical_input < 0 and global_position.y > min_altitude):
			velocity.y = vertical_input * vertical_speed
		else:
			velocity.y = move_toward(velocity.y, 0, deceleration * delta)
	else:
		velocity.y = move_toward(velocity.y, 0, deceleration * delta)
	
	# Handle scanning
	if Input.is_action_just_pressed("scan") and current_battery > scan_energy_cost:
		print("Scan initiated")
		begin_scan()
	
	# Check for docking - now on a different key
	if Input.is_action_just_pressed("dock") and is_near_base():
		print("Docking initiated")
		current_state = DroneState.DOCKING

func process_scanning(delta):
	# Continue draining battery
	drain_battery(delta)
	
	# Apply a small hover movement
	velocity = Vector3.ZERO
	
	# Scanning animation/effect logic
	if !is_scanning:
		is_scanning = true
		scan_effect.visible = true
		print("Scan in progress...")
		
		# Start scan animation
		await get_tree().create_timer(1.5).timeout
		
		# Perform the actual scan
		perform_scan()
		
		# End scanning state
		scan_effect.visible = false
		is_scanning = false
		current_state = DroneState.FLYING
		print("Scan complete, returning to flight mode")

func process_docking(delta):
	# Docking logic - move toward docking point
	velocity = Vector3.ZERO
	print("Docking sequence in progress")
	
	# Simulate docking completion
	await get_tree().create_timer(2.0).timeout
	
	# Release mouse when returning to base
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	complete_docking()

func process_depleted(delta):
	# Drone slowly descends when battery depleted
	velocity.x = 0
	velocity.z = 0
	velocity.y = -2.0  # Slow descent
	print("Battery depleted - emergency landing")

func drain_battery(delta):
	# Reduce battery over time
	current_battery -= battery_drain_rate * delta
	update_battery_display()
	
	# Check for low/depleted battery
	if current_battery <= 0 and !is_battery_depleted:
		current_battery = 0
		is_battery_depleted = true
		current_state = DroneState.DEPLETED
		print("Battery fully depleted!")
	elif current_battery <= low_battery_threshold:
		# Only print warning occasionally to reduce spam
		if int(current_battery) % 5 == 0 and fmod(current_battery, 1.0) < delta * battery_drain_rate:
			print("Low battery warning: ", int(current_battery))

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
	var scannable_objects = []
	
	# Use Area3D's overlapping bodies
	for body in $ScanEffect.get_overlapping_bodies():
		if body.is_in_group("resource"):
			scannable_objects.append(body)
			body.highlight_as_scanned()
	
	print("Found " + str(scannable_objects.size()) + " scannable objects")
	return scannable_objects

func mark_location(pos):
	# Add to marked locations
	marked_locations.append(pos)
	
	# In practice, you'd also create a visual marker in the world
	# and add it to the minimap
	print("Marked location at: ", pos)

func is_near_base():
	# This would check distance to base in practice
	# For now, we'll just return true when the dock key is pressed
	return true

func complete_docking():
	# Recharge battery
	current_battery = max_battery
	is_battery_depleted = false
	update_battery_display()
	
	# Reset state
	current_state = DroneState.IDLE
	
	# Signal to game controller that docking is complete
	print("Docking complete, battery recharged")
	emit_signal("docking_completed")

# Signal for docking completion
signal docking_completed
