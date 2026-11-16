extends RefCounted

const OPTIC_NONE := ""
const OPTIC_AIMPOINT := "aimpoint"
const OPTIC_ACOG := "acog"
const OPTIC_SCOPE := "scope"
const OPTIC_ORDER: Array[String] = ["", "aimpoint", "acog", "scope"]

const OPTIC_LABELS := {
	"": "Iron / Stock",
	"aimpoint": "Aimpoint RDS",
	"acog": "ACOG 4x",
	"scope": "Tactical Scope"
}

const OPTIC_CENTER_HEIGHT := 0.048
const SUPPRESSOR_OVERLAP_Z := 0.014

# Exact geometry-verified mount coordinates measured against every weapon .res mesh.
# rail: top flat Picatinny y & ideal center z (optical centerline sits at rail.y + OPTIC_CENTER_HEIGHT)
# suppressor: bore axis y & muzzle z crown tip
# ugl: handguard bottom contact y & safe center z clear of magazine well
const MOUNT_SPECS := {
	# ===== BUILT-IN SCOPED WEAPONS (6) =====
	"g36_k": {
		"built_in_scope": "acog",
		"ads_y": -0.118,
		"ads_fov": 34.0,
		"zoom_label": "3.5x",
		"suppressor": Vector3(0.0, 0.038, -0.546),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.005, -0.290),
		"laser": Vector3(0.020, 0.045, -0.28),
		"laser_style": "peq15",
	},
	"steyr_aug_a3": {
		"built_in_scope": "aug",
		"ads_y": -0.128,
		"ads_fov": 34.0,
		"zoom_label": "3x",
		"suppressor": Vector3(0.0, 0.055, -0.507),
		"suppressor_style": "rifle",
		"laser": Vector3(0.026, 0.035, -0.22),
		"laser_style": "peq15",
	},
	"hk_g28": {
		"built_in_scope": "sniper",
		"ads_y": -0.111,
		"ads_fov": 24.0,
		"zoom_label": "6x",
		"suppressor": Vector3(0.0, 0.008, -0.650),
		"suppressor_style": "sniper",
		"laser": Vector3(0.026, 0.092, -0.28),
		"laser_style": "peq15",
	},
	"barret_m82a1": {
		"built_in_scope": "sniper",
		"ads_y": -0.087,
		"ads_fov": 16.0,
		"zoom_label": "10x",
		"laser": Vector3(0.021, 0.020, -0.26),
		"laser_style": "peq15",
	},
	"blaser_r93": {
		"built_in_scope": "sniper",
		"ads_y": -0.123,
		"ads_fov": 19.0,
		"zoom_label": "8x",
		"suppressor": Vector3(0.0, 0.054, -0.7475),
		"suppressor_style": "sniper",
	},
	"remington_scoplu_applied": {
		"built_in_scope": "sniper",
		"ads_y": -0.105,
		"ads_fov": 20.0,
		"zoom_label": "8x",
		"suppressor": Vector3(0.0, 0.025, -0.741),
		"suppressor_style": "sniper",
		"laser": Vector3(0.025, 0.098, -0.24),
		"laser_style": "peq15",
	},

	# ===== INTEGRALLY SUPPRESSED =====
	"vss_vintorez": {
		"already_suppressed": true,
	},
	"pss_assassin_pistol": {
		"already_suppressed": true,
	},
	"weldrod_mark1": {
		"already_suppressed": true,
	},

	# ===== SUPPRESSABLE PISTOLS (14) =====
	"glock_17": {
		"suppressor": Vector3(0.0, 0.0595, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.031, -0.080),
		"laser_style": "pistol",
	},
	"beretta_m9": {
		"suppressor": Vector3(0.0, 0.0628, -0.120),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.032, -0.078),
		"laser_style": "pistol",
	},
	"baretta_93_r": {
		"suppressor": Vector3(0.0, 0.0774, -0.125),
		"suppressor_style": "pistol",
	},
	"hk_usp": {
		"suppressor": Vector3(0.0, 0.0620, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.018, -0.080),
		"laser_style": "pistol",
	},
	"hk_45": {
		"suppressor": Vector3(0.0, 0.0624, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.026, -0.080),
		"laser_style": "pistol",
	},
	"hk_mark23": {
		"suppressor": Vector3(0.0, 0.0572, -0.130),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.021, -0.086),
		"laser_style": "pistol",
	},
	"tarran_tactical": {
		"suppressor": Vector3(0.0, 0.0625, -0.120),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.031, -0.082),
		"laser_style": "pistol",
	},
	"sig_saguer_p226": {
		"suppressor": Vector3(0.0, 0.0651, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.028, -0.072),
		"laser_style": "pistol",
	},
	"canit_tp9_elite_combat": {
		"suppressor": Vector3(0.0, 0.0693, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.034, -0.072),
		"laser_style": "pistol",
	},
	"cz_75": {
		"suppressor": Vector3(0.0, 0.0570, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.027, -0.078),
		"laser_style": "pistol",
	},
	"cz_75_auto": {
		"suppressor": Vector3(0.0, 0.0668, -0.125),
		"suppressor_style": "pistol",
	},
	"x13": {
		"suppressor": Vector3(0.0, 0.0600, -0.115),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.021, -0.080),
		"laser_style": "pistol",
	},
	"government": {
		"suppressor": Vector3(0.0, 0.0560, -0.116),
		"suppressor_style": "pistol",
		"laser": Vector3(0.0, 0.030, -0.084),
		"laser_style": "pistol",
	},
	"makarov": {
		"suppressor": Vector3(0.0, 0.0598, -0.100),
		"suppressor_style": "pistol",
	},
	"desert_eagle": {
		"laser": Vector3(0.0, 0.030, -0.086),
		"laser_style": "pistol",
	},

	# ===== RAILED RIFLES (All 3 optics) =====
	"colt_m4a1": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.109, -0.085),
		"suppressor": Vector3(0.0, 0.070, -0.533),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.036, -0.290),
		"laser": Vector3(0.038, 0.074, -0.25),
		"laser_style": "peq15",
	},
	"fn_scar_l": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.097, -0.110),
		"suppressor": Vector3(0.0, 0.049, -0.546),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.023, -0.260),
		"laser": Vector3(0.024, 0.054, -0.24),
		"laser_style": "peq15",
	},
	"mk17": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.081, -0.110),
		"suppressor": Vector3(0.0, 0.036, -0.598),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.012, -0.260),
		"laser": Vector3(0.022, 0.041, -0.24),
		"laser_style": "peq15",
	},
	"hk_416": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.117, -0.110),
		"suppressor": Vector3(0.0, 0.076, -0.546),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.041, -0.240),
		"laser": Vector3(0.042, 0.086, -0.23),
		"laser_style": "peq15",
	},
	"hk417a2": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.099, -0.130),
		"suppressor": Vector3(0.0, 0.052, -0.598),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.014, -0.310),
		"laser": Vector3(0.040, 0.055, -0.28),
		"laser_style": "peq15",
	},
	"lvoa_c": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.112, -0.100),
		"suppressor": Vector3(0.0, 0.080, -0.559),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.054, -0.280),
		"laser": Vector3(0.025, 0.073, -0.28),
		"laser_style": "peq15",
	},
	"sig556": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.107, -0.120),
		"suppressor": Vector3(0.0, 0.070, -0.572),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.026, -0.280),
		"laser": Vector3(0.024, 0.071, -0.26),
		"laser_style": "peq15",
	},
	"g36c": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.116, -0.130),
		"suppressor": Vector3(0.0, 0.051, -0.468),
		"suppressor_style": "rifle",
		"laser": Vector3(0.025, 0.064, -0.24),
		"laser_style": "peq15",
	},

	# ===== NON-RAILED RIFLES (Suppressor + realistic UGL) =====
	"colt_m16a2": {
		"suppressor": Vector3(0.0, 0.068, -0.611),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.039, -0.360),
		"laser": Vector3(0.032, 0.069, -0.32),
		"laser_style": "peq15",
	},
	"armalite_ar10": {
		"suppressor": Vector3(0.0, 0.042, -0.6175),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.015, -0.280),
	},
	"l85a2": {
		"suppressor": Vector3(0.0, 0.044, -0.507),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.008, -0.270),
		"laser": Vector3(0.024, 0.059, -0.24),
		"laser_style": "peq15",
	},
	"hk33": {
		"suppressor": Vector3(0.0, 0.051, -0.572),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.031, -0.340),
	},
	"hk_g3": {
		"suppressor": Vector3(0.0, 0.047, -0.637),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.032, -0.310),
	},
	"korean_k2": {
		"suppressor": Vector3(0.0, 0.052, -0.572),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.030, -0.250),
	},
	"ak_47": {
		"suppressor": Vector3(0.0, 0.062, -0.572),
		"suppressor_style": "rifle",
		"ugl": Vector3(0.0, 0.038, -0.325),
		"laser": Vector3(0.018, 0.082, -0.26),
		"laser_style": "peq15",
	},
	"aks74u": {
		"suppressor": Vector3(0.0, 0.068, -0.442),
		"suppressor_style": "rifle",
	},
	"famas": {
		"suppressor": Vector3(0.0, 0.025, -0.494),
		"suppressor_style": "rifle",
	},
	"m14_classic": {
		"suppressor": Vector3(0.0, 0.060, -0.676),
		"suppressor_style": "rifle",
	},

	# ===== RAILED SNIPERS & DMRS (All 3 optics) =====
	"aw_338": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.080, -0.060),
		"suppressor": Vector3(0.0, 0.055, -0.767),
		"suppressor_style": "sniper",
		"laser": Vector3(0.020, 0.044, -0.24),
		"laser_style": "peq15",
	},
	"desert_tech_srs": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.084, -0.120),
		"suppressor": Vector3(0.0, 0.056, -0.611),
		"suppressor_style": "sniper",
		"laser": Vector3(0.018, 0.048, -0.25),
		"laser_style": "peq15",
	},
	"jng_90": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.099, -0.140),
		"suppressor": Vector3(0.0, 0.088, -0.7475),
		"suppressor_style": "sniper",
		"laser": Vector3(0.021, 0.046, -0.26),
		"laser_style": "peq15",
	},
	"m14_ebr": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.081, -0.200),
		"suppressor": Vector3(0.0, 0.065, -0.637),
		"suppressor_style": "sniper",
		"laser": Vector3(0.027, 0.051, -0.30),
		"laser_style": "peq15",
	},
	"m200": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.126, -0.020),
		"suppressor": Vector3(0.0, 0.090, -0.845),
		"suppressor_style": "sniper",
		"laser": Vector3(0.027, 0.090, -0.28),
		"laser_style": "peq15",
	},
	"m24_apply": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.084, -0.030),
		"already_suppressed": true,
		"laser": Vector3(0.027, 0.035, -0.22),
		"laser_style": "peq15",
	},
	"mk12": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.097, -0.120),
		"suppressor": Vector3(0.0, 0.067, -0.611),
		"suppressor_style": "sniper",
		"laser": Vector3(0.030, 0.055, -0.26),
		"laser_style": "peq15",
	},
	"sr_25_apply": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.094, -0.120),
		"suppressor": Vector3(0.0, 0.059, -0.663),
		"suppressor_style": "sniper",
		"laser": Vector3(0.040, 0.054, -0.28),
		"laser_style": "peq15",
	},
	"steyr_ssg69": {
		"optics": ["aimpoint", "acog", "scope"],
		"rail": Vector3(0.0, 0.080, -0.070),
		"suppressor": Vector3(0.0, 0.069, -0.715),
		"suppressor_style": "sniper",
		"laser": Vector3(0.021, 0.038, -0.22),
		"laser_style": "peq15",
	},
	"svd_drogunov": {
		"suppressor": Vector3(0.0, 0.035, -0.7475),
		"suppressor_style": "sniper",
	},

	# ===== RAILED SMGS & LMG (Aimpoint & ACOG) =====
	"arp_9": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.125, -0.140),
		"suppressor": Vector3(0.0, 0.097, -0.351),
		"suppressor_style": "smg",
		"laser": Vector3(0.023, 0.104, -0.18),
		"laser_style": "peq15",
	},
	"cz_scorpion_evo": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.106, -0.150),
		"suppressor": Vector3(0.0, 0.053, -0.377),
		"suppressor_style": "smg",
		"laser": Vector3(0.021, 0.061, -0.20),
		"laser_style": "peq15",
	},
	"hk_mp7": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.131, -0.090),
		"suppressor": Vector3(0.0, 0.073, -0.312),
		"suppressor_style": "smg",
		"laser": Vector3(0.026, 0.074, -0.15),
		"laser_style": "peq15",
	},
	"krissvector": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.125, -0.170),
		"suppressor": Vector3(0.0, 0.074, -0.377),
		"suppressor_style": "smg",
		"laser": Vector3(0.020, 0.104, -0.20),
		"laser_style": "peq15",
	},
	"sig_saguer_mpx": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.117, -0.150),
		"suppressor": Vector3(0.0, 0.085, -0.364),
		"suppressor_style": "smg",
		"laser": Vector3(0.028, 0.091, -0.19),
		"laser_style": "peq15",
	},
	"ump45": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.122, -0.130),
		"suppressor": Vector3(0.0, 0.075, -0.377),
		"suppressor_style": "smg",
		"laser": Vector3(0.028, 0.080, -0.20),
		"laser_style": "peq15",
	},
	"m249": {
		"optics": ["aimpoint", "acog"],
		"rail": Vector3(0.0, 0.164, -0.050),
		"laser": Vector3(0.049, 0.089, -0.28),
		"laser_style": "peq15",
	},

	# ===== NON-RAILED TACTICAL SMGS & LMG =====
	"hk_mp5": {
		"suppressor": Vector3(0.0, 0.065, -0.364),
		"suppressor_style": "smg",
		"laser": Vector3(0.025, 0.051, -0.19),
		"laser_style": "peq15",
	},
	"fn_p90": {
		"suppressor": Vector3(0.0, 0.0005, -0.338),
		"suppressor_style": "smg",
		"laser": Vector3(0.022, 0.068, -0.15),
		"laser_style": "peq15",
	},
	"pkm": {
		"laser": Vector3(-0.002, 0.032, -0.26),
		"laser_style": "peq15",
	},
}

