extends StaticBody3D

# Resource Properties
@export_enum("ScrapMetal", "PowerCell", "ElectronicParts", "RareMetal") var resource_type: String = "ScrapMetal"
@export var resource_amount: int = 1
@export var scan_visible: bool = true  # Can be detected by aerial drone scanner

# Collection progress (persistent between collection attempts)
var collection_progress: float = 0.0
var was_targeted: bool = false

# Visual components
@onready var mesh = $Mesh
@onready var collision_shape = $CollisionShape3D
@onready var scan_highlight = $ScanHighlight
@onready var collection_particles = $CollectionParticles

func _ready():
	# Add to resource group for easy detection
	add_to_group("resource")
	
	# Set the collision layer explicitly
	set_collision_layer_value(1, false) # Disable layer 1
	set_collision_layer_value(2, true)  # Enable layer 2 for resources
	
	# Initialize visual components
	scan_highlight.visible = false
	
	# Set different appearance based on resource type
	set_material_by_type()
	
	print("Resource initialized: " + resource_type + " x" + str(resource_amount))

# When detected by aerial drone scanner
func highlight_as_scanned():
	scan_highlight.visible = true
	print(resource_type + " detected")

# Note: we're not using these functions anymore since they affect scan_highlight
# which should only be modified by the aerial drone
func highlight_as_targeted():
	was_targeted = true
	# Don't change scan_highlight visibility

func unhighlight():
	was_targeted = false
	# Don't change scan_highlight visibility

# Remove one unit of resource
func deplete_one_unit():
	resource_amount -= 1
	print("Resource depleted by one unit, " + str(resource_amount) + " remaining")
	
	# If no resources left, prepare for removal
	if resource_amount <= 0:
		collect()
		return true
	return false

# When completely depleted
func collect():
	print("Resource completely depleted: " + resource_type)
	
	# Play collection effect
	collection_particles.emitting = true
	
	# Make resource mesh invisible but keep particles
	mesh.visible = false
	collision_shape.disabled = true
	scan_highlight.visible = false
	
	# Wait for particles to finish
	await get_tree().create_timer(1.5).timeout
	
	print("Resource being removed from scene")
	
	# Remove from game
	queue_free()

# Set appearance based on resource type
func set_material_by_type():
	var material = StandardMaterial3D.new()
	
	match resource_type:
		"ScrapMetal":
			material.albedo_color = Color(0.7, 0.7, 0.7)
			material.metallic = 0.7
			material.roughness = 0.3
		"PowerCell":
			material.albedo_color = Color(0.2, 0.4, 0.8)
			material.emission_enabled = true
			material.emission = Color(0.2, 0.4, 0.8)
			material.emission_energy = 1.5
		"ElectronicParts":
			material.albedo_color = Color(0.2, 0.6, 0.3)
			material.metallic = 0.5
			material.roughness = 0.4
		"RareMetal":
			material.albedo_color = Color(0.9, 0.8, 0.2)
			material.metallic = 0.9
			material.roughness = 0.1
	
	$Mesh.material_override = material
