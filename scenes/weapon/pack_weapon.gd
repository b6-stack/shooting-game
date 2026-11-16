extends "res://scenes/weapon/weapon.gd"

const ROCKET_SCENE = preload("res://scenes/weapon/rocket.tscn")
const WeaponAttachments = preload("res://scripts/weapon_attachments.gd")
const ANIM_PARTS_PATH := "res://data/weapon_anim_parts.json"

static var _anim_parts_loaded: bool = false
static var _anim_parts_db: Dictionary = {}

static func _get_anim_parts_spec(wid: String) -> Dictionary:
	if not _anim_parts_loaded:
		_anim_parts_loaded = true
		if FileAccess.file_exists(ANIM_PARTS_PATH):
			var f = FileAccess.open(ANIM_PARTS_PATH, FileAccess.READ)
			if f:
				var parsed = JSON.parse_string(f.get_as_text())
				f.close()
				if parsed is Dictionary:
					_anim_parts_db = parsed
	var entry = _anim_parts_db.get(wid, {})
	return entry if (entry is Dictionary) else {}

var weapon_id: String = ""
var category: String = "rifle"
var pellet_count: int = 1
var launcher_mode: String = ""
var projectile_mesh_path: String = ""
var weapon_mesh_path: String = ""
var muzzle_local_pos: Vector3 = Vector3(0, 0.03, -0.5)
var base_muzzle_local_pos: Vector3 = Vector3(0, 0.03, -0.5)
var base_ads_position: Vector3 = Vector3(0, -0.11, -0.38)
var base_ads_fov: float = 60.0
var aabb_size: Vector3 = Vector3(0.1, 0.2, 0.8)
var viewmodel_scale: float = 1.0
var grenade_type: String = "frag"

var is_melee: bool = false
var is_shield: bool = false
var is_grenade: bool = false
var is_suppressed: bool = false
var is_scope_hidden: bool = false
var current_attachments: Dictionary = {}

var has_laser_attachment: bool = false
var laser_active: bool = true
var _laser_emitter: Node3D = null
var _laser_beam: MeshInstance3D = null
var _laser_dot: MeshInstance3D = null
var _laser_dot_light: OmniLight3D = null

var rest_model_pos: Vector3 = Vector3.ZERO
var rest_model_rot: Vector3 = Vector3.ZERO
var physics_impulse_mult: float = 0.18

var _active_parts_spec: Dictionary = {}
var has_cover_part: bool = false
var has_belt_part: bool = false
var has_slide_part: bool = false
var has_bolt_part: bool = false
var has_mag_part: bool = false

var _cover_hinge: Vector3 = Vector3.ZERO
var _cover_angle_deg: float = -68.0
var _slide_travel: float = 0.032
var _bolt_travel: float = 0.052
var _bolt_lift_deg: float = 0.0
var _bolt_pivot_pos: Vector3 = Vector3.ZERO
var _mag_drop: Vector3 = Vector3(0.0, -0.18, 0.015)

var _slide_locked_back: bool = false
var _active_reload_tween: Tween = null
var _reload_seq_id: int = 0

@onready var weapon_mesh: MeshInstance3D = get_node_or_null("ModelContainer/WeaponMesh")
@onready var cover_pivot: Node3D = get_node_or_null("ModelContainer/CoverPivot")
@onready var cover_mesh: MeshInstance3D = get_node_or_null("ModelContainer/CoverPivot/CoverMesh")
@onready var bolt_pivot: Node3D = get_node_or_null("ModelContainer/BoltPivot")
@onready var bolt_mesh: MeshInstance3D = get_node_or_null("ModelContainer/BoltPivot/BoltMesh")
@onready var slide_mesh: MeshInstance3D = get_node_or_null("ModelContainer/SlideMesh")
@onready var belt_mesh: MeshInstance3D = get_node_or_null("ModelContainer/BeltMesh")
@onready var mag_mesh: MeshInstance3D = get_node_or_null("ModelContainer/MagMesh")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func configure(data: Dictionary, attachments: Dictionary = {}) -> void:
	if data.is_empty():
		return
	_kill_active_reload()

	weapon_id = str(data.get("id", "unknown"))
	weapon_name = str(data.get("name", "Weapon"))
	category = str(data.get("category", "rifle"))
	damage = float(data.get("damage", 32.0))
	fire_rate = float(data.get("fire_rate", 0.1))
	is_automatic = bool(data.get("is_automatic", false))
	max_ammo = int(data.get("max_ammo", 30))
	pellet_count = maxi(1, int(data.get("pellet_count", 1)))
	launcher_mode = str(data.get("launcher_mode", ""))
	projectile_mesh_path = str(data.get("projectile_mesh", ""))
	weapon_mesh_path = str(data.get("mesh_path", ""))
	base_ads_fov = float(data.get("ads_fov", 60.0))
	ads_fov = base_ads_fov
	viewmodel_scale = clampf(float(data.get("viewmodel_scale", 1.0)), 0.4, 2.0)
	grenade_type = str(data.get("grenade_type", "frag"))

	var r_time = float(data.get("reload_time", 2.2))
	tactical_reload_time = r_time
	empty_reload_time = r_time * 1.25 if r_time > 0.0 else 0.0
	has_grenade_launcher = false

	var hp = data.get("hip_pos", [0.2, -0.18, -0.42])
	hip_position = Vector3(float(hp[0]), float(hp[1]), float(hp[2]))
	var ap = data.get("ads_pos", [0.0, -0.11, -0.38])
	base_ads_position = Vector3(float(ap[0]), float(ap[1]), float(ap[2]))
	ads_position = base_ads_position
	var mp = data.get("muzzle_pos", [0.0, 0.04, -0.5])
	base_muzzle_local_pos = Vector3(float(mp[0]), float(mp[1]), float(mp[2]))
	muzzle_local_pos = base_muzzle_local_pos * viewmodel_scale
	var ab = data.get("aabb_size", [0.06, 0.2, 0.7])
	aabb_size = Vector3(float(ab[0]), float(ab[1]), float(ab[2]))

	is_melee = (category == "melee")
	is_shield = (category == "shield")
	is_grenade = (category == "grenade")

	_apply_category_tuning()

	current_attachments = WeaponAttachments.sanitize_attachments(weapon_id, attachments)
	current_ammo = max_ammo
	current_grenades = max_grenades
	if is_grenade or is_melee or is_shield or max_ammo <= 0:
		max_reserve_mags = 0
		reserve_mags.clear()
	else:
		max_reserve_mags = 5
		init_reserve_ammo()
	can_fire_grenade = true
	can_fire = true
	is_reloading = false
	is_switching = false
	is_scope_hidden = false
	_slide_locked_back = false
	ads_blend = 0.0
	recoil_offset = Vector3.ZERO
	recoil_rotation = Vector3.ZERO
	_sync_attachment_params()
	position = hip_position
	rotation = Vector3.ZERO

	if is_node_ready():
		_apply_visuals_and_audio()

