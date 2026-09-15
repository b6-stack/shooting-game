extends Node3D

@export var auto_rebuild_time: float = 10.0

@onready var sections: Node3D = $Sections
var rebuild_timer: float = 0.0
var needs_rebuild: bool = false

func _ready() -> void:
	for section in sections.get_children():
		if section.has_signal("section_destroyed"):
			section.section_destroyed.connect(_on_section_destroyed)

func _on_section_destroyed() -> void:
	needs_rebuild = true
	rebuild_timer = 0.0

func _process(delta: float) -> void:
	if needs_rebuild:
		rebuild_timer += delta
		if rebuild_timer >= auto_rebuild_time:
			rebuild_all()

func rebuild_all() -> void:
	needs_rebuild = false
	rebuild_timer = 0.0
	for section in sections.get_children():
		if section.has_method("reset_section"):
			section.reset_section()
