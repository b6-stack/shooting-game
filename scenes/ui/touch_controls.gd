extends Control
class_name TouchControls

## Modular Multi-Touch Virtual Controls & Tactical Mobile HUD Overlay
## Supports simultaneous multi-touch:
## - Left Virtual Joystick + Auto-Sprint Lock
## - Right-Screen Touch Drag Look + Fire-and-Drag Recoil Control
## - Tactical Action Cluster (Fire, Claw Fire, ADS Toggle, Reload / Hold-to-Consolidate, Jump, Crouch, M203 GL)
## - Gadget & Contextual Bar (NVG, Laser, Gyro Aim, Armory, Interact Door/Crate)
## - 5-Slot Interactive Weapon Strip

var player: Node = null
var is_mobile_enabled: bool = false

# Virtual Joystick State
var _joy_touch_index: int = -1
var _joy_origin: Vector2 = Vector2(165.0, 555.0)
var _joy_current: Vector2 = Vector2(165.0, 555.0)
var _joy_radius: float = 76.0
var _joy_knob_radius: float = 30.0
var _joy_deadzone: float = 0.12
var move_vector: Vector2 = Vector2.ZERO
var is_sprint_locked: bool = false
var is_sprint_dragging: bool = false

# Right Look & Action Touch Tracking
var _look_touch_index: int = -1
var _fire_touch_index: int = -1
var _claw_fire_touch_index: int = -1
var _reload_touch_index: int = -1
var _active_button_touches: Dictionary = {} # touch_index -> String button_id

# Safe area insets
var _safe_left: float = 0.0
var _safe_right: float = 0.0
var _safe_top: float = 0.0
var _safe_bottom: float = 0.0

# Cached layout dictionary: btn_id -> Dictionary { "type": "circle"/"rect", "center": Vector2, "radius": float, "rect": Rect2, "label": String, "sub": String }
var _buttons: Dictionary = {}
var _slot_names: Array[String] = ["M4A1", "M9", "RPG-7", "MK2", "Tanto"]
var _active_slot: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_safe_area()
	_rebuild_layout()

func bind_player(p: Node) -> void:
	player = p
	_rebuild_layout()
	queue_redraw()

func set_mobile_enabled(enabled: bool) -> void:
	is_mobile_enabled = enabled
	visible = enabled
	if not enabled:
		reset_all_touches()
	_rebuild_layout()
	queue_redraw()

func reset_all_touches() -> void:
	_joy_touch_index = -1
	_look_touch_index = -1
	_fire_touch_index = -1
	_claw_fire_touch_index = -1
	_reload_touch_index = -1
	_active_button_touches.clear()
	move_vector = Vector2.ZERO
	is_sprint_locked = false
	is_sprint_dragging = false
	_joy_current = _joy_origin
	if is_instance_valid(player):
		player.touch_move_dir = Vector2.ZERO
		player.touch_sprint_active = false
		player.touch_fire_held = false
		player.touch_reload_held = false
	queue_redraw()

func set_slot_summary(slot_names: Array, active_slot: int) -> void:
	_slot_names.clear()
	for s in slot_names:
		_slot_names.append(str(s))
	while _slot_names.size() < 5:
		_slot_names.append("---")
	_active_slot = active_slot
	_rebuild_layout()
	queue_redraw()

func _update_safe_area() -> void:
	var win_size := Vector2(DisplayServer.window_get_size())
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if win_size.x > 0.0 and win_size.y > 0.0 and safe_rect.size.x > 0.0 and safe_rect.size.y > 0.0:
		var vp_size := get_viewport_rect().size
		if vp_size.x <= 0.0:
			vp_size = Vector2(1280.0, 720.0)
		var scale_x := vp_size.x / win_size.x
		var scale_y := vp_size.y / win_size.y
		_safe_left = clampf(safe_rect.position.x * scale_x, 0.0, 64.0)
		_safe_top = clampf(safe_rect.position.y * scale_y, 0.0, 48.0)
		_safe_right = clampf((win_size.x - (safe_rect.position.x + safe_rect.size.x)) * scale_x, 0.0, 64.0)
		_safe_bottom = clampf((win_size.y - (safe_rect.position.y + safe_rect.size.y)) * scale_y, 0.0, 48.0)
	else:
		_safe_left = 0.0
		_safe_right = 0.0
		_safe_top = 0.0
		_safe_bottom = 0.0

