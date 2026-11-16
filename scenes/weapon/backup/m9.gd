extends "res://scenes/weapon/weapon.gd"

func _ready() -> void:
	# Hide the detached magazine / showcase prop meshes from the Sketchfab model
	var extra_prop = find_child("Gun001", true, false)
	if extra_prop:
		extra_prop.visible = false
	var loose_mag = find_child("Magazine", true, false)
	if loose_mag:
		loose_mag.visible = false
		
	super._ready()