static var _mats_ready := false
static var _mat_matte_black: StandardMaterial3D
static var _mat_dark_steel: StandardMaterial3D
static var _mat_titanium: StandardMaterial3D
static var _mat_lens_coated: StandardMaterial3D
static var _mat_lens_clear: StandardMaterial3D
static var _mat_red_dot: StandardMaterial3D
static var _mat_fiber_red: StandardMaterial3D

static var _mesh_cache: Dictionary = {}

static func default_attachments() -> Dictionary:
	return {"optic": "", "suppressor": false, "ugl": false, "laser": false}

static func get_spec(weapon_id: String) -> Dictionary:
	return MOUNT_SPECS.get(weapon_id, {})

static func has_built_in_scope(weapon_id: String) -> bool:
	return get_spec(weapon_id).has("built_in_scope")

static func get_allowed_optics(weapon_id: String) -> Array:
	var sp = get_spec(weapon_id)
	if sp.has("optics"):
		return sp["optics"]
	return []

static func has_rail(weapon_id: String) -> bool:
	return not get_allowed_optics(weapon_id).is_empty()

static func can_attach_optic(weapon_id: String, optic_id: String) -> bool:
	if optic_id == "":
		return true
	return optic_id in get_allowed_optics(weapon_id)

static func can_attach_suppressor(weapon_id: String) -> bool:
	return get_spec(weapon_id).has("suppressor")

