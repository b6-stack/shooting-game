extends Node3D

signal fired(ammo_left: int)
signal reloaded(ammo_left: int)
signal grenade_fired(grenades_left: int)
signal hit_target(points: int)
signal spread_changed(spread_ratio: float)

@export var weapon_name: String = "M4A1 5.56mm"
@export var is_automatic: bool = true
@export var has_grenade_launcher: bool = true

@export var damage: float = 35.0
@export var fire_rate: float = 0.1 # Seconds between shots
@export var max_ammo: int = 30
@export var tactical_reload_time: float = 2.4 # Reload with bullets in chamber
@export var empty_reload_time: float = 3.5    # Reload from empty
@export var max_range: float = 200.0

# Grenade Launcher (M203)
@export var max_grenades: int = 4
@export var grenade_cooldown: float = 3.2
var current_grenades: int = 4
var can_fire_grenade: bool = true

# Sight / Position Configuration
@export var hip_position: Vector3 = Vector3(0.18, -0.16, -0.28)
@export var ads_position: Vector3 = Vector3(0.0, -0.232, -0.30)
@export var sprint_position_offset: Vector3 = Vector3(-0.06, -0.05, 0.04)
@export var sprint_rotation_euler: Vector3 = Vector3(deg_to_rad(-16.0), deg_to_rad(24.0), deg_to_rad(-36.0))

# Spread Configuration
@export var base_standing_spread: float = 0.024
@export var base_crouching_spread: float = 0.002
@export var movement_spread_add: float = 0.030
@export var shot_spread_bloom: float = 0.012
@export var max_spread: float = 0.080
@export var spread_recovery_speed: float = 7.0

var current_spread: float = 0.024
var player_velocity_ratio: float = 0.0

@export var sway_amount: float = 0.002
@export var max_sway: float = 0.05
@export var sway_smooth: float = 8.0

var current_ammo: int = 30
var can_fire: bool = true
var is_reloading: bool = false
var is_aiming: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false
var is_switching: bool = false

# Procedural animation offsets
var recoil_offset: Vector3 = Vector3.ZERO
var recoil_rotation: Vector3 = Vector3.ZERO
var sway_offset: Vector2 = Vector2.ZERO
var bob_offset: Vector3 = Vector3.ZERO

@onready var muzzle_flash: Node3D = get_node_or_null("MuzzleFlash")
@onready var shoot_sound: AudioStreamPlayer = get_node_or_null("ShootSound")
@onready var reload_sound: AudioStreamPlayer = get_node_or_null("ReloadSound")
@onready var grenade_sound: AudioStreamPlayer = get_node_or_null("GrenadeSound")
@onready var model_container: Node3D = get_node_or_null("ModelContainer")

var snd_mag_out: AudioStreamWAV
var snd_mag_in: AudioStreamWAV
var snd_bolt_rack: AudioStreamWAV

const IMPACT_EFFECT = preload("res://scenes/effects/bullet_impact.tscn")
const GRENADE_SCENE = preload("res://scenes/weapon/grenade.tscn")
const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

func _ready() -> void:
	current_ammo = max_ammo
	current_grenades = max_grenades
	position = hip_position
	
	if shoot_sound and shoot_sound.stream == null:
		shoot_sound.stream = ProceduralAudio.create_gunshot_sample()
	if has_grenade_launcher and grenade_sound and grenade_sound.stream == null:
		grenade_sound.stream = ProceduralAudio.create_thump_sample()
		
	snd_mag_out = ProceduralAudio.create_mag_out_sample()
	snd_mag_in = ProceduralAudio.create_mag_in_sample()
	snd_bolt_rack = ProceduralAudio.create_bolt_rack_sample()

