extends Control

signal resume_game
signal quit_game

@onready var resume_button = $ResumeButton
@onready var quit_button = $QuitButton

func _ready():
	# Connect button signals
	resume_button.connect("pressed", Callable(self, "_on_resume_button_pressed"))
	quit_button.connect("pressed", Callable(self, "_on_quit_button_pressed"))
	
	# Hide menu initially
	visible = false

func _on_resume_button_pressed():
	emit_signal("resume_game")

func _on_quit_button_pressed():
	emit_signal("quit_game")
