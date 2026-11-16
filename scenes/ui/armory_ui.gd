extends CanvasLayer

const WeaponAttachments = preload("res://scripts/weapon_attachments.gd")

signal closed
signal slot_equipped(slot_idx: int)

@onready var search_edit: LineEdit = $Margin/MainPanel/RootVBox/HeaderBar/SearchEdit
@onready var randomize_btn: Button = $Margin/MainPanel/RootVBox/HeaderBar/RandomizeBtn
@onready var close_btn: Button = $Margin/MainPanel/RootVBox/HeaderBar/CloseBtn
@onready var category_list: VBoxContainer = $Margin/MainPanel/RootVBox/CategoryScroll/CategoryList if has_node("Margin/MainPanel/RootVBox/CategoryScroll/CategoryList") else $Margin/MainPanel/RootVBox/BodyHBox/CategoryScroll/CategoryList
@onready var weapon_grid: GridContainer = $Margin/MainPanel/RootVBox/BodyHBox/GridScroll/WeaponGrid
@onready var preview_container: Control = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/PreviewContainer")
@onready var preview_viewport: SubViewport = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/PreviewContainer/PreviewViewport
@onready var preview_camera: Camera3D = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/PreviewContainer/PreviewViewport/PreviewCamera
@onready var preview_pivot: Node3D = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/PreviewContainer/PreviewViewport/PreviewPivot
@onready var preview_mesh: MeshInstance3D = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/PreviewContainer/PreviewViewport/PreviewPivot/PreviewMesh
@onready var weapon_title: Label = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/WeaponTitle
@onready var weapon_subtitle: Label = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/WeaponSubtitle
@onready var stats_label: Label = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/StatsLabel
@onready var attachments_header: Label = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/AttachmentsHeader")
@onready var optic_none_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/OpticButtons/OpticNoneBtn")
@onready var optic_aimpoint_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/OpticButtons/OpticAimpointBtn")
@onready var optic_acog_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/OpticButtons/OpticAcogBtn")
@onready var optic_scope_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/OpticButtons/OpticScopeBtn")
@onready var suppressor_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/ModButtons/SuppressorBtn")
@onready var laser_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/ModButtons/LaserBtn")
@onready var ugl_btn: Button = get_node_or_null("Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/ModButtons/UGLBtn")
@onready var slot_buttons_box: VBoxContainer = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/SlotButtons
@onready var status_label: Label = $Margin/MainPanel/RootVBox/BodyHBox/InspectorPanel/InspectorVBox/StatusLabel
@onready var subtitle_label: Label = $Margin/MainPanel/RootVBox/HeaderBar/SubtitleLabel

const SLOT_LABELS := [
	"[1] PRIMARY GUN",
	"[2] SECONDARY GUN",
	"[3] ACCESSORY 1",
	"[4] ACCESSORY 2",
	"[5] MELEE"
]

var current_category: String = "all"
var search_query: String = ""
var selected_weapon_id: String = ""

var category_buttons: Dictionary = {}
var weapon_card_buttons: Dictionary = {}
var slot_buttons: Array[Button] = []