func _apply_category_tuning() -> void:
	rest_model_pos = Vector3.ZERO
	rest_model_rot = Vector3.ZERO
	physics_impulse_mult = 0.18
	sprint_position_offset = Vector3(-0.06, -0.05, 0.04)
	sprint_rotation_euler = Vector3(deg_to_rad(-16.0), deg_to_rad(24.0), deg_to_rad(-36.0))

	match category:
		"pistol":
			base_standing_spread = 0.016
			base_crouching_spread = 0.002
			movement_spread_add = 0.022
			shot_spread_bloom = 0.015
			max_spread = 0.060
			physics_impulse_mult = 0.16
		"smg":
			base_standing_spread = 0.022
			base_crouching_spread = 0.004
			movement_spread_add = 0.025
			shot_spread_bloom = 0.010
			max_spread = 0.085
			physics_impulse_mult = 0.14
		"rifle":
			base_standing_spread = 0.024
			base_crouching_spread = 0.002
			movement_spread_add = 0.030
			shot_spread_bloom = 0.012
			max_spread = 0.080
			physics_impulse_mult = 0.20
		"shotgun":
			base_standing_spread = 0.048
			base_crouching_spread = 0.032
			movement_spread_add = 0.022
			shot_spread_bloom = 0.018
			max_spread = 0.110
			physics_impulse_mult = 0.34
		"sniper":
			base_standing_spread = 0.048
			base_crouching_spread = 0.016
			movement_spread_add = 0.045
			shot_spread_bloom = 0.035
			max_spread = 0.140
			physics_impulse_mult = 0.32
		"lmg":
			base_standing_spread = 0.032
			base_crouching_spread = 0.006
			movement_spread_add = 0.040
			shot_spread_bloom = 0.011
			max_spread = 0.115
			physics_impulse_mult = 0.22
		"launcher":
			base_standing_spread = 0.012
			base_crouching_spread = 0.002
			movement_spread_add = 0.020
			shot_spread_bloom = 0.020
			max_spread = 0.060
		"grenade":
			base_standing_spread = 0.005
			base_crouching_spread = 0.003
			movement_spread_add = 0.008
			shot_spread_bloom = 0.004
			max_spread = 0.025
			rest_model_rot = Vector3(deg_to_rad(-10.0), deg_to_rad(14.0), deg_to_rad(8.0))
			sprint_position_offset = Vector3(-0.04, -0.05, 0.02)
			sprint_rotation_euler = Vector3(deg_to_rad(-12.0), deg_to_rad(16.0), deg_to_rad(-14.0))
		"melee":
			base_standing_spread = 0.002
			base_crouching_spread = 0.002
			movement_spread_add = 0.004
			shot_spread_bloom = 0.002
			max_spread = 0.015
			physics_impulse_mult = 0.28
			if aabb_size.y > 0.40:
				# Upright tomahawk / axe
				rest_model_rot = Vector3(deg_to_rad(10.0), deg_to_rad(-10.0), deg_to_rad(10.0))
			else:
				# Horizontal blade, shovel, baton pitched up into FPS viewmodel stance
				rest_model_rot = Vector3(deg_to_rad(36.0), deg_to_rad(-14.0), deg_to_rad(18.0))
			sprint_position_offset = Vector3(-0.05, -0.04, 0.02)
			sprint_rotation_euler = Vector3(deg_to_rad(-10.0), deg_to_rad(18.0), deg_to_rad(-16.0))
		"shield":
			base_standing_spread = 0.004
			base_crouching_spread = 0.004
			movement_spread_add = 0.006
			shot_spread_bloom = 0.004
			max_spread = 0.020
			physics_impulse_mult = 0.48
			sprint_position_offset = Vector3(-0.08, -0.06, 0.04)
			sprint_rotation_euler = Vector3(deg_to_rad(8.0), deg_to_rad(28.0), deg_to_rad(6.0))

func _ready() -> void:
	super._ready()
	_apply_visuals_and_audio()
	position = hip_position

func _process(delta: float) -> void:
	super._process(delta)
	_update_laser_visuals()

func _get_spread_multiplier() -> float:
	if is_laser_enabled() and not is_aiming:
		return 0.70
	return 1.0

func _apply_visuals_and_audio() -> void:
	_load_weapon_and_parts_meshes()

	if model_container:
		model_container.position = rest_model_pos
		model_container.rotation = rest_model_rot
		model_container.scale = Vector3.ONE * viewmodel_scale
		model_container.visible = not is_scope_hidden

	_reset_subpart_transforms()
	_rebuild_animations()
	_rebuild_attachment_meshes()
	_update_muzzle_and_sound()

func _load_mesh_safe(path: String) -> Mesh:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Mesh
	return null

func _load_weapon_and_parts_meshes() -> void:
	_active_parts_spec = _get_anim_parts_spec(weapon_id)
	has_cover_part = false
	has_belt_part = false
	has_slide_part = false
	has_bolt_part = false
	has_mag_part = false
	_cover_hinge = Vector3.ZERO
	_cover_angle_deg = -68.0
	_slide_travel = 0.032
	_bolt_travel = 0.052
	_bolt_lift_deg = 0.0
	_bolt_pivot_pos = Vector3(0.0, base_muzzle_local_pos.y, 0.0)
	_mag_drop = Vector3(0.0, -0.18, 0.015)

	var body_mesh: Mesh = null
	if not _active_parts_spec.is_empty():
		body_mesh = _load_mesh_safe(str(_active_parts_spec.get("body", "")))
		var cm = _load_mesh_safe(str(_active_parts_spec.get("cover", "")))
		var bm = _load_mesh_safe(str(_active_parts_spec.get("belt", "")))
		var sm = _load_mesh_safe(str(_active_parts_spec.get("slide", "")))
		var blm = _load_mesh_safe(str(_active_parts_spec.get("bolt", "")))
		var mm = _load_mesh_safe(str(_active_parts_spec.get("mag", "")))

		if cover_mesh:
			cover_mesh.mesh = cm
			has_cover_part = (cm != null)
			cover_mesh.visible = has_cover_part
			cover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if belt_mesh:
			belt_mesh.mesh = bm
			has_belt_part = (bm != null)
			belt_mesh.visible = has_belt_part
			belt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if slide_mesh:
			slide_mesh.mesh = sm
			has_slide_part = (sm != null)
			slide_mesh.visible = has_slide_part
			slide_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if bolt_mesh:
			bolt_mesh.mesh = blm
			has_bolt_part = (blm != null)
			bolt_mesh.visible = has_bolt_part
			bolt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mag_mesh:
			mag_mesh.mesh = mm
			has_mag_part = (mm != null)
			mag_mesh.visible = has_mag_part
			mag_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		if _active_parts_spec.has("hinge"):
			var h = _active_parts_spec["hinge"]
			_cover_hinge = Vector3(float(h[0]), float(h[1]), float(h[2]))
		_cover_angle_deg = float(_active_parts_spec.get("cover_angle", -68.0))
		_slide_travel = float(_active_parts_spec.get("slide_travel", 0.032))
		_bolt_travel = float(_active_parts_spec.get("bolt_travel", 0.052))

		# Turn-bolt handle lifts upward (+Z right-hand rule lifts +X handle toward +Y).
		# Straight bullpup dust plate (desert_tech_srs) translates purely backward along +Z.
		if _active_parts_spec.has("bolt_lift") and weapon_id != "desert_tech_srs":
			_bolt_lift_deg = absf(float(_active_parts_spec.get("bolt_lift", 50.0)))

		if _active_parts_spec.has("mag_drop"):
			var md = _active_parts_spec["mag_drop"]
			_mag_drop = Vector3(float(md[0]), float(md[1]), float(md[2]))
	else:
		if cover_mesh:
			cover_mesh.mesh = null
			cover_mesh.visible = false
		if belt_mesh:
			belt_mesh.mesh = null
			belt_mesh.visible = false
		if slide_mesh:
			slide_mesh.mesh = null
			slide_mesh.visible = false
		if bolt_mesh:
			bolt_mesh.mesh = null
			bolt_mesh.visible = false
		if mag_mesh:
			mag_mesh.mesh = null
			mag_mesh.visible = false

	if weapon_mesh:
		if body_mesh != null:
			weapon_mesh.mesh = body_mesh
		else:
			weapon_mesh.mesh = _load_mesh_safe(weapon_mesh_path)
		weapon_mesh.visible = (weapon_mesh.mesh != null)
		weapon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _reset_subpart_transforms() -> void:
	if cover_pivot:
		cover_pivot.position = _cover_hinge if has_cover_part else Vector3.ZERO
		cover_pivot.rotation = Vector3.ZERO
	if cover_mesh:
		cover_mesh.position = -_cover_hinge if has_cover_part else Vector3.ZERO
		cover_mesh.rotation = Vector3.ZERO
		cover_mesh.visible = has_cover_part
	if bolt_pivot:
		bolt_pivot.position = _bolt_pivot_pos if has_bolt_part else Vector3.ZERO
		bolt_pivot.rotation = Vector3.ZERO
	if bolt_mesh:
		bolt_mesh.position = -_bolt_pivot_pos if has_bolt_part else Vector3.ZERO
		bolt_mesh.rotation = Vector3.ZERO
		bolt_mesh.visible = has_bolt_part
	if slide_mesh:
		slide_mesh.position = Vector3(0.0, 0.0, _slide_travel) if (has_slide_part and _slide_locked_back) else Vector3.ZERO
		slide_mesh.rotation = Vector3.ZERO
		slide_mesh.visible = has_slide_part
	if belt_mesh:
		belt_mesh.position = Vector3.ZERO
		belt_mesh.rotation = Vector3.ZERO
		belt_mesh.visible = has_belt_part
	if mag_mesh:
		mag_mesh.position = Vector3.ZERO
		mag_mesh.rotation = Vector3.ZERO
		mag_mesh.visible = has_mag_part

func _sync_attachment_params() -> void:
	ads_position = WeaponAttachments.get_effective_ads_pos(weapon_id, current_attachments, base_ads_position)
	ads_fov = WeaponAttachments.get_effective_ads_fov(weapon_id, current_attachments, base_ads_fov, category)

	var was_ugl = has_grenade_launcher
	has_grenade_launcher = bool(current_attachments.get("ugl", false))
	if has_grenade_launcher and not was_ugl:
		current_grenades = max_grenades
		can_fire_grenade = true

	has_laser_attachment = bool(current_attachments.get("laser", false))

	is_suppressed = WeaponAttachments.is_effective_suppressed(weapon_id, current_attachments)
	if bool(current_attachments.get("suppressor", false)):
		muzzle_local_pos = (base_muzzle_local_pos + Vector3(0.0, 0.0, -WeaponAttachments.get_suppressor_forward_extension(weapon_id))) * viewmodel_scale
	else:
		muzzle_local_pos = base_muzzle_local_pos * viewmodel_scale