static func can_attach_laser(weapon_id: String) -> bool:
	return get_spec(weapon_id).has("laser")

static func get_laser_style(weapon_id: String) -> String:
	return str(get_spec(weapon_id).get("laser_style", "peq15"))

static func is_already_suppressed(weapon_id: String) -> bool:
	return bool(get_spec(weapon_id).get("already_suppressed", false))

static func is_effective_suppressed(weapon_id: String, att: Dictionary) -> bool:
	if is_already_suppressed(weapon_id):
		return true
	return can_attach_suppressor(weapon_id) and bool(att.get("suppressor", false))

static func can_attach_ugl(weapon_id: String) -> bool:
	return get_spec(weapon_id).has("ugl")

static func sanitize_attachments(weapon_id: String, raw: Variant) -> Dictionary:
	var clean := default_attachments()
	if not (raw is Dictionary):
		return clean
	var opt := str(raw.get("optic", ""))
	if opt != "" and can_attach_optic(weapon_id, opt):
		clean["optic"] = opt
	clean["suppressor"] = can_attach_suppressor(weapon_id) and bool(raw.get("suppressor", false))
	clean["ugl"] = can_attach_ugl(weapon_id) and bool(raw.get("ugl", false))
	clean["laser"] = can_attach_laser(weapon_id) and bool(raw.get("laser", false))
	return clean

