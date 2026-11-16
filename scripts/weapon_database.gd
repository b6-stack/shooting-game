extends Node

const WeaponAttachments = preload("res://scripts/weapon_attachments.gd")

signal loadout_changed(slot_idx: int, weapon_id: String)
signal attachments_changed(slot_idx: int)

const CATALOG_PATH := "res://data/weapon_catalog.json"
const SAVE_PATH := "user://loadout.json"
const SAVE_ATTACHMENTS_PATH := "user://attachments.json"
const SLOT_COUNT := 5

const GUN_CATEGORIES := ["rifle", "smg", "pistol", "shotgun", "sniper", "lmg"]
const ACCESSORY_CATEGORIES := ["launcher", "grenade", "shield"]
const MELEE_CATEGORIES := ["melee"]

const SLOT_RULES := [
	{"name": "PRIMARY GUN", "lock": "GUNS ONLY", "categories": GUN_CATEGORIES},
	{"name": "SECONDARY GUN", "lock": "GUNS ONLY", "categories": GUN_CATEGORIES},
	{"name": "ACCESSORY 1", "lock": "ACCESSORIES ONLY", "categories": ACCESSORY_CATEGORIES},
	{"name": "ACCESSORY 2", "lock": "ACCESSORIES ONLY", "categories": ACCESSORY_CATEGORIES},
	{"name": "MELEE", "lock": "MELEE ONLY", "categories": MELEE_CATEGORIES}
]

const DEFAULT_LOADOUT := [
	"colt_m4a1",
	"beretta_m9",
	"rpg7",
	"mk2_handbomb",
	"kabar_tanto"
]

const CATEGORY_ORDER := [
	"all",
	"rifle",
	"smg",
	"pistol",
	"shotgun",
	"sniper",
	"lmg",
	"launcher",
	"grenade",
	"melee",
	"shield"
]

const CATEGORY_LABELS := {
	"all": "ALL",
	"rifle": "RIFLES",
	"smg": "SMGS",
	"pistol": "PISTOLS",
	"shotgun": "SHOTGUNS",
	"sniper": "SNIPERS",
	"lmg": "LMGS",
	"launcher": "LAUNCHERS",
	"grenade": "GRENADES",
	"melee": "MELEE",
	"shield": "SHIELD"
}

var catalog: Array = []
var by_id: Dictionary = {}
var by_category: Dictionary = {}
var loadout: Array[String] = []
var slot_attachments: Array[Dictionary] = []
var weapon_presets: Dictionary = {}

func _ready() -> void:
	load_catalog()
	load_saved_loadout()
	load_saved_attachments()

func load_catalog() -> void:
	catalog.clear()
	by_id.clear()
	by_category.clear()
	for cat in CATEGORY_ORDER:
		by_category[cat] = []

	var f = FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if not f:
		push_error("[WeaponDB] Missing weapon_catalog.json!")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Array):
		push_error("[WeaponDB] Invalid weapon_catalog.json format!")
		return

	catalog = parsed
	catalog.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))

	for entry in catalog:
		var wid = str(entry.get("id", ""))
		var cat = str(entry.get("category", "rifle"))
		by_id[wid] = entry
		by_category["all"].append(entry)
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(entry)

func is_category_allowed_in_slot(slot_idx: int, category: String) -> bool:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return false
	return category in SLOT_RULES[slot_idx]["categories"]

func is_weapon_allowed_in_slot(slot_idx: int, weapon_id: String) -> bool:
	var data = by_id.get(weapon_id, {})
	if data.is_empty():
		return false
	return is_category_allowed_in_slot(slot_idx, str(data.get("category", "")))

func get_slot_display_name(slot_idx: int) -> String:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return "SLOT %d" % (slot_idx + 1)
	return str(SLOT_RULES[slot_idx]["name"])

func get_slot_lock_hint(slot_idx: int) -> String:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return ""
	return str(SLOT_RULES[slot_idx]["lock"])

func load_saved_loadout() -> void:
	loadout.clear()
	for id_str in DEFAULT_LOADOUT:
		loadout.append(id_str)

	var migrated := false
	if FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			f.close()
			if data is Array:
				for i in range(mini(SLOT_COUNT, data.size())):
					var cand = str(data[i])
					if is_weapon_allowed_in_slot(i, cand):
						loadout[i] = cand
					else:
						migrated = true
				if data.size() != SLOT_COUNT:
					migrated = true

	# Fallback guarantee: every slot holds a valid allowed weapon
	for i in range(SLOT_COUNT):
		if not is_weapon_allowed_in_slot(i, loadout[i]):
			for entry in catalog:
				if is_category_allowed_in_slot(i, str(entry.get("category", ""))):
					loadout[i] = str(entry["id"])
					migrated = true
					break

	if migrated:
		save_loadout()

func save_loadout() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(loadout))
		f.close()

func load_saved_attachments() -> void:
	slot_attachments.clear()
	weapon_presets.clear()
	for i in range(SLOT_COUNT):
		slot_attachments.append(WeaponAttachments.default_attachments())

	if FileAccess.file_exists(SAVE_ATTACHMENTS_PATH):
		var f = FileAccess.open(SAVE_ATTACHMENTS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				var slots_arr = parsed.get("slots", [])
				if slots_arr is Array:
					for i in range(mini(SLOT_COUNT, slots_arr.size())):
						var wid = get_slot_weapon_id(i)
						slot_attachments[i] = WeaponAttachments.sanitize_attachments(wid, slots_arr[i])
				var presets_dict = parsed.get("presets", {})
				if presets_dict is Dictionary:
					for k in presets_dict.keys():
						var wid = str(k)
						weapon_presets[wid] = WeaponAttachments.sanitize_attachments(wid, presets_dict[k])

	for i in range(SLOT_COUNT):
		var wid = get_slot_weapon_id(i)
		slot_attachments[i] = WeaponAttachments.sanitize_attachments(wid, slot_attachments[i])
		if wid != "" and not weapon_presets.has(wid):
			weapon_presets[wid] = slot_attachments[i].duplicate()

func save_attachments() -> void:
	var f = FileAccess.open(SAVE_ATTACHMENTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"slots": slot_attachments,
			"presets": weapon_presets
		}))
		f.close()

