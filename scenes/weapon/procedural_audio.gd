extends Node

static var _cache: Dictionary = {}

static func get_cached(sound_key: String) -> AudioStreamWAV:
	if _cache.has(sound_key):
		return _cache[sound_key]
	var s: AudioStreamWAV
	match sound_key:
		"pistol":
			s = create_pistol_sample()
		"smg":
			s = create_smg_sample()
		"sniper":
			s = create_sniper_sample()
		"gunshot_suppressed":
			s = create_gunshot_suppressed_sample()
		"pistol_suppressed":
			s = create_pistol_suppressed_sample()
		"sniper_suppressed":
			s = create_sniper_suppressed_sample()
		"shotgun":
			s = create_shotgun_sample()
		"lmg":
			s = create_lmg_sample()
		"launcher":
			s = create_rocket_launch_sample()
		"grenade_launcher":
			s = create_thump_sample()
		"grenade":
			s = create_grenade_throw_sample()
		"grenade_bounce":
			s = create_grenade_bounce_sample()
		"smoke_hiss":
			s = create_smoke_hiss_sample()
		"flashbang_bang":
			s = create_flashbang_sample()
		"door_latch":
			s = create_door_latch_sample()
		"melee":
			s = create_melee_swing_sample()
		"melee_hit":
			s = create_melee_hit_sample()
		"shield":
			s = create_shield_bash_sample()
		"mag_out":
			s = create_mag_out_sample()
		"mag_in":
			s = create_mag_in_sample()
		"bolt_rack":
			s = create_bolt_rack_sample()
		"laser_click":
			s = create_laser_click_sample()
		"nvg_on":
			s = create_nvg_sample(true)
		"nvg_off":
			s = create_nvg_sample(false)
		_:
			s = create_gunshot_sample()
	_cache[sound_key] = s
	return s