static func get_suppressor_dims(style: String) -> Dictionary:
	match style:
		"sniper":
			return {"length": 0.185, "radius": 0.0195}
		"smg":
			return {"length": 0.132, "radius": 0.0145}
		"pistol":
			return {"length": 0.128, "radius": 0.0126}
		_:
			return {"length": 0.155, "radius": 0.0168}

static func get_suppressor_forward_extension(weapon_id: String) -> float:
	if not can_attach_suppressor(weapon_id):
		return 0.0
	var sp = get_spec(weapon_id)
	var dims = get_suppressor_dims(str(sp.get("suppressor_style", "rifle")))
	return maxf(0.02, float(dims["length"]) - SUPPRESSOR_OVERLAP_Z)

static func get_effective_ads_pos(weapon_id: String, att: Dictionary, base_ads: Vector3) -> Vector3:
	var sp = get_spec(weapon_id)
	var opt := str(att.get("optic", ""))
	if opt != "" and can_attach_optic(weapon_id, opt) and sp.has("rail"):
		var rail: Vector3 = sp["rail"]
		var target_y := -(rail.y + OPTIC_CENTER_HEIGHT)
		var target_z := base_ads.z
		match opt:
			OPTIC_AIMPOINT:
				# Position Aimpoint ocular cleanly ~22cm from eye for crisp reflex aperture
				target_z = clampf(-0.22 - rail.z, -0.34, -0.10)
			OPTIC_ACOG:
				target_z = clampf(-0.24 - rail.z, -0.44, -0.14)
			OPTIC_SCOPE:
				target_z = base_ads.z
		return Vector3(0.0, target_y, target_z)

	if sp.has("built_in_scope") and sp.has("ads_y"):
		return Vector3(0.0, float(sp["ads_y"]), base_ads.z)

	return base_ads

static func get_effective_ads_fov(weapon_id: String, att: Dictionary, base_fov: float, category: String = "rifle") -> float:
	var sp = get_spec(weapon_id)
	var opt := str(att.get("optic", ""))
	if opt != "" and can_attach_optic(weapon_id, opt):
		match opt:
			OPTIC_AIMPOINT:
				return 62.0
			OPTIC_ACOG:
				return 32.0
			OPTIC_SCOPE:
				return 18.0 if category == "sniper" else 22.0
	if sp.has("built_in_scope") and sp.has("ads_fov"):
		return float(sp["ads_fov"])
	return base_fov

static func get_active_scope_style(weapon_id: String, att: Dictionary) -> String:
	var sp = get_spec(weapon_id)
	var opt := str(att.get("optic", ""))
	if opt != "" and can_attach_optic(weapon_id, opt):
		if opt == OPTIC_ACOG:
			return "acog"
		if opt == OPTIC_SCOPE:
			return "sniper"
		return ""
	if sp.has("built_in_scope"):
		return str(sp["built_in_scope"])
	return ""

static func get_scope_zoom_label(weapon_id: String, att: Dictionary, category: String = "rifle") -> String:
	var sp = get_spec(weapon_id)
	var opt := str(att.get("optic", ""))
	if opt != "" and can_attach_optic(weapon_id, opt):
		match opt:
			OPTIC_ACOG:
				return "4x"
			OPTIC_SCOPE:
				return "8x" if category == "sniper" else "6x"
	if sp.has("zoom_label"):
		return str(sp["zoom_label"])
	return ""

static func build_attachment_nodes(weapon_id: String, raw_att: Dictionary) -> Node3D:
	var att := sanitize_attachments(weapon_id, raw_att)
	var sp = get_spec(weapon_id)
	var container := Node3D.new()
	container.name = "AttachmentsNode"

	var opt := str(att.get("optic", ""))
	if opt != "" and sp.has("rail"):
		var optic_node: Node3D = null
		match opt:
			OPTIC_AIMPOINT:
				optic_node = _build_aimpoint_node()
			OPTIC_ACOG:
				optic_node = _build_acog_node()
			OPTIC_SCOPE:
				optic_node = _build_scope_node()
		if optic_node:
			optic_node.position = sp["rail"]
			container.add_child(optic_node)

	if can_attach_suppressor(weapon_id) and bool(att.get("suppressor", false)):
		var style := str(sp.get("suppressor_style", "rifle"))
		var supp_node := _build_suppressor_node(style)
		supp_node.position = sp["suppressor"]
		container.add_child(supp_node)

	if can_attach_ugl(weapon_id) and bool(att.get("ugl", false)):
		var ugl_node := _build_ugl_node()
		ugl_node.position = sp["ugl"]
		container.add_child(ugl_node)

	if can_attach_laser(weapon_id) and bool(att.get("laser", false)):
		var l_style := get_laser_style(weapon_id)
		var laser_node := _build_laser_node(l_style)
		laser_node.position = sp["laser"]
		container.add_child(laser_node)

	return container