var style_card_normal: StyleBoxFlat
var style_card_selected: StyleBoxFlat
var style_card_equipped: StyleBoxFlat
var style_cat_normal: StyleBoxFlat
var style_cat_active: StyleBoxFlat
var style_slot_allowed: StyleBoxFlat
var style_slot_locked: StyleBoxFlat
var style_att_off: StyleBoxFlat
var style_att_on: StyleBoxFlat
var style_att_disabled: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	_build_category_buttons()
	_build_slot_buttons()
	_connect_attachment_buttons()

	if search_edit:
		search_edit.text_changed.connect(_on_search_changed)
	if randomize_btn:
		randomize_btn.custom_minimum_size.y = 36
		randomize_btn.pressed.connect(_on_randomize_pressed)
	if close_btn:
		close_btn.custom_minimum_size.y = 36
		close_btn.pressed.connect(close_armory)
	if preview_container:
		preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
		preview_container.gui_input.connect(_on_preview_gui_input)

	if has_node("/root/WeaponDB"):
		var db = get_node("/root/WeaponDB")
		db.loadout_changed.connect(_on_loadout_changed)
		if db.has_signal("attachments_changed"):
			db.attachments_changed.connect(_on_db_attachments_changed)
		if subtitle_label:
			subtitle_label.text = "%d Weapons Ready — Slots 1–2: Guns | Slots 3–4: Accessories | Slot 5: Melee" % db.catalog.size()
		selected_weapon_id = db.get_slot_weapon_id(0)

	_refresh_weapon_grid()
	_refresh_inspector()
	_refresh_slot_buttons()

	if preview_viewport:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _build_styles() -> void:
	style_card_normal = StyleBoxFlat.new()
	style_card_normal.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style_card_normal.border_width_left = 1
	style_card_normal.border_width_top = 1
	style_card_normal.border_width_right = 1
	style_card_normal.border_width_bottom = 1
	style_card_normal.border_color = Color(0.24, 0.29, 0.36, 0.9)
	style_card_normal.set_corner_radius_all(6)
	style_card_normal.content_margin_left = 10
	style_card_normal.content_margin_right = 10
	style_card_normal.content_margin_top = 8
	style_card_normal.content_margin_bottom = 8

	style_card_selected = style_card_normal.duplicate()
	style_card_selected.bg_color = Color(0.18, 0.28, 0.42, 1.0)
	style_card_selected.border_width_left = 2
	style_card_selected.border_width_top = 2
	style_card_selected.border_width_right = 2
	style_card_selected.border_width_bottom = 2
	style_card_selected.border_color = Color(0.45, 0.78, 1.0, 1.0)

	style_card_equipped = style_card_normal.duplicate()
	style_card_equipped.bg_color = Color(0.12, 0.22, 0.16, 0.98)
	style_card_equipped.border_color = Color(0.35, 0.85, 0.45, 0.95)

	style_cat_normal = StyleBoxFlat.new()
	style_cat_normal.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	style_cat_normal.set_corner_radius_all(5)
	style_cat_normal.content_margin_left = 10
	style_cat_normal.content_margin_right = 10
	style_cat_normal.content_margin_top = 6
	style_cat_normal.content_margin_bottom = 6

	style_cat_active = style_cat_normal.duplicate()
	style_cat_active.bg_color = Color(0.20, 0.36, 0.56, 1.0)
	style_cat_active.border_width_left = 3
	style_cat_active.border_color = Color(0.45, 0.80, 1.0, 1.0)

	style_slot_allowed = StyleBoxFlat.new()
	style_slot_allowed.bg_color = Color(0.12, 0.20, 0.26, 0.96)
	style_slot_allowed.border_width_left = 2
	style_slot_allowed.border_color = Color(0.35, 0.78, 0.95, 0.95)
	style_slot_allowed.set_corner_radius_all(5)
	style_slot_allowed.content_margin_left = 10
	style_slot_allowed.content_margin_right = 10
	style_slot_allowed.content_margin_top = 2
	style_slot_allowed.content_margin_bottom = 2

	style_slot_locked = style_slot_allowed.duplicate()
	style_slot_locked.bg_color = Color(0.08, 0.09, 0.11, 0.65)
	style_slot_locked.border_color = Color(0.22, 0.24, 0.28, 0.5)

	style_att_off = StyleBoxFlat.new()
	style_att_off.bg_color = Color(0.11, 0.14, 0.18, 0.96)
	style_att_off.border_width_left = 1
	style_att_off.border_width_top = 1
	style_att_off.border_width_right = 1
	style_att_off.border_width_bottom = 1
	style_att_off.border_color = Color(0.28, 0.35, 0.45, 0.85)
	style_att_off.set_corner_radius_all(4)
	style_att_off.content_margin_left = 5
	style_att_off.content_margin_right = 5
	style_att_off.content_margin_top = 2
	style_att_off.content_margin_bottom = 2

	style_att_on = style_att_off.duplicate()
	style_att_on.bg_color = Color(0.16, 0.34, 0.46, 1.0)
	style_att_on.border_color = Color(0.45, 0.85, 1.0, 1.0)

	style_att_disabled = style_att_off.duplicate()
	style_att_disabled.bg_color = Color(0.07, 0.08, 0.10, 0.6)
	style_att_disabled.border_color = Color(0.18, 0.20, 0.24, 0.45)