func _process(delta: float) -> void:
	# Calculate target base spread depending on posture & movement
	var target_base_spread: float
	if is_aiming:
		target_base_spread = 0.0
	elif is_crouching:
		target_base_spread = base_crouching_spread + (player_velocity_ratio * 0.006)
	else:
		target_base_spread = base_standing_spread + (player_velocity_ratio * movement_spread_add)
		
	# Recover spread smoothly toward baseline
	current_spread = lerpf(current_spread, target_base_spread, delta * spread_recovery_speed)
	current_spread = clampf(current_spread, 0.0, max_spread)
	
	# Emit spread ratio to HUD (0.0 = tightest, 1.0 = widest)
	var spread_ratio = clampf((current_spread - base_crouching_spread) / (max_spread - base_crouching_spread), 0.0, 1.0)
	spread_changed.emit(spread_ratio)

	# Smoothly return recoil to zero
	recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * 14.0)
	recoil_rotation = recoil_rotation.lerp(Vector3.ZERO, delta * 14.0)
	
	# Smooth sway recovery
	sway_offset = sway_offset.lerp(Vector2.ZERO, delta * sway_smooth)
	
	# Target rest position based on aiming / sprint state
	var target_base_pos = hip_position
	var target_base_rot = Vector3.ZERO
	
	if is_aiming:
		target_base_pos = ads_position
	elif is_sprinting:
		target_base_pos = hip_position + sprint_position_offset
		target_base_rot = sprint_rotation_euler
	
	# Combine base pos, sway, bobbing, and recoil
	var final_pos = target_base_pos + Vector3(sway_offset.x, sway_offset.y, 0) + bob_offset + recoil_offset
	var lerp_speed = 10.0 if is_sprinting else 18.0
	position = position.lerp(final_pos, delta * lerp_speed)
	
	var final_rot = target_base_rot + recoil_rotation + Vector3(-sway_offset.y * 0.5, -sway_offset.x * 0.5, sway_offset.x * 0.3)
	rotation.x = lerpf(rotation.x, final_rot.x, delta * lerp_speed)
	rotation.y = lerpf(rotation.y, final_rot.y, delta * lerp_speed)
	rotation.z = lerpf(rotation.z, final_rot.z, delta * lerp_speed)

func add_sway(mouse_delta: Vector2) -> void:
	var sway_mult = 0.2 if is_aiming else (0.5 if is_sprinting else 1.0)
	sway_offset.x = clampf(sway_offset.x - mouse_delta.x * sway_amount * sway_mult, -max_sway, max_sway)
	sway_offset.y = clampf(sway_offset.y + mouse_delta.y * sway_amount * sway_mult, -max_sway, max_sway)

func set_bob(offset: Vector3) -> void:
	var mult = 0.15 if is_aiming else (1.4 if is_sprinting else 1.0)
	bob_offset = offset * mult

func set_aim(aiming: bool) -> void:
	is_aiming = aiming

func set_sprint(sprinting: bool) -> void:
	is_sprinting = sprinting

func set_crouch(crouching: bool) -> void:
	is_crouching = crouching

func set_movement_speed_ratio(ratio: float) -> void:
	player_velocity_ratio = clampf(ratio, 0.0, 1.0)

func holster() -> Tween:
	is_switching = true
	is_aiming = false
	var tween = create_tween()
	tween.tween_property(self, "recoil_offset:y", -0.35, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "recoil_rotation:x", deg_to_rad(-20.0), 0.2)
	tween.tween_callback(func(): visible = false)
	return tween

func draw_weapon() -> Tween:
	visible = true
	is_switching = true
	recoil_offset.y = -0.35
	recoil_rotation.x = deg_to_rad(-20.0)
	
	var tween = create_tween()
	tween.tween_property(self, "recoil_offset:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "recoil_rotation:x", 0.0, 0.25)
	
	tween.tween_callback(func():
		play_sound(snd_mag_out, -10.0)
		is_switching = false
	)
	return tween

func shoot(camera: Camera3D) -> bool:
	if not can_fire or is_reloading or is_sprinting or is_switching or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading and not is_sprinting and not is_switching:
			reload()
		return false

	can_fire = false
	current_ammo -= 1
	fired.emit(current_ammo)

	# Bloom spread on non-ADS shot
	if not is_aiming:
		var bloom = shot_spread_bloom * (0.3 if is_crouching else 1.0)
		current_spread = clampf(current_spread + bloom, 0.0, max_spread)

	# Recoil impulse
	var kick_z = 0.04 if is_aiming else (0.05 if is_crouching else 0.07)
	var kick_pitch = 0.020 if is_aiming else (0.030 if is_crouching else 0.045)
	recoil_offset.z += kick_z
	recoil_rotation.x += kick_pitch
	recoil_rotation.y += randf_range(-0.01, 0.01)
	recoil_rotation.z += randf_range(-0.008, 0.008)

	# Muzzle Flash
	if muzzle_flash and muzzle_flash.has_method("flash"):
		muzzle_flash.flash()

	# Gunshot sound effect
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.96, 1.04)
		shoot_sound.play()

	# Perform Raycast with current spread angle
	perform_raycast(camera)

	# Fire rate cooldown timer
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_fire = true)
	return true

