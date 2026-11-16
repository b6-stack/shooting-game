extends Control

@onready var hitmarker: Control = $Hitmarker
@onready var weapon_name_label: Label = $BottomRight/VBox/WeaponName
@onready var ammo_label: Label = $BottomRight/VBox/AmmoLabel
@onready var grenade_label: Label = $BottomRight/VBox/GrenadeLabel
@onready var slots_label: Label = get_node_or_null("BottomRight/VBox/SlotsLabel")
@onready var score_label: Label = $TopLeft/ScoreLabel
@onready var crosshair: Control = $Crosshair

@onready var ch_top: ColorRect = $Crosshair/Top
@onready var ch_bottom: ColorRect = $Crosshair/Bottom
@onready var ch_left: ColorRect = $Crosshair/Left
@onready var ch_right: ColorRect = $Crosshair/Right
@onready var perf_label: Label = $TopRight/PerfLabel
@onready var nvg_overlay: Control = get_node_or_null("NVGOverlay")
@onready var scope_overlay: Control = get_node_or_null("ScopeOverlay")
@onready var flash_overlay: ColorRect = get_node_or_null("FlashOverlay")
@onready var magazine_rack: HBoxContainer = get_node_or_null("BottomRight/VBox/MagazineRack")
@onready var top_left_box: MarginContainer = get_node_or_null("TopLeft")
@onready var top_right_box: MarginContainer = get_node_or_null("TopRight")
@onready var bottom_left_box: MarginContainer = get_node_or_null("BottomLeft")
@onready var bottom_right_box: MarginContainer = get_node_or_null("BottomRight")

const MagazineIconScript = preload("res://scenes/ui/magazine_icon.gd")
const TouchControlsScript = preload("res://scenes/ui/touch_controls.gd")
const PauseMenuScript = preload("res://scenes/ui/pause_menu.gd")
var touch_controls: Control = null
var pause_menu: Control = null
var _is_mobile_hud: bool = false
var _active_mag_icon: Control = null
var _reserve_mag_icons: Array[Control] = []
var _mag_rack_initialized: bool = false

var hitmarker_tween: Tween
var crosshair_tween: Tween
var flash_tween: Tween
var _last_aim_state: bool = false
var _last_keep_ch: bool = false
var score: int = 0
var gpu_name: String = ""

const BASE_GAP: float = 5.0
const MAX_EXTRA_GAP: float = 28.0
const LINE_LEN: float = 9.0
const LINE_THICK: float = 2.0

func _ready() -> void:
	gpu_name = RenderingServer.get_video_adapter_name()
	print("[SYSTEM] Active Video Adapter: %s" % gpu_name)
	if hitmarker:
		hitmarker.modulate.a = 0.0
	update_ammo(30, 30)
	update_grenades(4, 4)
	update_score(0)
	set_crosshair_spread(0.3)
	_init_magazine_rack()
	_ensure_touch_controls()
	_ensure_pause_menu()
	_apply_safe_area_and_layout()

func _ensure_touch_controls() -> void:
	if touch_controls == null:
		touch_controls = get_node_or_null("TouchControls")
	if touch_controls == null:
		touch_controls = TouchControlsScript.new()
		touch_controls.name = "TouchControls"
		touch_controls.z_index = 20
		add_child(touch_controls)

func _ensure_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = get_node_or_null("PauseMenu")
	if pause_menu == null:
		pause_menu = PauseMenuScript.new()
		pause_menu.name = "PauseMenu"
		pause_menu.z_index = 30
		add_child(pause_menu)

func bind_player(p: Node) -> void:
	_ensure_touch_controls()
	_ensure_pause_menu()
	if touch_controls and touch_controls.has_method("bind_player"):
		touch_controls.bind_player(p)
	if pause_menu and pause_menu.has_method("bind_player"):
		pause_menu.bind_player(p)

func set_mobile_mode(enabled: bool, player_ref: Node = null) -> void:
	_ensure_touch_controls()
	_ensure_pause_menu()
	_is_mobile_hud = enabled
	if touch_controls:
		if player_ref and touch_controls.has_method("bind_player"):
			touch_controls.bind_player(player_ref)
		if touch_controls.has_method("set_mobile_enabled"):
			touch_controls.set_mobile_enabled(enabled)
	if pause_menu and player_ref and pause_menu.has_method("bind_player"):
		pause_menu.bind_player(player_ref)
	_apply_safe_area_and_layout()

