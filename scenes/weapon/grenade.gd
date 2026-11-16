extends Node3D

signal grenade_hit_target(points: int)

@export var speed: float = 40.0
@export var gravity: float = 14.0
@export var explosion_radius: float = 12.0 # Blast radius for frag/40mm
@export var max_damage: float = 200.0
@export var grenade_type: String = "frag" # "frag", "smoke", "flash"
@export var explode_on_contact: bool = true # true = 40mm launcher impact; false = thrown hand grenade bounce + fuse
@export var fuse_time: float = 2.6
@export var restitution: float = 0.42
@export var friction: float = 0.76

var is_hand_grenade: bool = false
var spin_axis: Vector3 = Vector3(1, 0.3, 0.2).normalized()
var spin_rate: float = 11.0

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 6.0
var fuse_timer: float = 2.6
var has_exploded: bool = false
var is_resting: bool = false
var bounce_sound_cooldown: float = 0.0
var exclude_rids: Array[RID] = []

const GRENADE_RADIUS: float = 0.045
const EXPLOSION_EFFECT = preload("res://scenes/effects/explosion.tscn")
const SmokeCloudScript = preload("res://scenes/effects/smoke_cloud.gd")
const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

@onready var area: Area3D = $Area3D
@onready var trail_particles: GPUParticles3D = get_node_or_null("TrailParticles")

var _bounce_audio: AudioStreamPlayer3D

func set_shooter_exclude(rids: Array[RID]) -> void:
	exclude_rids = rids.duplicate()

func set_custom_mesh(mesh_res: Mesh, hand_thrown: bool = false) -> void:
	is_hand_grenade = hand_thrown
	if hand_thrown and trail_particles:
		trail_particles.emitting = false
		trail_particles.visible = false
	if not mesh_res:
		return
	var def_mesh = get_node_or_null("MeshInstance3D")
	if def_mesh:
		def_mesh.visible = false
	var custom = MeshInstance3D.new()
	custom.name = "CustomGrenadeMesh"
	custom.mesh = mesh_res
	add_child(custom)

func _ready() -> void:
	fuse_timer = fuse_time
	if is_hand_grenade or not explode_on_contact:
		if trail_particles:
			trail_particles.emitting = false
			trail_particles.visible = false
	_bounce_audio = AudioStreamPlayer3D.new()
	_bounce_audio.stream = ProceduralAudio.get_cached("grenade_bounce")
	_bounce_audio.unit_size = 10.0
	_bounce_audio.max_distance = 50.0
	add_child(_bounce_audio)
	if area:
		area.body_entered.connect(_on_impact)
		area.area_entered.connect(_on_impact)

func launch(direction: Vector3, initial_speed: float = -1.0) -> void:
	if initial_speed > 0:
		speed = initial_speed
	velocity = direction.normalized() * speed
	is_resting = false
	fuse_timer = fuse_time
	if (is_hand_grenade or not explode_on_contact) and trail_particles:
		trail_particles.emitting = false
		trail_particles.visible = false