func launch_grenade(camera: Camera3D) -> bool:
	if not has_grenade_launcher or not can_fire_grenade or is_sprinting or is_switching or current_grenades <= 0:
		return false
		
	can_fire_grenade = false
	current_grenades -= 1
	grenade_fired.emit(current_grenades)
	
	# Heavy M203 recoil
	recoil_offset.z += 0.18
	recoil_rotation.x += 0.14
	recoil_rotation.y += randf_range(-0.03, 0.03)
	
	# 40mm Thump sound
	if grenade_sound:
		grenade_sound.pitch_scale = randf_range(0.95, 1.05)
		grenade_sound.play()
		
	# Spawn Grenade Projectile
	var grenade = GRENADE_SCENE.instantiate()
	get_tree().current_scene.add_child(grenade)
	
	# Spawn from grenade launcher muzzle (underslung barrel)
	var spawn_pos = global_position - global_transform.basis.z * 0.5 - global_transform.basis.y * 0.06
	grenade.global_position = spawn_pos
	
	# Launch forward with slight upward trajectory
	var launch_dir = -camera.global_transform.basis.z + camera.global_transform.basis.y * 0.04
	grenade.launch(launch_dir.normalized(), 35.0)
	
	# Connect grenade hit target signal
	grenade.grenade_hit_target.connect(func(pts): hit_target.emit(pts))
	
	# Long 3.2s reload cooldown for M203
	get_tree().create_timer(grenade_cooldown).timeout.connect(func(): can_fire_grenade = true)
	return true

func perform_raycast(camera: Camera3D) -> void:
	var space_state = camera.get_world_3d().direct_space_state
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z
	
	# Apply variance / spread
	if not is_aiming and current_spread > 0.0001:
		var spread_rad = current_spread
		var rand_angle = randf() * TAU
		var rand_dist = sqrt(randf()) * spread_rad
		var offset_x = cos(rand_angle) * rand_dist
		var offset_y = sin(rand_angle) * rand_dist
		
		forward += camera.global_transform.basis.x * offset_x
		forward += camera.global_transform.basis.y * offset_y
		forward = forward.normalized()

	var target = origin + forward * max_range
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result:
		var hit_collider = result.collider
		var hit_pos = result.position
		var hit_normal = result.normal

		# Spawn Impact Effect
		spawn_impact_effect(hit_pos, hit_normal)

		# Check if damageable / target
		var damaged_target = false
		if hit_collider.has_method("take_damage"):
			hit_collider.take_damage(damage, hit_pos, hit_normal)
			damaged_target = true
		elif hit_collider.has_meta("target_root"):
			var root = hit_collider.get_meta("target_root")
			if root and root.has_method("take_damage"):
				root.take_damage(damage, hit_pos, hit_normal)
				damaged_target = true
		elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
			hit_collider.get_parent().take_damage(damage, hit_pos, hit_normal)
			damaged_target = true

		if damaged_target:
			hit_target.emit(100)

func spawn_impact_effect(pos: Vector3, normal: Vector3) -> void:
	var impact = IMPACT_EFFECT.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	if normal.cross(Vector3.UP).length_squared() > 0.001:
		impact.look_at(pos + normal, Vector3.UP)
	else:
		impact.look_at(pos + normal, Vector3.RIGHT)

func refill_all() -> bool:
	var changed = false
	if current_ammo < max_ammo:
		current_ammo = max_ammo
		fired.emit(current_ammo)
		changed = true
	if has_grenade_launcher and current_grenades < max_grenades:
		current_grenades = max_grenades
		grenade_fired.emit(current_grenades)
		changed = true
	return changed