func _apply_safe_area_and_layout() -> void:
	var safe_left := 0
	var safe_right := 0
	var safe_top := 0
	var safe_bottom := 0
	var win_size := Vector2(DisplayServer.window_get_size())
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if win_size.x > 0.0 and win_size.y > 0.0 and safe_rect.size.x > 0.0 and safe_rect.size.y > 0.0:
		var vp_size := get_viewport_rect().size
		if vp_size.x <= 0.0:
			vp_size = Vector2(1280.0, 720.0)
		var sx := vp_size.x / win_size.x
		var sy := vp_size.y / win_size.y
		safe_left = int(clampf(safe_rect.position.x * sx, 0.0, 64.0))
		safe_top = int(clampf(safe_rect.position.y * sy, 0.0, 48.0))
		safe_right = int(clampf((win_size.x - (safe_rect.position.x + safe_rect.size.x)) * sx, 0.0, 64.0))
		safe_bottom = int(clampf((win_size.y - (safe_rect.position.y + safe_rect.size.y)) * sy, 0.0, 48.0))

	if top_left_box:
		top_left_box.add_theme_constant_override("margin_left", 24 + safe_left)
		top_left_box.add_theme_constant_override("margin_top", 20 + safe_top)
	if top_right_box:
		if _is_mobile_hud:
			top_right_box.anchor_left = 1.0
			top_right_box.anchor_right = 1.0
			top_right_box.anchor_top = 0.0
			top_right_box.anchor_bottom = 0.0
			top_right_box.offset_left = -280.0
			top_right_box.offset_right = -(safe_right + 20.0)
			top_right_box.offset_top = 8.0 + safe_top
			top_right_box.offset_bottom = 28.0 + safe_top
			top_right_box.add_theme_constant_override("margin_right", 0)
			top_right_box.add_theme_constant_override("margin_top", 0)
		else:
			top_right_box.anchor_left = 1.0
			top_right_box.anchor_right = 1.0
			top_right_box.anchor_top = 0.0
			top_right_box.anchor_bottom = 0.0
			top_right_box.offset_left = -380.0
			top_right_box.offset_right = 0.0
			top_right_box.offset_top = 0.0
			top_right_box.offset_bottom = 60.0
			top_right_box.add_theme_constant_override("margin_right", 24 + safe_right)
			top_right_box.add_theme_constant_override("margin_top", 18 + safe_top)
	if bottom_left_box:
		bottom_left_box.visible = not _is_mobile_hud
		bottom_left_box.add_theme_constant_override("margin_left", 24 + safe_left)
		bottom_left_box.add_theme_constant_override("margin_bottom", 20 + safe_bottom)
	if slots_label:
		slots_label.visible = not _is_mobile_hud
	if bottom_right_box:
		if _is_mobile_hud:
			# Anchor WeaponName, MagazineRack, and AmmoLabel at Top-Right header
			# Completely clears the bottom of the screen from obscuring interact text and weapon slots
			# Leaves an ~88px clear buffer above the upper-middle action cluster
			bottom_right_box.anchor_left = 1.0
			bottom_right_box.anchor_right = 1.0
			bottom_right_box.anchor_top = 0.0
			bottom_right_box.anchor_bottom = 0.0
			bottom_right_box.offset_left = -460.0
			bottom_right_box.offset_right = -(safe_right + 20.0)
			bottom_right_box.offset_top = 30.0 + safe_top
			bottom_right_box.offset_bottom = 120.0 + safe_top
			bottom_right_box.add_theme_constant_override("margin_bottom", 0)
			bottom_right_box.add_theme_constant_override("margin_right", 0)
			if magazine_rack:
				magazine_rack.alignment = BoxContainer.ALIGNMENT_END
			if weapon_name_label:
				weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if ammo_label:
				ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if grenade_label:
				grenade_label.visible = false
		else:
			bottom_right_box.anchor_left = 1.0
			bottom_right_box.anchor_right = 1.0
			bottom_right_box.anchor_top = 1.0
			bottom_right_box.anchor_bottom = 1.0
			bottom_right_box.offset_left = -690.0
			bottom_right_box.offset_right = 0.0
			bottom_right_box.offset_top = -175.0
			bottom_right_box.offset_bottom = 0.0
			bottom_right_box.add_theme_constant_override("margin_bottom", 24 + safe_bottom)
			bottom_right_box.add_theme_constant_override("margin_right", 28 + safe_right)
			if magazine_rack:
				magazine_rack.alignment = BoxContainer.ALIGNMENT_END
			if weapon_name_label:
				weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if ammo_label:
				ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if grenade_label:
				grenade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if pause_menu and pause_menu.has_method("apply_safe_area"):
		pause_menu.apply_safe_area()

func _process(_delta: float) -> void:
	if perf_label:
		var fps = Engine.get_frames_per_second()
		if _is_mobile_hud:
			perf_label.text = "%d FPS" % fps
		else:
			perf_label.text = "%d FPS | %s" % [fps, gpu_name]
		if fps < 35:
			perf_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.9))
		else:
			perf_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.9))

