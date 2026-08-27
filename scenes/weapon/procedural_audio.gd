extends Node

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
		var byte_val = int((sample + 1.0) * 127.5)
		data.set(i, byte_val)
		
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
		var byte_val = int((sample + 1.0) * 127.5)
		data.set(i, byte_val)
		
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
		var byte_val = int((sample + 1.0) * 127.5)
		data.set(i, byte_val)
		
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
		var byte_val = int((sample + 1.0) * 127.5)
		data.set(i, byte_val)
		
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
		var byte_val = int((sample + 1.0) * 127.5)
		data.set(i, byte_val)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
