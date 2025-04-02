extends Control

# Resource display labels
@onready var scrap_metal_label = $ResourceCounts/VBoxContainer/ScrapMetalCount
@onready var power_cell_label = $ResourceCounts/VBoxContainer/PowerCellCount
@onready var electronic_parts_label = $ResourceCounts/VBoxContainer/ElectronicPartsCount
@onready var rare_metal_label = $ResourceCounts/VBoxContainer/RareMetalCount

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
			scrap_metal_label.text = "Scrap Metal: " + str(amount)
		"PowerCell":
			power_cell_label.text = "Power Cell: " + str(amount)
		"ElectronicParts":
			electronic_parts_label.text = "Electronic Parts: " + str(amount)
		"RareMetal":
			rare_metal_label.text = "Rare Metal: " + str(amount)

# Update all resources at once
func update_all(resources):
	for resource_type in resources:
		update_resource(resource_type, resources[resource_type])