func reload() -> void:
	if is_reloading or is_switching or current_ammo >= max_ammo:
		return
	
	is_reloading = true
	var is_empty_reload = (current_ammo == 0)
	
	if is_empty_reload:
		perform_empty_reload()
	else:
		perform_tactical_reload()

func perform_tactical_reload() -> void:
	var tween = create_tween()
	
	tween.tween_property(self, "recoil_offset:y", -0.16, tactical_reload_time * 0.2)
	tween.parallel().tween_property(self, "recoil_offset:z", -0.04, tactical_reload_time * 0.2)
	tween.parallel().tween_property(self, "recoil_rotation:z", deg_to_rad(-28.0), tactical_reload_time * 0.2)
	tween.parallel().tween_property(self, "recoil_rotation:x", deg_to_rad(12.0), tactical_reload_time * 0.2)
	
	tween.tween_callback(func(): play_sound(snd_mag_out, -6.0))
	tween.tween_interval(tactical_reload_time * 0.3)
	
	tween.tween_callback(func():
		play_sound(snd_mag_in, -4.0)
		recoil_offset.y += 0.03
	)
	tween.tween_interval(tactical_reload_time * 0.3)
	
	tween.tween_property(self, "recoil_offset:y", 0.0, tactical_reload_time * 0.2)
	tween.parallel().tween_property(self, "recoil_offset:z", 0.0, tactical_reload_time * 0.2)
	tween.parallel().tween_property(self, "recoil_rotation:z", 0.0, tactical_reload_time * 0.2)
	tween.parallel().tween_property(self, "recoil_rotation:x", 0.0, tactical_reload_time * 0.2)
	
	await tween.finished
	current_ammo = max_ammo
	is_reloading = false
	reloaded.emit(current_ammo)

func perform_empty_reload() -> void:
	var tween = create_tween()
	
	tween.tween_property(self, "recoil_offset:y", -0.18, empty_reload_time * 0.18)
	tween.parallel().tween_property(self, "recoil_offset:z", -0.05, empty_reload_time * 0.18)
	tween.parallel().tween_property(self, "recoil_rotation:z", deg_to_rad(-32.0), empty_reload_time * 0.18)
	tween.parallel().tween_property(self, "recoil_rotation:x", deg_to_rad(14.0), empty_reload_time * 0.18)
	
	tween.tween_callback(func(): play_sound(snd_mag_out, -6.0))
	tween.tween_interval(empty_reload_time * 0.25)
	
	tween.tween_callback(func():
		play_sound(snd_mag_in, -4.0)
		recoil_offset.y += 0.03
	)
	tween.tween_interval(empty_reload_time * 0.22)
	
	tween.tween_property(self, "recoil_rotation:z", deg_to_rad(-10.0), empty_reload_time * 0.12)
	tween.parallel().tween_property(self, "recoil_offset:y", -0.10, empty_reload_time * 0.12)
	
	tween.tween_callback(func():
		play_sound(snd_bolt_rack, -3.0)
		recoil_offset.z += 0.06
		recoil_rotation.x -= deg_to_rad(6.0)
	)
	tween.tween_interval(empty_reload_time * 0.15)
	
	tween.tween_property(self, "recoil_offset:y", 0.0, empty_reload_time * 0.18)
	tween.parallel().tween_property(self, "recoil_offset:z", 0.0, empty_reload_time * 0.18)
	tween.parallel().tween_property(self, "recoil_rotation:z", 0.0, empty_reload_time * 0.18)
	tween.parallel().tween_property(self, "recoil_rotation:x", 0.0, empty_reload_time * 0.18)
	
	await tween.finished
	current_ammo = max_ammo
	is_reloading = false
	reloaded.emit(current_ammo)

func play_sound(stream: AudioStream, vol_db: float = -6.0) -> void:
	if not stream or not reload_sound:
		return
	reload_sound.stream = stream
	reload_sound.volume_db = vol_db
	reload_sound.pitch_scale = randf_range(0.97, 1.03)
	reload_sound.play()