func set_weapon_info(w_name: String, has_gl: bool, slot_num: int, cat_label: String = "") -> void:
	if weapon_name_label:
		if cat_label != "":
			weapon_name_label.text = "[%d] %s  (%s)" % [slot_num, w_name, cat_label.to_upper()]
		else:
			weapon_name_label.text = "[%d] %s" % [slot_num, w_name]
	if grenade_label:
		grenade_label.visible = has_gl and not _is_mobile_hud

func set_slot_summary(slot_names: Array, active_slot: int) -> void:
	if touch_controls and touch_controls.has_method("set_slot_summary"):
		touch_controls.set_slot_summary(slot_names, active_slot)
	if not slots_label:
		return
	var parts: Array[String] = []
	for i in range(slot_names.size()):
		var prefix = ">[%d]<" % (i + 1) if i == active_slot else "[%d]" % (i + 1)
		parts.append("%s %s" % [prefix, str(slot_names[i])])
	slots_label.text = "  |  ".join(parts)

func update_ammo(current: int, total: int, label_override: String = "", mag_count: int = -1) -> void:
	if ammo_label:
		if label_override != "":
			ammo_label.text = label_override
		elif total < 0:
			ammo_label.text = "%d" % current
		elif mag_count >= 0:
			if total == 0 and current == 0:
				ammo_label.text = "0 / 0  [EMPTY]"
			else:
				ammo_label.text = "%d / %d  [%d MAGS]" % [current, total, mag_count]
		elif total == 0 and current == 0:
			ammo_label.text = "0 / 0  [EMPTY]"
		else:
			ammo_label.text = "%d / %d" % [current, total]

func update_grenades(current: int, total: int) -> void:
	if grenade_label:
		grenade_label.text = "M203 40mm: %d / %d" % [current, total]

func _init_magazine_rack() -> void:
	if _mag_rack_initialized:
		return
	if magazine_rack == null:
		magazine_rack = get_node_or_null("BottomRight/VBox/MagazineRack")
	if magazine_rack == null:
		var vbox = get_node_or_null("BottomRight/VBox")
		if vbox:
			magazine_rack = HBoxContainer.new()
			magazine_rack.name = "MagazineRack"
			magazine_rack.alignment = BoxContainer.ALIGNMENT_END
			magazine_rack.add_theme_constant_override("separation", 5)
			var ammo_idx = ammo_label.get_index() if ammo_label else -1
			if ammo_idx >= 0:
				vbox.add_child(magazine_rack)
				vbox.move_child(magazine_rack, ammo_idx)
			else:
				vbox.add_child(magazine_rack)

	if magazine_rack:
		for c in magazine_rack.get_children():
			c.queue_free()
		_reserve_mag_icons.clear()

		# Loaded in gun magazine icon
		var active_box = VBoxContainer.new()
		active_box.alignment = BoxContainer.ALIGNMENT_CENTER
		active_box.add_theme_constant_override("separation", 1)

		_active_mag_icon = MagazineIconScript.new()
		_active_mag_icon.name = "ActiveMagIcon"
		active_box.add_child(_active_mag_icon)

		var active_lbl = Label.new()
		active_lbl.text = "LOADED"
		active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_lbl.add_theme_font_size_override("font_size", 9)
		active_lbl.add_theme_color_override("font_color", Color(0.40, 0.88, 1.0, 0.95))
		active_box.add_child(active_lbl)
		magazine_rack.add_child(active_box)

		# Vertical divider between loaded magazine and reserve rig
		var v_sep = VSeparator.new()
		v_sep.add_theme_constant_override("separation", 8)
		magazine_rack.add_child(v_sep)

		# 5 Reserve magazine pouches in rig
		for i in range(5):
			var res_box = VBoxContainer.new()
			res_box.alignment = BoxContainer.ALIGNMENT_CENTER
			res_box.add_theme_constant_override("separation", 1)

			var r_icon = MagazineIconScript.new()
			r_icon.name = "ReserveMagIcon_%d" % (i + 1)
			res_box.add_child(r_icon)
			_reserve_mag_icons.append(r_icon)

			var r_lbl = Label.new()
			r_lbl.text = "R%d" % (i + 1)
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_lbl.add_theme_font_size_override("font_size", 9)
			r_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.80))
			res_box.add_child(r_lbl)
			magazine_rack.add_child(res_box)

		_mag_rack_initialized = true