func _connect_attachment_buttons() -> void:
	if optic_none_btn:
		optic_none_btn.pressed.connect(_on_select_optic.bind(""))
	if optic_aimpoint_btn:
		optic_aimpoint_btn.pressed.connect(_on_select_optic.bind(WeaponAttachments.OPTIC_AIMPOINT))
	if optic_acog_btn:
		optic_acog_btn.pressed.connect(_on_select_optic.bind(WeaponAttachments.OPTIC_ACOG))
	if optic_scope_btn:
		optic_scope_btn.pressed.connect(_on_select_optic.bind(WeaponAttachments.OPTIC_SCOPE))
	if suppressor_btn:
		suppressor_btn.pressed.connect(_on_toggle_suppressor)
	if laser_btn:
		laser_btn.pressed.connect(_on_toggle_laser)
	if ugl_btn:
		ugl_btn.pressed.connect(_on_toggle_ugl)

func _build_category_buttons() -> void:
	if not category_list or not has_node("/root/WeaponDB"):
		return
	var db = get_node("/root/WeaponDB")
	for c in category_list.get_children():
		c.queue_free()
	category_buttons.clear()

	for cat in db.CATEGORY_ORDER:
		var count = db.get_weapons_in_category(cat).size()
		var btn = Button.new()
		btn.text = "%s (%d)" % [db.CATEGORY_LABELS.get(cat, cat.to_upper()), count]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.clip_text = true
		btn.pressed.connect(_on_category_selected.bind(cat))
		category_list.add_child(btn)
		category_buttons[cat] = btn
	_update_category_button_styles()

func _build_slot_buttons() -> void:
	if not slot_buttons_box:
		return
	for c in slot_buttons_box.get_children():
		c.queue_free()
	slot_buttons.clear()

	for i in range(5):
		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 34)
		btn.add_theme_font_size_override("font_size", 12)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.pressed.connect(_on_assign_slot.bind(i))
		slot_buttons_box.add_child(btn)
		slot_buttons.append(btn)

func open_armory(active_slot: int = 0) -> void:
	visible = true
	if preview_viewport:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if has_node("/root/WeaponDB") and selected_weapon_id == "":
		selected_weapon_id = get_node("/root/WeaponDB").get_slot_weapon_id(active_slot)
	_refresh_weapon_grid()
	_refresh_inspector()
	_refresh_slot_buttons()
	if status_label:
		status_label.text = ""

func close_armory() -> void:
	visible = false
	if preview_viewport:
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if search_edit and search_edit.has_focus():
		search_edit.release_focus()
	closed.emit()

var _preview_manual_cooldown: float = 0.0

func _on_preview_gui_input(event: InputEvent) -> void:
	if not preview_pivot:
		return
	if event is InputEventScreenDrag:
		_preview_manual_cooldown = 2.0
		preview_pivot.rotate_y(event.relative.x * 0.012)
		preview_pivot.rotation.x = clampf(preview_pivot.rotation.x + event.relative.y * 0.008, -0.55, 0.55)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_preview_manual_cooldown = 2.0
		preview_pivot.rotate_y(event.relative.x * 0.012)
		preview_pivot.rotation.x = clampf(preview_pivot.rotation.x + event.relative.y * 0.008, -0.55, 0.55)