static func _ensure_materials() -> void:
	if _mats_ready:
		return
	_mats_ready = true

	_mat_matte_black = StandardMaterial3D.new()
	_mat_matte_black.albedo_color = Color(0.11, 0.12, 0.14, 1.0)
	_mat_matte_black.metallic = 0.25
	_mat_matte_black.roughness = 0.58

	_mat_dark_steel = StandardMaterial3D.new()
	_mat_dark_steel.albedo_color = Color(0.17, 0.18, 0.21, 1.0)
	_mat_dark_steel.metallic = 0.55
	_mat_dark_steel.roughness = 0.42

	_mat_titanium = StandardMaterial3D.new()
	_mat_titanium.albedo_color = Color(0.14, 0.15, 0.17, 1.0)
	_mat_titanium.metallic = 0.45
	_mat_titanium.roughness = 0.48

	_mat_lens_coated = StandardMaterial3D.new()
	_mat_lens_coated.albedo_color = Color(0.06, 0.16, 0.28, 1.0)
	_mat_lens_coated.metallic = 0.25
	_mat_lens_coated.roughness = 0.08

	_mat_lens_clear = StandardMaterial3D.new()
	_mat_lens_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_lens_clear.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_lens_clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_lens_clear.albedo_color = Color(0.16, 0.58, 0.78, 0.11)

	_mat_red_dot = StandardMaterial3D.new()
	_mat_red_dot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_red_dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_red_dot.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_red_dot.albedo_color = Color(1.0, 0.16, 0.14, 0.96)

	_mat_fiber_red = StandardMaterial3D.new()
	_mat_fiber_red.albedo_color = Color(0.92, 0.12, 0.10, 1.0)
	_mat_fiber_red.emission_enabled = true
	_mat_fiber_red.emission = Color(1.0, 0.14, 0.08, 1.0)
	_mat_fiber_red.emission_energy_multiplier = 2.0

