extends StaticBody3D

# Resource Properties
@export_enum("ScrapMetal", "PowerCell", "ElectronicParts", "RareMetal") var resource_type: String = "ScrapMetal"
@export var resource_amount: int = 1
@export var scan_visible: bool = true  # Can be detected by aerial drone scanner

# Visual components
@onready var mesh = $Mesh
@onready var collision_shape = $CollisionShape3D
@onready var scan_highlight = $ScanHighlight
@onready var collection_particles = $CollectionParticles

func _ready():
	# Add to resource group for easy detection
	add_to_group("resource")
	
	# IMPORTANT: Set the collision layer explicitly (this is key)
	set_collision_layer_value(1, false) # Disable layer 1
	set_collision_layer_value(2, true)  # Enable layer 2 for resources
	
	# Verify collision layer is set correctly
	print("Resource " + name + " collision layer: " + str(collision_layer) + 
		", in group 'resource': " + str(is_in_group("resource")))
	
	# Initialize visual components
	scan_highlight.visible = false
	
	# Set different appearance based on resource type
	match resource_type:
		"ScrapMetal":
			# Light gray/silver color
			$Mesh.material_override = get_material_for_type("ScrapMetal")
		"PowerCell":
			# Glowing blue color
			$Mesh.material_override = get_material_for_type("PowerCell")
		"ElectronicParts":
			# Circuit board green
			$Mesh.material_override = get_material_for_type("ElectronicParts")
		"RareMetal":
			# Shiny gold color
			$Mesh.material_override = get_material_for_type("RareMetal")

# When detected by aerial drone scanner
func highlight_as_scanned():
	scan_highlight.visible = true
	print(resource_type + " detected")

# When collected by ground drone
func collect():
	print("Resource collection started for: " + resource_type)
	
	# Play collection effect
	collection_particles.emitting = true
	
	# Make resource mesh invisible but keep particles
	mesh.visible = false
	collision_shape.disabled = true
	scan_highlight.visible = false
	
	print("Resource visuals hidden, waiting for particles...")
	
	# Wait for particles to finish
	await get_tree().create_timer(1.5).timeout
	
	print("Resource being removed from scene")
	
	# Remove from game
	queue_free()

# Helper function to get material based on type
func get_material_for_type(type):
	var material = StandardMaterial3D.new()
	
	match type:
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
	
	return material
