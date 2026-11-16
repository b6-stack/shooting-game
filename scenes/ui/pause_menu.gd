extends Control
class_name PauseMenu

signal menu_opened
signal menu_closed

@onready var top_menu_btn: Button = get_node_or_null("TopMenuBtn")
@onready var modal_overlay: Control = get_node_or_null("ModalOverlay")
@onready var resume_btn: Button = get_node_or_null("ModalOverlay/Center/Panel/VBox/ResumeBtn")
@onready var sens_slider: HSlider = get_node_or_null("ModalOverlay/Center/Panel/VBox/SensBox/SensSlider")
@onready var sens_label: Label = get_node_or_null("ModalOverlay/Center/Panel/VBox/SensBox/SensLabel")
@onready var gyro_btn: Button = get_node_or_null("ModalOverlay/Center/Panel/VBox/GyroBtn")
@onready var haptics_btn: Button = get_node_or_null("ModalOverlay/Center/Panel/VBox/HapticsBtn")
@onready var restart_btn: Button = get_node_or_null("ModalOverlay/Center/Panel/VBox/RestartBtn")
@onready var quit_btn: Button = get_node_or_null("ModalOverlay/Center/Panel/VBox/QuitBtn")

var player: Node = null
var is_menu_open: bool = false
var haptics_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui_if_needed()
	if modal_overlay:
		modal_overlay.visible = false
	apply_safe_area()

func bind_player(p: Node) -> void:
	player = p
	_sync_settings_to_ui()

func apply_safe_area() -> void:
	var safe_top := 0.0
	var win_size := Vector2(DisplayServer.window_get_size())
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if win_size.y > 0.0 and safe_rect.size.y > 0.0:
		var vp_size := get_viewport_rect().size
		if vp_size.y <= 0.0:
			vp_size = Vector2(1280.0, 720.0)
		var sy := vp_size.y / win_size.y
		safe_top = clampf(safe_rect.position.y * sy, 0.0, 48.0)

	if top_menu_btn:
		top_menu_btn.anchor_left = 0.5
		top_menu_btn.anchor_right = 0.5
		top_menu_btn.anchor_top = 0.0
		top_menu_btn.anchor_bottom = 0.0
		top_menu_btn.offset_left = -75.0
		top_menu_btn.offset_right = 75.0
		top_menu_btn.offset_top = 12.0 + safe_top
		top_menu_btn.offset_bottom = 58.0 + safe_top

