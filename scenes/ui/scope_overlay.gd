extends Control

var scope_style: String = ""
var overlay_alpha: float = 0.0
var zoom_label: String = ""
var recoil_px: Vector2 = Vector2.ZERO

func set_scope_state(style: String, alpha: float, zoom_txt: String = "", recoil_offset_px: Vector2 = Vector2.ZERO) -> void:
	var clamped := clampf(alpha, 0.0, 1.0)
	var should_show := (style != "" and clamped > 0.01)
	if not should_show:
		if visible:
			visible = false
		scope_style = ""
		overlay_alpha = 0.0
		zoom_label = ""
		recoil_px = Vector2.ZERO
		return

	var dirty := (
		not visible
		or scope_style != style
		or absf(overlay_alpha - clamped) > 0.005
		or zoom_label != zoom_txt
		or recoil_px.distance_squared_to(recoil_offset_px) > 0.04
	)
	scope_style = style
	overlay_alpha = clamped
	zoom_label = zoom_txt
	recoil_px = recoil_offset_px
	visible = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	if scope_style == "" or overlay_alpha <= 0.01:
		return

	var a := overlay_alpha
	var c := size * 0.5 + recoil_px
	var outer_r := maxf(size.x, size.y) * 0.95

	var r_lens := size.y * 0.425
	var surround_alpha := 0.97 * a
	var lens_tint := Color(0.02, 0.04, 0.05, 0.07 * a)
	match scope_style:
		"acog":
			r_lens = size.y * 0.405
			surround_alpha = 0.86 * a
			lens_tint = Color(0.04, 0.03, 0.02, 0.05 * a)
		"aug":
			r_lens = size.y * 0.375
			surround_alpha = 0.93 * a
			lens_tint = Color(0.02, 0.05, 0.04, 0.06 * a)

	# Subtle optical glass tint inside aperture
	draw_circle(c, r_lens, lens_tint)

	# Soft inner tube bezel gradient rings
	_draw_annulus(c, r_lens * 0.91, r_lens * 0.97, Color(0.01, 0.012, 0.015, 0.30 * a), 56)
	_draw_annulus(c, r_lens * 0.97, r_lens, Color(0.01, 0.012, 0.015, 0.72 * a), 56)
	# Outer dark housing surround
	_draw_annulus(c, r_lens, outer_r, Color(0.012, 0.015, 0.020, surround_alpha), 56)
	# Sharp machined inner ring lip
	draw_arc(c, r_lens, 0.0, TAU, 64, Color(0.08, 0.09, 0.11, 0.95 * a), 2.5, true)

	match scope_style:
		"sniper":
			_draw_sniper_reticle(c, r_lens, a)
		"acog":
			_draw_acog_reticle(c, r_lens, a)
		"aug":
			_draw_aug_reticle(c, r_lens, a)

	if zoom_label != "":
		var font := ThemeDB.fallback_font
		if font:
			var badge_pos := c + Vector2(r_lens * 0.52, r_lens * 0.78)
			draw_string(font, badge_pos, zoom_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.85, 0.92, 1.0, 0.85 * a))

func _draw_annulus(center: Vector2, r_in: float, r_out: float, color: Color, segs: int) -> void:
	for i in range(segs):
		var a0 := float(i) / segs * TAU
		var a1 := float(i + 1) / segs * TAU
		var p0 := center + Vector2(cos(a0), sin(a0)) * r_in
		var p1 := center + Vector2(cos(a1), sin(a1)) * r_in
		var p2 := center + Vector2(cos(a1), sin(a1)) * r_out
		var p3 := center + Vector2(cos(a0), sin(a0)) * r_out
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), color)

