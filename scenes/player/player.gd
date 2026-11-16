extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.6
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

@export var default_head_height: float = 1.55
@export var crouch_head_height: float = 0.95
@export var default_capsule_height: float = 1.8
@export var crouch_capsule_height: float = 1.2

@export var default_fov: float = 75.0
@export var ads_fov: float = 55.0
@export var fov_transition_speed: float = 14.0

const PACK_WEAPON_SCENE = preload("res://scenes/weapon/pack_weapon.tscn")
const WeaponAttachments = preload("res://scripts/weapon_attachments.gd")
const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

# Head & Camera
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hud: CanvasLayer = $HUD
@onready var armory_ui: CanvasLayer = get_node_or_null("ArmoryUI")

# Multi-Weapon System (4 slots)
var weapon_slots: Array[Node3D] = []
var current_slot: int = 0
var weapon: Node3D = null
var is_switching_weapon: bool = false

# State variables
var mouse_captured: bool = false
var is_mobile_controls: bool = false
var is_automation_mode: bool = false
var is_menu_open: bool = false
var haptics_enabled: bool = true
var touch_move_dir: Vector2 = Vector2.ZERO
var touch_sprint_active: bool = false
var touch_fire_held: bool = false
var touch_fire_just_pressed: bool = false
var touch_reload_held: bool = false
var touch_aim_toggled: bool = false
var touch_jump_queued: bool = false
var touch_grenade_queued: bool = false
var gyro_enabled: bool = false
@export var touch_look_sensitivity: float = 0.0032
@export var gyro_sensitivity: float = 0.65

var is_armory_open: bool = false
var is_near_ammo_crate: bool = false
var reload_hold_time: float = 0.0
var has_consolidated_this_press: bool = false
var is_nvg_active: bool = false
var nvg_spot: SpotLight3D = null
var nvg_fill: OmniLight3D = null
var is_aiming: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var bob_time: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	var auto_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	set_mobile_controls_enabled(auto_mobile)
	var hud_ctrl = hud.get_node_or_null("HUDControl") if hud else null
	if hud_ctrl and hud_ctrl.has_method("bind_player"):
		hud_ctrl.bind_player(self)
	capture_mouse(true)
	# Disable physics interpolation on head and camera since their transforms are
	# driven at render framerate in _process/_input for smooth mouse-look and crouching.
	if head:
		head.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if camera:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if weapon_holder:
		weapon_holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	# Ensure player collision shape is a unique resource instance so runtime height adjustments don't conflict
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()

	if camera:
		camera.fov = default_fov
		camera.near = 0.03

	var db = get_node_or_null("/root/WeaponDB")
	if db:
		if not db.loadout_changed.is_connected(_on_loadout_changed):
			db.loadout_changed.connect(_on_loadout_changed)
		if db.has_signal("attachments_changed") and not db.attachments_changed.is_connected(_on_attachments_changed):
			db.attachments_changed.connect(_on_attachments_changed)

	if armory_ui:
		if not armory_ui.closed.is_connected(_on_armory_closed):
			armory_ui.closed.connect(_on_armory_closed)
		if not armory_ui.slot_equipped.is_connected(_on_armory_slot_equipped):
			armory_ui.slot_equipped.connect(_on_armory_slot_equipped)

	init_weapons()

func _process(delta: float) -> void:
	var gameplay_active := (mouse_captured or is_mobile_controls) and not is_armory_open and not is_menu_open
	var zoom_sens := 1.0
	if camera and default_fov > 1.0 and camera.fov < default_fov - 0.5:
		zoom_sens = clampf(tan(deg_to_rad(camera.fov * 0.5)) / tan(deg_to_rad(default_fov * 0.5)), 0.14, 1.0)

	# Smooth render-rate mouse & touch look (scaled proportionally by FOV zoom when scoped)
	if gameplay_active and mouse_input.length_squared() > 0.0:
		var eff_sens := mouse_sensitivity * zoom_sens
		rotate_y(-mouse_input.x * eff_sens)
		head.rotate_x(-mouse_input.y * eff_sens)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		if weapon and weapon.has_method("add_sway"):
			weapon.add_sway(mouse_input)
		mouse_input = Vector2.ZERO
	elif not gameplay_active:
		mouse_input = Vector2.ZERO

	# Optional Gyroscope fine-aiming for mobile devices
	if gameplay_active and is_mobile_controls and gyro_enabled:
		var gyro := Input.get_gyroscope()
		if gyro.length_squared() > 0.0001:
			var g_scale := gyro_sensitivity * zoom_sens * delta
			rotate_y(gyro.y * g_scale)
			head.rotate_x(gyro.x * g_scale)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	# Smooth camera crouch transition in render frame
	var target_head_y = crouch_head_height if is_crouching else default_head_height
	head.position.y = lerpf(head.position.y, target_head_y, delta * 14.0)

	# Continuous real-time crosshair spread update
	if weapon and hud:
		var hud_control = hud.get_node_or_null("HUDControl")
		if hud_control and "current_spread" in weapon:
			var min_s = weapon.base_crouching_spread if "base_crouching_spread" in weapon else 0.001
			var max_s = weapon.max_spread if "max_spread" in weapon else 0.08
			var span = maxf(max_s - min_s, 0.0001)
			var spread_ratio = clampf((weapon.current_spread - min_s) / span, 0.0, 1.0)
			hud_control.set_crosshair_spread(spread_ratio)

