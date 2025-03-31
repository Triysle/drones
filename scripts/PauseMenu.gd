extends Control

signal resume_game
signal quit_game

# UI elements
@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var quit_button = $Panel/VBoxContainer/QuitButton

func _ready():
	# Ensure we're set up correctly
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	
	# Connect the button signals
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	print("Pause menu initialized")

# Signal handlers
func _on_resume_pressed():
	print("Resume button pressed")
	emit_signal("resume_game")

func _on_quit_pressed():
	print("Quit button pressed")
	emit_signal("quit_game")

# Show/hide methods for cleaner code
func show_menu():
	visible = true
	print("Pause menu shown")

func hide_menu():
	visible = false
	print("Pause menu hidden")