func _process(delta: float) -> void:
	if not visible:
		return
	if _preview_manual_cooldown > 0.0:
		_preview_manual_cooldown = maxf(0.0, _preview_manual_cooldown - delta)
	elif preview_pivot:
		preview_pivot.rotate_y(delta * 0.75)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if search_edit and search_edit.has_focus():
			if event.keycode == KEY_ESCAPE:
				search_edit.release_focus()
				get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_B, KEY_TAB, KEY_ESCAPE:
				close_armory()
				get_viewport().set_input_as_handled()
			KEY_1:
				_on_assign_slot(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_on_assign_slot(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_on_assign_slot(2)
				get_viewport().set_input_as_handled()
			KEY_4:
				_on_assign_slot(3)
				get_viewport().set_input_as_handled()
			KEY_5:
				_on_assign_slot(4)
				get_viewport().set_input_as_handled()
			KEY_X:
				_on_randomize_pressed()
				get_viewport().set_input_as_handled()

func _on_category_selected(cat: String) -> void:
	current_category = cat
	_update_category_button_styles()
	_refresh_weapon_grid()

func _update_category_button_styles() -> void:
	for cat in category_buttons.keys():
		var btn: Button = category_buttons[cat]
		var st = style_cat_active if cat == current_category else style_cat_normal
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", style_cat_active)
		btn.add_theme_stylebox_override("pressed", style_cat_active)

func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges().to_lower()
	_refresh_weapon_grid()

func _refresh_weapon_grid() -> void:
	if not weapon_grid or not has_node("/root/WeaponDB"):
		return
	var db = get_node("/root/WeaponDB")
	for c in weapon_grid.get_children():
		c.queue_free()
	weapon_card_buttons.clear()

	var list: Array = db.get_weapons_in_category(current_category)
	var filtered: Array = []
	for entry in list:
		if search_query == "":
			filtered.append(entry)
		else:
			var wname = str(entry.get("name", "")).to_lower()
			var wcat = str(entry.get("category", "")).to_lower()
			var wid = str(entry.get("id", "")).to_lower()
			if search_query in wname or search_query in wcat or search_query in wid:
				filtered.append(entry)

	for entry in filtered:
		var wid = str(entry.get("id", ""))
		var wname = str(entry.get("name", ""))
		var wcat = str(entry.get("category", "")).to_upper()

		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 62)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var slot_tags = _get_equipped_slot_tags(wid)
		var tag_str = ("  [%s]" % slot_tags) if slot_tags != "" else ""
		btn.text = "%s\n%s%s" % [wname, wcat, tag_str]
		btn.pressed.connect(_on_weapon_clicked.bind(wid))
		weapon_grid.add_child(btn)
		weapon_card_buttons[wid] = btn

	if filtered.size() > 0 and filtered.size() < 3:
		for _p in range(3 - filtered.size()):
			var pad = Control.new()
			pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pad.custom_minimum_size = Vector2(0, 62)
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			weapon_grid.add_child(pad)

	_update_card_styles()

func _get_equipped_slot_tags(wid: String) -> String:
	if not has_node("/root/WeaponDB"):
		return ""
	var db = get_node("/root/WeaponDB")
	var tags: Array[String] = []
	for i in range(db.loadout.size()):
		if db.loadout[i] == wid:
			tags.append("S%d" % (i + 1))
	return ",".join(tags)

func _update_card_styles() -> void:
	if not has_node("/root/WeaponDB"):
		return
	var db = get_node("/root/WeaponDB")
	for wid in weapon_card_buttons.keys():
		var btn: Button = weapon_card_buttons[wid]
		var is_sel = (wid == selected_weapon_id)
		var is_eq = (wid in db.loadout)
		var st = style_card_selected if is_sel else (style_card_equipped if is_eq else style_card_normal)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", style_card_selected)
		btn.add_theme_stylebox_override("pressed", style_card_selected)

		var entry = db.get_weapon(wid)
		var wname = str(entry.get("name", wid))
		var wcat = str(entry.get("category", "")).to_upper()
		var slot_tags = _get_equipped_slot_tags(wid)
		var tag_str = ("  [%s]" % slot_tags) if slot_tags != "" else ""
		btn.text = "%s\n%s%s" % [wname, wcat, tag_str]

func _on_weapon_clicked(wid: String) -> void:
	selected_weapon_id = wid
	_update_card_styles()
	_refresh_inspector()
	_refresh_slot_buttons()

func _get_current_selected_attachments() -> Dictionary:
	if not has_node("/root/WeaponDB") or selected_weapon_id == "":
		return WeaponAttachments.default_attachments()
	var db = get_node("/root/WeaponDB")
	for i in range(db.loadout.size()):
		if db.loadout[i] == selected_weapon_id:
			return db.get_slot_attachments(i)
	return db.get_weapon_preset(selected_weapon_id)

func _apply_selected_attachments(att: Dictionary) -> void:
	if not has_node("/root/WeaponDB") or selected_weapon_id == "":
		return
	var db = get_node("/root/WeaponDB")
	db.set_weapon_preset(selected_weapon_id, att)
	_refresh_inspector()
	_refresh_slot_buttons()

func _on_select_optic(optic_id: String) -> void:
	if selected_weapon_id == "":
		return
	if not WeaponAttachments.can_attach_optic(selected_weapon_id, optic_id):
		return
	var att = _get_current_selected_attachments()
	att["optic"] = optic_id
	_apply_selected_attachments(att)

func _on_toggle_suppressor() -> void:
	if selected_weapon_id == "" or not WeaponAttachments.can_attach_suppressor(selected_weapon_id):
		return
	var att = _get_current_selected_attachments()
	att["suppressor"] = not bool(att.get("suppressor", false))
	_apply_selected_attachments(att)

func _on_toggle_laser() -> void:
	if selected_weapon_id == "" or not WeaponAttachments.can_attach_laser(selected_weapon_id):
		return
	var att = _get_current_selected_attachments()
	att["laser"] = not bool(att.get("laser", false))
	_apply_selected_attachments(att)

func _on_toggle_ugl() -> void:
	if selected_weapon_id == "" or not WeaponAttachments.can_attach_ugl(selected_weapon_id):
		return
	var att = _get_current_selected_attachments()
	att["ugl"] = not bool(att.get("ugl", false))
	_apply_selected_attachments(att)

func _style_att_button(btn: Button, active: bool, is_enabled: bool) -> void:
	if not btn:
		return
	btn.disabled = not is_enabled
	if not is_enabled:
		btn.add_theme_stylebox_override("disabled", style_att_disabled)
		btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.46, 0.52, 0.72))
	elif active:
		btn.add_theme_stylebox_override("normal", style_att_on)
		btn.add_theme_stylebox_override("hover", style_att_on)
		btn.add_theme_stylebox_override("pressed", style_att_on)
		btn.add_theme_color_override("font_color", Color(0.95, 1.0, 1.0))
	else:
		btn.add_theme_stylebox_override("normal", style_att_off)
		btn.add_theme_stylebox_override("hover", style_att_on)
		btn.add_theme_stylebox_override("pressed", style_att_on)
		btn.add_theme_color_override("font_color", Color(0.80, 0.85, 0.92))

