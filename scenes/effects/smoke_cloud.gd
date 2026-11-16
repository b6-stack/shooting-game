extends Node3D

const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

@export var cloud_radius: float = 3.8
@export var hold_duration: float = 11.5
@export var fade_duration: float = 3.5

var _puffs: Array = []
var _puff_mats: Array = []
var _elapsed: float = 0.0
var _hiss_player: AudioStreamPlayer3D

func _ready() -> void:
	# Volumetric-feeling low-poly billboard/sphere cluster that works reliably on Mobile renderer
	var shared_sphere := SphereMesh.new()
	shared_sphere.radius = 1.0
	shared_sphere.height = 2.0
	shared_sphere.radial_segments = 10
	shared_sphere.rings = 6

	var num_puffs := 26
	for i in range(num_puffs):
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.no_depth_test = false
		var shade := randf_range(0.66, 0.84)
		mat.albedo_color = Color(shade, shade + 0.02, shade + 0.04, 0.0)

		var mi := MeshInstance3D.new()
		mi.mesh = shared_sphere
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var ring_ang := float(i) / float(num_puffs) * TAU + randf_range(-0.25, 0.25)
		var ring_dist := (0.14 if i < 6 else randf_range(0.30, 0.90)) * cloud_radius
		var puff_h := randf_range(0.55, 2.35) if i >= 4 else randf_range(0.85, 1.95)
		var base_pos := Vector3(cos(ring_ang) * ring_dist, puff_h, sin(ring_ang) * ring_dist)
		var target_scale := randf_range(1.30, 2.25) * (cloud_radius / 3.8)
		mi.position = base_pos * 0.25
		mi.scale = Vector3.ONE * 0.35
		add_child(mi)

		_puffs.append({
			"node": mi,
			"base_pos": base_pos,
			"target_scale": target_scale,
			"target_alpha": randf_range(0.84, 0.96) if i < 8 else randf_range(0.68, 0.88),
			"phase": randf() * TAU,
			"drift": randf_range(0.5, 1.1)
		})
		_puff_mats.append(mat)

	# Soft rising smoke particles on top of the core volume
	var gp := GPUParticles3D.new()
	gp.amount = 32
	gp.lifetime = 2.8
	gp.explosiveness = 0.15
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 85.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, 0.35, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.6
	pm.scale_min = 1.8
	pm.scale_max = 3.2
	gp.process_material = pm

	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.albedo_color = Color(0.78, 0.81, 0.84, 0.38)
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 1.4)
	qm.material = qmat
	gp.draw_pass_1 = qm
	add_child(gp)

	_hiss_player = AudioStreamPlayer3D.new()
	_hiss_player.stream = ProceduralAudio.get_cached("smoke_hiss")
	_hiss_player.unit_size = 18.0
	_hiss_player.max_distance = 75.0
	_hiss_player.volume_db = -3.0
	add_child(_hiss_player)
	_hiss_player.play()

	get_tree().create_timer(hold_duration + fade_duration).timeout.connect(queue_free)

func _process(delta: float) -> void:
	_elapsed += delta
	var expand_t := clampf(_elapsed / 1.15, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - expand_t, 2.5)
	var fade_mult := 1.0
	if _elapsed > hold_duration:
		fade_mult = clampf(1.0 - (_elapsed - hold_duration) / maxf(fade_duration, 0.1), 0.0, 1.0)

	for i in range(_puffs.size()):
		var p: Dictionary = _puffs[i]
		var mi: MeshInstance3D = p["node"]
		var mat: StandardMaterial3D = _puff_mats[i]
		var base_pos: Vector3 = p["base_pos"]
		var ph: float = p["phase"]
		var spd: float = p["drift"]

		var sway := Vector3(sin(_elapsed * spd + ph) * 0.28, sin(_elapsed * 0.8 + ph) * 0.15, cos(_elapsed * spd + ph) * 0.28)
		mi.position = base_pos * ease_out + sway * expand_t
		var sc: float = lerpf(0.35, p["target_scale"], ease_out) * (1.0 + (1.0 - fade_mult) * 0.35)
		mi.scale = Vector3(sc, sc * 0.84, sc)
		mat.albedo_color.a = p["target_alpha"] * minf(expand_t * 1.4, 1.0) * fade_mult
