extends Control

# Resource display labels
@onready var scrap_metal_label = $ResourceCounts/ScrapMetalCount
@onready var power_cell_label = $ResourceCounts/PowerCellCount
@onready var electronic_parts_label = $ResourceCounts/ElectronicPartsCount
@onready var rare_metal_label = $ResourceCounts/RareMetalCount

func _ready():
	# Initialize with zeros
	update_resource("ScrapMetal", 0)
	update_resource("PowerCell", 0)
	update_resource("ElectronicParts", 0)
	update_resource("RareMetal", 0)

# Update a specific resource count
func update_resource(resource_type, amount):
	match resource_type:
		"ScrapMetal":
			scrap_metal_label.text = str(amount)
		"PowerCell":
			power_cell_label.text = str(amount)
		"ElectronicParts":
			electronic_parts_label.text = str(amount)
		"RareMetal":
			rare_metal_label.text = str(amount)

# Update all resources at once
func update_all(resources):
	for resource_type in resources:
		update_resource(resource_type, resources[resource_type])