func update_magazines(current: int, max_mag: int, reserve_mags: Array[int], is_firearm: bool) -> void:
	if not _mag_rack_initialized:
		_init_magazine_rack()
	if not magazine_rack:
		return

	if not is_firearm or max_mag <= 0:
		magazine_rack.visible = false
		return

	magazine_rack.visible = true

	# Update active magazine
	if _active_mag_icon and _active_mag_icon.has_method("set_mag_state"):
		_active_mag_icon.set_mag_state(current, max_mag, true, "LOADED")

	# Update 5 reserve magazines
	for i in range(_reserve_mag_icons.size()):
		var icon = _reserve_mag_icons[i]
		if not is_instance_valid(icon) or not icon.has_method("set_mag_state"):
			continue
		var parent_box = icon.get_parent()
		if i < reserve_mags.size():
			if parent_box:
				parent_box.visible = true
			icon.set_mag_state(reserve_mags[i], max_mag, false, "R%d" % (i + 1))
		else:
			if parent_box:
				parent_box.visible = false

func add_score(amount: int) -> void:
	score += amount
	update_score(score)

func update_score(new_score: int) -> void:
	score = new_score
	if score_label:
		score_label.text = "SCORE: %d" % score

func set_crosshair_spread(ratio: float) -> void:
	var gap = BASE_GAP + clampf(ratio, 0.0, 1.0) * MAX_EXTRA_GAP
	var half_t = LINE_THICK * 0.5
	
	if ch_top:
		ch_top.offset_left = -half_t
		ch_top.offset_right = half_t
		ch_top.offset_top = -gap - LINE_LEN
		ch_top.offset_bottom = -gap
	if ch_bottom:
		ch_bottom.offset_left = -half_t
		ch_bottom.offset_right = half_t
		ch_bottom.offset_top = gap
		ch_bottom.offset_bottom = gap + LINE_LEN
	if ch_left:
		ch_left.offset_left = -gap - LINE_LEN
		ch_left.offset_right = -gap
		ch_left.offset_top = -half_t
		ch_left.offset_bottom = half_t
	if ch_right:
		ch_right.offset_left = gap
		ch_right.offset_right = gap + LINE_LEN
		ch_right.offset_top = -half_t
		ch_right.offset_bottom = half_t

func show_hitmarker() -> void:
	if not hitmarker:
		return
	if hitmarker_tween and hitmarker_tween.is_valid():
		hitmarker_tween.kill()
	hitmarker.scale = Vector2(1.4, 1.4)
	hitmarker.modulate = Color(1.0, 0.2, 0.2, 1.0)
	hitmarker_tween = create_tween().set_parallel(true)
	hitmarker_tween.tween_property(hitmarker, "scale", Vector2.ONE, 0.15)
	hitmarker_tween.tween_property(hitmarker, "modulate:a", 0.0, 0.25)

func set_aiming(is_aiming: bool, keep_crosshair: bool = false) -> void:
	if crosshair and (is_aiming != _last_aim_state or keep_crosshair != _last_keep_ch):
		_last_aim_state = is_aiming
		_last_keep_ch = keep_crosshair
		var target_alpha = 0.7 if (is_aiming and keep_crosshair) else (0.0 if is_aiming else 1.0)
		if crosshair_tween and crosshair_tween.is_valid():
			crosshair_tween.kill()
		crosshair_tween = create_tween()
		crosshair_tween.tween_property(crosshair, "modulate:a", target_alpha, 0.12)

func set_scope_overlay(style: String, alpha: float, zoom_txt: String = "", recoil_px: Vector2 = Vector2.ZERO) -> void:
	if scope_overlay and scope_overlay.has_method("set_scope_state"):
		scope_overlay.set_scope_state(style, alpha, zoom_txt, recoil_px)

func set_nvg(enabled: bool) -> void:
	if nvg_overlay and nvg_overlay.has_method("set_nvg_active"):
		nvg_overlay.set_nvg_active(enabled)

func trigger_flashbang(intensity: float = 1.0) -> void:
	if not flash_overlay:
		return
	var clamped := clampf(intensity, 0.2, 1.0)
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_overlay.color = Color(1.0, 0.99, 0.95, clamped)
	flash_tween = create_tween()
	flash_tween.tween_interval(0.35 * clamped)
	flash_tween.tween_property(flash_overlay, "color:a", 0.0, 1.65 * clamped).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

var _notification_label: Label = null
var _notification_tween: Tween = null

func show_notification(text: String, duration: float = 2.0, color: Color = Color(1.0, 0.4, 0.4)) -> void:
	if _notification_label == null:
		_notification_label = Label.new()
		_notification_label.name = "NotificationLabel"
		_notification_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_notification_label.offset_top = 80.0
		_notification_label.offset_left = -300.0
		_notification_label.offset_right = 300.0
		_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notification_label.add_theme_font_size_override("font_size", 18)
		add_child(_notification_label)
	_notification_label.text = text
	_notification_label.modulate = color
	_notification_label.modulate.a = 1.0
	_notification_label.visible = true
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_interval(duration * 0.6)
	_notification_tween.tween_property(_notification_label, "modulate:a", 0.0, duration * 0.4)
	_notification_tween.tween_callback(func(): _notification_label.visible = false)