func apply_attachments(raw_att: Dictionary) -> void:
	current_attachments = WeaponAttachments.sanitize_attachments(weapon_id, raw_att)
	_sync_attachment_params()
	if is_node_ready():
		_rebuild_attachment_meshes()
		_update_muzzle_and_sound()

func _rebuild_attachment_meshes() -> void:
	if not model_container:
		return
	var old_att = model_container.get_node_or_null("AttachmentsNode")
	if old_att:
		model_container.remove_child(old_att)
		old_att.queue_free()
	var att_node := WeaponAttachments.build_attachment_nodes(weapon_id, current_attachments)
	model_container.add_child(att_node)

	_setup_laser_visuals(att_node)

func _update_muzzle_and_sound() -> void:
	if muzzle_flash:
		muzzle_flash.position = muzzle_local_pos
		muzzle_flash.visible = false
		if muzzle_flash.has_method("set_suppressed"):
			muzzle_flash.set_suppressed(is_suppressed)

	if shoot_sound:
		var sound_key = category
		if category == "launcher" and launcher_mode == "grenade_launcher":
			sound_key = "grenade_launcher"
		elif is_suppressed:
			if category == "sniper":
				sound_key = "sniper_suppressed"
			elif category == "pistol":
				sound_key = "pistol_suppressed"
			else:
				sound_key = "gunshot_suppressed"
		elif category == "rifle":
			sound_key = "gunshot"
		shoot_sound.stream = ProceduralAudio.get_cached(sound_key)

	if grenade_sound and has_grenade_launcher and grenade_sound.stream == null:
		grenade_sound.stream = ProceduralAudio.get_cached("grenade_launcher")

func get_active_scope_style() -> String:
	return WeaponAttachments.get_active_scope_style(weapon_id, current_attachments)

func get_scope_zoom_label() -> String:
	return WeaponAttachments.get_scope_zoom_label(weapon_id, current_attachments, category)

func set_scope_view_hidden(hidden: bool) -> void:
	if is_scope_hidden == hidden:
		return
	is_scope_hidden = hidden
	if model_container:
		model_container.visible = not hidden
	if hidden and muzzle_flash:
		muzzle_flash.visible = false
	if hidden:
		_hide_laser_visuals()

func toggle_laser() -> bool:
	if not has_laser_attachment:
		return false
	laser_active = not laser_active
	if not laser_active:
		_hide_laser_visuals()
	return laser_active

func is_laser_enabled() -> bool:
	return has_laser_attachment and laser_active and is_inside_tree() and visible and not is_scope_hidden

func _cleanup_laser() -> void:
	if _laser_beam and is_instance_valid(_laser_beam):
		_laser_beam.queue_free()
		_laser_beam = null
	if _laser_dot and is_instance_valid(_laser_dot):
		_laser_dot.queue_free()
		_laser_dot = null
	if _laser_dot_light and is_instance_valid(_laser_dot_light):
		_laser_dot_light.queue_free()
		_laser_dot_light = null
	_laser_emitter = null

func _hide_laser_visuals() -> void:
	if _laser_beam and is_instance_valid(_laser_beam):
		_laser_beam.visible = false
	if _laser_dot and is_instance_valid(_laser_dot):
		_laser_dot.visible = false
	if _laser_dot_light and is_instance_valid(_laser_dot_light):
		_laser_dot_light.visible = false

func _setup_laser_visuals(att_node: Node3D) -> void:
	_cleanup_laser()
	if not has_laser_attachment or att_node == null:
		return

	_laser_emitter = att_node.find_child("LaserEmitter", true, false) as Node3D
	if not _laser_emitter:
		return

	# Slender collimated crimson laser beam cylinder
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.0016
	beam_mesh.bottom_radius = 0.0016
	beam_mesh.height = 1.0
	beam_mesh.radial_segments = 8
	beam_mesh.rings = 1

	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.12, 0.10, 0.42)

	_laser_beam = MeshInstance3D.new()
	_laser_beam.name = "LaserBeamVisual"
	_laser_beam.mesh = beam_mesh
	_laser_beam.material_override = beam_mat
	_laser_beam.top_level = true
	_laser_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_beam.visible = false
	add_child(_laser_beam)

	# High-intensity laser impact dot disc
	var dot_mesh := CylinderMesh.new()
	dot_mesh.top_radius = 0.016
	dot_mesh.bottom_radius = 0.016
	dot_mesh.height = 0.002
	dot_mesh.radial_segments = 12
	dot_mesh.rings = 1

	var dot_mat := StandardMaterial3D.new()
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dot_mat.albedo_color = Color(1.0, 0.18, 0.14, 0.95)

	_laser_dot = MeshInstance3D.new()
	_laser_dot.name = "LaserDotVisual"
	_laser_dot.mesh = dot_mesh
	_laser_dot.material_override = dot_mat
	_laser_dot.top_level = true
	_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_dot.visible = false
	add_child(_laser_dot)

	# Subtle diffuse bounce light at the laser impact point
	_laser_dot_light = OmniLight3D.new()
	_laser_dot_light.name = "LaserDotLight"
	_laser_dot_light.light_color = Color(1.0, 0.18, 0.15)
	_laser_dot_light.light_energy = 0.65
	_laser_dot_light.omni_range = 1.2
	_laser_dot_light.top_level = true
	_laser_dot_light.visible = false
	add_child(_laser_dot_light)

func _update_laser_visuals() -> void:
	if not is_laser_enabled() or _laser_emitter == null or not is_instance_valid(_laser_emitter) or not is_inside_tree():
		_hide_laser_visuals()
		return

	if _laser_beam == null or _laser_dot == null or _laser_dot_light == null:
		return

	var start_pos: Vector3 = _laser_emitter.global_position
	var ex_rids := _find_shooter_exclude_rids()
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		_hide_laser_visuals()
		return

	var cam := get_viewport().get_camera_3d()
	var hit_pos := Vector3.ZERO
	var hit_norm := Vector3.UP
	var hit_found := false

	var emitter_fwd: Vector3 = (-_laser_emitter.global_transform.basis.z).normalized()
	var beam_dir: Vector3 = emitter_fwd

	var bq := PhysicsRayQueryParameters3D.create(start_pos, start_pos + beam_dir * 100.0)
	bq.collide_with_areas = false
	bq.collide_with_bodies = true
	if not ex_rids.is_empty():
		bq.exclude = ex_rids
	var b_hit: Dictionary = space_state.intersect_ray(bq)
	if not b_hit.is_empty():
		hit_pos = b_hit["position"] as Vector3
		hit_norm = b_hit["normal"] as Vector3
		hit_found = true
	else:
		hit_pos = start_pos + beam_dir * 80.0

	var beam_vec := hit_pos - start_pos
	var forward_proj: float = beam_vec.dot(beam_dir)
	var beam_len := beam_vec.length()

	# Safeguard: if hit is behind emitter or too close, do not draw a backward/clipped beam cylinder
	if forward_proj > 0.05 and beam_len > 0.05:
		_laser_beam.visible = true
		_laser_beam.scale = Vector3(1.0, beam_len, 1.0)
		_laser_beam.global_position = start_pos + beam_vec * 0.5
		var beam_dir_norm := beam_vec / beam_len
		var up_cand := Vector3.UP if absf(beam_dir_norm.y) < 0.98 else Vector3.RIGHT
		_laser_beam.look_at(hit_pos, up_cand)
		_laser_beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	else:
		_laser_beam.visible = false

	if hit_found and forward_proj > 0.03:
		_laser_dot.visible = true
		_laser_dot.global_position = hit_pos + hit_norm * 0.003
		var up_dot := Vector3.UP if absf(hit_norm.y) < 0.98 else Vector3.RIGHT
		_laser_dot.look_at(hit_pos + hit_norm, up_dot)
		_laser_dot.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		_laser_dot_light.visible = true
		_laser_dot_light.global_position = hit_pos + hit_norm * 0.05
	else:
		_laser_dot.visible = false
		_laser_dot_light.visible = false
		_laser_dot_light.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_laser()

