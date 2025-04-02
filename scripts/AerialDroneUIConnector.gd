extends Node

# This helper script connects the instantiated aerial drone to UI elements

var aerial_drone = null

func connect_drone(drone):
	# Store reference
	aerial_drone = drone
	
	# Connect drone's battery indicator to the UI
	var battery_indicator = drone.get_node("CanvasLayer/BatteryIndicator")
	
	# Set any specific UI properties
	if battery_indicator:
		battery_indicator.custom_minimum_size = Vector2(300, 25)
		
	print("Aerial drone UI connected")
	
func disconnect_drone():
	aerial_drone = null
	print("Aerial drone UI disconnected")
