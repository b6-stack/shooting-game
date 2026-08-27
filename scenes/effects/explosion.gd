extends Node3D

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var smoke_particles: GPUParticles3D = $SmokeParticles
@onready var light: OmniLight3D = $OmniLight3D
@onready var sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

const ProceduralAudio = preload("res://scenes/weapon/procedural_audio.gd")

func _ready() -> void:
	if particles:
		particles.emitting = true
	if smoke_particles:
		smoke_particles.emitting = true
	if sound and sound.stream == null:
		sound.stream = create_explosion_sound()
		sound.play()
		
	if light:
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, 0.4)
		
	await get_tree().create_timer(1.2).timeout
	queue_free()

func create_explosion_sound() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.6
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 8.0)
		var bass = sin(t * 55.0 * TAU) * exp(-t * 12.0)
		var noise = (randf() * 2.0 - 1.0) * env
		var sample = clampf(bass * 0.8 + noise * 0.7, -1.0, 1.0)
		var byte_val = int((sample + 1.0) * 127.5)
		data.set(i, byte_val)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