func init_weapons() -> void:
	weapon_slots.clear()
	weapon = null

	if weapon_holder:
		for child in weapon_holder.get_children():
			weapon_holder.remove_child(child)
			child.queue_free()

	var db = get_node_or_null("/root/WeaponDB")
	if db and db.loadout.size() > 0 and weapon_holder:
		for i in range(db.loadout.size()):
			var wid = db.loadout[i]
			var data = db.get_weapon(wid)
			var att = db.get_slot_attachments(i) if db.has_method("get_slot_attachments") else {}
			var pw = PACK_WEAPON_SCENE.instantiate()
			pw.name = "Slot_%d_%s" % [i + 1, wid]
			pw.configure(data, att)
			pw.visible = false
			weapon_holder.add_child(pw)
			pw.set_process(false)
			weapon_slots.append(pw)

	if weapon_slots.size() > 0:
		current_slot = 0
		weapon = weapon_slots[0]
		weapon.visible = true
		weapon.set_process(true)
		setup_weapon_signals()
		refresh_hud()

func _on_loadout_changed(slot_idx: int, weapon_id: String) -> void:
	equip_weapon_in_slot(slot_idx, weapon_id)

func _on_attachments_changed(slot_idx: int) -> void:
	var db = get_node_or_null("/root/WeaponDB")
	if not db or slot_idx < 0 or slot_idx >= weapon_slots.size():
		return
	var w = weapon_slots[slot_idx]
	if is_instance_valid(w) and w.has_method("apply_attachments"):
		w.apply_attachments(db.get_slot_attachments(slot_idx))
	if slot_idx == current_slot:
		refresh_hud()

func equip_weapon_in_slot(slot_idx: int, weapon_id: String) -> void:
	var db = get_node_or_null("/root/WeaponDB")
	if not db or not weapon_holder or slot_idx < 0:
		return
	var data = db.get_weapon(weapon_id)
	if data.is_empty():
		return

	while weapon_slots.size() <= slot_idx:
		weapon_slots.append(null)

	var old_w = weapon_slots[slot_idx]
	if is_instance_valid(old_w):
		_disconnect_weapon_signals(old_w)
		weapon_holder.remove_child(old_w)
		old_w.queue_free()

	var att = db.get_slot_attachments(slot_idx) if db.has_method("get_slot_attachments") else {}
	var new_w = PACK_WEAPON_SCENE.instantiate()
	new_w.name = "Slot_%d_%s" % [slot_idx + 1, weapon_id]
	new_w.configure(data, att)
	weapon_holder.add_child(new_w)
	weapon_slots[slot_idx] = new_w

	if slot_idx == current_slot:
		weapon = new_w
		is_switching_weapon = false
		new_w.visible = true
		new_w.set_process(true)
		setup_weapon_signals()
	else:
		new_w.visible = false
		new_w.set_process(false)

	refresh_hud()

func _disconnect_weapon_signals(w: Node3D) -> void:
	if not is_instance_valid(w):
		return
	if w.has_signal("fired") and w.fired.is_connected(_on_weapon_fired):
		w.fired.disconnect(_on_weapon_fired)
	if w.has_signal("reloaded") and w.reloaded.is_connected(_on_weapon_reloaded):
		w.reloaded.disconnect(_on_weapon_reloaded)
	if w.has_signal("grenade_fired") and w.grenade_fired.is_connected(_on_grenade_fired):
		w.grenade_fired.disconnect(_on_grenade_fired)
	if w.has_signal("hit_target") and w.hit_target.is_connected(_on_hit_target):
		w.hit_target.disconnect(_on_hit_target)

