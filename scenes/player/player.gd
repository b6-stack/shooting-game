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

# Head & Camera
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hud: CanvasLayer = $HUD

# Multi-Weapon System
var weapon_slots: Array[Node3D] = []
var current_slot: int = 0
var weapon: Node3D = null
var is_switching_weapon: bool = false

# State variables
var mouse_captured: bool = false
var is_aiming: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var bob_time: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	capture_mouse(true)
	if camera:
		camera.fov = default_fov
		camera.near = 0.01
	
	init_weapons()

func _process(_delta: float) -> void:
	# Continuous real-time crosshair spread update
	if weapon and hud:
		var hud_control = hud.get_node_or_null("HUDControl")
		if hud_control and "current_spread" in weapon:
			var min_s = weapon.base_crouching_spread if "base_crouching_spread" in weapon else 0.001
			var max_s = weapon.max_spread if "max_spread" in weapon else 0.08
			var spread_ratio = clampf((weapon.current_spread - min_s) / (max_s - min_s), 0.0, 1.0)
			hud_control.set_crosshair_spread(spread_ratio)

func init_weapons() -> void:
	weapon_slots.clear()
	if weapon_holder:
		for child in weapon_holder.get_children():
			if child is Node3D:
				weapon_slots.append(child)
				child.visible = false
				
	if weapon_slots.size() > 0:
		current_slot = 0
		weapon = weapon_slots[0]
		weapon.visible = true
		weapon.set_process(true)
		setup_weapon_signals()
		refresh_hud()

func setup_weapon_signals() -> void:
	if not weapon or not hud:
		return
	var hud_control = hud.get_node_or_null("HUDControl")
	if not hud_control:
		return
		
	if not weapon.fired.is_connected(_on_weapon_fired):
		weapon.fired.connect(_on_weapon_fired)
	if not weapon.reloaded.is_connected(_on_weapon_reloaded):
		weapon.reloaded.connect(_on_weapon_reloaded)
	if weapon.has_signal("grenade_fired") and not weapon.grenade_fired.is_connected(_on_grenade_fired):
		weapon.grenade_fired.connect(_on_grenade_fired)
	if not weapon.hit_target.is_connected(_on_hit_target):
		weapon.hit_target.connect(_on_hit_target)

