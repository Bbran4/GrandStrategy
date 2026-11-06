extends Control
func _ready() -> void:
	%CountryCreator.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/country_creator.tscn"))
	%MapEditor.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map_editor.tscn"))