func _refresh_attachment_controls(att: Dictionary) -> void:
	var has_rail = WeaponAttachments.has_rail(selected_weapon_id)
	var builtin = WeaponAttachments.has_built_in_scope(selected_weapon_id)
	var cur_opt = str(att.get("optic", ""))

	if attachments_header:
		if builtin:
			attachments_header.text = "ATTACHMENTS (BUILT-IN SCOPE):"
		elif has_rail:
			attachments_header.text = "ATTACHMENTS (PICATINNY RAIL):"
		else:
			attachments_header.text = "ATTACHMENTS:"

	if optic_none_btn:
		if builtin:
			optic_none_btn.text = "Built-in"
		elif not has_rail:
			optic_none_btn.text = "No Rail"
		else:
			optic_none_btn.text = "Stock"
		_style_att_button(optic_none_btn, has_rail and cur_opt == "", has_rail)

	_style_att_button(optic_aimpoint_btn, cur_opt == WeaponAttachments.OPTIC_AIMPOINT, WeaponAttachments.can_attach_optic(selected_weapon_id, WeaponAttachments.OPTIC_AIMPOINT))
	_style_att_button(optic_acog_btn, cur_opt == WeaponAttachments.OPTIC_ACOG, WeaponAttachments.can_attach_optic(selected_weapon_id, WeaponAttachments.OPTIC_ACOG))
	_style_att_button(optic_scope_btn, cur_opt == WeaponAttachments.OPTIC_SCOPE, WeaponAttachments.can_attach_optic(selected_weapon_id, WeaponAttachments.OPTIC_SCOPE))

	if suppressor_btn:
		var can_supp = WeaponAttachments.can_attach_suppressor(selected_weapon_id)
		var builtin_supp = WeaponAttachments.is_already_suppressed(selected_weapon_id)
		var on_supp = can_supp and bool(att.get("suppressor", false))
		if builtin_supp:
			suppressor_btn.text = "Supp: BUILT"
		elif not can_supp:
			suppressor_btn.text = "Supp: N/A"
		else:
			suppressor_btn.text = "Supp: ON" if on_supp else "Supp: OFF"
		_style_att_button(suppressor_btn, on_supp, can_supp)

	if laser_btn:
		var can_laser = WeaponAttachments.can_attach_laser(selected_weapon_id)
		var on_laser = can_laser and bool(att.get("laser", false))
		if not can_laser:
			laser_btn.text = "Laser: N/A"
		else:
			laser_btn.text = "Laser: ON" if on_laser else "Laser: OFF"
		_style_att_button(laser_btn, on_laser, can_laser)

	if ugl_btn:
		var can_ugl = WeaponAttachments.can_attach_ugl(selected_weapon_id)
		var on_ugl = can_ugl and bool(att.get("ugl", false))
		if not can_ugl:
			ugl_btn.text = "M203: N/A"
		else:
			ugl_btn.text = "M203: ON" if on_ugl else "M203: OFF"
		_style_att_button(ugl_btn, on_ugl, can_ugl)

