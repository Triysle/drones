extends Control

signal resume_game
signal quit_game

@onready var resume_button = $ResumeButton
@onready var quit_button = $QuitButton

func _ready():
	# Connect button signals directly using connect() method
	resume_button.pressed.connect(_on_resume_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Hide menu initially
	visible = false
	
	print("Pause menu initialized - buttons connected")

func _on_resume_button_pressed():
	print("Resume button pressed")
	emit_signal("resume_game")

func _on_quit_button_pressed():
	print("Quit button pressed")
	emit_signal("quit_game")