static func create_gunshot_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.25
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 22.0)
		var punch = sin(t * 120.0 * TAU) * exp(-t * 30.0)
		var noise = (randf() * 2.0 - 1.0) * env
		var sample = clampf((punch * 0.7 + noise * 0.6), -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_gunshot_suppressed_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.14
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	var lp := 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 42.0)
		var thump = sin(t * 140.0 * TAU) * exp(-t * 50.0) * 0.55
		var raw_air = (randf() * 2.0 - 1.0)
		lp = lp * 0.65 + raw_air * 0.35
		var air = lp * exp(-t * 28.0) * 0.45
		var click = sin(t * 950.0 * TAU) * exp(-t * 110.0) * 0.25
		var sample = clampf((thump + air + click) * env * 0.85, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_pistol_suppressed_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.11
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	var lp := 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 52.0)
		var thump = sin(t * 175.0 * TAU) * exp(-t * 60.0) * 0.45
		var raw_air = randf() * 2.0 - 1.0
		lp = lp * 0.58 + raw_air * 0.42
		var air = lp * exp(-t * 36.0) * 0.48
		var slide_click = sin(t * 1350.0 * TAU) * exp(-t * 130.0) * 0.28
		var sample = clampf((thump + air + slide_click) * env * 0.9, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_sniper_suppressed_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.24
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	var lp := 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var bass = sin(t * 88.0 * TAU) * exp(-t * 24.0) * 0.65
		var raw_air = (randf() * 2.0 - 1.0)
		lp = lp * 0.72 + raw_air * 0.28
		var puff = lp * exp(-t * 18.0) * 0.50
		var crack = sin(t * 420.0 * TAU) * exp(-t * 75.0) * 0.30
		var sample = clampf(bass + puff + crack, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_pistol_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.18
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 32.0)
		var punch = sin(t * 185.0 * TAU) * exp(-t * 42.0)
		var crack = (randf() * 2.0 - 1.0) * exp(-t * 26.0)
		var sample = clampf((punch * 0.75 + crack * 0.65) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_smg_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.14
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 38.0)
		var punch = sin(t * 210.0 * TAU) * exp(-t * 48.0)
		var snap = (randf() * 2.0 - 1.0) * env
		var sample = clampf((punch * 0.6 + snap * 0.65), -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_sniper_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.45
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var boom = sin(t * 75.0 * TAU) * exp(-t * 16.0)
		var crack = sin(t * 260.0 * TAU) * exp(-t * 40.0)
		var tail = (randf() * 2.0 - 1.0) * exp(-t * 9.0)
		var sample = clampf(boom * 0.8 + crack * 0.5 + tail * 0.75, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_shotgun_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.36
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var thump = sin(t * 68.0 * TAU) * exp(-t * 14.0)
		var blast = (randf() * 2.0 - 1.0) * exp(-t * 12.0)
		var sample = clampf(thump * 0.85 + blast * 0.85, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_lmg_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.22
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var punch = sin(t * 110.0 * TAU) * exp(-t * 26.0)
		var crack = (randf() * 2.0 - 1.0) * exp(-t * 18.0)
		var sample = clampf(punch * 0.75 + crack * 0.65, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_melee_swing_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.22
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = sin(clampf(t / duration, 0.0, 1.0) * PI)
		var sweep = sin(t * (280.0 - t * 650.0) * TAU) * 0.35
		var air = (randf() * 2.0 - 1.0) * 0.55
		var sample = clampf((sweep + air) * env * 0.85, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_melee_hit_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.16
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 28.0)
		var thud = sin(t * 110.0 * TAU) * 0.75
		var ring = sin(t * 920.0 * TAU) * exp(-t * 36.0) * 0.45
		var sample = clampf((thud + ring) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_shield_bash_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.28
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var thud = sin(t * 65.0 * TAU) * exp(-t * 14.0)
		var clang = sin(t * 480.0 * TAU) * exp(-t * 20.0) * 0.5
		var noise = (randf() * 2.0 - 1.0) * exp(-t * 22.0) * 0.4
		var sample = clampf(thud * 0.8 + clang + noise, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_grenade_throw_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.25
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var ping = sin(t * 2600.0 * TAU) * exp(-t * 50.0) * 0.4
		var whoosh = (randf() * 2.0 - 1.0) * sin(clampf(t / duration, 0.0, 1.0) * PI) * 0.5
		var sample = clampf(ping + whoosh, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_grenade_bounce_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.09
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 58.0)
		var clink = sin(t * 1950.0 * TAU) * 0.45 + sin(t * 3100.0 * TAU) * 0.25
		var body_tap = sin(t * 240.0 * TAU) * exp(-t * 40.0) * 0.55
		var sample = clampf((clink + body_tap) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_smoke_hiss_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 1.6
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	var lp := 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var valve = sin(t * 420.0 * TAU) * exp(-t * 45.0) * 0.45
		var raw_n = randf() * 2.0 - 1.0
		lp = lp * 0.45 + raw_n * 0.55
		var env = (1.0 - exp(-t * 25.0)) * exp(-t * 1.4)
		var sample = clampf(valve + (raw_n - lp * 0.5) * env * 0.65, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_flashbang_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 2.0
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var snap = (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.90
		var crack = sin(t * 145.0 * TAU) * exp(-t * 28.0) * 0.75
		var ring = sin(t * 2850.0 * TAU) * exp(-t * 1.8) * 0.22 * (1.0 - exp(-t * 18.0))
		var sample = clampf(snap + crack + ring, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_door_latch_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.18
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var click1 = sin(t * 1480.0 * TAU) * exp(-t * 75.0) * 0.55
		var click2 = sin(t * 920.0 * TAU) * exp(-pow((t - 0.04) * 55.0, 2.0)) * 0.50
		var thud = sin(t * 85.0 * TAU) * exp(-t * 22.0) * 0.65
		var creak = (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.22
		var sample = clampf(click1 + click2 + thud + creak, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_mag_out_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.22
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 18.0)
		var click1 = sin(t * 1200.0 * TAU) * exp(-t * 40.0)
		var slide = (randf() * 2.0 - 1.0) * 0.4 * env
		var sample = clampf(click1 * 0.7 + slide, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_mag_in_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.25
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 24.0)
		var click = sin(t * 600.0 * TAU) * env
		var slap = sin(t * 150.0 * TAU) * exp(-t * 30.0)
		var sample = clampf(click * 0.6 + slap * 0.65, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_bolt_rack_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.35
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var pull_env = exp(-pow((t - 0.05) * 40.0, 2.0))
		var slam_env = exp(-pow((t - 0.20) * 35.0, 2.0))
		var pull = sin(t * 1400.0 * TAU) * pull_env
		var slam = (sin(t * 350.0 * TAU) + sin(t * 850.0 * TAU)) * slam_env
		var noise = (randf() * 2.0 - 1.0) * (pull_env * 0.3 + slam_env * 0.4)
		var sample = clampf(pull * 0.5 + slam * 0.8 + noise, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_reload_sample() -> AudioStreamWAV:
	return create_mag_in_sample()

static func create_thump_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.35
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 10.0)
		var thud = sin(t * 70.0 * TAU) * exp(-t * 14.0)
		var pop = sin(t * 220.0 * TAU) * exp(-t * 35.0)
		var sample = clampf((thud * 0.75 + pop * 0.45) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_rocket_launch_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.55
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var initial_blast = exp(-t * 18.0) * sin(t * 80.0 * TAU)
		var whoosh_env = exp(-pow((t - 0.12) * 10.0, 2.0))
		var whoosh = (randf() * 2.0 - 1.0) * whoosh_env * 0.8
		var rumble = sin(t * (140.0 + t * 400.0) * TAU) * whoosh_env * 0.6
		var sample = clampf(initial_blast * 0.8 + whoosh + rumble, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_can_ding_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.3
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 22.0)
		var harmonic1 = sin(t * 2400.0 * TAU) * 0.6
		var harmonic2 = sin(t * 3650.0 * TAU) * 0.4
		var sample = clampf((harmonic1 + harmonic2) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_robot_hit_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.2
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 30.0)
		var zap = sin(t * (800.0 - t * 2000.0) * TAU)
		var clank = sin(t * 180.0 * TAU) * 0.7
		var sample = clampf((zap * 0.5 + clank * 0.5) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_robot_death_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.6
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 8.0)
		var siren = sin(t * (1200.0 - t * 1500.0) * TAU) * 0.4
		var boom = sin(t * 60.0 * TAU) * exp(-t * 12.0) * 0.8
		var noise = (randf() * 2.0 - 1.0) * env * 0.4
		var sample = clampf((siren + boom + noise) * env, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_laser_click_sample() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.06
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var snap = sin(t * 2400.0 * TAU) * exp(-t * 95.0) * 0.55
		var tic = sin(t * 4100.0 * TAU) * exp(-pow((t - 0.015) * 120.0, 2.0)) * 0.35
		var sample = clampf(snap + tic, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func create_nvg_sample(power_on: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration: float = 0.34 if power_on else 0.24
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var switch_click := sin(t * 1750.0 * TAU) * exp(-t * 85.0) * 0.45
		var frac: float = t / duration
		var freq: float = (950.0 + frac * 3100.0) if power_on else (3600.0 * exp(-t * 11.0))
		phase += freq * TAU / sample_rate
		var whine_env: float = (1.0 - exp(-t * 22.0)) * exp(-t * 5.2) if power_on else exp(-t * 12.0)
		var whine := sin(phase) * whine_env * 0.35
		var sample := clampf(switch_click + whine, -1.0, 1.0)
		data.set(i, int((sample + 1.0) * 127.5))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

static func play_click(node: Node, freq: float = 1200.0, _dur: float = 0.05) -> void:
	if not node or not node.is_inside_tree():
		return
	var asp := AudioStreamPlayer.new()
	asp.stream = get_cached("laser_click")
	asp.pitch_scale = clampf(freq / 2000.0, 0.4, 2.5)
	asp.volume_db = -6.0
	node.add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)