func _refresh_inspector() -> void:
	if not has_node("/root/WeaponDB") or selected_weapon_id == "":
		return
	var db = get_node("/root/WeaponDB")
	var data = db.get_weapon(selected_weapon_id)
	if data.is_empty():
		return

	var att = _get_current_selected_attachments()

	if weapon_title:
		weapon_title.text = str(data.get("name", selected_weapon_id))

	var cat = str(data.get("category", "rifle"))
	var fire_mode = "AUTO" if bool(data.get("is_automatic", false)) else "SEMI"
	if cat == "melee":
		fire_mode = "MELEE SLASH"
	elif cat == "shield":
		fire_mode = "GUARD / BASH"
	elif cat == "grenade":
		fire_mode = "THROWABLE"
	elif cat == "launcher":
		fire_mode = "40MM DRUM" if str(data.get("launcher_mode", "")) == "grenade_launcher" else "ROCKET"
	elif cat == "shotgun":
		fire_mode = "BUCKSHOT"

	var slot_role = "GUNS (1-2)"
	if cat in db.ACCESSORY_CATEGORIES:
		slot_role = "ACCESSORIES (3-4)"
	elif cat in db.MELEE_CATEGORIES:
		slot_role = "MELEE (5)"

	if weapon_subtitle:
		weapon_subtitle.text = "%s  |  %s  |  %s" % [cat.to_upper(), fire_mode, slot_role]

	var dmg = float(data.get("damage", 0.0))
	var pellets = int(data.get("pellet_count", 1))
	var fr = maxf(float(data.get("fire_rate", 0.1)), 0.01)
	var rpm = int(round(60.0 / fr))
	var mag = int(data.get("max_ammo", 0))
	var r_time = float(data.get("reload_time", 0.0))
	var eff_fov = int(round(WeaponAttachments.get_effective_ads_fov(selected_weapon_id, att, float(data.get("ads_fov", 60.0)), cat)))
	var zoom_tag = WeaponAttachments.get_scope_zoom_label(selected_weapon_id, att, cat)
	var fov_str = ("%d deg (%s)" % [eff_fov, zoom_tag]) if zoom_tag != "" else ("%d deg" % eff_fov)

	var dmg_str = "%d x %d (%d total)" % [int(dmg), pellets, int(dmg * pellets)] if pellets > 1 else "%d" % int(dmg)
	var ammo_str = "Infinite" if mag <= 0 else "%d" % mag
	var reload_str = "-" if r_time <= 0.0 else "%.1fs" % r_time

	if cat == "grenade":
		var gtype := str(data.get("grenade_type", "frag"))
		var effect_str := "Frag Blast (%d DMG)" % int(dmg)
		var fuse_str := "2.6s Fuse (Bounce)"
		if gtype == "smoke":
			effect_str = "Smoke Screen (15s)"
			fuse_str = "1.7s Fuse (Bounce)"
		elif gtype == "flash":
			effect_str = "Stun / Blind (16m)"
			fuse_str = "1.6s Fuse (Bounce)"
		if stats_label:
			stats_label.text = "Effect: %s  |  Fuse: %s\nThrow: LMB Overhand / RMB+LMB Underhand\nCarry: %s  |  Restock: %s" % [
				effect_str, fuse_str, ammo_str, reload_str
			]
	elif stats_label:
		stats_label.text = "Damage: %s  |  Rate: %d RPM\nADS FOV: %s\nMagazine: %s  |  Reload: %s" % [
			dmg_str, rpm, fov_str, ammo_str, reload_str
		]

	_refresh_attachment_controls(att)

	# Update 3D Preview Mesh + Live Attachment Models
	var mpath = str(data.get("mesh_path", ""))
	if preview_mesh and mpath != "" and ResourceLoader.exists(mpath):
		preview_mesh.mesh = load(mpath) as Mesh
		if preview_pivot:
			preview_pivot.rotation = Vector3.ZERO
			var old_att = preview_pivot.get_node_or_null("AttachmentsNode")
			if old_att:
				preview_pivot.remove_child(old_att)
				old_att.queue_free()
			var att_node = WeaponAttachments.build_attachment_nodes(selected_weapon_id, att)
			preview_pivot.add_child(att_node)

		var ab = data.get("aabb_size", [0.1, 0.2, 0.7])
		var sz = Vector3(float(ab[0]), float(ab[1]), float(ab[2]))
		if bool(att.get("suppressor", false)):
			sz.z += WeaponAttachments.get_suppressor_forward_extension(selected_weapon_id)
		var radius = maxf(0.18, sz.length() * 0.52)
		var dist = radius / sin(deg_to_rad(18.0)) * 0.72
		if preview_camera:
			preview_camera.look_at_from_position(Vector3(dist * 0.78, radius * 0.25, dist * 0.62), Vector3.ZERO, Vector3.UP)

