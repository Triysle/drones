extends Node3D

# Waypoint marker for resource locations

# Visual properties
@export var marker_color: Color = Color(0, 1, 1, 0.7) # Cyan with transparency
@export var pulse_speed: float = 1.0
@export var hover_height: float = 1.5

# Marker state
var resource_type: String = ""
var original_position: Vector3
var pulse_time: float = 0.0

func _ready():
	# Setup marker visual
	create_marker_visual()
	
	# Store original position
	original_position = global_position
	
	# Adjust height above ground
	global_position.y = original_position.y + hover_height

func _process(delta):
	# Make the marker pulse
	pulse_time += delta * pulse_speed
	
	# Modulate scale for pulsing effect
	var pulse_scale = 1.0 + 0.2 * sin(pulse_time * 3.0)
	scale = Vector3(pulse_scale, pulse_scale, pulse_scale)
	
	# Slight hover up and down
	var hover_offset = 0.2 * sin(pulse_time * 1.5)
	global_position.y = original_position.y + hover_height + hover_offset

func create_marker_visual():
	# Create a simple visual for the waypoint
	var cylinder = CSGCylinder3D.new()
	cylinder.radius = 0.5
	cylinder.height = 0.1
	add_child(cylinder)
	
	# Create material with emission
	var material = StandardMaterial3D.new()
	material.albedo_color = marker_color
	material.emission_enabled = true
	material.emission = marker_color
	material.emission_energy = 1.5
	cylinder.material = material
	
	# Add a vertical beam
	var beam = CSGCylinder3D.new()
	beam.radius = 0.05
	beam.height = hover_height * 2
	beam.position.y = -hover_height
	add_child(beam)
	
	# Set beam material
	var beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = marker_color
	beam_material.emission_enabled = true
	beam_material.emission = marker_color
	beam_material.emission_energy = 1.0
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material = beam_material