func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	if bounce_sound_cooldown > 0.0:
		bounce_sound_cooldown = maxf(0.0, bounce_sound_cooldown - delta)

	if not explode_on_contact:
		fuse_timer -= delta
		if fuse_timer <= 0.0:
			explode()
			return
	else:
		lifetime -= delta
		if lifetime <= 0.0:
			explode()
			return

	var space_state := get_world_3d().direct_space_state
	if is_resting:
		# Wake up if supporting floor moved or disappeared (e.g. door / destructible object)
		var check_q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0.0, -(GRENADE_RADIUS + 0.04), 0.0))
		check_q.collide_with_areas = false
		check_q.collide_with_bodies = true
		check_q.exclude = exclude_rids
		var fhit := space_state.intersect_ray(check_q)
		if fhit.is_empty():
			is_resting = false
		else:
			return

	# Apply gravity to ballistic arc
	velocity.y -= gravity * delta

	var rem_time := delta
	for _bounce_iter in range(3):
		var step := velocity * rem_time
		var step_len := step.length()
		if step_len < 0.0001:
			break
		var step_dir := step / step_len
		var probe_end := global_position + step + (step_dir * GRENADE_RADIUS if not explode_on_contact else Vector3.ZERO)
		var query := PhysicsRayQueryParameters3D.create(global_position, probe_end)
		query.collide_with_areas = explode_on_contact
		query.collide_with_bodies = true
		if not exclude_rids.is_empty():
			query.exclude = exclude_rids
		var hit := space_state.intersect_ray(query)

		if not hit.is_empty():
			if explode_on_contact:
				global_position = hit.position
				explode()
				return

			var hit_pos: Vector3 = hit.position
			var n: Vector3 = hit.normal.normalized()
			var traveled := maxf(0.0, global_position.distance_to(hit_pos) - GRENADE_RADIUS)
			var frac := clampf(traveled / maxf(step_len, 0.0001), 0.0, 1.0)
			global_position = hit_pos + n * GRENADE_RADIUS
			rem_time *= (1.0 - frac)

			var vn := velocity.dot(n)
			if vn < 0.0:
				if -vn > 1.25 and bounce_sound_cooldown <= 0.0 and _bounce_audio:
					_bounce_audio.volume_db = clampf(linear_to_db(clampf(-vn / 14.0, 0.25, 1.0)), -16.0, -2.0)
					_bounce_audio.pitch_scale = randf_range(0.88, 1.15)
					_bounce_audio.play()
					bounce_sound_cooldown = 0.08
				var v_n := vn * n
				var v_t := velocity - v_n
				velocity = v_t * friction - v_n * restitution
				spin_rate = clampf(velocity.length() * 1.4, 1.5, 11.0)

			if n.y > 0.68 and velocity.length() < 0.85:
				velocity = Vector3.ZERO
				is_resting = true
				break
			if rem_time <= 0.001:
				break
		else:
			global_position += step
			if is_hand_grenade or not explode_on_contact:
				rotate(spin_axis, rem_time * spin_rate)
			elif velocity.length_squared() > 0.1:
				var vel_dir := velocity.normalized()
				var up_v := Vector3.UP if absf(vel_dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
				look_at(global_position + vel_dir, up_v)
			break

func _on_impact(_other: Node) -> void:
	if not explode_on_contact:
		return
	explode()

func explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	var spawn_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
	match grenade_type:
		"smoke":
			_detonate_smoke(spawn_parent)
		"flash":
			_detonate_flash(spawn_parent)
		_:
			_detonate_frag(spawn_parent)

	queue_free()

func _detonate_smoke(spawn_parent: Node) -> void:
	var cloud := Node3D.new()
	cloud.name = "SmokeCloud"
	cloud.set_script(SmokeCloudScript)
	spawn_parent.add_child(cloud)
	cloud.global_position = global_position + Vector3(0.0, 0.18, 0.0)

func _detonate_flash(spawn_parent: Node) -> void:
	var flash_origin := global_position + Vector3(0.0, 0.14, 0.0)

	# Visual bright flash light + acoustic bang node that persists cleanly after grenade frees
	var fx := Node3D.new()
	fx.name = "FlashbangEffect"
	spawn_parent.add_child(fx)
	fx.global_position = flash_origin

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.98, 0.90)
	light.light_energy = 14.0
	light.omni_range = 24.0
	fx.add_child(light)
	var lt := fx.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.28)

	var snd := AudioStreamPlayer3D.new()
	snd.stream = ProceduralAudio.get_cached("flashbang_bang")
	snd.unit_size = 28.0
	snd.max_distance = 140.0
	fx.add_child(snd)
	snd.play()
	fx.get_tree().create_timer(2.2).timeout.connect(fx.queue_free)

	var space_state := get_world_3d().direct_space_state

	# 1. Check Player Flash-blindness with LOS occlusion (closed doors & walls block!)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var cam: Camera3D = player.get_node_or_null("Head/Camera3D")
		var eye_pos: Vector3 = cam.global_position if cam else (player.global_position + Vector3(0.0, 1.5, 0.0))
		var dist := flash_origin.distance_to(eye_pos)
		if dist < 24.0:
			var p_ex: Array[RID] = []
			if player is CollisionObject3D:
				p_ex.append(player.get_rid())
			var los_q := PhysicsRayQueryParameters3D.create(flash_origin, eye_pos)
			los_q.collide_with_areas = false
			los_q.collide_with_bodies = true
			los_q.exclude = p_ex
			var blocked := space_state.intersect_ray(los_q)
			if blocked.is_empty():
				var cam_fwd: Vector3 = -cam.global_transform.basis.z if cam else Vector3.FORWARD
				var to_flash := (flash_origin - eye_pos).normalized()
				var facing := clampf(cam_fwd.dot(to_flash) * 0.5 + 0.5, 0.22, 1.0)
				var dist_falloff := clampf(1.0 - (dist / 24.0), 0.15, 1.0)
				var intensity := clampf(dist_falloff * (0.38 + 0.68 * facing), 0.22, 1.0)
				if "hud" in player and player.hud:
					var hud_ctrl = player.hud.get_node_or_null("HUDControl")
					if hud_ctrl and hud_ctrl.has_method("trigger_flashbang"):
						hud_ctrl.trigger_flashbang(intensity)

	# 2. Stun Robots & minor close concussion within 16m with clear LOS
	var shape_query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 16.0
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), flash_origin)
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true
	shape_query.exclude = exclude_rids

	var hits := space_state.intersect_shape(shape_query, 64)
	var stunned_count := 0
	var seen := {}
	for res in hits:
		var col: Node = res.collider
		var cid := col.get_instance_id()
		if seen.has(cid):
			continue
		seen[cid] = true
		if col is Node3D and col.has_method("stun"):
			var c3d := col as Node3D
			var r_pos: Vector3 = c3d.global_position + Vector3(0.0, 1.1, 0.0)
			var rq := PhysicsRayQueryParameters3D.create(flash_origin, r_pos)
			rq.collide_with_areas = false
			rq.collide_with_bodies = true
			var rex := exclude_rids.duplicate()
			if col is CollisionObject3D:
				rex.append((col as CollisionObject3D).get_rid())
			rq.exclude = rex
			if space_state.intersect_ray(rq).is_empty():
				var d: float = flash_origin.distance_to(r_pos)
				col.stun(clampf(5.5 * (1.0 - d / 17.5), 2.0, 5.5))
				stunned_count += 1
		if max_damage > 0.0 and col is RigidBody3D:
			var rb := col as RigidBody3D
			var d: float = flash_origin.distance_to(rb.global_position)
			if d < 5.0:
				var dir: Vector3 = (rb.global_position - flash_origin).normalized()
				if dir.length_squared() < 0.001: dir = Vector3.UP
				rb.apply_impulse((dir + Vector3.UP * 0.3).normalized() * (3.5 * clampf(1.0 - d / 5.0, 0.1, 1.0)))

	if stunned_count > 0:
		grenade_hit_target.emit(stunned_count * 100)

