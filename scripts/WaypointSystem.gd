extends Node3D

# Manages waypoints for navigation between the aerial and ground drones

# Reference to waypoint marker scene
@export var waypoint_marker_scene = preload("res://scenes/WaypointMarker.tscn")

# Waypoint tracking
var active_waypoints = []
var waypoint_nodes = []

func _ready():
	# Initialize empty waypoint list
	clear_waypoints()

# Add a new waypoint at the specified position
func add_waypoint(position: Vector3, resource_type: String = ""):
	# Add to waypoint list
	active_waypoints.append(position)
	
	# Create visual marker
	var marker = waypoint_marker_scene.instantiate()
	add_child(marker)
	marker.global_position = position
	marker.resource_type = resource_type
	
	# Adjust name for clarity
	marker.name = "Waypoint_" + str(waypoint_nodes.size())
	
	# Store reference
	waypoint_nodes.append(marker)
	
	print("Waypoint added at: " + str(position))
	
	return waypoint_nodes.size() - 1  # Return index of new waypoint

# Remove a specific waypoint
func remove_waypoint(index: int):
	if index >= 0 and index < waypoint_nodes.size():
		if is_instance_valid(waypoint_nodes[index]):
			waypoint_nodes[index].queue_free()
		
		waypoint_nodes.remove_at(index)
		active_waypoints.remove_at(index)

# Clear all waypoints
func clear_waypoints():
	# Remove all waypoint markers
	for marker in waypoint_nodes:
		if is_instance_valid(marker):
			marker.queue_free()
	
	# Clear arrays
	waypoint_nodes.clear()
	active_waypoints.clear()
	
	print("All waypoints cleared")

# Get the closest waypoint to a position
func get_closest_waypoint(position: Vector3) -> int:
	var closest_index = -1
	var closest_distance = INF
	
	for i in range(active_waypoints.size()):
		var distance = position.distance_to(active_waypoints[i])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	return closest_index

# Get all waypoint positions
func get_all_waypoints() -> Array:
	return active_waypoints.duplicate()

# Get count of active waypoints
func get_waypoint_count() -> int:
	return active_waypoints.size()
