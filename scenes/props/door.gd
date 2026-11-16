extends Node3D

signal door_state_changed(is_open: bool)

@export var open_angle_deg: float = 92.0
@export var open_duration: float = 0.34
@export var breach_threshold: float = 100.0

@onready var door_pivot: Node3D = $DoorPivot
@onready var door_body: StaticBody3D = $DoorPivot/DoorBody
@onready var interact_area: Area3D = $InteractArea
@onready var prompt_label: Label3D = $PromptLabel
@onready var audio_player: AudioStreamPlayer3D = $DoorPivot/DoorBody/AudioStreamPlayer3D

const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

var is_open: bool = false
var current_angle_sign: float = 1.0
var breach_damage_accum: float = 0.0
var player_in_range: Node3D = null
var active_tween: Tween = null

func _ready() -> void:
	add_to_group("interactable_door")
	if door_body:
		door_body.set_meta("target_root", self)
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	_update_prompt()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = body
		_update_prompt()

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		_update_prompt()

func _update_prompt() -> void:
	if not prompt_label:
		return
	if player_in_range and is_instance_valid(player_in_range):
		prompt_label.visible = true
		prompt_label.text = "[E] Close Door" if is_open else "[E] Open Door"
	else:
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed = true
	if pressed and player_in_range and is_instance_valid(player_in_range):
		toggle(player_in_range.global_position)
		get_viewport().set_input_as_handled()

func toggle(actor_world_pos: Vector3 = Vector3.ZERO) -> void:
	if is_open:
		close_door()
	else:
		open_door(actor_world_pos, false)

func _compute_away_sign(from_world_pos: Vector3) -> float:
	# Door local -Z points into the room; +Z is outside toward firing line.
	# Right-hand rule around +Y: positive rotation swings +X door panel into -Z (into room).
	if from_world_pos == Vector3.ZERO:
		return 1.0
	var local_actor: Vector3 = to_local(from_world_pos)
	return 1.0 if local_actor.z >= 0.0 else -1.0

func open_door(actor_world_pos: Vector3 = Vector3.ZERO, breached: bool = false) -> void:
	if is_open:
		return
	is_open = true
	breach_damage_accum = 0.0
	current_angle_sign = _compute_away_sign(actor_world_pos)
	var target_rad := deg_to_rad(open_angle_deg) * current_angle_sign
	var dur := 0.16 if breached else open_duration
	_animate_door(target_rad, dur, Tween.TRANS_BACK if breached else Tween.TRANS_QUAD)
	_play_door_sound(1.35 if breached else 1.0, -2.0 if breached else -6.0)
	_update_prompt()
	door_state_changed.emit(true)

func close_door() -> void:
	if not is_open:
		return
	is_open = false
	breach_damage_accum = 0.0
	_animate_door(0.0, open_duration, Tween.TRANS_QUAD)
	_play_door_sound(0.85, -7.0)
	_update_prompt()
	door_state_changed.emit(false)

func _animate_door(target_rot_y: float, duration: float, trans: Tween.TransitionType) -> void:
	if not door_pivot:
		return
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.tween_property(door_pivot, "rotation:y", target_rot_y, duration).set_trans(trans).set_ease(Tween.EASE_OUT)

func _play_door_sound(pitch: float = 1.0, vol_db: float = -6.0) -> void:
	if not audio_player:
		return
	if audio_player.stream == null:
		audio_player.stream = ProceduralAudio.get_cached("door_latch")
	audio_player.pitch_scale = pitch
	audio_player.volume_db = vol_db
	audio_player.play()

func take_damage(amount: float, hit_pos: Vector3 = Vector3.ZERO, shot_dir: Vector3 = Vector3.ZERO) -> void:
	if is_open:
		return
	breach_damage_accum += amount
	# Visual rattle feedback on shot
	if door_pivot and breach_damage_accum < breach_threshold:
		var push_origin := hit_pos - shot_dir
		var rattle_sign := _compute_away_sign(push_origin if hit_pos != Vector3.ZERO else Vector3.ZERO)
		if active_tween and active_tween.is_valid():
			active_tween.kill()
		active_tween = create_tween()
		active_tween.tween_property(door_pivot, "rotation:y", deg_to_rad(5.5) * rattle_sign, 0.04)
		active_tween.tween_property(door_pivot, "rotation:y", 0.0, 0.09)
		_play_door_sound(1.15, -10.0)
		return

	var origin := hit_pos - shot_dir if shot_dir.length_squared() > 0.001 else hit_pos
	open_door(origin, true)