func _kill_active_reload() -> void:
	_reload_seq_id += 1
	if _active_reload_tween and _active_reload_tween.is_valid():
		_active_reload_tween.kill()
	_active_reload_tween = null
	is_reloading = false
	_slide_locked_back = has_slide_part and current_ammo <= 0
	if anim_player and anim_player.is_playing():
		anim_player.stop()
	if is_node_ready():
		_reset_subpart_transforms()

func _reset_model_anim() -> void:
	if anim_player and anim_player.is_playing():
		anim_player.stop()
	if model_container:
		model_container.position = rest_model_pos
		model_container.rotation = rest_model_rot
		model_container.scale = Vector3.ONE * viewmodel_scale
	_reset_subpart_transforms()

func _play_anim(anim_name: String) -> void:
	if not anim_player or not model_container:
		return
	if anim_player.has_animation(anim_name):
		anim_player.stop()
		anim_player.play(anim_name)

func _add_vec3_track(anim: Animation, path: String, keys: Array) -> void:
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(path))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for k in keys:
		var t := float(k[0])
		var v: Vector3 = k[1]
		var tr := float(k[2]) if k.size() > 2 else 1.0
		anim.track_insert_key(track, t, v, tr)

func _add_bool_track(anim: Animation, path: String, keys: Array) -> void:
	var track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(path))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for k in keys:
		anim.track_insert_key(track, float(k[0]), bool(k[1]))

func _add_method_track(anim: Animation, node_path: String, calls: Array) -> void:
	var track = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(track, NodePath(node_path))
	for c in calls:
		anim.track_insert_key(track, float(c[0]), {"method": str(c[1]), "args": c[2]})

func _make_pose_anim(length: float, pos_keys: Array, rot_keys: Array, method_calls: Array = []) -> Animation:
	var anim = Animation.new()
	anim.length = length
	_add_vec3_track(anim, "ModelContainer:position", pos_keys)
	_add_vec3_track(anim, "ModelContainer:rotation", rot_keys)
	if not method_calls.is_empty():
		_add_method_track(anim, ".", method_calls)
	return anim

func _anim_cue(cue_name: String) -> void:
	if not is_inside_tree() or not visible:
		return
	match cue_name:
		"mag_out":
			play_sound(snd_mag_out, -6.0)
			recoil_offset.y -= 0.015
			recoil_rotation.x -= 0.025
		"mag_in":
			play_sound(snd_mag_in, -4.0)
			recoil_offset.y += 0.032
			recoil_rotation.x += 0.042
		"bolt_rack":
			play_sound(snd_bolt_rack, -3.0)
			_slide_locked_back = false
			recoil_offset.z += 0.045
			recoil_rotation.x -= deg_to_rad(5.0)
		"cover_open":
			play_sound(ProceduralAudio.get_cached("door_latch"), -7.0)
			recoil_offset.y += 0.016
		"cover_close":
			play_sound(snd_bolt_rack, -2.5)
			recoil_offset.y -= 0.038
			recoil_rotation.x -= deg_to_rad(4.5)
		"shell_in":
			play_sound(snd_mag_in, -7.0)
			recoil_offset.y += 0.018
		"bolt_cycle":
			play_sound(snd_bolt_rack, -5.0)
		"pump":
			play_sound(snd_bolt_rack, -8.0)

func _build_pistol_fire_anim(lock_slide: bool) -> Animation:
	var p0: Vector3 = rest_model_pos
	var r0: Vector3 = rest_model_rot
	var len := 0.16 if lock_slide else 0.15
	var anim := _make_pose_anim(
		len,
		[
			[0.0, p0, 0.28],
			[0.03, p0 + Vector3(0.0, 0.006, 0.028), -2.0],
			[len, p0, 1.0]
		],
		[
			[0.0, r0, 0.28],
			[0.03, r0 + Vector3(deg_to_rad(8.0 if lock_slide else 7.5), 0.0, deg_to_rad(-1.5)), -2.0],
			[len, r0, 1.0]
		]
	)
	if has_slide_part:
		var back_pos := Vector3(0.0, 0.0, _slide_travel)
		if lock_slide:
			_add_vec3_track(anim, "ModelContainer/SlideMesh:position", [
				[0.0, Vector3.ZERO, 0.3],
				[0.024, back_pos, -1.8],
				[len, back_pos, 1.0]
			])
		else:
			_add_vec3_track(anim, "ModelContainer/SlideMesh:position", [
				[0.0, Vector3.ZERO, 0.25],
				[0.022, back_pos, 1.0],
				[0.044, back_pos, -2.0],
				[0.105, Vector3.ZERO, 1.0]
			])
	return anim

func _build_rifle_fire_anim(len: float, kick_z: float, kick_deg: float) -> Animation:
	var p0: Vector3 = rest_model_pos
	var r0: Vector3 = rest_model_rot
	var anim := _make_pose_anim(
		len,
		[
			[0.0, p0, 0.25],
			[0.025, p0 + Vector3(0.0, 0.003, kick_z), -1.8],
			[len, p0, 1.0]
		],
		[
			[0.0, r0, 0.25],
			[0.025, r0 + Vector3(deg_to_rad(kick_deg), 0.0, deg_to_rad(-0.6)), -1.8],
			[len, r0, 1.0]
		]
	)
	if has_bolt_part:
		_add_vec3_track(anim, "ModelContainer/BoltPivot:position", [
			[0.0, _bolt_pivot_pos, 0.25],
			[0.022, _bolt_pivot_pos + Vector3(0.0, 0.0, _bolt_travel), -1.8],
			[minf(len * 0.88, 0.095), _bolt_pivot_pos, 1.0]
		])
	if has_belt_part:
		_add_vec3_track(anim, "ModelContainer/BeltMesh:position", [
			[0.0, Vector3.ZERO, 0.4],
			[0.028, Vector3(0.011, 0.004, 0.0), -1.6],
			[minf(len * 0.82, 0.085), Vector3.ZERO, 1.0]
		])
	return anim

func _build_bolt_cycle_anim() -> Animation:
	var p0: Vector3 = rest_model_pos
	var r0: Vector3 = rest_model_rot
	var anim := _make_pose_anim(
		0.58,
		[
			[0.0, p0, 0.25],
			[0.06, p0 + Vector3(0.0, 0.008, 0.044), -1.6],
			[0.18, p0 + Vector3(-0.018, -0.012, 0.020), -1.6],
			[0.32, p0 + Vector3(-0.014, -0.014, 0.060), -1.6],
			[0.45, p0 + Vector3(-0.006, -0.005, -0.006), -2.0],
			[0.58, p0, 1.0]
		],
		[
			[0.0, r0, 0.25],
			[0.06, r0 + Vector3(deg_to_rad(5.5), 0.0, 0.0), -1.6],
			[0.18, r0 + Vector3(deg_to_rad(4.0), deg_to_rad(-3.0), deg_to_rad(20.0)), -1.6],
			[0.32, r0 + Vector3(deg_to_rad(7.0), deg_to_rad(-2.0), deg_to_rad(24.0)), -1.6],
			[0.45, r0 + Vector3(deg_to_rad(-1.0), 0.0, deg_to_rad(8.0)), -2.0],
			[0.58, r0, 1.0]
		],
		[[0.20, "_anim_cue", ["bolt_cycle"]]]
	)
	if has_bolt_part:
		var lift_rad := deg_to_rad(_bolt_lift_deg)
		_add_vec3_track(anim, "ModelContainer/BoltPivot:rotation", [
			[0.0, Vector3.ZERO, 1.0],
			[0.11, Vector3.ZERO, 0.4],
			[0.20, Vector3(0.0, 0.0, lift_rad), 1.0],
			[0.43, Vector3(0.0, 0.0, lift_rad), 0.4],
			[0.50, Vector3.ZERO, 1.0],
			[0.58, Vector3.ZERO, 1.0]
		])
		_add_vec3_track(anim, "ModelContainer/BoltPivot:position", [
			[0.0, _bolt_pivot_pos, 1.0],
			[0.20, _bolt_pivot_pos, 0.4],
			[0.32, _bolt_pivot_pos + Vector3(0.0, 0.0, _bolt_travel), -1.6],
			[0.43, _bolt_pivot_pos, -1.8],
			[0.58, _bolt_pivot_pos, 1.0]
		])
	return anim