static func _add_box_mesh(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var key := "box_%.4f_%.4f_%.4f" % [sz.x, sz.y, sz.z]
	var m: BoxMesh
	if _mesh_cache.has(key):
		m = _mesh_cache[key]
	else:
		m = BoxMesh.new()
		m.size = sz
		_mesh_cache[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func _add_cyl_mesh(parent: Node3D, r_top: float, r_bot: float, h: float, segs: int, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var key := "cyl_%.4f_%.4f_%.4f_%d" % [r_top, r_bot, h, segs]
	var m: CylinderMesh
	if _mesh_cache.has(key):
		m = _mesh_cache[key]
	else:
		m = CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bot
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_mesh_cache[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func _get_hollow_tube_mesh(r_inner: float, r_outer: float, length: float, segs: int) -> ArrayMesh:
	var key := "htube_%.4f_%.4f_%.4f_%d" % [r_inner, r_outer, length, segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := length * 0.5

	for i in range(segs):
		var a0 := float(i) / segs * TAU
		var a1 := float(i + 1) / segs * TAU
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)

		var o_f0 := Vector3(c0 * r_outer, s0 * r_outer, -hz)
		var o_f1 := Vector3(c1 * r_outer, s1 * r_outer, -hz)
		var o_b0 := Vector3(c0 * r_outer, s0 * r_outer, hz)
		var o_b1 := Vector3(c1 * r_outer, s1 * r_outer, hz)

		var i_f0 := Vector3(c0 * r_inner, s0 * r_inner, -hz)
		var i_f1 := Vector3(c1 * r_inner, s1 * r_inner, -hz)
		var i_b0 := Vector3(c0 * r_inner, s0 * r_inner, hz)
		var i_b1 := Vector3(c1 * r_inner, s1 * r_inner, hz)

		# Outer cylinder wall (outward normal)
		st.add_vertex(o_f0); st.add_vertex(o_b1); st.add_vertex(o_b0)
		st.add_vertex(o_f0); st.add_vertex(o_f1); st.add_vertex(o_b1)

		# Inner bore wall (inward normal)
		st.add_vertex(i_f0); st.add_vertex(i_b0); st.add_vertex(i_b1)
		st.add_vertex(i_f0); st.add_vertex(i_b1); st.add_vertex(i_f1)

		# Front annular ring (-Z)
		st.add_vertex(o_f0); st.add_vertex(i_f0); st.add_vertex(i_f1)
		st.add_vertex(o_f0); st.add_vertex(i_f1); st.add_vertex(o_f1)

		# Rear annular ring (+Z)
		st.add_vertex(o_b0); st.add_vertex(i_b1); st.add_vertex(i_b0)
		st.add_vertex(o_b0); st.add_vertex(o_b1); st.add_vertex(i_b1)

	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh

static func _build_aimpoint_node() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "AimpointOptic"

	var cy := OPTIC_CENTER_HEIGHT # 0.048m optical center above rail

	# Picatinny rail grabber clamp seated flush on rail (y = -0.002 .. +0.010)
	_add_box_mesh(root, Vector3(0.024, 0.012, 0.042), Vector3(0.0, 0.004, 0.0), _mat_dark_steel)
	# Side thumb-screw knob
	_add_cyl_mesh(root, 0.0045, 0.0045, 0.008, 8, Vector3(-0.015, 0.004, 0.0), Vector3(0, 0, PI * 0.5), _mat_titanium)
	# Skeletonized cantilever high riser stem up to bottom of optic housing (y = 0.009 .. 0.032)
	_add_box_mesh(root, Vector3(0.019, 0.023, 0.026), Vector3(0.0, 0.0205, 0.003), _mat_matte_black)

	# Hollow Aimpoint CompM4 tube (open bore r_inner=0.0155, r_outer=0.0198, len=0.076)
	var tube_mi := MeshInstance3D.new()
	tube_mi.mesh = _get_hollow_tube_mesh(0.0155, 0.0198, 0.076, 14)
	tube_mi.material_override = _mat_matte_black
	tube_mi.position = Vector3(0.0, cy, 0.0)
	tube_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tube_mi)

	# Objective front armor collar ring
	var collar_mi := MeshInstance3D.new()
	collar_mi.mesh = _get_hollow_tube_mesh(0.0185, 0.0218, 0.016, 14)
	collar_mi.material_override = _mat_dark_steel
	collar_mi.position = Vector3(0.0, cy, -0.030)
	collar_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(collar_mi)

	# Top elevation turret cap & right side brightness dial / battery compartment (strictly outside inner bore r=0.0155)
	_add_cyl_mesh(root, 0.0058, 0.0058, 0.008, 8, Vector3(0.0, cy + 0.0235, -0.004), Vector3.ZERO, _mat_dark_steel)
	_add_cyl_mesh(root, 0.0064, 0.0064, 0.0095, 8, Vector3(0.0242, cy + 0.006, 0.008), Vector3(0.0, 0.0, PI * 0.5), _mat_dark_steel)

	# Subtle reflex coated glass element (recessed forward inside tube)
	_add_cyl_mesh(root, 0.0150, 0.0150, 0.001, 14, Vector3(0.0, cy, -0.022), Vector3(PI * 0.5, 0.0, 0.0), _mat_lens_clear)

	# Crisp unshaded red dot reflex emitter centered at (0, cy, 0)
	var dot_key := "aimpoint_red_dot_disc"
	var dot_mesh: CylinderMesh
	if _mesh_cache.has(dot_key):
		dot_mesh = _mesh_cache[dot_key]
	else:
		dot_mesh = CylinderMesh.new()
		dot_mesh.top_radius = 0.0011
		dot_mesh.bottom_radius = 0.0011
		dot_mesh.height = 0.0006
		dot_mesh.radial_segments = 10
		dot_mesh.rings = 1
		_mesh_cache[dot_key] = dot_mesh
	var dot_mi := MeshInstance3D.new()
	dot_mi.mesh = dot_mesh
	dot_mi.material_override = _mat_red_dot
	dot_mi.position = Vector3(0.0, cy, -0.006)
	dot_mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	dot_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dot_mi)

	return root

static func _build_acog_node() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "ACOGOptic"

	var cy := OPTIC_CENTER_HEIGHT # 0.048m

	# TA51 flat-top thumb-screw Picatinny rail mount
	_add_box_mesh(root, Vector3(0.024, 0.011, 0.068), Vector3(0.0, 0.0035, 0.0), _mat_dark_steel)
	_add_cyl_mesh(root, 0.004, 0.004, 0.007, 8, Vector3(-0.015, 0.0035, 0.020), Vector3(0, 0, PI * 0.5), _mat_titanium)
	_add_cyl_mesh(root, 0.004, 0.004, 0.007, 8, Vector3(-0.015, 0.0035, -0.020), Vector3(0, 0, PI * 0.5), _mat_titanium)
	# Twin pedestal risers
	_add_box_mesh(root, Vector3(0.020, 0.024, 0.052), Vector3(0.0, 0.020, 0.0), _mat_matte_black)

	# Central prism housing & flared objective/eyepiece bells along Z
	_add_cyl_mesh(root, 0.0165, 0.0165, 0.056, 12, Vector3(0.0, cy, 0.004), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	# Flared 32mm front objective bell (extends forward to z=-0.064)
	_add_cyl_mesh(root, 0.0205, 0.0165, 0.042, 12, Vector3(0.0, cy, -0.043), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	# Ocular eyepiece bell (extends back to z=+0.058)
	_add_cyl_mesh(root, 0.0165, 0.0195, 0.032, 12, Vector3(0.0, cy, 0.044), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)

	# Side & top adjustment turrets
	_add_cyl_mesh(root, 0.0055, 0.0055, 0.008, 8, Vector3(0.0, cy + 0.019, -0.006), Vector3.ZERO, _mat_dark_steel)
	_add_cyl_mesh(root, 0.0055, 0.0055, 0.008, 8, Vector3(0.019, cy, -0.006), Vector3(0.0, 0.0, PI * 0.5), _mat_dark_steel)

	# Signature glowing red tritium fiber-optic collector spine along the top of ACOG
	_add_box_mesh(root, Vector3(0.007, 0.006, 0.046), Vector3(0.0, cy + 0.020, -0.020), _mat_dark_steel)
	_add_cyl_mesh(root, 0.0026, 0.0026, 0.042, 8, Vector3(0.0, cy + 0.0235, -0.020), Vector3(PI * 0.5, 0.0, 0.0), _mat_fiber_red)

	# Coated front/rear lens discs
	_add_cyl_mesh(root, 0.0180, 0.0180, 0.002, 12, Vector3(0.0, cy, -0.063), Vector3(PI * 0.5, 0.0, 0.0), _mat_lens_coated)
	_add_cyl_mesh(root, 0.0170, 0.0170, 0.002, 12, Vector3(0.0, cy, 0.059), Vector3(PI * 0.5, 0.0, 0.0), _mat_lens_coated)

	return root

static func _build_scope_node() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "SniperScopeOptic"

	var cy := OPTIC_CENTER_HEIGHT # 0.048m

	# Dual heavy tactical Picatinny rings at z = -0.042 and +0.042 clamping flush to rail
	for rz in [-0.042, 0.042]:
		_add_box_mesh(root, Vector3(0.024, 0.012, 0.022), Vector3(0.0, 0.004, rz), _mat_dark_steel)
		_add_box_mesh(root, Vector3(0.018, 0.024, 0.018), Vector3(0.0, 0.020, rz), _mat_dark_steel)
		_add_cyl_mesh(root, 0.0178, 0.0178, 0.019, 12, Vector3(0.0, cy, rz), Vector3(PI * 0.5, 0.0, 0.0), _mat_dark_steel)
		_add_cyl_mesh(root, 0.004, 0.004, 0.007, 8, Vector3(-0.015, 0.004, rz), Vector3(0.0, 0.0, PI * 0.5), _mat_titanium)

	# 30mm main tube (z = -0.06 .. +0.06)
	_add_cyl_mesh(root, 0.0148, 0.0148, 0.125, 12, Vector3(0.0, cy, 0.0), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	# Flared 50mm front objective bell + sunshade (z = -0.055 .. -0.130)
	_add_cyl_mesh(root, 0.0225, 0.0148, 0.036, 14, Vector3(0.0, cy, -0.073), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	_add_cyl_mesh(root, 0.0225, 0.0225, 0.042, 14, Vector3(0.0, cy, -0.111), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	# Ocular magnification ring & rear eyepiece bell (z = +0.055 .. +0.105)
	_add_cyl_mesh(root, 0.0182, 0.0182, 0.014, 12, Vector3(0.0, cy, 0.062), Vector3(PI * 0.5, 0.0, 0.0), _mat_titanium)
	_add_cyl_mesh(root, 0.0185, 0.0205, 0.038, 12, Vector3(0.0, cy, 0.086), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)

	# Central turret saddle + elevation, windage & parallax knobs
	_add_box_mesh(root, Vector3(0.032, 0.032, 0.028), Vector3(0.0, cy, -0.002), _mat_dark_steel)
	_add_cyl_mesh(root, 0.0085, 0.0085, 0.014, 10, Vector3(0.0, cy + 0.022, -0.002), Vector3.ZERO, _mat_titanium)
	_add_cyl_mesh(root, 0.0080, 0.0080, 0.013, 10, Vector3(0.021, cy, -0.002), Vector3(0.0, 0.0, PI * 0.5), _mat_titanium)
	_add_cyl_mesh(root, 0.0075, 0.0075, 0.011, 10, Vector3(-0.020, cy, -0.002), Vector3(0.0, 0.0, PI * 0.5), _mat_dark_steel)

	# Coated sapphire lenses at front and rear
	_add_cyl_mesh(root, 0.0205, 0.0205, 0.002, 14, Vector3(0.0, cy, -0.131), Vector3(PI * 0.5, 0.0, 0.0), _mat_lens_coated)
	_add_cyl_mesh(root, 0.0185, 0.0185, 0.002, 12, Vector3(0.0, cy, 0.104), Vector3(PI * 0.5, 0.0, 0.0), _mat_lens_coated)

	return root

static func _build_suppressor_node(style: String) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "SuppressorAttachment"

	var dims = get_suppressor_dims(style)
	var total_len := float(dims["length"])
	var r := float(dims["radius"])
	var z_back := SUPPRESSOR_OVERLAP_Z # overlaps flash hider by 1.4cm to prevent any visible gap
	var z_front := z_back - total_len

	# Rear QD locking collar
	var collar_len := 0.022
	_add_cyl_mesh(root, r * 1.12, r * 1.06, collar_len, 12, Vector3(0.0, 0.0, z_back - collar_len * 0.5), Vector3(PI * 0.5, 0.0, 0.0), _mat_dark_steel)

	# Tapered weld collar -> main baffled cylinder
	var body_len := total_len - collar_len
	_add_cyl_mesh(root, r, r, body_len, 14, Vector3(0.0, 0.0, z_front + body_len * 0.5), Vector3(PI * 0.5, 0.0, 0.0), _mat_titanium)

	# Ribbed retention ring near mid & front crown
	_add_cyl_mesh(root, r * 1.05, r * 1.05, 0.010, 14, Vector3(0.0, 0.0, z_front + body_len * 0.55), Vector3(PI * 0.5, 0.0, 0.0), _mat_dark_steel)
	_add_cyl_mesh(root, r * 0.92, r, 0.008, 14, Vector3(0.0, 0.0, z_front + 0.004), Vector3(PI * 0.5, 0.0, 0.0), _mat_dark_steel)
	# Dark muzzle bore center
	_add_cyl_mesh(root, r * 0.42, r * 0.42, 0.002, 10, Vector3(0.0, 0.0, z_front), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)

	return root

static func _build_ugl_node() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "M203Launcher"

	# Upper receiver mounting rail & handguard clamp (slight +2mm upward overlap for flush contact)
	_add_box_mesh(root, Vector3(0.036, 0.020, 0.145), Vector3(0.0, -0.008, 0.008), _mat_dark_steel)
	# Lower launcher chassis block
	_add_box_mesh(root, Vector3(0.032, 0.024, 0.128), Vector3(0.0, -0.022, 0.012), _mat_matte_black)
	# Ribbed 40mm barrel tube extending forward
	_add_cyl_mesh(root, 0.0195, 0.0195, 0.200, 12, Vector3(0.0, -0.028, -0.004), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	# Distinctive M203 ribbed heat-shield rings along barrel
	for rz in [-0.072, -0.046, -0.020, 0.006]:
		_add_cyl_mesh(root, 0.0220, 0.0220, 0.011, 12, Vector3(0.0, -0.028, rz), Vector3(PI * 0.5, 0.0, 0.0), _mat_dark_steel)
	# Front 40mm barrel muzzle crown + dark bore face
	_add_cyl_mesh(root, 0.0202, 0.0202, 0.010, 12, Vector3(0.0, -0.028, -0.100), Vector3(PI * 0.5, 0.0, 0.0), _mat_titanium)
	_add_cyl_mesh(root, 0.0145, 0.0145, 0.002, 10, Vector3(0.0, -0.028, -0.1055), Vector3(PI * 0.5, 0.0, 0.0), _mat_matte_black)
	# Rear breech latch & quadrant trigger guard
	_add_box_mesh(root, Vector3(0.018, 0.020, 0.032), Vector3(0.0, -0.044, 0.072), _mat_dark_steel)
	_add_box_mesh(root, Vector3(0.008, 0.016, 0.006), Vector3(0.0, -0.042, 0.072), _mat_titanium, Vector3(deg_to_rad(18.0), 0.0, 0.0))

	return root

static func _build_laser_node(style: String) -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "LaserAttachment"

	if style == "pistol":
		# Compact underbarrel tactical pistol laser (e.g. TLR-2 / X400 style)
		# Rail clamp brackets at top (y = 0.005)
		_add_box_mesh(root, Vector3(0.026, 0.008, 0.038), Vector3(0.0, 0.004, 0.0), _mat_dark_steel)
		# Main lower chassis housing battery and electronics
		_add_box_mesh(root, Vector3(0.022, 0.016, 0.044), Vector3(0.0, -0.007, 0.002), _mat_matte_black)
		# Underslung laser diode bezel cylinder
		_add_cyl_mesh(root, 0.0055, 0.0055, 0.016, 10, Vector3(0.0, -0.012, -0.018), Vector3(PI * 0.5, 0.0, 0.0), _mat_titanium)
		# Glowing red diode lens
		_add_cyl_mesh(root, 0.0028, 0.0028, 0.001, 8, Vector3(0.0, -0.012, -0.026), Vector3(PI * 0.5, 0.0, 0.0), _mat_fiber_red)

		var emitter := Node3D.new()
		emitter.name = "LaserEmitter"
		emitter.position = Vector3(0.0, -0.012, -0.026)
		root.add_child(emitter)
	else:
		# AN/PEQ-15 Advanced Target Pointer / Illuminator Aiming Laser (side-mounted on long guns)
		# Mount clamp against weapon receiver/handguard (at left side of unit, x = -0.010)
		_add_box_mesh(root, Vector3(0.006, 0.012, 0.046), Vector3(-0.010, 0.0, 0.0), _mat_dark_steel)
		# Main polymer module body
		_add_box_mesh(root, Vector3(0.022, 0.018, 0.054), Vector3(0.004, 0.0, 0.0), _mat_matte_black)
		# Top mode selector dial & fire activation button
		_add_cyl_mesh(root, 0.0045, 0.0045, 0.006, 8, Vector3(0.006, 0.011, 0.014), Vector3.ZERO, _mat_dark_steel)
		_add_box_mesh(root, Vector3(0.008, 0.004, 0.014), Vector3(0.003, 0.010, -0.008), _mat_titanium)
		# Dual front apertures: IR illuminator bell (large) + Red laser diode aperture (small)
		_add_cyl_mesh(root, 0.0055, 0.0055, 0.008, 10, Vector3(0.010, 0.0, -0.029), Vector3(PI * 0.5, 0.0, 0.0), _mat_dark_steel)
		_add_cyl_mesh(root, 0.0042, 0.0042, 0.006, 8, Vector3(-0.002, 0.001, -0.028), Vector3(PI * 0.5, 0.0, 0.0), _mat_titanium)
		# Glowing red laser diode lens
		_add_cyl_mesh(root, 0.0022, 0.0022, 0.001, 8, Vector3(-0.002, 0.001, -0.031), Vector3(PI * 0.5, 0.0, 0.0), _mat_fiber_red)

		var emitter := Node3D.new()
		emitter.name = "LaserEmitter"
		emitter.position = Vector3(-0.002, 0.001, -0.031)
		root.add_child(emitter)

	return root
