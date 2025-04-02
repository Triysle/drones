extends Control

# Simple 2D top-down minimap display

# Map settings
@export var map_scale: float = 0.1  # 1 world unit = X pixels on minimap
@export var map_size: Vector2 = Vector2(200, 200)
@export var border_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.8)

# Icons and markers
@export var base_color: Color = Color(0, 0.5, 1, 1)
@export var drone_color: Color = Color(0, 1, 0, 1)
@export var waypoint_color: Color = Color(1, 1, 0, 1)
@export var resource_colors = {
	"ScrapMetal": Color(0.7, 0.7, 0.7, 1),
	"PowerCell": Color(0.2, 0.4, 0.8, 1),
	"ElectronicParts": Color(0.2, 0.6, 0.3, 1),
	"RareMetal": Color(0.9, 0.8, 0.2, 1)
}

# Object references
var base_station = null
var active_drone = null

func _ready():
	# Set control minimum size
	custom_minimum_size = map_size
	
	# Find base station reference
	base_station = get_node("/root/Main/BaseStation")
	
	# Minimap starts visible in base mode
	visible = true

func _process(_delta):
	# Request redraw every frame to update positions
	queue_redraw()
	
	# Get current active drone reference from base
	if base_station:
		active_drone = base_station.get_active_drone()

func _draw():
	# Draw background and border
	draw_rect(Rect2(Vector2.ZERO, map_size), background_color, true)
	draw_rect(Rect2(Vector2.ZERO, map_size), border_color, false, 2.0)
	
	# Center point for the map (base station at center)
	var center = map_size / 2
	
	# Draw base station
	if base_station:
		draw_circle(center, 6, base_color)
	
	# Draw resources
	draw_resources(center)
	
	# Draw waypoints
	draw_waypoints(center)
	
	# Draw active drone
	if active_drone:
		var drone_pos = world_to_map(active_drone.global_position, center)
		draw_circle(drone_pos, 4, drone_color)
		
		# Show drone direction
		var forward = active_drone.transform.basis.z.normalized()
		var direction_point = drone_pos + Vector2(-forward.x, -forward.z) * 10
		draw_line(drone_pos, direction_point, drone_color, 2.0)

# Draw all resources on the minimap
func draw_resources(center: Vector2):
	var resources = get_tree().get_nodes_in_group("resource")
	
	for resource in resources:
		var map_pos = world_to_map(resource.global_position, center)
		
		# Get color based on resource type
		var color = resource_colors.get(resource.resource_type, Color.WHITE)
		
		# Draw a small square for the resource
		var rect_size = Vector2(3, 3)
		draw_rect(Rect2(map_pos - rect_size/2, rect_size), color, true)

# Draw all waypoints on the minimap
func draw_waypoints(center: Vector2):
	var waypoint_system = get_node("/root/Main/Waypoints")
	if waypoint_system:
		var waypoints = waypoint_system.get_all_waypoints()
		
		for point in waypoints:
			var map_pos = world_to_map(point, center)
			
			# Draw a small triangle for the waypoint
			var triangle_size = 4
			var p1 = map_pos + Vector2(0, -triangle_size)
			var p2 = map_pos + Vector2(triangle_size, triangle_size)
			var p3 = map_pos + Vector2(-triangle_size, triangle_size)
			
			var points = PackedVector2Array([p1, p2, p3])
			draw_colored_polygon(points, waypoint_color)

# Convert world position to minimap position
func world_to_map(world_pos: Vector3, center: Vector2) -> Vector2:
	# Base station at origin, Z forward, X right
	var base_pos = Vector3.ZERO
	if base_station:
		base_pos = base_station.global_position
	
	# Calculate relative position and scale
	var relative_x = (world_pos.x - base_pos.x) * map_scale
	var relative_z = (world_pos.z - base_pos.z) * map_scale
	
	# Return the map position (Z axis is forward in 3D, so mapped to -Y in 2D)
	return center + Vector2(relative_x, -relative_z)