func _rebuild_layout() -> void:
	var vp := size
	if vp.x <= 10.0 or vp.y <= 10.0:
		vp = get_viewport_rect().size
	if vp.x <= 10.0 or vp.y <= 10.0:
		vp = Vector2(1280.0, 720.0)

	var left_pad := 24.0 + _safe_left
	var right_pad := 24.0 + _safe_right
	var top_pad := 20.0 + _safe_top
	var bot_pad := 20.0 + _safe_bottom

	var default_joy := Vector2(left_pad + 138.0, vp.y - bot_pad - 142.0)
	if _joy_touch_index == -1:
		_joy_origin = default_joy
		_joy_current = default_joy

	_buttons.clear()

	# 0. Top-Center Pause Button Zone (Generous touch target for instant response)
	var pause_rect := Rect2(Vector2(vp.x * 0.5 - 80.0, top_pad + 10.0), Vector2(160.0, 52.0))
	_buttons["pause"] = {
		"type": "rect",
		"rect": pause_rect,
		"center": pause_rect.get_center(),
		"label": "PAUSE",
		"sub": ""
	}

	# 1. Right-Thumb Action Cluster (Raised to Right Upper-Middle, leaving the lower-right wide open for pitch/yaw swipe aiming)
	var cluster_y := clampf(vp.y * 0.43, 295.0, vp.y * 0.50)
	var base_x := vp.x - right_pad

	var fire_c := Vector2(base_x - 115.0, cluster_y + 6.0)
	_buttons["fire"] = {
		"type": "circle",
		"center": fire_c,
		"radius": 46.0,
		"label": "FIRE",
		"sub": "AUTO/TAP"
	}

	var ads_c := Vector2(base_x - 38.0, cluster_y - 56.0)
	_buttons["ads"] = {
		"type": "circle",
		"center": ads_c,
		"radius": 34.0,
		"label": "ADS",
		"sub": "SCOPE"
	}

	var reload_c := Vector2(base_x - 222.0, cluster_y - 26.0)
	_buttons["reload"] = {
		"type": "circle",
		"center": reload_c,
		"radius": 34.0,
		"label": "RELOAD",
		"sub": "HOLD:PACK"
	}

	var crouch_c := Vector2(base_x - 38.0, cluster_y + 44.0)
	_buttons["crouch"] = {
		"type": "circle",
		"center": crouch_c,
		"radius": 32.0,
		"label": "CROUCH",
		"sub": ""
	}

	var gl_c := Vector2(base_x - 115.0, cluster_y - 78.0)
	_buttons["gl"] = {
		"type": "circle",
		"center": gl_c,
		"radius": 30.0,
		"label": "M203",
		"sub": "40MM"
	}

	# 2. Contextual Interact & Vault Pill Button (Door / Ammo Crate / Vault Obstacles)
	var interact_rect := Rect2(Vector2(base_x - 275.0, cluster_y + 32.0), Vector2(105.0, 36.0))
	_buttons["interact"] = {
		"type": "rect",
		"rect": interact_rect,
		"center": interact_rect.get_center(),
		"label": "VAULT",
		"sub": "[E]"
	}

	# 3. Left-Index Claw Fire Button (Ergonomic for 4-finger claw grip)
	var claw_c := Vector2(left_pad + 76.0, vp.y * 0.38)
	_buttons["claw_fire"] = {
		"type": "circle",
		"center": claw_c,
		"radius": 36.0,
		"label": "FIRE",
		"sub": "L-INDEX"
	}

	# 4. Top-Left Gadget & Armory Bar (below ScoreLabel)
	var gadget_y := top_pad + 44.0
	var gx := left_pad
	var pill_h := 34.0
	var pill_gap := 8.0

	var nvg_rect := Rect2(Vector2(gx, gadget_y), Vector2(72.0, pill_h))
	_buttons["nvg"] = {
		"type": "rect",
		"rect": nvg_rect,
		"center": nvg_rect.get_center(),
		"label": "NVG",
		"sub": ""
	}
	gx += nvg_rect.size.x + pill_gap

	var laser_rect := Rect2(Vector2(gx, gadget_y), Vector2(82.0, pill_h))
	_buttons["laser"] = {
		"type": "rect",
		"rect": laser_rect,
		"center": laser_rect.get_center(),
		"label": "LASER",
		"sub": ""
	}
	gx += laser_rect.size.x + pill_gap

	var gyro_rect := Rect2(Vector2(gx, gadget_y), Vector2(76.0, pill_h))
	_buttons["gyro"] = {
		"type": "rect",
		"rect": gyro_rect,
		"center": gyro_rect.get_center(),
		"label": "GYRO",
		"sub": ""
	}
	gx += gyro_rect.size.x + pill_gap

	var armory_rect := Rect2(Vector2(gx, gadget_y), Vector2(108.0, pill_h))
	_buttons["armory"] = {
		"type": "rect",
		"rect": armory_rect,
		"center": armory_rect.get_center(),
		"label": "ARMORY",
		"sub": ""
	}

	# 5. Bottom-Center 5-Slot Interactive Weapon Bar
	var slot_w := 102.0
	var slot_h := 44.0
	var slot_gap := 7.0
	var total_w := slot_w * 5.0 + slot_gap * 4.0
	var start_x := (vp.x - total_w) * 0.5
	var slot_y := vp.y - bot_pad - slot_h

	for i in range(5):
		var s_rect := Rect2(Vector2(start_x + i * (slot_w + slot_gap), slot_y), Vector2(slot_w, slot_h))
		var s_name := _slot_names[i] if i < _slot_names.size() else "---"
		_buttons["slot_%d" % (i + 1)] = {
			"type": "rect",
			"rect": s_rect,
			"center": s_rect.get_center(),
			"label": "[%d] %s" % [i + 1, s_name],
			"sub": "",
			"slot_idx": i
		}