func _build_reload_anim(dur: float, is_empty: bool) -> Animation:
	var p0: Vector3 = rest_model_pos
	var r0: Vector3 = rest_model_rot
	var anim := Animation.new()
	anim.length = dur
	var cues := []

	var is_pistol := (category == "pistol")

	# Base tilt offsets tailored for handgun ergonomics vs shoulder weapons
	var tilt_pos: Vector3 = p0 + (Vector3(-0.024, -0.022, 0.035) if is_pistol else Vector3(-0.028, -0.038, 0.025))
	var tilt_rot: Vector3 = r0 + (Vector3(deg_to_rad(15.0), deg_to_rad(8.0), deg_to_rad(-22.0)) if is_pistol else Vector3(deg_to_rad(10.0), deg_to_rad(-12.0), deg_to_rad(-18.0)))

	if not is_empty:
		# ========================================================
		# 1. MAG RELOAD (Tactical Reload - Round in chamber)
		# ========================================================
		# - Cant & lower gun to inspect magwell
		# - Audio cue: mag_out
		# - Subtle hold / reach for fresh magazine
		# - Downward dip followed by crisp upward seating bump
		# - Audio cue: mag_in
		# - Smooth return to ready aim
		_add_vec3_track(anim, "ModelContainer:position", [
			[0.0, p0, 0.4],
			[0.18 * dur, tilt_pos, 1.0],
			[0.45 * dur, tilt_pos + Vector3(-0.002, -0.004, 0.003), 1.0],
			[0.58 * dur, tilt_pos + Vector3(0.002, -0.014, -0.003), 1.0],
			[0.66 * dur, tilt_pos + Vector3(0.006, 0.016, 0.006), -1.8],
			[0.78 * dur, p0 + (tilt_pos - p0) * 0.35, 1.0],
			[dur, p0, 1.0]
		])
		_add_vec3_track(anim, "ModelContainer:rotation", [
			[0.0, r0, 0.4],
			[0.18 * dur, tilt_rot, 1.0],
			[0.45 * dur, tilt_rot + Vector3(deg_to_rad(1.0), 0.0, 0.0), 1.0],
			[0.58 * dur, tilt_rot + Vector3(deg_to_rad(2.0), 0.0, 0.0), 1.0],
			[0.66 * dur, tilt_rot + Vector3(deg_to_rad(-5.0), deg_to_rad(4.0), deg_to_rad(6.0)), -1.8],
			[0.78 * dur, r0 + (tilt_rot - r0) * 0.3, 1.0],
			[dur, r0, 1.0]
		])
		cues.append([0.18 * dur, "_anim_cue", ["mag_out"]])
		cues.append([0.65 * dur, "_anim_cue", ["mag_in"]])

		# Exposed rounds / ammo belt (M249, PKM): invisible during reload, visible when complete
		if has_belt_part:
			_add_bool_track(anim, "ModelContainer/BeltMesh:visible", [
				[0.0, false],
				[dur, true]
			])
	else:
		# ========================================================
		# 2. FULL RELOAD (Empty Reload - Requires Slide Pull Back)
		# ========================================================
		# - Cant & lower gun to inspect magwell
		# - Audio cue: mag_out
		# - Seat fresh mag with upward seating bump
		# - Audio cue: mag_in
		# - Shift viewmodel to charging handle / slide
		# - Pull back sharply along +Z toward camera/shooter
		# - Audio cue: bolt_rack (slide / bolt pulled back)
		# - Snap forward into battery as action closes
		# - Smooth return to ready aim
		var rack_shift_pos: Vector3 = p0 + (Vector3(-0.012, -0.012, 0.018) if is_pistol else Vector3(-0.012, -0.018, 0.015))
		var rack_shift_rot: Vector3 = r0 + (Vector3(deg_to_rad(8.0), deg_to_rad(4.0), deg_to_rad(-6.0)) if is_pistol else Vector3(deg_to_rad(5.0), deg_to_rad(5.0), deg_to_rad(8.0)))

		var rack_pull_pos: Vector3 = p0 + (Vector3(-0.008, -0.005, 0.052) if is_pistol else Vector3(-0.014, -0.010, 0.062))
		var rack_pull_rot: Vector3 = r0 + (Vector3(deg_to_rad(10.0), deg_to_rad(2.0), deg_to_rad(-3.0)) if is_pistol else Vector3(deg_to_rad(7.0), deg_to_rad(7.0), deg_to_rad(12.0)))

		var rack_slam_pos: Vector3 = p0 + Vector3(0.002, -0.004, -0.008)
		var rack_slam_rot: Vector3 = r0 + Vector3(deg_to_rad(-3.0), deg_to_rad(-1.0), deg_to_rad(-2.0))

		_add_vec3_track(anim, "ModelContainer:position", [
			[0.0, p0, 0.4],
			[0.14 * dur, tilt_pos, 1.0],
			[0.34 * dur, tilt_pos + Vector3(-0.002, -0.004, 0.003), 1.0],
			[0.44 * dur, tilt_pos + Vector3(0.002, -0.012, -0.003), 1.0],
			[0.50 * dur, tilt_pos + Vector3(0.006, 0.016, 0.005), -1.8],
			[0.58 * dur, rack_shift_pos, 1.0],
			[0.68 * dur, rack_pull_pos, 0.4],
			[0.76 * dur, rack_slam_pos, -2.0],
			[0.86 * dur, p0 + Vector3(0.0, -0.002, 0.005), 1.0],
			[dur, p0, 1.0]
		])
		_add_vec3_track(anim, "ModelContainer:rotation", [
			[0.0, r0, 0.4],
			[0.14 * dur, tilt_rot, 1.0],
			[0.34 * dur, tilt_rot + Vector3(deg_to_rad(1.0), 0.0, 0.0), 1.0],
			[0.50 * dur, tilt_rot + Vector3(deg_to_rad(-4.0), deg_to_rad(3.0), deg_to_rad(5.0)), -1.8],
			[0.58 * dur, rack_shift_rot, 1.0],
			[0.68 * dur, rack_pull_rot, 0.4],
			[0.76 * dur, rack_slam_rot, -2.0],
			[0.86 * dur, r0 + Vector3(deg_to_rad(-1.0), 0.0, 0.0), 1.0],
			[dur, r0, 1.0]
		])
		cues.append([0.14 * dur, "_anim_cue", ["mag_out"]])
		cues.append([0.49 * dur, "_anim_cue", ["mag_in"]])
		cues.append([0.68 * dur, "_anim_cue", ["bolt_rack"]])

		# Exposed rounds / ammo belt (M249, PKM): invisible during reload, visible when complete
		if has_belt_part:
			_add_bool_track(anim, "ModelContainer/BeltMesh:visible", [
				[0.0, false],
				[dur, true]
			])

		# Handgun slide pulls back and slams forward on empty reload
		if has_slide_part:
			var back_pos := Vector3(0.0, 0.0, _slide_travel)
			_add_vec3_track(anim, "ModelContainer/SlideMesh:position", [
				[0.0, Vector3.ZERO, 1.0],
				[0.58 * dur, Vector3.ZERO, 0.4],
				[0.68 * dur, back_pos, 1.0],
				[0.76 * dur, Vector3.ZERO, -2.0],
				[dur, Vector3.ZERO, 1.0]
			])

	if not cues.is_empty():
		_add_method_track(anim, ".", cues)
	return anim

