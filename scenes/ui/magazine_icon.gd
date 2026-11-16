extends Control
class_name MagazineIcon

@export var current_ammo: int = 30
@export var max_ammo: int = 30
@export var is_active_mag: bool = false
@export var mag_label: String = ""

const ICON_W: float = 16.0
const ICON_H: float = 27.0

func _init() -> void:
	custom_minimum_size = Vector2(ICON_W + 4.0, ICON_H + 6.0)
	mouse_filter = MOUSE_FILTER_IGNORE

func set_mag_state(current: int, maximum: int, active: bool = false, label_text: String = "") -> void:
	var changed = (current_ammo != current or max_ammo != maximum or is_active_mag != active or mag_label != label_text)
	current_ammo = current
	max_ammo = maxi(1, maximum)
	is_active_mag = active
	mag_label = label_text
	if changed:
		queue_redraw()

func get_status_color() -> Color:
	if current_ammo <= 0:
		return Color(0.10, 0.11, 0.13, 0.92) # Black (Empty)
	var ratio = float(current_ammo) / float(max_ammo)
	if ratio < 0.30:
		return Color(0.95, 0.22, 0.20, 0.95) # Red (~1/4)
	elif ratio < 0.55:
		return Color(1.0, 0.52, 0.12, 0.95) # Orange (< 1/2)
	elif ratio < 0.85:
		return Color(0.96, 0.86, 0.18, 0.95) # Yellow (~3/4)
	else:
		return Color(0.20, 0.92, 0.36, 0.95) # Green (Full)

func _draw() -> void:
	var ox: float = 2.0
	var oy: float = 4.0
	
	# Active magazine highlight glow and bracket
	if is_active_mag:
		var glow_rect = Rect2(ox - 2.5, oy - 2.5, ICON_W + 5.0, ICON_H + 5.0)
		draw_rect(glow_rect, Color(0.20, 0.75, 1.0, 0.18), true)
		draw_rect(glow_rect, Color(0.35, 0.88, 1.0, 0.90), false, 1.2)
		draw_circle(Vector2(ox + ICON_W * 0.5, oy - 2.5), 1.8, Color(0.40, 0.92, 1.0, 1.0))
	
	# Outer magazine silhouette polygon
	var outer_pts := PackedVector2Array([
		Vector2(ox + 4.5, oy + 0.0), Vector2(ox + 11.5, oy + 0.0),   # Feed lips top
		Vector2(ox + 11.5, oy + 3.5), Vector2(ox + 14.5, oy + 5.5), # Right shoulder
		Vector2(ox + 14.5, oy + 22.0),                               # Right body
		Vector2(ox + 16.0, oy + 22.5), Vector2(ox + 16.0, oy + 26.5), # Right baseplate flange
		Vector2(ox + 0.0, oy + 26.5), Vector2(ox + 0.0, oy + 22.5),   # Left baseplate flange
		Vector2(ox + 1.5, oy + 22.0),                               # Left body bottom
		Vector2(ox + 1.5, oy + 5.5), Vector2(ox + 4.5, oy + 3.5)    # Left shoulder
	])
	
	# Subtle drop shadow
	var shadow_pts := PackedVector2Array()
	for pt in outer_pts:
		shadow_pts.append(pt + Vector2(1.0, 1.2))
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.45))
	
	# Outer dark casing
	draw_colored_polygon(outer_pts, Color(0.13, 0.15, 0.18, 0.95))
	
	# Inner fill polygon (color coded status)
	var fill_col = get_status_color()
	var inner_pts := PackedVector2Array([
		Vector2(ox + 5.5, oy + 1.5), Vector2(ox + 10.5, oy + 1.5),
		Vector2(ox + 10.5, oy + 4.0), Vector2(ox + 13.0, oy + 5.8),
		Vector2(ox + 13.0, oy + 21.0),
		Vector2(ox + 3.0, oy + 21.0),
		Vector2(ox + 3.0, oy + 5.8), Vector2(ox + 5.5, oy + 4.0)
	])
	draw_colored_polygon(inner_pts, fill_col)
	
	# Baseplate fill (metal floorplate)
	draw_rect(Rect2(ox + 1.0, oy + 23.0, 14.0, 3.0), Color(0.18, 0.20, 0.24, 0.95))
	draw_rect(Rect2(ox + 1.0, oy + 23.0, 14.0, 3.0), Color(0.35, 0.38, 0.44, 0.75), false, 1.0)
	
	# Tactical magazine ribs (horizontal ridges)
	var rib_col = Color(0, 0, 0, 0.35)
	draw_line(Vector2(ox + 4.0, oy + 10.5), Vector2(ox + 12.0, oy + 10.5), rib_col, 1.0)
	draw_line(Vector2(ox + 4.0, oy + 15.5), Vector2(ox + 12.0, oy + 15.5), rib_col, 1.0)
	
	# Cartridge viewport window slit in center
	var slot_col = Color(0, 0, 0, 0.40)
	draw_line(Vector2(ox + 8.0, oy + 7.5), Vector2(ox + 8.0, oy + 18.5), slot_col, 1.2)
	
	# Top brass cartridge head sitting at feed lips if not empty
	if current_ammo > 0:
		draw_rect(Rect2(ox + 6.0, oy + 1.0, 4.0, 2.5), Color(0.92, 0.76, 0.32, 0.95))
	
	# Outer casing stroke outline
	var border_col = Color(0.38, 0.42, 0.48, 0.85) if not is_active_mag else Color(0.55, 0.85, 1.0, 0.95)
	draw_polyline(outer_pts, border_col, 1.1)
