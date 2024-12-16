extends Node2D
class_name Level

@export var show_dev_ui: bool = true

var _dev_ui: PackedScene = preload("res://menus/run/dev_ui.tscn")


func _ready() -> void:
	if show_dev_ui:
		var dev_ui := _dev_ui.instantiate()
		add_child(dev_ui)
		move_child(dev_ui, 0) 
