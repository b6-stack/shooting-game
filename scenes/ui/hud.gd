extends Control

@onready var hitmarker: Control = $Hitmarker
@onready var weapon_name_label: Label = $BottomRight/VBox/WeaponName
@onready var ammo_label: Label = $BottomRight/VBox/AmmoLabel
@onready var grenade_label: Label = $BottomRight/VBox/GrenadeLabel
@onready var score_label: Label = $TopLeft/ScoreLabel
@onready var crosshair: Control = $Crosshair

@onready var ch_top: ColorRect = $Crosshair/Top
@onready var ch_bottom: ColorRect = $Crosshair/Bottom
@onready var ch_left: ColorRect = $Crosshair/Left
@onready var ch_right: ColorRect = $Crosshair/Right
@onready var perf_label: Label = $TopRight/PerfLabel

var hitmarker_tween: Tween
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

func _process(_delta: float) -> void:
	if perf_label:
		var fps = Engine.get_frames_per_second()
		perf_label.text = "%d FPS | %s" % [fps, gpu_name]
		if fps < 35:
			perf_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.9))
		else:
			perf_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.9))

func set_weapon_info(w_name: String, has_gl: bool, slot_num: int) -> void:
	if weapon_name_label:
		weapon_name_label.text = "[%d] %s" % [slot_num, w_name]
	if grenade_label:
		grenade_label.visible = has_gl

func update_ammo(current: int, total: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current, total]

func update_grenades(current: int, total: int) -> void:
	if grenade_label:
		grenade_label.text = "M203 40mm: %d / %d" % [current, total]

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

func set_aiming(is_aiming: bool) -> void:
	if crosshair:
		var target_alpha = 0.0 if is_aiming else 1.0
		var tween = create_tween()
		tween.tween_property(crosshair, "modulate:a", target_alpha, 0.15)