func _build_ui_if_needed() -> void:
	if top_menu_btn == null:
		top_menu_btn = Button.new()
		top_menu_btn.name = "TopMenuBtn"
		top_menu_btn.text = "[ || PAUSE ]"
		top_menu_btn.custom_minimum_size = Vector2(150, 46)
		top_menu_btn.anchor_left = 0.5
		top_menu_btn.anchor_right = 0.5
		top_menu_btn.anchor_top = 0.0
		top_menu_btn.anchor_bottom = 0.0
		top_menu_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		top_menu_btn.offset_left = -75.0
		top_menu_btn.offset_right = 75.0
		top_menu_btn.offset_top = 12.0
		top_menu_btn.offset_bottom = 58.0
		
		var st_btn := StyleBoxFlat.new()
		st_btn.bg_color = Color(0.08, 0.14, 0.22, 0.92)
		st_btn.border_width_left = 2
		st_btn.border_width_top = 2
		st_btn.border_width_right = 2
		st_btn.border_width_bottom = 2
		st_btn.border_color = Color(0.45, 0.88, 1.0, 0.95)
		st_btn.set_corner_radius_all(8)
		top_menu_btn.add_theme_stylebox_override("normal", st_btn)
		top_menu_btn.add_theme_stylebox_override("hover", st_btn)
		top_menu_btn.add_theme_stylebox_override("pressed", st_btn)
		top_menu_btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		top_menu_btn.add_theme_font_size_override("font_size", 14)
		top_menu_btn.pressed.connect(open_menu)
		add_child(top_menu_btn)

	if modal_overlay == null:
		modal_overlay = ColorRect.new()
		modal_overlay.name = "ModalOverlay"
		modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal_overlay.color = Color(0.04, 0.06, 0.08, 0.78)
		modal_overlay.visible = false
		add_child(modal_overlay)

		var center := CenterContainer.new()
		center.name = "Center"
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal_overlay.add_child(center)

		var panel := PanelContainer.new()
		panel.name = "Panel"
		panel.custom_minimum_size = Vector2(400, 390)
		var st_pan := StyleBoxFlat.new()
		st_pan.bg_color = Color(0.10, 0.13, 0.18, 0.98)
		st_pan.border_width_left = 2
		st_pan.border_width_top = 2
		st_pan.border_width_right = 2
		st_pan.border_width_bottom = 2
		st_pan.border_color = Color(0.35, 0.78, 1.0, 0.95)
		st_pan.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", st_pan)
		center.add_child(panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_bottom", 20)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.name = "VBox"
		vbox.add_theme_constant_override("separation", 12)
		margin.add_child(vbox)

		var title := Label.new()
		title.text = "TACTICAL OPTIONS"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
		vbox.add_child(title)

		var h_sep := HSeparator.new()
		vbox.add_child(h_sep)

		resume_btn = Button.new()
		resume_btn.name = "ResumeBtn"
		resume_btn.text = "RESUME MISSION"
		resume_btn.custom_minimum_size = Vector2(0, 44)
		resume_btn.add_theme_font_size_override("font_size", 14)
		resume_btn.pressed.connect(close_menu)
		vbox.add_child(resume_btn)

		var sens_box := VBoxContainer.new()
		sens_box.name = "SensBox"
		sens_box.add_theme_constant_override("separation", 4)
		sens_label = Label.new()
		sens_label.name = "SensLabel"
		sens_label.text = "Look Sensitivity: 1.0x"
		sens_label.add_theme_font_size_override("font_size", 12)
		sens_box.add_child(sens_label)

		sens_slider = HSlider.new()
		sens_slider.name = "SensSlider"
		sens_slider.min_value = 0.2
		sens_slider.max_value = 2.5
		sens_slider.step = 0.05
		sens_slider.value = 1.0
		sens_slider.custom_minimum_size = Vector2(0, 24)
		sens_slider.value_changed.connect(_on_sens_changed)
		sens_box.add_child(sens_slider)
		vbox.add_child(sens_box)

		gyro_btn = Button.new()
		gyro_btn.name = "GyroBtn"
		gyro_btn.text = "Gyro Aim: OFF"
		gyro_btn.custom_minimum_size = Vector2(0, 38)
		gyro_btn.add_theme_font_size_override("font_size", 13)
		gyro_btn.pressed.connect(_on_toggle_gyro)
		vbox.add_child(gyro_btn)

		haptics_btn = Button.new()
		haptics_btn.name = "HapticsBtn"
		haptics_btn.text = "Vibration Haptics: ON"
		haptics_btn.custom_minimum_size = Vector2(0, 38)
		haptics_btn.add_theme_font_size_override("font_size", 13)
		haptics_btn.pressed.connect(_on_toggle_haptics)
		vbox.add_child(haptics_btn)

		restart_btn = Button.new()
		restart_btn.name = "RestartBtn"
		restart_btn.text = "RESTART ARENA"
		restart_btn.custom_minimum_size = Vector2(0, 38)
		restart_btn.add_theme_font_size_override("font_size", 13)
		restart_btn.pressed.connect(_on_restart_pressed)
		vbox.add_child(restart_btn)

		quit_btn = Button.new()
		quit_btn.name = "QuitBtn"
		quit_btn.text = "QUIT TO DESKTOP / ANDROID"
		quit_btn.custom_minimum_size = Vector2(0, 42)
		quit_btn.add_theme_font_size_override("font_size", 13)
		quit_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		var st_quit := StyleBoxFlat.new()
		st_quit.bg_color = Color(0.35, 0.12, 0.12, 0.90)
		st_quit.border_width_left = 1
		st_quit.border_width_top = 1
		st_quit.border_width_right = 1
		st_quit.border_width_bottom = 1
		st_quit.border_color = Color(0.95, 0.35, 0.35, 0.95)
		st_quit.set_corner_radius_all(6)
		quit_btn.add_theme_stylebox_override("normal", st_quit)
		quit_btn.pressed.connect(_on_quit_pressed)
		vbox.add_child(quit_btn)

func _sync_settings_to_ui() -> void:
	if is_instance_valid(player):
		if "gyro_enabled" in player and gyro_btn:
			gyro_btn.text = "Gyro Aim: ON" if player.gyro_enabled else "Gyro Aim: OFF"
		if "touch_look_sensitivity" in player and sens_slider and sens_label:
			var base_mult = player.touch_look_sensitivity / 0.0032
			sens_slider.value = base_mult
			sens_label.text = "Look Sensitivity: %.2fx" % base_mult

func toggle_menu() -> void:
	if is_menu_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	if is_menu_open:
		return
	is_menu_open = true
	_sync_settings_to_ui()
	if top_menu_btn:
		top_menu_btn.visible = false
	if modal_overlay:
		modal_overlay.visible = true
	if is_instance_valid(player):
		player.is_menu_open = true
		player.capture_mouse(false)
		if player.has_method("reset_touch_controls"):
			player.reset_touch_controls()
	menu_opened.emit()

func close_menu() -> void:
	if not is_menu_open:
		return
	is_menu_open = false
	if modal_overlay:
		modal_overlay.visible = false
	if top_menu_btn:
		top_menu_btn.visible = true
	if is_instance_valid(player):
		player.is_menu_open = false
		player.capture_mouse(not player.is_mobile_controls)
	menu_closed.emit()

func _on_sens_changed(val: float) -> void:
	if sens_label:
		sens_label.text = "Look Sensitivity: %.2fx" % val
	if is_instance_valid(player):
		player.touch_look_sensitivity = 0.0032 * val
		player.mouse_sensitivity = 0.002 * val

func _on_toggle_gyro() -> void:
	if is_instance_valid(player) and "gyro_enabled" in player:
		player.gyro_enabled = not player.gyro_enabled
		if gyro_btn:
			gyro_btn.text = "Gyro Aim: ON" if player.gyro_enabled else "Gyro Aim: OFF"

func _on_toggle_haptics() -> void:
	haptics_enabled = not haptics_enabled
	if haptics_btn:
		haptics_btn.text = "Vibration Haptics: ON" if haptics_enabled else "Vibration Haptics: OFF"
	if is_instance_valid(player) and "haptics_enabled" in player:
		player.haptics_enabled = haptics_enabled
	if haptics_enabled and is_instance_valid(player) and player.has_method("vibrate_mobile"):
		player.vibrate_mobile(25)

func _on_restart_pressed() -> void:
	close_menu()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_menu()
			get_viewport().set_input_as_handled()
