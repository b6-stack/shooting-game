extends Control

const NVG_SHADER = preload("res://shaders/nvg_screen.gdshader")

@onready var screen_filter: ColorRect = get_node_or_null("ScreenFilter")
@onready var tube_frame: Control = get_node_or_null("TubeFrame")
@onready var telemetry_label: Label = get_node_or_null("TelemetryLabel")

var is_active: bool = false
var _fade_tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_components()

func _ensure_components() -> void:
	if not screen_filter:
		screen_filter = ColorRect.new()
		screen_filter.name = "ScreenFilter"
		screen_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = NVG_SHADER
		screen_filter.material = mat
		add_child(screen_filter)

	if not tube_frame:
		tube_frame = Control.new()
		tube_frame.name = "TubeFrame"
		tube_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tube_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tube_frame.draw.connect(_on_draw_tube_frame)
		add_child(tube_frame)

	if not telemetry_label:
		telemetry_label = Label.new()
		telemetry_label.name = "TelemetryLabel"
		telemetry_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		telemetry_label.offset_top = 22.0
		telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		telemetry_label.add_theme_font_size_override("font_size", 13)
		telemetry_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.52, 0.88))
		telemetry_label.text = "[NVG ACTIVE  |  GEN-3 PHOSPHOR  |  IR ILLUM ON]"
		add_child(telemetry_label)

func set_nvg_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	_ensure_components()

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if active:
		visible = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_fade_tween.tween_callback(func(): visible = false)

func _process(_delta: float) -> void:
	if visible and tube_frame:
		tube_frame.queue_redraw()

func _on_draw_tube_frame() -> void:
	if not visible:
		return
	var vp_size := get_viewport_rect().size
	var center := vp_size * 0.5
	var r := minf(vp_size.x * 0.44, vp_size.y * 0.52)
	var ring_thick := maxf(vp_size.x, vp_size.y) * 0.55

	# Smooth circular dual/single tube vignette around viewport
	# Inner clear circular aperture with soft dark vignetting ring
	var dark_edge := Color(0.02, 0.04, 0.02, 0.98)
	var num_pts := 48
	var outer_r := r + ring_thick

	for i in range(num_pts):
		var a0 := float(i) / float(num_pts) * TAU
		var a1 := float(i + 1) / float(num_pts) * TAU
		var p0_in := center + Vector2(cos(a0), sin(a0)) * r
		var p1_in := center + Vector2(cos(a1), sin(a1)) * r
		var p0_out := center + Vector2(cos(a0), sin(a0)) * outer_r
		var p1_out := center + Vector2(cos(a1), sin(a1)) * outer_r

		var quad := PackedVector2Array([p0_in, p1_in, p1_out, p0_out])
		var cols := PackedColorArray([Color(0.04, 0.08, 0.04, 0.65), Color(0.04, 0.08, 0.04, 0.65), dark_edge, dark_edge])
		tube_frame.draw_polygon(quad, cols)

	# Thin phosphor green reticle ring border
	tube_frame.draw_arc(center, r + 2.0, 0.0, TAU, 64, Color(0.25, 0.85, 0.40, 0.35), 2.0)