func get_slot_attachments(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slot_attachments.size():
		return WeaponAttachments.default_attachments()
	return slot_attachments[slot_idx].duplicate()

func get_weapon_preset(weapon_id: String) -> Dictionary:
	if weapon_presets.has(weapon_id):
		return WeaponAttachments.sanitize_attachments(weapon_id, weapon_presets[weapon_id])
	return WeaponAttachments.default_attachments()

func set_weapon_preset(weapon_id: String, raw_att: Dictionary) -> Dictionary:
	var clean = WeaponAttachments.sanitize_attachments(weapon_id, raw_att)
	weapon_presets[weapon_id] = clean.duplicate()
	var changed_any := false
	for i in range(mini(SLOT_COUNT, loadout.size())):
		if loadout[i] == weapon_id:
			while slot_attachments.size() <= i:
				slot_attachments.append(WeaponAttachments.default_attachments())
			slot_attachments[i] = clean.duplicate()
			changed_any = true
	save_attachments()
	if changed_any:
		for i in range(mini(SLOT_COUNT, loadout.size())):
			if loadout[i] == weapon_id:
				attachments_changed.emit(i)
	return clean

func set_slot_attachments(slot_idx: int, raw_att: Dictionary) -> void:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return
	var wid = get_slot_weapon_id(slot_idx)
	var clean = WeaponAttachments.sanitize_attachments(wid, raw_att)
	while slot_attachments.size() <= slot_idx:
		slot_attachments.append(WeaponAttachments.default_attachments())
	slot_attachments[slot_idx] = clean.duplicate()
	if wid != "":
		weapon_presets[wid] = clean.duplicate()
	save_attachments()
	attachments_changed.emit(slot_idx)

func get_weapon(weapon_id: String) -> Dictionary:
	return by_id.get(weapon_id, {})

func get_weapons_in_category(cat: String) -> Array:
	return by_category.get(cat, [])

func get_slot_weapon_id(slot_idx: int) -> String:
	if slot_idx >= 0 and slot_idx < loadout.size():
		return loadout[slot_idx]
	return ""

func set_slot_weapon(slot_idx: int, weapon_id: String, custom_att: Variant = null) -> bool:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return false
	if not is_weapon_allowed_in_slot(slot_idx, weapon_id):
		return false
	loadout[slot_idx] = weapon_id
	while slot_attachments.size() <= slot_idx:
		slot_attachments.append(WeaponAttachments.default_attachments())
	var src_att: Dictionary = custom_att if (custom_att is Dictionary) else get_weapon_preset(weapon_id)
	var clean = WeaponAttachments.sanitize_attachments(weapon_id, src_att)
	slot_attachments[slot_idx] = clean.duplicate()
	weapon_presets[weapon_id] = clean.duplicate()
	save_loadout()
	save_attachments()
	loadout_changed.emit(slot_idx, weapon_id)
	return true

func _pick_random_attachments(weapon_id: String) -> Dictionary:
	var att = WeaponAttachments.default_attachments()
	var opts = WeaponAttachments.get_allowed_optics(weapon_id)
	if not opts.is_empty() and randf() < 0.78:
		att["optic"] = opts[randi() % opts.size()]
	if WeaponAttachments.can_attach_suppressor(weapon_id) and randf() < 0.45:
		att["suppressor"] = true
	if WeaponAttachments.can_attach_ugl(weapon_id) and randf() < 0.35:
		att["ugl"] = true
	if WeaponAttachments.can_attach_laser(weapon_id) and randf() < 0.45:
		att["laser"] = true
	return att

func randomize_loadout() -> void:
	var pool_primary = get_weapons_in_category("rifle") + get_weapons_in_category("smg") + get_weapons_in_category("shotgun") + get_weapons_in_category("sniper") + get_weapons_in_category("lmg")
	var pool_guns = pool_primary + get_weapons_in_category("pistol")
	var pool_acc = get_weapons_in_category("launcher") + get_weapons_in_category("grenade") + get_weapons_in_category("shield")
	var pool_melee = get_weapons_in_category("melee")

	if not pool_primary.is_empty():
		var w1 = str(pool_primary[randi() % pool_primary.size()]["id"])
		set_slot_weapon(0, w1, _pick_random_attachments(w1))
	if not pool_guns.is_empty():
		var w2 = str(pool_guns[randi() % pool_guns.size()]["id"])
		if pool_guns.size() > 1 and w2 == loadout[0]:
			w2 = str(pool_guns[(randi() % (pool_guns.size() - 1) + 1) % pool_guns.size()]["id"])
		set_slot_weapon(1, w2, _pick_random_attachments(w2))
	if not pool_acc.is_empty():
		var a1 = str(pool_acc[randi() % pool_acc.size()]["id"])
		set_slot_weapon(2, a1)
		var a2 = str(pool_acc[randi() % pool_acc.size()]["id"])
		if pool_acc.size() > 1 and a2 == a1:
			for attempt in range(5):
				var cand = str(pool_acc[randi() % pool_acc.size()]["id"])
				if cand != a1:
					a2 = cand
					break
		set_slot_weapon(3, a2)
	if not pool_melee.is_empty():
		set_slot_weapon(4, str(pool_melee[randi() % pool_melee.size()]["id"]))