func _rebuild_animations() -> void:
	if not anim_player:
		return
	var lib = AnimationLibrary.new()
	var p0 = rest_model_pos
	var r0 = rest_model_rot

	lib.add_animation("pistol_fire", _build_pistol_fire_anim(false))
	lib.add_animation("pistol_fire_last", _build_pistol_fire_anim(true))
	lib.add_animation("rifle_fire", _build_rifle_fire_anim(0.11, 0.022, 1.8))
	lib.add_animation("bolt_cycle", _build_bolt_cycle_anim())
	lib.add_animation("sniper_semi", _build_rifle_fire_anim(0.22, 0.038, 4.2))

	# Pump-action shotgun rack
	lib.add_animation("shotgun_pump", _make_pose_anim(
		0.42,
		[
			[0.0, p0, 0.28],
			[0.05, p0 + Vector3(0.0, 0.006, 0.040), -1.6],
			[0.16, p0 + Vector3(-0.015, -0.012, 0.015), -1.6],
			[0.25, p0 + Vector3(-0.012, -0.015, 0.058), -1.6],
			[0.34, p0 + Vector3(-0.006, -0.005, -0.010), -2.0],
			[0.42, p0, 1.0]
		],
		[
			[0.0, r0, 0.28],
			[0.05, r0 + Vector3(deg_to_rad(6.0), 0.0, 0.0), -1.6],
			[0.16, r0 + Vector3(deg_to_rad(3.0), 0.0, deg_to_rad(12.0)), -1.6],
			[0.25, r0 + Vector3(deg_to_rad(6.5), 0.0, deg_to_rad(16.0)), -1.6],
			[0.34, r0 + Vector3(deg_to_rad(-1.5), 0.0, deg_to_rad(6.0)), -2.0],
			[0.42, r0, 1.0]
		],
		[[0.18, "_anim_cue", ["pump"]]]
	))

	# Semi-auto / automatic shotgun kick
	lib.add_animation("shotgun_semi", _make_pose_anim(
		0.20,
		[
			[0.0, p0, 0.28],
			[0.04, p0 + Vector3(0.0, 0.006, 0.036), -1.8],
			[0.20, p0, 1.0]
		],
		[
			[0.0, r0, 0.28],
			[0.04, r0 + Vector3(deg_to_rad(5.0), 0.0, deg_to_rad(-1.5)), -1.8],
			[0.20, r0, 1.0]
		]
	))

	# Heavy rocket / 40mm launcher kick
	lib.add_animation("launcher_fire", _make_pose_anim(
		0.28,
		[
			[0.0, p0, 0.25],
			[0.06, p0 + Vector3(0.0, 0.012, 0.065), -2.0],
			[0.28, p0, 1.0]
		],
		[
			[0.0, r0, 0.25],
			[0.06, r0 + Vector3(deg_to_rad(6.0), 0.0, deg_to_rad(-2.0)), -2.0],
			[0.28, r0, 1.0]
		]
	))

	# Simplified, consistent reload animations (pure gun movements + slide rack on empty)
	var tact_len := maxf(tactical_reload_time, 0.5)
	var empty_len := maxf(empty_reload_time, 0.6)
	lib.add_animation("reload_tactical", _build_reload_anim(tact_len, false))
	lib.add_animation("reload_empty", _build_reload_anim(empty_len, true))

	# Hand grenade throw arc
	lib.add_animation("grenade_throw", _make_pose_anim(
		0.36,
		[
			[0.0, p0, 0.5],
			[0.07, p0 + Vector3(0.02, 0.03, 0.05), 0.35],
			[0.16, p0 + Vector3(-0.16, 0.02, -0.16), -2.0],
			[0.36, p0, 1.0]
		],
		[
			[0.0, r0, 0.5],
			[0.07, r0 + Vector3(deg_to_rad(22.0), deg_to_rad(-6.0), 0.0), 0.35],
			[0.16, r0 + Vector3(deg_to_rad(-44.0), deg_to_rad(16.0), deg_to_rad(10.0)), -2.0],
			[0.36, r0, 1.0]
		]
	))

	# Melee swipe: strictly inward from right hip to screen center (never swinging to +X right side)
	if aabb_size.y > 0.40:
		lib.add_animation("melee_swipe", _make_pose_anim(
			0.28,
			[
				[0.0, p0, 0.35],
				[0.09, p0 + Vector3(-0.21, 0.08, -0.14), -2.0],
				[0.28, p0, 1.0]
			],
			[
				[0.0, r0, 0.35],
				[0.09, r0 + Vector3(deg_to_rad(-52.0), deg_to_rad(28.0), deg_to_rad(28.0)), -2.0],
				[0.28, r0, 1.0]
			]
		))
	else:
		lib.add_animation("melee_swipe", _make_pose_anim(
			0.28,
			[
				[0.0, p0, 0.35],
				[0.04, p0 + Vector3(-0.08, 0.06, -0.07), 0.7],
				[0.095, p0 + Vector3(-0.23, 0.10, -0.14), -2.0],
				[0.28, p0, 1.0]
			],
			[
				[0.0, r0, 0.35],
				[0.04, r0 + Vector3(deg_to_rad(-12.0), deg_to_rad(24.0), deg_to_rad(26.0)), 0.7],
				[0.095, r0 + Vector3(deg_to_rad(-28.0), deg_to_rad(60.0), deg_to_rad(56.0)), -2.0],
				[0.28, r0, 1.0]
			]
		))

	# Riot shield bash lunge
	lib.add_animation("shield_bash", _make_pose_anim(
		0.34,
		[
			[0.0, p0, 0.35],
			[0.10, p0 + Vector3(0.05, 0.02, -0.30), -2.0],
			[0.34, p0, 1.0]
		],
		[
			[0.0, r0, 0.35],
			[0.10, r0 + Vector3(deg_to_rad(-8.0), deg_to_rad(-10.0), deg_to_rad(6.0)), -2.0],
			[0.34, r0, 1.0]
		]
	))

	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", lib)

func holster() -> Tween:
	_kill_active_reload()
	_reset_model_anim()
	set_scope_view_hidden(false)
	_hide_laser_visuals()
	return super.holster()

func draw_weapon() -> Tween:
	_kill_active_reload()
	_reset_model_anim()
	set_scope_view_hidden(false)
	visible = true
	if weapon_mesh and not is_grenade:
		weapon_mesh.visible = true
	elif weapon_mesh and is_grenade:
		weapon_mesh.visible = (current_ammo > 0)
	is_switching = true
	ads_blend = 0.0
	recoil_offset.y = -0.35
	recoil_rotation.x = deg_to_rad(-20.0)

	var tween = create_tween()
	tween.tween_property(self, "recoil_offset:y", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "recoil_rotation:x", 0.0, 0.22)
	tween.tween_callback(_on_draw_finished)
	return tween

func _on_draw_finished() -> void:
	if not is_melee and not is_shield and not is_grenade:
		play_sound(snd_mag_out, -10.0)
	elif is_melee:
		play_sound(ProceduralAudio.get_cached("melee"), -14.0)
	is_switching = false

func shoot(camera: Camera3D) -> bool:
	if is_melee:
		return _shoot_melee(camera)
	if is_shield:
		return _shoot_shield_bash(camera)
	if is_grenade:
		return _shoot_hand_grenade(camera)

	if not can_fire or is_reloading or is_sprinting or is_switching or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading and not is_sprinting and not is_switching:
			reload()
		return false

	can_fire = false
	current_ammo -= 1
	fired.emit(current_ammo)

	if not is_aiming:
		var bloom = shot_spread_bloom * (0.35 if is_crouching else 1.0)
		current_spread = clampf(current_spread + bloom, 0.0, max_spread)

	match category:
		"launcher":
			_shoot_launcher(camera)
		"shotgun":
			_shoot_shotgun(camera)
		"sniper":
			_apply_recoil(0.14, 0.09)
			_flash_muzzle()
			_play_shoot_audio()
			_perform_raycast_with_impulse(camera, physics_impulse_mult, 0.0 if is_aiming else current_spread)
			if fire_rate >= 0.85:
				_play_anim("bolt_cycle")
			else:
				_play_anim("sniper_semi")
		"pistol":
			_apply_recoil(0.045, 0.045)
			_flash_muzzle()
			_play_shoot_audio()
			_perform_raycast_with_impulse(camera, physics_impulse_mult, 0.0 if is_aiming else current_spread)
			if has_bolt_part and _bolt_lift_deg > 0.1 and fire_rate >= 0.7:
				_play_anim("bolt_cycle")
			elif has_slide_part and current_ammo <= 0:
				_slide_locked_back = true
				_play_anim("pistol_fire_last")
			else:
				_play_anim("pistol_fire")
		"lmg":
			_apply_recoil(0.065, 0.045)
			_flash_muzzle()
			_play_shoot_audio()
			_perform_raycast_with_impulse(camera, physics_impulse_mult, current_spread * (0.18 if is_aiming else 1.0))
			_play_anim("rifle_fire")
		_:
			# rifle / smg
			var kick_z = 0.032 if category == "smg" else 0.055
			var kick_p = 0.025 if category == "smg" else 0.038
			_apply_recoil(kick_z, kick_p)
			_flash_muzzle()
			_play_shoot_audio()
			_perform_raycast_with_impulse(camera, physics_impulse_mult, 0.0 if is_aiming else current_spread)
			_play_anim("rifle_fire")

	get_tree().create_timer(fire_rate).timeout.connect(_on_fire_cooldown)
	return true

func _apply_recoil(base_z: float, base_pitch: float) -> void:
	var mult = 0.55 if is_aiming else (0.75 if is_crouching else 1.0)
	if is_suppressed:
		mult *= 0.85
	recoil_offset.z += base_z * mult
	recoil_rotation.x += base_pitch * mult
	recoil_rotation.y += randf_range(-0.012, 0.012) * mult
	recoil_rotation.z += randf_range(-0.009, 0.009) * mult

func _flash_muzzle() -> void:
	if is_scope_hidden:
		return
	if muzzle_flash and muzzle_flash.has_method("flash"):
		muzzle_flash.flash()

func _find_shooter_exclude_rids() -> Array[RID]:
	var out: Array[RID] = []
	var p: Node = get_parent()
	while p:
		if p is CollisionObject3D:
			out.append(p.get_rid())
		p = p.get_parent()
	if out.is_empty():
		var player := get_tree().get_first_node_in_group("player")
		if player is CollisionObject3D:
			out.append(player.get_rid())
	return out

