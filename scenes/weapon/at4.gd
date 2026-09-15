extends "res://scenes/weapon/weapon.gd"

const ROCKET_SCENE = preload("res://scenes/weapon/rocket.tscn")

func _ready() -> void:
	weapon_name = "AT4 84mm Rocket"
	is_automatic = false
	has_grenade_launcher = false
	damage = 450.0
	fire_rate = 1.0
	max_ammo = 1
	tactical_reload_time = 3.6
	empty_reload_time = 3.6
	
	super._ready()
	
	if shoot_sound:
		shoot_sound.stream = ProceduralAudio.create_rocket_launch_sample()

func shoot(camera: Camera3D) -> bool:
	if not can_fire or is_reloading or is_sprinting or is_switching or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading and not is_sprinting and not is_switching:
			reload()
		return false

	can_fire = false
	current_ammo -= 1
	fired.emit(current_ammo)

	# Heavy AT4 Backblast Recoil
	recoil_offset.z += 0.28
	recoil_rotation.x += 0.20
	recoil_rotation.y += randf_range(-0.02, 0.02)

	# Launch audio
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.96, 1.04)
		shoot_sound.play()

	# Muzzle Flash / Backblast Flash
	if muzzle_flash and muzzle_flash.has_method("flash"):
		muzzle_flash.flash()

	# Spawn Rocket Projectile
	var rocket = ROCKET_SCENE.instantiate()
	get_tree().current_scene.add_child(rocket)
	
	var spawn_pos = global_position - global_transform.basis.z * 0.7
	rocket.global_position = spawn_pos
	
	var launch_dir = -camera.global_transform.basis.z
	rocket.launch(launch_dir.normalized(), 75.0)
	
	rocket.rocket_hit_target.connect(func(pts): hit_target.emit(pts))

	get_tree().create_timer(fire_rate).timeout.connect(func(): can_fire = true)
	return true