func get_button_center(btn_id: String) -> Vector2:
	_rebuild_layout()
	if btn_id == "joystick":
		return _joy_origin
	if _buttons.has(btn_id):
		return _buttons[btn_id]["center"]
	return Vector2.ZERO

func _is_button_visible(btn_id: String) -> bool:
	if btn_id == "pause":
		return false
	if btn_id == "gl":
		if is_instance_valid(player) and is_instance_valid(player.weapon):
			return bool(player.weapon.get("has_grenade_launcher")) if ("has_grenade_launcher" in player.weapon) else false
		return false
	return true

func _find_pause_menu() -> Node:
	if is_instance_valid(player) and player.hud:
		var p_menu: Node = player.hud.get_node_or_null("PauseMenu")
		if p_menu:
			return p_menu
		var hud_ctrl = player.hud.get_node_or_null("HUDControl")
		if hud_ctrl:
			p_menu = hud_ctrl.get_node_or_null("PauseMenu")
			if p_menu:
				return p_menu
	return null

func _hit_test_button(pos: Vector2) -> String:
	# Check buttons in priority order
	var check_order := [
		"pause",
		"fire", "claw_fire", "ads", "reload", "crouch", "gl",
		"interact", "armory", "nvg", "laser", "gyro",
		"slot_1", "slot_2", "slot_3", "slot_4", "slot_5"
	]
	for btn_id in check_order:
		if btn_id != "pause" and not _is_button_visible(btn_id):
			continue
		if not _buttons.has(btn_id):
			continue
		var b: Dictionary = _buttons[btn_id]
		if b["type"] == "circle":
			var c: Vector2 = b["center"]
			var r: float = float(b["radius"]) * 1.12 # Slight generous touch padding
			if pos.distance_to(c) <= r:
				return btn_id
		elif b["type"] == "rect":
			var rect: Rect2 = b["rect"]
			var grow_px: float = 14.0 if btn_id == "pause" else 4.0
			if rect.grow(grow_px).has_point(pos):
				return btn_id
	return ""

func _is_in_joystick_zone(pos: Vector2) -> bool:
	var vp := size if size.x > 10.0 else Vector2(1280.0, 720.0)
	return pos.x < vp.x * 0.40 and pos.y > vp.y * 0.34