func _format_att_summary(wid: String, att: Dictionary) -> String:
	var parts: Array[String] = []
	var opt = str(att.get("optic", ""))
	if opt != "":
		parts.append(WeaponAttachments.OPTIC_LABELS.get(opt, opt.to_upper()))
	elif WeaponAttachments.has_built_in_scope(wid):
		parts.append("Scope")
	if bool(att.get("suppressor", false)):
		parts.append("Supp")
	if bool(att.get("laser", false)):
		parts.append("Laser")
	if bool(att.get("ugl", false)):
		parts.append("M203")
	return ", ".join(parts)

func _refresh_slot_buttons() -> void:
	if not has_node("/root/WeaponDB"):
		return
	var db = get_node("/root/WeaponDB")
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var wid = db.get_slot_weapon_id(i)
		var wdata = db.get_weapon(wid)
		var wname = str(wdata.get("name", wid))
		var att = db.get_slot_attachments(i) if db.has_method("get_slot_attachments") else {}
		var mod_str = _format_att_summary(wid, att)
		var cur_str = "%s [%s]" % [wname, mod_str] if mod_str != "" else wname
		var allowed = (selected_weapon_id != "" and db.is_weapon_allowed_in_slot(i, selected_weapon_id))
		btn.disabled = not allowed
		if allowed:
			btn.text = "%s\nCurrent: %s" % [SLOT_LABELS[i], cur_str]
			btn.add_theme_stylebox_override("normal", style_slot_allowed)
			btn.add_theme_stylebox_override("hover", style_card_selected)
			btn.add_theme_stylebox_override("pressed", style_card_selected)
			btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		else:
			btn.text = "%s (%s)\nCurrent: %s" % [SLOT_LABELS[i], db.get_slot_lock_hint(i), cur_str]
			btn.add_theme_stylebox_override("disabled", style_slot_locked)
			btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.54, 0.75))

func _on_assign_slot(slot_idx: int) -> void:
	if not has_node("/root/WeaponDB") or selected_weapon_id == "":
		return
	var db = get_node("/root/WeaponDB")
	var wdata = db.get_weapon(selected_weapon_id)
	if not db.is_weapon_allowed_in_slot(slot_idx, selected_weapon_id):
		if status_label:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
			status_label.text = "Slot %d is locked (%s)" % [slot_idx + 1, db.get_slot_lock_hint(slot_idx)]
		return
	var cur_att = _get_current_selected_attachments()
	if db.set_slot_weapon(slot_idx, selected_weapon_id, cur_att):
		if status_label:
			status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			status_label.text = "Equipped %s -> Slot %d" % [str(wdata.get("name", "")), slot_idx + 1]
		slot_equipped.emit(slot_idx)

func _on_randomize_pressed() -> void:
	if not has_node("/root/WeaponDB"):
		return
	var db = get_node("/root/WeaponDB")
	db.randomize_loadout()
	_refresh_inspector()
	if status_label:
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		status_label.text = "Randomized all 5 slots!"

func _on_loadout_changed(_slot_idx: int, _weapon_id: String) -> void:
	_refresh_slot_buttons()
	_update_card_styles()

func _on_db_attachments_changed(_slot_idx: int) -> void:
	_refresh_slot_buttons()