func _detonate_frag(spawn_parent: Node) -> void:
	# Spawn explosion effect
	var exp_node = EXPLOSION_EFFECT.instantiate()
	spawn_parent.add_child(exp_node)
	exp_node.global_position = global_position

	# Radial AoE Damage & Target Knockdown
	var space_state = get_world_3d().direct_space_state
	var shape_query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), global_position)
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true

	var hits = space_state.intersect_shape(shape_query, 64)
	var targets_hit = 0
	var processed_roots = {}

	for result in hits:
		var collider = result.collider
		var target_obj = null
		if collider.has_method("take_damage"):
			target_obj = collider
		elif collider.has_meta("target_root"):
			target_obj = collider.get_meta("target_root")
		elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
			target_obj = collider.get_parent()

		if target_obj and target_obj.has_method("take_damage"):
			var obj_id = target_obj.get_instance_id()
			if processed_roots.has(obj_id):
				continue
			processed_roots[obj_id] = true

			var dist = global_position.distance_to(result.collider.global_position)
			var falloff = clampf(1.0 - (dist / explosion_radius), 0.25, 1.0)
			var blast_dir = (result.collider.global_position - global_position).normalized()
			if blast_dir.length_squared() < 0.001:
				blast_dir = Vector3.FORWARD
			target_obj.take_damage(max_damage * falloff, global_position, blast_dir)
			targets_hit += 1

		if collider is RigidBody3D:
			var dir = (collider.global_position - global_position).normalized()
			if dir.length_squared() < 0.001:
				dir = Vector3.UP
			var dist = global_position.distance_to(collider.global_position)
			var falloff = clampf(1.0 - (dist / explosion_radius), 0.2, 1.0)
			collider.apply_impulse((dir + Vector3.UP * 0.4).normalized() * (max_damage * 0.25 * falloff))

	if targets_hit > 0:
		grenade_hit_target.emit(targets_hit * 100)