func launch_grenade(camera: Camera3D) -> bool:
	if not has_grenade_launcher or not can_fire_grenade or is_sprinting or is_switching or current_grenades <= 0:
		return false

	can_fire_grenade = false
	current_grenades -= 1
	grenade_fired.emit(current_grenades)

	recoil_offset.z += 0.16
	recoil_rotation.x += 0.12
	recoil_rotation.y += randf_range(-0.025, 0.025)
	_play_anim("launcher_fire")

	if grenade_sound:
		if grenade_sound.stream == null:
			grenade_sound.stream = ProceduralAudio.get_cached("grenade_launcher")
		grenade_sound.pitch_scale = randf_range(0.95, 1.05)
		grenade_sound.play()

	var ex_rids := _find_shooter_exclude_rids()
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z
	var space_state = camera.get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(origin, origin + forward * 120.0)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if not ex_rids.is_empty():
		q.exclude = ex_rids
	var aim_hit = space_state.intersect_ray(q)

	var spawn_dist = 0.55
	if aim_hit and origin.distance_to(aim_hit.position) < 0.8:
		spawn_dist = 0.15
	var spawn_pos = origin + forward * spawn_dist - camera.global_transform.basis.y * 0.05

	var launch_dir = forward
	if aim_hit and origin.distance_to(aim_hit.position) > 1.8:
		launch_dir = (aim_hit.position - spawn_pos).normalized()

	var g = GRENADE_SCENE.instantiate()
	g.explode_on_contact = true
	g.grenade_type = "frag"
	g.set_shooter_exclude(ex_rids)
	var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	spawn_parent.add_child(g)
	g.global_position = spawn_pos
	var arc_dir = (launch_dir + camera.global_transform.basis.y * 0.045).normalized()
	g.launch(arc_dir, 36.0)
	g.grenade_hit_target.connect(_on_projectile_hit_target)

	get_tree().create_timer(grenade_cooldown).timeout.connect(_on_grenade_cooldown)
	return true

func _play_shoot_audio() -> void:
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.95, 1.05)
		shoot_sound.play()

func _perform_raycast_with_impulse(camera: Camera3D, impulse_mult: float, spread_rad: float) -> bool:
	var space_state = camera.get_world_3d().direct_space_state
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z

	if is_suppressed and spread_rad > 0.0001:
		spread_rad *= 0.85

	if spread_rad > 0.0001:
		var rand_angle = randf() * TAU
		var rand_dist = sqrt(randf()) * spread_rad
		forward += camera.global_transform.basis.x * (cos(rand_angle) * rand_dist)
		forward += camera.global_transform.basis.y * (sin(rand_angle) * rand_dist)
		forward = forward.normalized()

	var ex_rids := _find_shooter_exclude_rids()
	var target = origin + forward * max_range
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if not ex_rids.is_empty():
		query.exclude = ex_rids

	var result = space_state.intersect_ray(query)
	if result:
		var hit_collider = result.collider
		var hit_pos = result.position
		var hit_normal = result.normal

		spawn_impact_effect(hit_pos, hit_normal)

		var damaged_target = false
		var shot_dir = (target - origin).normalized()
		if hit_collider.has_method("take_damage"):
			hit_collider.take_damage(damage, hit_pos, shot_dir)
			damaged_target = true
		elif hit_collider.has_meta("target_root"):
			var root = hit_collider.get_meta("target_root")
			if root and root.has_method("take_damage"):
				root.take_damage(damage, hit_pos, shot_dir)
				damaged_target = true
		elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
			hit_collider.get_parent().take_damage(damage, hit_pos, shot_dir)
			damaged_target = true

		if hit_collider is RigidBody3D:
			var local_offset = hit_pos - hit_collider.global_position
			hit_collider.apply_impulse(shot_dir * (damage * impulse_mult), local_offset)

		if damaged_target:
			hit_target.emit(100)
			return true
	return false

func _shoot_shotgun(camera: Camera3D) -> void:
	_apply_recoil(0.13, 0.085)
	_flash_muzzle()
	_play_shoot_audio()
	_play_anim("shotgun_pump" if fire_rate >= 0.50 else "shotgun_semi")

	var cone = 0.024 if is_aiming else maxf(current_spread, 0.048)
	var ex_rids := _find_shooter_exclude_rids()
	var space_state = camera.get_world_3d().direct_space_state
	var origin = camera.global_position
	var cam_fwd = -camera.global_transform.basis.z
	var cam_right = camera.global_transform.basis.x
	var cam_up = camera.global_transform.basis.y
	var any_damaged = false

	for i in range(pellet_count):
		var a = randf() * TAU
		var d = sqrt(randf()) * cone
		var ray_dir = (cam_fwd + cam_right * (cos(a) * d) + cam_up * (sin(a) * d)).normalized()
		var target = origin + ray_dir * 85.0
		var q = PhysicsRayQueryParameters3D.create(origin, target)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		if not ex_rids.is_empty():
			q.exclude = ex_rids
		var res = space_state.intersect_ray(q)
		if res:
			var col = res.collider
			var hpos = res.position
			spawn_impact_effect(hpos, res.normal)
			if col.has_method("take_damage"):
				col.take_damage(damage, hpos, ray_dir)
				any_damaged = true
			elif col.has_meta("target_root"):
				var root = col.get_meta("target_root")
				if root and root.has_method("take_damage"):
					root.take_damage(damage, hpos, ray_dir)
					any_damaged = true
			elif col.get_parent() and col.get_parent().has_method("take_damage"):
				col.get_parent().take_damage(damage, hpos, ray_dir)
				any_damaged = true

			if col is RigidBody3D:
				col.apply_impulse(ray_dir * (damage * physics_impulse_mult), hpos - col.global_position)

	if any_damaged:
		hit_target.emit(120)

func _shoot_launcher(camera: Camera3D) -> void:
	_play_shoot_audio()
	_play_anim("launcher_fire")
	var origin = camera.global_position
	var forward = -camera.global_transform.basis.z

	var ex_rids := _find_shooter_exclude_rids()
	var space_state = camera.get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(origin, origin + forward * 120.0)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if not ex_rids.is_empty():
		q.exclude = ex_rids
	var aim_hit = space_state.intersect_ray(q)

	var spawn_dist = 0.55
	if aim_hit and origin.distance_to(aim_hit.position) < 0.8:
		spawn_dist = 0.15
	var spawn_pos = origin + forward * spawn_dist

	var launch_dir = forward
	if aim_hit and origin.distance_to(aim_hit.position) > 1.8:
		launch_dir = (aim_hit.position - spawn_pos).normalized()

	var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if launcher_mode == "grenade_launcher":
		_apply_recoil(0.16, 0.11)
		var g = GRENADE_SCENE.instantiate()
		g.max_damage = damage
		g.explode_on_contact = true
		g.grenade_type = "frag"
		g.set_shooter_exclude(ex_rids)
		spawn_parent.add_child(g)
		g.global_position = spawn_pos
		var arc_dir = (launch_dir + camera.global_transform.basis.y * 0.045).normalized()
		g.launch(arc_dir, 36.0)
		g.grenade_hit_target.connect(_on_projectile_hit_target)
	else:
		_apply_recoil(0.25, 0.18)
		_flash_muzzle()
		var r = ROCKET_SCENE.instantiate()
		r.max_damage = damage
		spawn_parent.add_child(r)
		if projectile_mesh_path != "" and ResourceLoader.exists(projectile_mesh_path):
			r.set_custom_mesh(load(projectile_mesh_path) as Mesh)
		r.global_position = spawn_pos
		r.launch(launch_dir, 75.0)
		r.rocket_hit_target.connect(_on_projectile_hit_target)

func _get_hand_grenade_fuse() -> float:
	match grenade_type:
		"smoke":
			return 1.7
		"flash":
			return 1.6
		_:
			return 2.6

