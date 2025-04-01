extends Control

# Cargo Slots UI - Displays the ground drone's cargo inventory as slots

# Display properties
@export var slot_size: Vector2 = Vector2(40, 40)
@export var slot_spacing: int = 5
@export var slots_per_row: int = 5

# References
var slot_container: HBoxContainer
var warning_label: Label
var cargo_full_animation: AnimationPlayer

# Resource textures - will load these from icons or create programmatically
var empty_slot_texture: Texture2D
var scrap_metal_texture: Texture2D
var power_cell_texture: Texture2D
var electronic_parts_texture: Texture2D
var rare_metal_texture: Texture2D

# Current slot data
var slots = []  # Will contain references to the slot TextureRect nodes
var cargo_data = []  # Will contain the resource type for each slot or "" if empty

func _ready():
	# Set up the warning label (initially hidden)
	warning_label = Label.new()
	warning_label.text = "CARGO FULL!"
	warning_label.add_theme_color_override("font_color", Color(1, 0, 0))  # Red text
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.visible = false
	add_child(warning_label)
	
	# Create animation player for the warning
	cargo_full_animation = AnimationPlayer.new()
	add_child(cargo_full_animation)
	create_warning_animation()
	
	# Create the slot container (horizontal box)
	slot_container = HBoxContainer.new()
	slot_container.add_theme_constant_override("separation", slot_spacing)
	add_child(slot_container)
	
	# Position the warning above the slots
	warning_label.position.y = -30
	
	# Set up textures (will replace with actual icons later)
	create_placeholder_textures()
	
	# Initialize UI with default 5 slots
	initialize_slots(5)

# Create placeholder colored textures for resources
func create_placeholder_textures():
	# Empty slot - dark gray
	empty_slot_texture = create_colored_texture(Color(0.2, 0.2, 0.2, 0.5))
	
	# Scrap Metal - light gray
	scrap_metal_texture = create_colored_texture(Color(0.7, 0.7, 0.7))
	
	# Power Cell - blue
	power_cell_texture = create_colored_texture(Color(0.2, 0.4, 0.8))
	
	# Electronic Parts - green
	electronic_parts_texture = create_colored_texture(Color(0.2, 0.6, 0.3))
	
	# Rare Metal - gold
	rare_metal_texture = create_colored_texture(Color(0.9, 0.8, 0.2))

# Helper to create colored textures
func create_colored_texture(color: Color) -> ImageTexture:
	var image = Image.create(int(slot_size.x), int(slot_size.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	# Add a border
	var border_color = Color(1, 1, 1, 0.8)  # White, slightly transparent
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			if x < 2 or x >= image.get_width() - 2 or y < 2 or y >= image.get_height() - 2:
				image.set_pixel(x, y, border_color)
	
	return ImageTexture.create_from_image(image)

# Initialize the UI with a specific number of slots
func initialize_slots(num_slots: int):
	# Clear existing slots if any
	for slot in slots:
		slot.queue_free()
	
	slots.clear()
	cargo_data.clear()
	
	# Calculate how many rows we need
	var rows = ceil(float(num_slots) / slots_per_row)
	
	# Create a VBoxContainer for multiple rows if needed
	var rows_container
	if slot_container.get_parent() == self:
		# First time setup
		rows_container = VBoxContainer.new()
		rows_container.add_theme_constant_override("separation", slot_spacing)
		remove_child(slot_container)
		add_child(rows_container)
	else:
		rows_container = slot_container.get_parent()
		rows_container.remove_child(slot_container)
		
	# Remove any existing rows
	for child in rows_container.get_children():
		child.queue_free()
	
	# Create new rows
	for row_idx in range(rows):
		var row_container = HBoxContainer.new()
		row_container.add_theme_constant_override("separation", slot_spacing)
		rows_container.add_child(row_container)
		
		# Calculate how many slots in this row
		var slots_in_row = min(slots_per_row, num_slots - row_idx * slots_per_row)
		
		# Add slots to this row
		for i in range(slots_in_row):
			var slot = TextureRect.new()
			slot.texture = empty_slot_texture
			slot.custom_minimum_size = slot_size
			slot.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			row_container.add_child(slot)
			slots.append(slot)
			cargo_data.append("")  # Empty slot
	
	print("Initialized cargo UI with " + str(num_slots) + " slots")

# Update slot display based on current cargo
func update_slots(cargo_items: Array):
	# cargo_items should be an array of resource types, one per slot
	# If a slot is empty, the corresponding entry should be ""
	
	for i in range(min(cargo_items.size(), slots.size())):
		cargo_data[i] = cargo_items[i]
		set_slot_texture(i, cargo_items[i])
	
	# Check if cargo is full and show/hide warning
	var is_full = !cargo_items.has("")
	set_cargo_full_warning(is_full)

# Set the appropriate texture for a slot based on content
func set_slot_texture(slot_index: int, resource_type: String):
	if slot_index >= slots.size():
		return
		
	var texture = empty_slot_texture
	
	match resource_type:
		"ScrapMetal":
			texture = scrap_metal_texture
		"PowerCell":
			texture = power_cell_texture
		"ElectronicParts":
			texture = electronic_parts_texture
		"RareMetal":
			texture = rare_metal_texture
		_:  # Empty or unknown
			texture = empty_slot_texture
	
	slots[slot_index].texture = texture

# Create and play the cargo full warning animation
func create_warning_animation():
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath("../warning_label:modulate"))
	
	# Create the pulsing effect - fade from full opacity to half and back
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))
	animation.track_insert_key(track_index, 0.5, Color(1, 1, 1, 0.5))
	animation.track_insert_key(track_index, 1.0, Color(1, 1, 1, 1))
	
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	
	var library = AnimationLibrary.new()
	library.add_animation("cargo_full_pulse", animation)
	cargo_full_animation.add_animation_library("", library)

# Show/hide the cargo full warning
func set_cargo_full_warning(is_full: bool):
	warning_label.visible = is_full
	
	if is_full && !cargo_full_animation.is_playing():
		cargo_full_animation.play("cargo_full_pulse")
	elif !is_full && cargo_full_animation.is_playing():
		cargo_full_animation.stop()

# Expand the cargo capacity (add new row of slots)
func expand_capacity(new_total_slots: int):
	initialize_slots(new_total_slots)
	
	# Update the cargo data array to match the new size
	while cargo_data.size() < new_total_slots:
		cargo_data.append("")
	
	print("Expanded cargo capacity to " + str(new_total_slots) + " slots")