func _on_weapon_fired(ammo_left: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control:
		hud_control.update_ammo(ammo_left, weapon.max_ammo)

func _on_weapon_reloaded(ammo_left: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control:
		hud_control.update_ammo(ammo_left, weapon.max_ammo)

func _on_grenade_fired(grenades_left: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control:
		hud_control.update_grenades(grenades_left, weapon.max_grenades)

func _on_hit_target(points: int) -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control:
		hud_control.show_hitmarker()
		hud_control.add_score(points)

func refresh_hud() -> void:
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if not hud_control or not weapon:
		return
		
	var w_name = weapon.weapon_name if "weapon_name" in weapon else "Weapon"
	var has_gl = weapon.has_grenade_launcher if "has_grenade_launcher" in weapon else false
	var cur_gl = weapon.current_grenades if "current_grenades" in weapon else 0
	var max_gl = weapon.max_grenades if "max_grenades" in weapon else 0
	
	hud_control.set_weapon_info(w_name, has_gl, current_slot + 1)
	hud_control.update_ammo(weapon.current_ammo, weapon.max_ammo)
	if has_gl:
		hud_control.update_grenades(cur_gl, max_gl)

func switch_to_slot(slot_idx: int) -> void:
	if is_switching_weapon or slot_idx == current_slot or slot_idx < 0 or slot_idx >= weapon_slots.size():
		return
		
	is_switching_weapon = true
	var old_weapon = weapon
	var new_weapon = weapon_slots[slot_idx]
	
	# Holster old weapon
	if old_weapon and old_weapon.has_method("holster"):
		var holster_tween = old_weapon.holster()
		await holster_tween.finished
		old_weapon.set_process(false)
	elif old_weapon:
		old_weapon.visible = false
		old_weapon.set_process(false)
		
	# Switch reference
	current_slot = slot_idx
	weapon = new_weapon
	weapon.set_process(true)
	setup_weapon_signals()
	refresh_hud()
	
	# Draw new weapon
	if weapon and weapon.has_method("draw_weapon"):
		var draw_tween = weapon.draw_weapon()
		await draw_tween.finished
	elif weapon:
		weapon.visible = true
		
	is_switching_weapon = false

func capture_mouse(capture: bool) -> void:
	mouse_captured = capture
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		capture_mouse(not mouse_captured)
		return
		
	if not mouse_captured:
		if event is InputEventMouseButton and event.pressed:
			capture_mouse(true)
		return

	# Weapon Switching Input
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			switch_to_slot(0)
			return
		elif event.keycode == KEY_2:
			switch_to_slot(1)
			return
		elif event.keycode == KEY_3:
			switch_to_slot(2)
			return
		elif event.keycode == KEY_Q:
			var next_slot = (current_slot + 1) % weapon_slots.size()
			switch_to_slot(next_slot)
			return
			
	if event is InputEventMouseButton and event.pressed:
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

	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		
		# Apply weapon sway
		if weapon and weapon.has_method("add_sway"):
			weapon.add_sway(event.relative)

func toggle_crouch() -> void:
	is_crouching = not is_crouching
	if is_crouching and is_sprinting:
		is_sprinting = false

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump (uncrouches if crouched)
	var jump_pressed = (InputMap.has_action("jump") and Input.is_action_just_pressed("jump")) or Input.is_key_pressed(KEY_SPACE)
	if jump_pressed and is_on_floor():
		if is_crouching:
			is_crouching = false
		else:
			velocity.y = jump_velocity

	# Movement Input (WASD)
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

	# Sprint handling (Shift)
	var is_sprint_held = (InputMap.has_action("sprint") and Input.is_action_pressed("sprint")) or Input.is_key_pressed(KEY_SHIFT)
	if is_sprint_held and input_dir.y < 0 and not is_aiming and not is_switching_weapon:
		if is_crouching:
			is_crouching = false
		is_sprinting = true
	else:
		is_sprinting = false

	# Speed selection
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

	move_and_slide()

	# Update weapon posture & movement state
	if weapon:
		if weapon.has_method("set_crouch"):
			weapon.set_crouch(is_crouching)
		if weapon.has_method("set_movement_speed_ratio"):
			var horiz_speed = Vector2(velocity.x, velocity.z).length()
			weapon.set_movement_speed_ratio(horiz_speed / walk_speed)

	# Process Crouch height transition
	var target_head_y = crouch_head_height if is_crouching else default_head_height
	head.position.y = lerpf(head.position.y, target_head_y, delta * 10.0)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var target_height = crouch_capsule_height if is_crouching else default_capsule_height
		if abs(collision_shape.shape.height - target_height) > 0.005:
			collision_shape.shape.height = lerpf(collision_shape.shape.height, target_height, delta * 10.0)
			collision_shape.position.y = collision_shape.shape.height * 0.5

	# Process Weapon & Aiming
	handle_weapon_actions(delta)

	# Weapon Bobbing
	handle_weapon_bob(delta, input_dir.length())

func handle_weapon_actions(delta: float) -> void:
	if not mouse_captured or is_switching_weapon or not weapon:
		return

	# Tell weapon if sprinting
	if weapon.has_method("set_sprint"):
		weapon.set_sprint(is_sprinting)

	# Aiming (RMB)
	var aim_input = (InputMap.has_action("aim") and Input.is_action_pressed("aim")) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if aim_input:
		is_sprinting = false
	is_aiming = aim_input
	
	if weapon.has_method("set_aim"):
		weapon.set_aim(is_aiming)
		
	var hud_control = hud.get_node_or_null("HUDControl") if hud else null
	if hud_control and hud_control.has_method("set_aiming"):
		hud_control.set_aiming(is_aiming)

	# Dynamic FOV for ADS
	var target_fov = ads_fov if is_aiming else default_fov
	camera.fov = lerpf(camera.fov, target_fov, delta * fov_transition_speed)

	# Firing (LMB) - automatic vs semi-automatic support
	var is_auto = weapon.is_automatic if "is_automatic" in weapon else true
	var shoot_input = false
	if is_auto:
		shoot_input = (InputMap.has_action("shoot") and Input.is_action_pressed("shoot")) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	else:
		shoot_input = (InputMap.has_action("shoot") and Input.is_action_just_pressed("shoot")) or (not InputMap.has_action("shoot") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
			
	if shoot_input:
		is_sprinting = false
		if weapon.has_method("shoot"):
			weapon.shoot(camera)

	# M203 Grenade Launching (F, G, or Middle Mouse Button)
	var has_gl = weapon.has_grenade_launcher if "has_grenade_launcher" in weapon else false
	if has_gl:
		var grenade_input = Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_G) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		if (InputMap.has_action("launch_grenade") and Input.is_action_just_pressed("launch_grenade")):
			grenade_input = true
		if grenade_input:
			is_sprinting = false
			if weapon.has_method("launch_grenade"):
				weapon.launch_grenade(camera)

	# Reloading (R)
	var reload_input = (InputMap.has_action("reload") and Input.is_action_just_pressed("reload")) or Input.is_key_pressed(KEY_R)
	if reload_input and weapon.has_method("reload"):
		weapon.reload()

func handle_weapon_bob(delta: float, move_amount: float) -> void:
	if not weapon or not weapon.has_method("set_bob"):
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