func _shoot_hand_grenade(camera: Camera3D) -> bool:
	if not can_fire or is_reloading or is_switching or current_ammo <= 0:
		if current_ammo <= 0 and not is_reloading and not is_switching:
			ProceduralAudio.play_click(self, 440.0, 0.08)
			_notify_player("No grenades left! Resupply at Ammo Crate.")
		return false

	can_fire = false
	current_ammo -= 1
	fired.emit(current_ammo)

	_play_shoot_audio()
	_play_anim("grenade_throw")
	recoil_offset.z -= 0.08
	recoil_rotation.x -= 0.12

	var ex_rids := _find_shooter_exclude_rids()
	var origin := camera.global_position
	var cam_fwd := -camera.global_transform.basis.z
	var cam_right := camera.global_transform.basis.x
	var cam_up := camera.global_transform.basis.y
	var desired_spawn := origin + cam_fwd * 0.45 + cam_right * 0.12 - cam_up * 0.05

	# Clamp spawn outside adjacent wall / closed door so close throws always bounce off the obstacle cleanly
	var space_state := camera.get_world_3d().direct_space_state
	var obs_q := PhysicsRayQueryParameters3D.create(origin, desired_spawn + cam_fwd * 0.12)
	obs_q.collide_with_areas = false
	obs_q.collide_with_bodies = true
	if not ex_rids.is_empty():
		obs_q.exclude = ex_rids
	var obs_hit := space_state.intersect_ray(obs_q)
	var spawn_pos := desired_spawn
	if not obs_hit.is_empty():
		var to_hit: Vector3 = obs_hit.position - origin
		var hit_len := to_hit.length()
		var dir := (to_hit / maxf(hit_len, 0.001))
		spawn_pos = obs_hit.position - dir * 0.065 if hit_len > 0.08 else origin + dir * 0.02

	var fuse := _get_hand_grenade_fuse()
	var g = GRENADE_SCENE.instantiate()
	g.grenade_type = grenade_type
	g.explode_on_contact = false
	g.fuse_time = fuse
	g.restitution = 0.44
	g.friction = 0.74
	g.max_damage = damage if grenade_type == "frag" else 5.0
	g.explosion_radius = 13.0 if grenade_type == "frag" else 16.0
	g.set_shooter_exclude(ex_rids)

	var spawn_parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	spawn_parent.add_child(g)
	if weapon_mesh_path != "" and ResourceLoader.exists(weapon_mesh_path):
		g.set_custom_mesh(load(weapon_mesh_path) as Mesh, true)
	g.global_position = spawn_pos

	# RMB / Z held = gentle underhand lob; default LMB = full overhand throw
	var throw_speed := 11.5 if is_aiming else 21.0
	var lift := 0.24 if is_aiming else 0.18
	var throw_dir := (cam_fwd + cam_up * lift).normalized()
	g.launch(throw_dir, throw_speed)
	g.grenade_hit_target.connect(_on_projectile_hit_target)

	if weapon_mesh:
		weapon_mesh.visible = false
	if current_ammo > 0:
		get_tree().create_timer(0.45).timeout.connect(_show_held_grenade)

	get_tree().create_timer(fire_rate).timeout.connect(_on_fire_cooldown)
	return true

func _show_held_grenade() -> void:
	if weapon_mesh and current_ammo > 0:
		weapon_mesh.visible = true

func _shoot_melee(camera: Camera3D) -> bool:
	if not can_fire or is_switching:
		return false
	can_fire = false

	if shoot_sound:
		shoot_sound.stream = ProceduralAudio.get_cached("melee")
		shoot_sound.pitch_scale = randf_range(0.92, 1.08)
		shoot_sound.play()

	_play_anim("melee_swipe")

	recoil_offset.z -= 0.04
	recoil_rotation.y += 0.03

	_perform_melee_sweep(camera, 2.8, 0.42, "melee_hit")
	get_tree().create_timer(fire_rate).timeout.connect(_on_fire_cooldown)
	return true

func _shoot_shield_bash(camera: Camera3D) -> bool:
	if not can_fire or is_switching:
		return false
	can_fire = false

	if shoot_sound:
		shoot_sound.stream = ProceduralAudio.get_cached("shield")
		shoot_sound.pitch_scale = randf_range(0.94, 1.06)
		shoot_sound.play()

	_play_anim("shield_bash")

	recoil_offset.z -= 0.07
	recoil_rotation.x -= 0.04

	_perform_melee_sweep(camera, 2.6, 0.55, "")
	get_tree().create_timer(fire_rate).timeout.connect(_on_fire_cooldown)
	return true

func _perform_melee_sweep(camera: Camera3D, reach: float, radius: float, hit_sound_key: String) -> void:
	var space_state = camera.get_world_3d().direct_space_state
	var origin = camera.global_position
	var fwd = -camera.global_transform.basis.z
	var ex_rids := _find_shooter_exclude_rids()

	var ray_q = PhysicsRayQueryParameters3D.create(origin, origin + fwd * reach)
	ray_q.collide_with_areas = false
	ray_q.collide_with_bodies = true
	if not ex_rids.is_empty():
		ray_q.exclude = ex_rids
	var ray_hit = space_state.intersect_ray(ray_q)

	var processed = {}
	var hit_any_geometry = false
	var damaged_any = false

	if ray_hit:
		hit_any_geometry = true
		spawn_impact_effect(ray_hit.position, ray_hit.normal)
		if _apply_melee_hit_to_collider(ray_hit.collider, ray_hit.position, fwd, processed):
			damaged_any = true

	# Wide sweep at half/full reach so melee & shield bash feel responsive
	for step_dist in [reach * 0.55, reach * 0.9]:
		var sq = PhysicsShapeQueryParameters3D.new()
		var sp = SphereShape3D.new()
		sp.radius = radius
		sq.shape = sp
		sq.transform = Transform3D(Basis(), origin + fwd * step_dist)
		sq.collide_with_areas = false
		sq.collide_with_bodies = true
		if not ex_rids.is_empty():
			sq.exclude = ex_rids
		var hits = space_state.intersect_shape(sq, 16)
		for res in hits:
			var col = res.collider
			if col.is_in_group("player"):
				continue
			if _apply_melee_hit_to_collider(col, origin + fwd * step_dist, fwd, processed):
				damaged_any = true
				hit_any_geometry = true

	if hit_any_geometry and hit_sound_key != "":
		play_sound(ProceduralAudio.get_cached(hit_sound_key), -4.0)
	if damaged_any:
		hit_target.emit(125)

func _apply_melee_hit_to_collider(col: Object, hit_pos: Vector3, fwd: Vector3, processed: Dictionary) -> bool:
	if col == null:
		return false
	var id = col.get_instance_id()
	if processed.has(id):
		return false
	processed[id] = true

	var damaged = false
	var target_root: Node = null
	if col.has_method("take_damage"):
		target_root = col
	elif col.has_meta("target_root"):
		target_root = col.get_meta("target_root")
	elif col.get_parent() and col.get_parent().has_method("take_damage"):
		target_root = col.get_parent()

	if target_root:
		var root_id = target_root.get_instance_id()
		if not processed.has(root_id) or target_root == col:
			processed[root_id] = true
			target_root.take_damage(damage, hit_pos, fwd)
			damaged = true

	if col is RigidBody3D:
		col.apply_impulse((fwd + Vector3.UP * 0.25).normalized() * (damage * physics_impulse_mult), hit_pos - col.global_position)
		damaged = true

	return damaged

func _on_projectile_hit_target(pts: int) -> void:
	hit_target.emit(pts)

func _notify_player(msg: String) -> void:
	var p: Node = get_parent()
	while p and not p.is_in_group("player"):
		p = p.get_parent()
	if p and p.has_method("_show_hud_warning"):
		p._show_hud_warning(msg)

func reload() -> void:
	if is_melee or is_shield or is_grenade or max_ammo <= 0:
		return
	if is_reloading or is_switching or current_ammo >= max_ammo:
		return
	if get_total_reserve_ammo() <= 0:
		ProceduralAudio.play_click(self, 480.0, 0.08)
		_notify_player("Out of reserve ammo! Resupply at Ammo Crate.")
		return
	_kill_active_reload()
	_reset_model_anim()
	super.reload()

func perform_tactical_reload() -> void:
	var seq := _reload_seq_id
	var dur := maxf(tactical_reload_time, 0.5)
	_play_anim("reload_tactical")
	var t = create_tween()
	_active_reload_tween = t
	t.tween_interval(dur)
	t.tween_callback(_finish_reload.bind(seq))

func perform_empty_reload() -> void:
	var seq := _reload_seq_id
	var dur := maxf(empty_reload_time, 0.6)
	_play_anim("reload_empty")
	var t = create_tween()
	_active_reload_tween = t
	t.tween_interval(dur)
	t.tween_callback(_finish_reload.bind(seq))

func _finish_reload(seq_id: int) -> void:
	if seq_id != _reload_seq_id or not is_inside_tree():
		return
	_active_reload_tween = null
	_slide_locked_back = false
	_apply_tactical_mag_swap()
	is_reloading = false
	if weapon_mesh and is_grenade:
		weapon_mesh.visible = true
	_reset_model_anim()
	reloaded.emit(current_ammo)

func refill_all() -> bool:
	if is_melee or is_shield or max_ammo <= 0:
		return false
	var changed = super.refill_all()
	if changed:
		_slide_locked_back = false
		_reset_subpart_transforms()
		if is_grenade and weapon_mesh:
			weapon_mesh.visible = true
	return changed