func setup_weapon_signals() -> void:
	if not is_instance_valid(weapon):
		return
	if not weapon.fired.is_connected(_on_weapon_fired):
		weapon.fired.connect(_on_weapon_fired)
	if not weapon.reloaded.is_connected(_on_weapon_reloaded):
		weapon.reloaded.connect(_on_weapon_reloaded)
	if weapon.has_signal("grenade_fired") and not weapon.grenade_fired.is_connected(_on_grenade_fired):
		weapon.grenade_fired.connect(_on_grenade_fired)
	if not weapon.hit_target.is_connected(_on_hit_target):
		weapon.hit_target.connect(_on_hit_target)

func _get_ammo_override(w: Node3D) -> String:
	if not is_instance_valid(w):
		return ""
	if "is_shield" in w and w.is_shield:
		return "SHIELD"
	if "is_melee" in w and w.is_melee:
		return "MELEE"
	if "is_grenade" in w and w.is_grenade:
		var g_name = w.grenade_type.to_upper() if "grenade_type" in w else "FRAG"
		if w.current_ammo <= 0:
			return "%s: 0 / %d  [EMPTY]" % [g_name, w.max_ammo]
		return "%s: %d / %d" % [g_name, w.current_ammo, w.max_ammo]
	return ""

func _sync_hud_magazines() -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if not hud_control or not is_instance_valid(weapon):
		return
	var is_firearm = not ("is_melee" in weapon and weapon.is_melee) and not ("is_shield" in weapon and weapon.is_shield) and not ("is_grenade" in weapon and weapon.is_grenade) and weapon.max_ammo > 0
	var res_mags: Array[int] = weapon.reserve_mags if ("reserve_mags" in weapon) else []
	if hud_control.has_method("update_magazines"):
		hud_control.update_magazines(weapon.current_ammo, weapon.max_ammo, res_mags, is_firearm)