func _is_in_top_menu_zone(pos: Vector2) -> bool:
	var vp := size if size.x > 10.0 else Vector2(1280.0, 720.0)
	var top_pad := 20.0 + _safe_top
	return absf(pos.x - vp.x * 0.5) < 110.0 and pos.y <= (top_pad + 75.0)

func _process(_delta: float) -> void:
	if not is_mobile_enabled or not visible:
		return
	if not is_instance_valid(player) or player.is_menu_open:
		return

	# Sync movement and sprint state to player every frame
	if _joy_touch_index != -1 or is_sprint_locked:
		if is_sprint_locked and _joy_touch_index == -1:
			player.touch_move_dir = Vector2(0.0, -1.0)
			player.touch_sprint_active = true
		else:
			player.touch_move_dir = move_vector
			player.touch_sprint_active = is_sprint_dragging or is_sprint_locked
	else:
		player.touch_move_dir = Vector2.ZERO
		player.touch_sprint_active = false

	# Sync fire and reload hold states
	player.touch_fire_held = (_fire_touch_index != -1 or _claw_fire_touch_index != -1)
	player.touch_reload_held = (_reload_touch_index != -1)

	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_mobile_enabled or not visible:
		return
	if not is_instance_valid(player) or player.is_armory_open or player.is_menu_open:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event.index, event.pressed, event.position)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event.index, event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Allow desktop mouse interaction with the Mobile HUD when previewing on PC
		if not DisplayServer.is_touchscreen_available():
			_handle_screen_touch(99, event.pressed, event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not DisplayServer.is_touchscreen_available():
			_handle_screen_drag(99, event.position, event.relative)

func _handle_screen_touch(idx: int, pressed: bool, pos: Vector2) -> void:
	if is_instance_valid(player) and player.is_menu_open:
		reset_all_touches()
		return

	_rebuild_layout()
	if pressed:
		# Check if touch started in the Top-Center Pause Menu zone: directly trigger menu with haptic feedback
		if _is_in_top_menu_zone(pos):
			get_viewport().set_input_as_handled()
			var p_menu = _find_pause_menu()
			if p_menu and p_menu.has_method("open_menu"):
				p_menu.open_menu()
				if player.has_method("vibrate_mobile"):
					player.vibrate_mobile(25)
			return

		# 1. Check if a tactical button was pressed
		var hit_btn := _hit_test_button(pos)
		if hit_btn != "":
			_active_button_touches[idx] = hit_btn
			_on_button_pressed(idx, hit_btn)
			queue_redraw()
			return

		# 2. Check if touch started in the Left Virtual Joystick zone
		if _joy_touch_index == -1 and _is_in_joystick_zone(pos):
			_joy_touch_index = idx
			is_sprint_locked = false
			# Anchor joystick near the default origin or slightly shifted toward finger
			var default_joy := Vector2(24.0 + _safe_left + 138.0, size.y - (20.0 + _safe_bottom) - 142.0)
			if pos.distance_to(default_joy) <= _joy_radius * 1.45:
				_joy_origin = default_joy
			else:
				_joy_origin = Vector2(
					clampf(pos.x, 95.0 + _safe_left, size.x * 0.34),
					clampf(pos.y, size.y * 0.46, size.y - 95.0 - _safe_bottom)
				)
			_update_joystick(pos)
			queue_redraw()
			return

		# 3. Otherwise, assign to Right-Screen Camera Look zone
		if _look_touch_index == -1:
			_look_touch_index = idx
			queue_redraw()
	else:
		# Touch released
		if idx == _joy_touch_index:
			_joy_touch_index = -1
			if is_sprint_dragging and (_joy_current.y - _joy_origin.y) < -_joy_radius * 2.0 and absf(_joy_current.x - _joy_origin.x) < 38.0:
				# Lock auto-sprint only if released inside the high Sprint Lock latch notch
				is_sprint_locked = true
				move_vector = Vector2(0.0, -1.0)
			else:
				is_sprint_dragging = false
				if not is_sprint_locked:
					move_vector = Vector2.ZERO
			var default_joy := Vector2(24.0 + _safe_left + 138.0, size.y - (20.0 + _safe_bottom) - 142.0)
			_joy_origin = default_joy
			_joy_current = default_joy if not is_sprint_locked else (default_joy + Vector2(0.0, -_joy_radius * 1.5))

		if idx == _look_touch_index:
			_look_touch_index = -1

		if idx == _fire_touch_index:
			_fire_touch_index = -1

		if idx == _claw_fire_touch_index:
			_claw_fire_touch_index = -1

		if idx == _reload_touch_index:
			_reload_touch_index = -1

		if _active_button_touches.has(idx):
			_active_button_touches.erase(idx)

		queue_redraw()

func _handle_screen_drag(idx: int, pos: Vector2, relative: Vector2) -> void:
	if idx == _joy_touch_index:
		_update_joystick(pos)
		queue_redraw()
	elif idx == _look_touch_index or idx == _fire_touch_index:
		# Both dedicated look finger and primary right-thumb fire finger can drag to aim/control recoil
		if is_instance_valid(player) and player.has_method("add_touch_look"):
			player.add_touch_look(relative)

func _update_joystick(pos: Vector2) -> void:
	var delta_vec := pos - _joy_origin
	var dist := delta_vec.length()
	var dir := delta_vec / dist if dist > 0.0001 else Vector2.ZERO

	# Allow the thumb knob to stretch toward the raised sprint lock latch when pushing forward
	var max_reach := _joy_radius * 2.25 if (delta_vec.y < -_joy_radius * 0.85 and absf(delta_vec.x) < 55.0) else _joy_radius
	var clamped_dist := minf(dist, max_reach)
	_joy_current = _joy_origin + dir * clamped_dist

	var norm_len := clampf(dist / _joy_radius, 0.0, 1.0)
	if norm_len < _joy_deadzone:
		move_vector = Vector2.ZERO
		is_sprint_dragging = false
	else:
		var remapped := (norm_len - _joy_deadzone) / (1.0 - _joy_deadzone)
		move_vector = (dir * remapped).limit_length(1.0)
		# Regular forward sprint while thumb is held forward
		is_sprint_dragging = (move_vector.y < -0.78 and absf(move_vector.x) < 0.65)
		# Auto-Sprint Lock requires pushing high up into the raised latch notch
		if dist >= _joy_radius * 2.10 and delta_vec.y < -_joy_radius * 2.0 and absf(delta_vec.x) < 38.0:
			is_sprint_locked = true

func _on_button_pressed(idx: int, btn_id: String) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("vibrate_mobile"):
		player.vibrate_mobile(14)

	match btn_id:
		"pause":
			get_viewport().set_input_as_handled()
			var p_menu = _find_pause_menu()
			if p_menu and p_menu.has_method("open_menu"):
				p_menu.open_menu()
				if player.has_method("vibrate_mobile"):
					player.vibrate_mobile(25)
		"fire":
			_fire_touch_index = idx
			is_sprint_locked = false
			player.touch_fire_held = true
			player.touch_fire_just_pressed = true
		"claw_fire":
			_claw_fire_touch_index = idx
			is_sprint_locked = false
			player.touch_fire_held = true
			player.touch_fire_just_pressed = true
		"ads":
			is_sprint_locked = false
			if player.has_method("toggle_aim_touch"):
				player.toggle_aim_touch()
		"reload":
			_reload_touch_index = idx
			player.touch_reload_held = true
		"crouch":
			if player.has_method("toggle_crouch"):
				player.toggle_crouch()
		"gl":
			is_sprint_locked = false
			if player.has_method("trigger_grenade"):
				player.trigger_grenade()
		"nvg":
			if player.has_method("toggle_nvg"):
				player.toggle_nvg()
		"laser":
			if player.has_method("toggle_laser"):
				player.toggle_laser()
		"gyro":
			if "gyro_enabled" in player:
				player.gyro_enabled = not player.gyro_enabled
		"armory":
			if player.has_method("open_armory"):
				player.open_armory()
		"interact":
			if player.has_method("trigger_interact"):
				player.trigger_interact()
		"slot_1", "slot_2", "slot_3", "slot_4", "slot_5":
			var slot_idx := int(_buttons[btn_id].get("slot_idx", 0))
			if player.has_method("switch_to_slot"):
				player.switch_to_slot(slot_idx)

func _is_btn_pressed(btn_id: String) -> bool:
	for k in _active_button_touches.keys():
		if _active_button_touches[k] == btn_id:
			return true
	return false

func _draw() -> void:
	if not is_mobile_enabled or not visible:
		return
	_rebuild_layout()
	var font := ThemeDB.fallback_font
	if not font:
		return

	# 1. Draw Virtual Joystick
	_draw_joystick(font)

	# 2. Draw Circular Action Buttons
	var circle_ids := ["fire", "claw_fire", "ads", "reload", "crouch", "gl"]
	for cid in circle_ids:
		if not _is_button_visible(cid):
			continue
		_draw_circle_button(font, cid, _buttons[cid])

	# 3. Draw Top-Left Gadget Pills & Contextual Interact Pill
	var pill_ids := ["nvg", "laser", "gyro", "armory", "interact"]
	for pid in pill_ids:
		if not _is_button_visible(pid):
			continue
		_draw_pill_button(font, pid, _buttons[pid])

	# 4. Draw 5-Slot Interactive Weapon Bar
	for i in range(1, 6):
		var sid := "slot_%d" % i
		if _buttons.has(sid):
			_draw_slot_pill(font, i - 1, _buttons[sid], _is_btn_pressed(sid))

func _draw_joystick(font: Font) -> void:
	var c := _joy_origin
	var r := _joy_radius
	var active := (_joy_touch_index != -1 or is_sprint_locked)

	# Outer Ring Base
	draw_circle(c, r, Color(0.06, 0.09, 0.14, 0.42 if not active else 0.56))
	draw_arc(c, r, 0.0, TAU, 48, Color(0.45, 0.78, 1.0, 0.75 if active else 0.40), 2.2, true)
	draw_arc(c, r * _joy_deadzone, 0.0, TAU, 24, Color(0.55, 0.70, 0.85, 0.22), 1.2, true)

	# Cardinal ticks
	for angle_deg in [0.0, 90.0, 180.0, 270.0]:
		var rad := deg_to_rad(angle_deg)
		var p1 := c + Vector2(cos(rad), sin(rad)) * (r - 8.0)
		var p2 := c + Vector2(cos(rad), sin(rad)) * (r - 2.0)
		draw_line(p1, p2, Color(0.65, 0.85, 1.0, 0.50), 2.0)

	# Auto-Sprint Lock Latch indicator above joystick (Raised much higher with deliberate latch distance threshold)
	var sprint_pos := c + Vector2(0.0, -r - 110.0)
	var sprint_active := is_sprint_dragging or is_sprint_locked
	var sprint_rect := Rect2(sprint_pos - Vector2(50.0, 14.0), Vector2(100.0, 28.0))
	var sprint_bg := Color(0.18, 0.52, 0.32, 0.88) if is_sprint_locked else (Color(0.22, 0.44, 0.62, 0.82) if is_sprint_dragging else Color(0.08, 0.11, 0.16, 0.50))
	var sprint_border := Color(0.35, 1.0, 0.55, 0.95) if is_sprint_locked else (Color(0.45, 0.88, 1.0, 0.90) if is_sprint_dragging else Color(0.38, 0.50, 0.65, 0.42))

	# Dashed track connecting joystick outer ring to sprint latch
	draw_dashed_line(c + Vector2(0.0, -r), sprint_pos + Vector2(0.0, 14.0), Color(0.40, 0.85, 1.0, 0.45 if sprint_active else 0.20), 2.0, 5.0)

	draw_rect(sprint_rect, sprint_bg, true)
	draw_rect(sprint_rect, sprint_border, false, 1.6)
	var sprint_txt := "SPRINT LOCK" if is_sprint_locked else ("^ SPRINT LOCK" if is_sprint_dragging else "^ SPRINT LOCK")
	draw_string(font, Vector2(sprint_rect.position.x, sprint_rect.position.y + 18.0), sprint_txt, HORIZONTAL_ALIGNMENT_CENTER, sprint_rect.size.x, 10, Color(0.95, 1.0, 0.98, 0.95 if sprint_active else 0.70))

	# Stem & Thumb Knob
	if active:
		draw_line(c, _joy_current, Color(0.45, 0.85, 1.0, 0.65), 3.0)
	var knob_col := Color(0.28, 0.88, 0.55, 0.88) if is_sprint_locked else (Color(0.32, 0.78, 1.0, 0.88) if active else Color(0.75, 0.85, 0.96, 0.52))
	draw_circle(_joy_current, _joy_knob_radius, knob_col)
	draw_arc(_joy_current, _joy_knob_radius, 0.0, TAU, 32, Color(0.92, 0.98, 1.0, 0.90), 2.0, true)
	draw_string(font, Vector2(_joy_current.x - 28.0, _joy_current.y + 4.0), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 56.0, 10, Color(0.05, 0.08, 0.12, 0.92))

func _draw_circle_button(font: Font, btn_id: String, b: Dictionary) -> void:
	var c: Vector2 = b["center"]
	var r: float = float(b["radius"])
	var pressed := _is_btn_pressed(btn_id)

	var toggled_on := false
	if is_instance_valid(player):
		if btn_id == "ads":
			toggled_on = bool(player.get("is_aiming"))
		elif btn_id == "crouch":
			toggled_on = bool(player.get("is_crouching"))

	var bg_col := Color(0.08, 0.12, 0.18, 0.62)
	var border_col := Color(0.45, 0.68, 0.88, 0.72)

	if btn_id == "fire" or btn_id == "claw_fire":
		bg_col = Color(0.78, 0.22, 0.16, 0.86) if pressed else Color(0.42, 0.12, 0.12, 0.65)
		border_col = Color(1.0, 0.55, 0.35, 0.98) if pressed else Color(0.95, 0.38, 0.28, 0.82)
	elif toggled_on:
		bg_col = Color(0.16, 0.46, 0.66, 0.88)
		border_col = Color(0.45, 0.95, 1.0, 1.0)
	elif pressed:
		bg_col = Color(0.22, 0.42, 0.60, 0.88)
		border_col = Color(0.65, 0.92, 1.0, 1.0)

	draw_circle(c, r, bg_col)
	draw_arc(c, r, 0.0, TAU, 36, border_col, 2.4 if (pressed or toggled_on) else 1.8, true)

	# Draw inner reticle ring on Fire buttons
	if btn_id == "fire" or btn_id == "claw_fire":
		draw_arc(c, r * 0.68, 0.0, TAU, 28, Color(1.0, 0.78, 0.68, 0.42), 1.4, true)

	# Draw live 0.7s Hold-to-Consolidate progress arc around RELOAD button
	if btn_id == "reload" and is_instance_valid(player) and "reload_hold_time" in player:
		var hold_t := float(player.reload_hold_time)
		if hold_t > 0.02:
			var ratio := clampf(hold_t / 0.70, 0.0, 1.0)
			var arc_col := Color(0.25, 1.0, 0.55, 0.98) if ratio >= 1.0 else Color(1.0, 0.82, 0.25, 0.96)
			draw_arc(c, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, arc_col, 4.0, true)

	var label_txt: String = str(b.get("label", ""))
	var sub_txt: String = str(b.get("sub", ""))
	if btn_id == "gl" and is_instance_valid(player) and is_instance_valid(player.weapon):
		var cur_g := int(player.weapon.get("current_grenades")) if ("current_grenades" in player.weapon) else 0
		sub_txt = "%d LEFT" % cur_g

	if sub_txt != "":
		draw_string(font, Vector2(c.x - r, c.y - 2.0), label_txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 12, Color(0.96, 0.99, 1.0, 0.98))
		draw_string(font, Vector2(c.x - r, c.y + 12.0), sub_txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 9, Color(0.78, 0.88, 0.96, 0.85))
	else:
		draw_string(font, Vector2(c.x - r, c.y + 4.0), label_txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 12, Color(0.96, 0.99, 1.0, 0.98))

func _draw_pill_button(font: Font, btn_id: String, b: Dictionary) -> void:
	var rect: Rect2 = b["rect"]
	var pressed := _is_btn_pressed(btn_id)
	var is_active := false
	var is_available := true
	var label_txt: String = str(b.get("label", ""))

	if is_instance_valid(player):
		match btn_id:
			"nvg":
				is_active = bool(player.get("is_nvg_active"))
				label_txt = "NVG: ON" if is_active else "NVG: OFF"
			"laser":
				var w = player.weapon
				var has_l: bool = is_instance_valid(w) and ("has_laser_attachment" in w) and bool(w.has_laser_attachment)
				is_available = has_l
				is_active = has_l and bool(w.get("laser_active"))
				label_txt = ("LASER: ON" if is_active else "LASER: OFF") if has_l else "LASER: N/A"
			"gyro":
				is_active = bool(player.get("gyro_enabled"))
				label_txt = "GYRO: ON" if is_active else "GYRO: OFF"
			"armory":
				is_active = player.can_access_armory() if player.has_method("can_access_armory") else false
				label_txt = "ARMORY [OPEN]" if is_active else "ARMORY [LOCK]"
			"interact":
				var prompt: String = player.get_nearby_interact_prompt() if player.has_method("get_nearby_interact_prompt") else ""
				if prompt != "":
					is_active = (prompt != "[E] VAULT")
					label_txt = prompt
				else:
					is_active = false
					label_txt = "[E] VAULT"
				is_available = true

	var bg_col := Color(0.08, 0.11, 0.16, 0.65)
	var border_col := Color(0.38, 0.55, 0.74, 0.68)
	var txt_col := Color(0.92, 0.96, 1.0, 0.95)

	if not is_available:
		bg_col = Color(0.06, 0.08, 0.11, 0.35)
		border_col = Color(0.25, 0.30, 0.38, 0.35)
		txt_col = Color(0.55, 0.62, 0.70, 0.55)
	elif is_active:
		if btn_id == "nvg" or btn_id == "armory" or btn_id == "interact":
			bg_col = Color(0.12, 0.42, 0.24, 0.88)
			border_col = Color(0.35, 0.98, 0.55, 0.98)
		else:
			bg_col = Color(0.16, 0.40, 0.58, 0.88)
			border_col = Color(0.45, 0.90, 1.0, 0.98)
	elif pressed:
		bg_col = Color(0.22, 0.38, 0.55, 0.88)
		border_col = Color(0.65, 0.92, 1.0, 0.98)
	elif btn_id == "interact":
		# Distinct tactical cyan styling for Vault/Interact
		bg_col = Color(0.10, 0.18, 0.28, 0.82)
		border_col = Color(0.40, 0.78, 1.0, 0.85)
		txt_col = Color(0.88, 0.96, 1.0, 0.95)

	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 2.0 if (is_active or pressed) else 1.4)
	draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y + rect.size.y * 0.5 + 4.0), label_txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, 11, txt_col)

func _draw_slot_pill(font: Font, slot_idx: int, b: Dictionary, pressed: bool) -> void:
	var rect: Rect2 = b["rect"]
	var is_cur := (slot_idx == _active_slot)
	var bg_col := Color(0.16, 0.36, 0.54, 0.88) if is_cur else (Color(0.20, 0.32, 0.46, 0.82) if pressed else Color(0.07, 0.10, 0.15, 0.68))
	var border_col := Color(0.45, 0.90, 1.0, 0.98) if is_cur else Color(0.30, 0.42, 0.56, 0.65)

	draw_rect(rect, bg_col, true)
	draw_rect(rect, border_col, false, 2.2 if is_cur else 1.2)

	var slot_num_str := "SLOT %d" % (slot_idx + 1)
	var w_name := _slot_names[slot_idx] if slot_idx < _slot_names.size() else "---"
	draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y + 15.0), slot_num_str, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, 9, Color(0.48, 0.88, 1.0, 0.95) if is_cur else Color(0.65, 0.75, 0.86, 0.78))
	draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y + 33.0), w_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, 11, Color(0.98, 1.0, 1.0, 0.98) if is_cur else Color(0.82, 0.88, 0.94, 0.88))