func _draw_sniper_reticle(c: Vector2, r: float, a: float) -> void:
	var ink := Color(0.04, 0.04, 0.05, 0.94 * a)
	var red_glow := Color(1.0, 0.18, 0.14, 0.95 * a)

	# Fine hairline crosshairs
	draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), ink, 1.4, true)
	draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), ink, 1.4, true)

	# Heavy German outer stadia posts on Left, Right, Bottom
	var post_start := r * 0.56
	draw_line(Vector2(c.x - r, c.y), Vector2(c.x - post_start, c.y), ink, 4.5)
	draw_line(Vector2(c.x + post_start, c.y), Vector2(c.x + r, c.y), ink, 4.5)
	draw_line(Vector2(c.x, c.y + post_start), Vector2(c.x, c.y + r), ink, 4.5)

	# Mil-dots & half-mil hash marks
	var mil_step := 22.0
	for k in range(1, 6):
		var d := k * mil_step
		if d < post_start - 8.0:
			draw_circle(Vector2(c.x + d, c.y), 2.3, ink)
			draw_circle(Vector2(c.x - d, c.y), 2.3, ink)
			draw_circle(Vector2(c.x, c.y + d), 2.3, ink)
			draw_circle(Vector2(c.x, c.y - d), 2.3, ink)
		var hd := d - mil_step * 0.5
		if hd > 6.0 and hd < post_start:
			draw_line(Vector2(c.x + hd, c.y - 3.0), Vector2(c.x + hd, c.y + 3.0), ink, 1.2)
			draw_line(Vector2(c.x - hd, c.y - 3.0), Vector2(c.x - hd, c.y + 3.0), ink, 1.2)
			draw_line(Vector2(c.x - 3.0, c.y + hd), Vector2(c.x + 3.0, c.y + hd), ink, 1.2)
			draw_line(Vector2(c.x - 3.0, c.y - hd), Vector2(c.x + 3.0, c.y - hd), ink, 1.2)

	# Illuminated micro red center pip
	draw_circle(c, 2.4, red_glow)

func _draw_acog_reticle(c: Vector2, r: float, a: float) -> void:
	var ink := Color(0.04, 0.04, 0.05, 0.94 * a)
	var chev_outer := Color(1.0, 0.14, 0.08, 0.96 * a)
	var chev_core := Color(1.0, 0.65, 0.35, 0.96 * a)

	# Left, right, bottom black stadia posts leading toward chevron
	var side_gap := 38.0
	draw_line(Vector2(c.x - r, c.y + 2.0), Vector2(c.x - side_gap, c.y + 2.0), ink, 2.2)
	draw_line(Vector2(c.x + side_gap, c.y + 2.0), Vector2(c.x + r, c.y + 2.0), ink, 2.2)
	for sx in [58.0, 96.0]:
		draw_line(Vector2(c.x - sx, c.y - 3.0), Vector2(c.x - sx, c.y + 7.0), ink, 1.5)
		draw_line(Vector2(c.x + sx, c.y - 3.0), Vector2(c.x + sx, c.y + 7.0), ink, 1.5)

	# Lower BDC drop ladder with 400 / 600 / 800m horizontal stadia bars
	draw_line(Vector2(c.x, c.y + 11.0), Vector2(c.x, c.y + r), ink, 2.0)
	var drops := [
		{"y": 24.0, "w": 16.0, "lbl": "4"},
		{"y": 48.0, "w": 12.0, "lbl": "6"},
		{"y": 74.0, "w": 9.0, "lbl": "8"},
	]
	var font := ThemeDB.fallback_font
	for d in drops:
		var dy := float(d["y"])
		var hw := float(d["w"])
		draw_line(Vector2(c.x - hw, c.y + dy), Vector2(c.x + hw, c.y + dy), ink, 1.8)
		if font:
			draw_string(font, Vector2(c.x + hw + 5.0, c.y + dy + 4.0), str(d["lbl"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)

	# Glowing red ACOG chevron whose apex tip is exact screen center (c)
	var tip := c
	var leg_l := c + Vector2(-11.0, 12.0)
	var leg_r := c + Vector2(11.0, 12.0)
	draw_polyline(PackedVector2Array([leg_l, tip, leg_r]), chev_outer, 3.6, true)
	draw_polyline(PackedVector2Array([leg_l + Vector2(2.0, -1.5), tip, leg_r + Vector2(-2.0, -1.5)]), chev_core, 1.5, true)

func _draw_aug_reticle(c: Vector2, r: float, a: float) -> void:
	var ink := Color(0.05, 0.05, 0.06, 0.92 * a)
	var ring_r := 13.0

	# Classic Steyr AUG Donut-of-Death center circle + 4 outer posts
	draw_arc(c, ring_r, 0.0, TAU, 32, ink, 2.2, true)
	draw_line(Vector2(c.x - r, c.y), Vector2(c.x - ring_r, c.y), ink, 2.0)
	draw_line(Vector2(c.x + ring_r, c.y), Vector2(c.x + r, c.y), ink, 2.0)
	draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y - ring_r), ink, 2.0)
	draw_line(Vector2(c.x, c.y + ring_r), Vector2(c.x, c.y + r), ink, 2.0)
	draw_circle(c, 1.6, Color(1.0, 0.25, 0.15, 0.65 * a))