func _on_weapon_fired(ammo_left: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and is_instance_valid(weapon):
		var res = weapon.get_total_reserve_ammo() if weapon.has_method("get_total_reserve_ammo") else -1
		var mags = weapon.get_non_empty_mag_count() if weapon.has_method("get_non_empty_mag_count") else -1
		hud_control.update_ammo(ammo_left, res, _get_ammo_override(weapon), mags)
		_sync_hud_magazines()

func _on_weapon_reloaded(ammo_left: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and is_instance_valid(weapon):
		var res = weapon.get_total_reserve_ammo() if weapon.has_method("get_total_reserve_ammo") else -1
		var mags = weapon.get_non_empty_mag_count() if weapon.has_method("get_non_empty_mag_count") else -1
		hud_control.update_ammo(ammo_left, res, _get_ammo_override(weapon), mags)
		_sync_hud_magazines()

func _on_grenade_fired(grenades_left: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and is_instance_valid(weapon):
		hud_control.update_grenades(grenades_left, weapon.max_grenades)

func _on_hit_target(points: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control:
		hud_control.show_hitmarker()
		hud_control.add_score(points)

func refresh_hud() -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if not hud_control or not is_instance_valid(weapon):
		return

	var w_name = weapon.weapon_name if "weapon_name" in weapon else "Weapon"
	var w_cat = weapon.category if "category" in weapon else ""
	var has_gl = weapon.has_grenade_launcher if "has_grenade_launcher" in weapon else false
	var cur_gl = weapon.current_grenades if "current_grenades" in weapon else 0
	var max_gl = weapon.max_grenades if "max_grenades" in weapon else 0

	var mod_tags: Array[String] = []
	if "current_attachments" in weapon and weapon.current_attachments is Dictionary:
		var opt := str(weapon.current_attachments.get("optic", ""))
		if opt != "":
			mod_tags.append(WeaponAttachments.OPTIC_LABELS.get(opt, opt.to_upper()))
		if bool(weapon.current_attachments.get("suppressor", false)):
			mod_tags.append("SUPP")
		if "has_laser_attachment" in weapon and weapon.has_laser_attachment:
			var on = bool(weapon.get("laser_active"))
			mod_tags.append("LASER" if on else "LASER OFF")
	if has_gl:
		mod_tags.append("M203")
	var display_name = "%s [%s]" % [w_name, " + ".join(mod_tags)] if not mod_tags.is_empty() else w_name

	hud_control.set_weapon_info(display_name, has_gl, current_slot + 1, w_cat)
	var res = weapon.get_total_reserve_ammo() if weapon.has_method("get_total_reserve_ammo") else -1
	var mags = weapon.get_non_empty_mag_count() if weapon.has_method("get_non_empty_mag_count") else -1
	hud_control.update_ammo(weapon.current_ammo, res, _get_ammo_override(weapon), mags)
	_sync_hud_magazines()
	if has_gl:
		hud_control.update_grenades(cur_gl, max_gl)

	if hud_control.has_method("set_slot_summary"):
		var slot_names: Array = []
		for w in weapon_slots:
			if is_instance_valid(w) and "weapon_name" in w:
				var sn = str(w.weapon_name)
				if sn.length() > 14:
					sn = sn.substr(0, 12) + ".."
				slot_names.append(sn)
			else:
				slot_names.append("---")
		hud_control.set_slot_summary(slot_names, current_slot)

func _instant_select_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= weapon_slots.size():
		return
	_clear_scope_overlay()
	for i in range(weapon_slots.size()):
		var w = weapon_slots[i]
		if is_instance_valid(w):
			var active = (i == slot_idx)
			w.visible = active
			w.set_process(active)
	current_slot = slot_idx
	weapon = weapon_slots[slot_idx]
	setup_weapon_signals()
	refresh_hud()

func _clear_scope_overlay() -> void:
	if is_instance_valid(weapon) and weapon.has_method("set_scope_view_hidden"):
		weapon.set_scope_view_hidden(false)
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and hud_control.has_method("set_scope_overlay"):
		hud_control.set_scope_overlay("", 0.0)

func switch_to_slot(slot_idx: int) -> void:
	if is_switching_weapon or is_armory_open or slot_idx == current_slot or slot_idx < 0 or slot_idx >= weapon_slots.size():
		return

	touch_aim_toggled = false
	_clear_scope_overlay()
	is_switching_weapon = true
	var old_weapon = weapon
	var new_weapon = weapon_slots[slot_idx]

	if is_instance_valid(old_weapon) and old_weapon.has_method("holster"):
		var holster_tween = old_weapon.holster()
		await holster_tween.finished
		if is_instance_valid(old_weapon):
			old_weapon.set_process(false)
	elif is_instance_valid(old_weapon):
		old_weapon.visible = false
		old_weapon.set_process(false)

	# Slot might have been swapped in Armory while async awaiting
	new_weapon = weapon_slots[slot_idx]
	current_slot = slot_idx
	weapon = new_weapon
	if is_instance_valid(weapon):
		weapon.set_process(true)
		setup_weapon_signals()
	refresh_hud()

	if is_instance_valid(weapon) and weapon.has_method("draw_weapon"):
		var draw_tween = weapon.draw_weapon()
		await draw_tween.finished
	elif is_instance_valid(weapon):
		weapon.visible = true

	is_switching_weapon = false

func set_mobile_controls_enabled(enabled: bool) -> void:
	is_mobile_controls = enabled
	if enabled:
		mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		touch_move_dir = Vector2.ZERO
		touch_sprint_active = false
		touch_fire_held = false
		touch_fire_just_pressed = false
		touch_reload_held = false
		touch_aim_toggled = false
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and hud_control.has_method("set_mobile_mode"):
		hud_control.set_mobile_mode(enabled, self)
	refresh_hud()

func add_touch_look(relative: Vector2) -> void:
	var scale_factor := touch_look_sensitivity / maxf(mouse_sensitivity, 0.0001)
	mouse_input += relative * scale_factor

func toggle_aim_touch() -> void:
	touch_aim_toggled = not touch_aim_toggled

func trigger_jump() -> void:
	touch_jump_queued = true

func trigger_grenade() -> void:
	touch_grenade_queued = true

func vibrate_mobile(duration_ms: int = 15) -> void:
	if not haptics_enabled:
		return
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)

func reset_touch_controls() -> void:
	touch_move_dir = Vector2.ZERO
	touch_sprint_active = false
	touch_fire_held = false
	touch_fire_just_pressed = false
	touch_reload_held = false
	touch_jump_queued = false
	touch_grenade_queued = false
	var hud_ctrl = hud.get_node_or_null("HUDControl") if hud else null
	if hud_ctrl and "touch_controls" in hud_ctrl and is_instance_valid(hud_ctrl.touch_controls):
		if hud_ctrl.touch_controls.has_method("reset_all_touches"):
			hud_ctrl.touch_controls.reset_all_touches()

func trigger_vault() -> void:
	if is_crouching:
		is_crouching = false
	if is_on_floor() or is_on_wall():
		velocity.y = jump_velocity * 0.95
		var fwd := -transform.basis.z.normalized()
		velocity.x += fwd.x * 2.5
		velocity.z += fwd.z * 2.5
		vibrate_mobile(18)

func get_nearby_interact_prompt() -> String:
	var doors = get_tree().get_nodes_in_group("interactable_door")
	for d in doors:
		if is_instance_valid(d):
			var in_r: bool = ("player_in_range" in d and d.player_in_range == self) or (global_position.distance_to(d.global_position) <= 2.8)
			if in_r:
				var is_op := bool(d.get("is_open"))
				return "[E] CLOSE DOOR" if is_op else "[E] OPEN DOOR"
	if can_access_armory():
		return "[E] RESUPPLY"
	return "[E] VAULT"

func trigger_interact() -> bool:
	var interacted := false
	var doors = get_tree().get_nodes_in_group("interactable_door")
	for d in doors:
		if is_instance_valid(d):
			var in_r: bool = ("player_in_range" in d and d.player_in_range == self) or (global_position.distance_to(d.global_position) <= 2.8)
			if in_r and d.has_method("toggle"):
				d.toggle(global_position)
				interacted = true
				break
	if not interacted:
		var crates = get_tree().get_nodes_in_group("ammo_box")
		for box in crates:
			if is_instance_valid(box):
				var in_r: bool = ("player_in_range" in box and box.player_in_range == self) or (global_position.distance_to(box.global_position) <= 3.4)
				if in_r and box.has_method("try_refill"):
					box.player_in_range = self
					box.try_refill()
					interacted = true
					break
	if not interacted:
		trigger_vault()
		interacted = true
	return interacted

func can_access_armory() -> bool:
	if is_near_ammo_crate:
		return true
	var crates = get_tree().get_nodes_in_group("ammo_box")
	for box in crates:
		if is_instance_valid(box) and global_position.distance_to(box.global_position) <= 3.4:
			is_near_ammo_crate = true
			return true
	return false

func _show_hud_warning(text: String) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and hud_control.has_method("show_notification"):
		hud_control.show_notification(text, 2.2, Color(1.0, 0.35, 0.35))

func open_armory() -> void:
	if not armory_ui or is_armory_open:
		return
	if not can_access_armory():
		_show_hud_warning("Armory Locked: Must be at Ammo Crate to swap weapons!")
		ProceduralAudio.play_click(self, 480.0, 0.09)
		return
	if is_nvg_active:
		_apply_nvg_state(false)
	is_armory_open = true
	is_aiming = false
	touch_aim_toggled = false
	is_sprinting = false
	if is_instance_valid(weapon) and weapon.has_method("set_aim"):
		weapon.set_aim(false)
	_clear_scope_overlay()
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and hud_control.has_method("set_aiming"):
		hud_control.set_aiming(false, false)
	capture_mouse(false)
	armory_ui.open_armory(current_slot)

func _on_armory_closed() -> void:
	is_armory_open = false
	if is_nvg_active:
		_apply_nvg_state(true)
	capture_mouse(true)
	if is_instance_valid(weapon) and weapon.has_method("draw_weapon"):
		weapon.draw_weapon()

func _on_armory_slot_equipped(slot_idx: int) -> void:
	_instant_select_slot(slot_idx)

func capture_mouse(capture: bool) -> void:
	mouse_captured = capture
	if is_mobile_controls or is_automation_mode or OS.has_feature("mobile") or OS.has_feature("android"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if is_armory_open:
		return

	# Open Armory toggle (B or Tab) and Mobile HUD toggle (F1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			set_mobile_controls_enabled(not is_mobile_controls)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_B or event.keycode == KEY_TAB:
			open_armory()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE:
			capture_mouse(not mouse_captured)
			return

	if not mouse_captured and not is_mobile_controls:
		if event is InputEventMouseButton and event.pressed:
			capture_mouse(true)
		return

	# Weapon Switching Input (1-5, Q, Scroll Wheel)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			switch_to_slot(0)
			return
		elif event.keycode == KEY_2:
			switch_to_slot(1)
			return
		elif event.keycode == KEY_3:
			switch_to_slot(2)
			return
		elif event.keycode == KEY_4:
			switch_to_slot(3)
			return
		elif event.keycode == KEY_5:
			switch_to_slot(4)
			return
		elif event.keycode == KEY_Q:
			if not weapon_slots.is_empty():
				var next_slot = (current_slot + 1) % weapon_slots.size()
				switch_to_slot(next_slot)
			return

	if event is InputEventMouseButton and event.pressed and not is_mobile_controls:
		if not weapon_slots.is_empty():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var next_slot = (current_slot - 1 + weapon_slots.size()) % weapon_slots.size()
				switch_to_slot(next_slot)
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var next_slot = (current_slot + 1) % weapon_slots.size()
				switch_to_slot(next_slot)
				return

	# Crouch toggle (C or Ctrl)
	if event.is_action_pressed("crouch") or (event is InputEventKey and event.pressed and (event.keycode == KEY_C or event.keycode == KEY_CTRL)):
		toggle_crouch()
		return

	# Laser toggle (L)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		toggle_laser()
		return

	# Night Vision Goggles toggle (N)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		toggle_nvg()
		return

	# Mouse look: accumulate for render-rate _process (when not in touch mode or when mouse is captured)
	if event is InputEventMouseMotion and not is_mobile_controls:
		mouse_input += event.relative

func toggle_crouch() -> void:
	is_crouching = not is_crouching
	if is_crouching and is_sprinting:
		is_sprinting = false

var _player_audio_player: AudioStreamPlayer = null

func _play_player_sound(key: String, vol_db: float = -6.0) -> void:
	if _player_audio_player == null:
		_player_audio_player = AudioStreamPlayer.new()
		_player_audio_player.name = "PlayerAudio"
		add_child(_player_audio_player)
	_player_audio_player.stream = ProceduralAudio.get_cached(key)
	_player_audio_player.volume_db = vol_db
	_player_audio_player.play()

func toggle_laser() -> void:
	if is_instance_valid(weapon) and weapon.has_method("toggle_laser"):
		var has_laser: bool = weapon.get("has_laser_attachment") if ("has_laser_attachment" in weapon) else false
		if has_laser:
			weapon.toggle_laser()
			_play_player_sound("laser_click", -5.0)
			refresh_hud()

func toggle_nvg() -> void:
	is_nvg_active = not is_nvg_active
	_apply_nvg_state(is_nvg_active)
	_play_player_sound("nvg_on" if is_nvg_active else "nvg_off", -4.0)

func _ensure_nvg_lights() -> void:
	if not is_instance_valid(camera):
		return
	if not is_instance_valid(nvg_spot):
		nvg_spot = SpotLight3D.new()
		nvg_spot.name = "NVGSpot"
		nvg_spot.light_energy = 2.4
		nvg_spot.spot_range = 38.0
		nvg_spot.spot_angle = 36.0
		nvg_spot.spot_attenuation = 0.85
		nvg_spot.light_color = Color(0.85, 0.96, 0.88)
		nvg_spot.shadow_enabled = true
		nvg_spot.shadow_bias = 0.06
		nvg_spot.shadow_normal_bias = 2.0
		nvg_spot.shadow_transmittance_bias = 0.05
		nvg_spot.visible = false
		camera.add_child(nvg_spot)
	if not is_instance_valid(nvg_fill):
		nvg_fill = OmniLight3D.new()
		nvg_fill.name = "NVGFill"
		nvg_fill.light_energy = 0.55
		nvg_fill.omni_range = 14.0
		nvg_fill.omni_attenuation = 1.0
		nvg_fill.light_color = Color(0.80, 0.95, 0.85)
		nvg_fill.shadow_enabled = false
		nvg_fill.visible = false
		camera.add_child(nvg_fill)

func _apply_nvg_state(active: bool) -> void:
	_ensure_nvg_lights()
	if is_instance_valid(nvg_spot):
		nvg_spot.visible = active
	if is_instance_valid(nvg_fill):
		nvg_fill.visible = active
	var hud_node = hud.get_node_or_null("HUDControl") if hud else null
	if hud_node and hud_node.has_method("set_nvg"):
		hud_node.set_nvg(active)
	elif hud and hud.has_method("set_nvg"):
		hud.set_nvg(active)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_armory_open or is_menu_open:
		velocity.x = lerpf(velocity.x, 0.0, delta * 14.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 14.0)
		move_and_slide()
		if camera:
			camera.fov = lerpf(camera.fov, default_fov, delta * fov_transition_speed)
		return

	var jump_pressed = (InputMap.has_action("jump") and Input.is_action_just_pressed("jump")) or Input.is_key_pressed(KEY_SPACE) or touch_jump_queued
	touch_jump_queued = false
	if jump_pressed and is_on_floor():
		if is_crouching:
			is_crouching = false
		else:
			velocity.y = jump_velocity

	var input_dir = Vector2.ZERO
	if (InputMap.has_action("move_forward") and Input.is_action_pressed("move_forward")) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if (InputMap.has_action("move_backward") and Input.is_action_pressed("move_backward")) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if (InputMap.has_action("move_left") and Input.is_action_pressed("move_left")) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if (InputMap.has_action("move_right") and Input.is_action_pressed("move_right")) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	if touch_move_dir.length_squared() > 0.001:
		input_dir = (input_dir + touch_move_dir).limit_length(1.0)

	var is_sprint_held = (InputMap.has_action("sprint") and Input.is_action_pressed("sprint")) or Input.is_key_pressed(KEY_SHIFT) or touch_sprint_active
	if is_sprint_held and input_dir.y < -0.25 and not is_aiming and not is_switching_weapon:
		if is_crouching:
			is_crouching = false
		is_sprinting = true
	else:
		is_sprinting = false

	var target_speed = walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = lerpf(velocity.x, direction.x * target_speed, delta * 12.0)
		velocity.z = lerpf(velocity.z, direction.z * target_speed, delta * 12.0)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 14.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 14.0)

	# Maintain orthonormal basis and prevent degenerate matrix inversion in physics
	if absf(transform.basis.determinant()) < 0.0001:
		transform.basis = Basis.IDENTITY
	else:
		transform.basis = transform.basis.orthonormalized()

	move_and_slide()

	if is_instance_valid(weapon):
		if weapon.has_method("set_crouch"):
			weapon.set_crouch(is_crouching)
		if weapon.has_method("set_movement_speed_ratio"):
			var horiz_speed = Vector2(velocity.x, velocity.z).length()
			weapon.set_movement_speed_ratio(horiz_speed / walk_speed)

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var target_height = crouch_capsule_height if is_crouching else default_capsule_height
		if abs(collision_shape.shape.height - target_height) > 0.005:
			var min_h: float = (collision_shape.shape as CapsuleShape3D).radius * 2.0 + 0.02
			collision_shape.shape.height = maxf(lerpf(collision_shape.shape.height, target_height, delta * 10.0), min_h)
			collision_shape.position.y = collision_shape.shape.height * 0.5

	handle_weapon_actions(delta)
	handle_weapon_bob(delta, input_dir.length())

func handle_weapon_actions(delta: float) -> void:
	if (not mouse_captured and not is_mobile_controls) or is_armory_open or is_menu_open or is_switching_weapon or not is_instance_valid(weapon):
		_clear_scope_overlay()
		return

	# Aiming / Guard (RMB, Z, or Mobile ADS Toggle) - resolve BEFORE updating weapon sprint state so Shift+W+Aim never flickers
	var desktop_aim := not is_mobile_controls and ((InputMap.has_action("aim") and Input.is_action_pressed("aim")) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_Z))
	var aim_input := desktop_aim or Input.is_key_pressed(KEY_Z) or touch_aim_toggled
	if aim_input:
		is_sprinting = false
	is_aiming = aim_input

	if weapon.has_method("set_sprint"):
		weapon.set_sprint(is_sprinting)
	if weapon.has_method("set_aim"):
		weapon.set_aim(is_aiming)

	var keep_ch = ("is_melee" in weapon and weapon.is_melee) or ("is_shield" in weapon and weapon.is_shield) or ("is_grenade" in weapon and weapon.is_grenade)
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and hud_control.has_method("set_aiming"):
		hud_control.set_aiming(is_aiming, keep_ch)

	var w_reloading: bool = bool(weapon.get("is_reloading")) if ("is_reloading" in weapon) else false

	# Per-weapon Dynamic FOV for ADS
	var w_ads_fov = weapon.ads_fov if ("ads_fov" in weapon) else ads_fov
	var target_fov = w_ads_fov if (is_aiming and not w_reloading) else default_fov
	camera.fov = lerpf(camera.fov, target_fov, delta * fov_transition_speed)

	# Optical Scope Reticle Overlay for magnified optics (driven by clean weapon.ads_blend so movement/bob/recoil never cause blinking)
	var scope_style: String = weapon.get_active_scope_style() if weapon.has_method("get_active_scope_style") else ""
	var show_scope := false
	var scope_alpha := 0.0
	if is_aiming and not w_reloading and not is_sprinting and scope_style != "":
		var ads_progress := float(weapon.get("ads_blend")) if ("ads_blend" in weapon) else 1.0
		if ads_progress >= 0.65:
			show_scope = true
			scope_alpha = clampf((ads_progress - 0.65) / 0.25, 0.55, 1.0)

	if weapon.has_method("set_scope_view_hidden"):
		weapon.set_scope_view_hidden(show_scope)
	if hud_control and hud_control.has_method("set_scope_overlay"):
		if show_scope:
			var zoom_txt: String = weapon.get_scope_zoom_label() if weapon.has_method("get_scope_zoom_label") else ""
			var r_rot: Vector3 = weapon.recoil_rotation if ("recoil_rotation" in weapon) else Vector3.ZERO
			var r_px := Vector2(-r_rot.y * 420.0, -r_rot.x * 420.0)
			hud_control.set_scope_overlay(scope_style, scope_alpha, zoom_txt, r_px)
		else:
			hud_control.set_scope_overlay("", 0.0)

	# Firing / Attack / Throw (LMB or Touch Fire)
	var is_auto = weapon.is_automatic if "is_automatic" in weapon else true
	var shoot_input = false
	var desktop_lmb := not is_mobile_controls and ((InputMap.has_action("shoot") and Input.is_action_pressed("shoot")) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var desktop_lmb_just := not is_mobile_controls and ((InputMap.has_action("shoot") and Input.is_action_just_pressed("shoot")) or (not InputMap.has_action("shoot") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))
	if is_auto:
		shoot_input = desktop_lmb or touch_fire_held or touch_fire_just_pressed
	else:
		shoot_input = desktop_lmb_just or touch_fire_just_pressed
	touch_fire_just_pressed = false

	if shoot_input:
		is_sprinting = false
		if weapon.has_method("shoot"):
			weapon.shoot(camera)

	# Legacy M203 launcher if a weapon enables has_grenade_launcher
	var has_gl = weapon.has_grenade_launcher if "has_grenade_launcher" in weapon else false
	if has_gl:
		var grenade_input = Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_G) or (not is_mobile_controls and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) or touch_grenade_queued
		if not is_mobile_controls and (InputMap.has_action("launch_grenade") and Input.is_action_just_pressed("launch_grenade")):
			grenade_input = true
		touch_grenade_queued = false
		if grenade_input:
			is_sprinting = false
			if weapon.has_method("launch_grenade"):
				weapon.launch_grenade(camera)

	# Reloading / Magazine Consolidation (R or Touch Reload: tap to reload, hold 0.7s to consolidate)
	var reload_held = (InputMap.has_action("reload") and Input.is_action_pressed("reload")) or Input.is_key_pressed(KEY_R) or touch_reload_held
	if reload_held and not is_switching_weapon and not is_armory_open:
		reload_hold_time += delta
		if reload_hold_time >= 0.70 and not has_consolidated_this_press:
			has_consolidated_this_press = true
			vibrate_mobile(28)
			if weapon and weapon.has_method("consolidate_magazines"):
				if weapon.consolidate_magazines():
					ProceduralAudio.play_click(self, 520.0, 0.12)
					var active_mags = weapon.reserve_mags.filter(func(m): return m > 0)
					_show_hud_warning("Ammo Consolidated: %s" % str(active_mags))
					refresh_hud()
				else:
					_show_hud_warning("Magazines already optimal.")
	else:
		if not reload_held:
			if reload_hold_time > 0.0 and reload_hold_time < 0.70 and not has_consolidated_this_press:
				if weapon and weapon.has_method("reload"):
					touch_aim_toggled = false
					weapon.reload()
			reload_hold_time = 0.0
			has_consolidated_this_press = false

func handle_weapon_bob(delta: float, move_amount: float) -> void:
	if not is_instance_valid(weapon) or not weapon.has_method("set_bob"):
		return

	if is_on_floor() and move_amount > 0.1:
		var speed_mult = 1.6 if is_sprinting else (0.7 if is_crouching else 1.0)
		bob_time += delta * 9.0 * speed_mult

		var amp_x = 0.024 if is_sprinting else 0.012
		var amp_y = 0.020 if is_sprinting else 0.010

		var bob_x = cos(bob_time * 0.5) * amp_x
		var bob_y = sin(bob_time) * amp_y
		weapon.set_bob(Vector3(bob_x, bob_y, 0))
	else:
		bob_time = 0.0
		weapon.set_bob(Vector3.ZERO)
