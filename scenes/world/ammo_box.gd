extends Node3D

@export var prompt_text: String = "Press E to Resupply Ammo & Grenades"
@export var auto_refill_on_touch: bool = true

@onready var area: Area3D = $Area3D
@onready var prompt_label: Label3D = $PromptLabel
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var player_in_range: Node = null
var can_refill: bool = true

const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

func _ready() -> void:
	if prompt_label:
		prompt_label.text = prompt_text
		prompt_label.visible = false
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		if prompt_label:
			prompt_label.visible = true
		if auto_refill_on_touch:
			try_refill()

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		if prompt_label:
			prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	var interact_pressed = (InputMap.has_action("interact") and event.is_action_pressed("interact")) or (event is InputEventKey and event.pressed and event.keycode == KEY_E)
	if player_in_range and interact_pressed:
		try_refill()

func try_refill() -> void:
	if not can_refill or not player_in_range:
		return
		
	var any_refilled = false
	
	# Refill active weapon
	if "weapon" in player_in_range and player_in_range.weapon and player_in_range.weapon.has_method("refill_all"):
		if player_in_range.weapon.refill_all():
			any_refilled = true
			
	# Refill all weapons in inventory
	if "weapon_slots" in player_in_range:
		for w in player_in_range.weapon_slots:
			if w and w.has_method("refill_all"):
				if w.refill_all():
					any_refilled = true
					
	if any_refilled:
		can_refill = false
		play_refill_sound()
		
		# Refresh player HUD
		if player_in_range.has_method("refresh_hud"):
			player_in_range.refresh_hud()
			
		# Pulse green highlight on prompt
		if prompt_label:
			prompt_label.text = "RESUPPLIED!"
			prompt_label.modulate = Color(0.3, 1.0, 0.4)
			var tween = create_tween()
			tween.tween_property(prompt_label, "scale", Vector3(1.2, 1.2, 1.2), 0.15)
			tween.tween_property(prompt_label, "scale", Vector3.ONE, 0.15)
			
		get_tree().create_timer(1.5).timeout.connect(func():
			can_refill = true
			if prompt_label:
				prompt_label.text = prompt_text
				prompt_label.modulate = Color.WHITE
		)

func play_refill_sound() -> void:
	if audio_player:
		audio_player.stream = ProceduralAudio.create_mag_in_sample()
		audio_player.pitch_scale = 0.9
		audio_player.play()
