# AudioBus — all sound playback. Wraps a pool of AudioStreamPlayer.
#
# Procedurally synthesizes classic retro 8-bit sound effects at boot as
# `AudioStreamWAV` resources, rather than streaming via `AudioStreamGenerator`
# per-frame. Boot-time synthesis trades a few hundred ms of startup work for
# zero per-shot synth cost and no buffer-underrun clicks on rapid fire — the
# per-shot path is just a player checkout from the pool.
extends Node

# Load the tuning file
var tuning: AudioTuning

# Streams populated at boot time
var shoot_stream: AudioStreamWAV
var explosion_stream: AudioStreamWAV
var large_explosion_stream: AudioStreamWAV
var splash_stream: AudioStreamWAV
var dock_jingle_stream: AudioStreamWAV
var coin_stream: AudioStreamWAV
var clink_stream: AudioStreamWAV
var low_buzz_stream: AudioStreamWAV
var travel_sweep_stream: AudioStreamWAV
var siren_loop_stream: AudioStreamWAV
var siren_oneshot_stream: AudioStreamWAV
var wind_stream: AudioStreamWAV
var waves_stream: AudioStreamWAV

# SFX Pooling
const POOL_SIZE = 16
var sfx_pool: Array[AudioStreamPlayer] = []

# Ambient & Continuous Players
var wind_player: AudioStreamPlayer
var waves_player: AudioStreamPlayer
var siren_player: AudioStreamPlayer

# Dynamic controls
var current_wind_pitch: float = 1.0
var current_wind_intensity: float = 0.0
var time_passed: float = 0.0


func _ready() -> void:
	# Load tuning resource or fallback to defaults
	if ResourceLoader.exists("res://data/tuning/audio.tres"):
		tuning = load("res://data/tuning/audio.tres") as AudioTuning
	if not tuning:
		tuning = AudioTuning.new()

	# Create Audio Buses programmatically if not present
	setup_audio_buses()

	# Pre-generate all synth waveforms
	generate_all_waveforms()

	# Setup the SFX Player Pool
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)

	# Setup Ambient wind player
	wind_player = AudioStreamPlayer.new()
	wind_player.bus = "Ambient"
	wind_player.stream = wind_stream
	add_child(wind_player)
	wind_player.play()

	# Setup Ambient waves player
	waves_player = AudioStreamPlayer.new()
	waves_player.bus = "Ambient"
	waves_player.stream = waves_stream
	add_child(waves_player)
	waves_player.play()

	# Setup Siren alarm player
	siren_player = AudioStreamPlayer.new()
	siren_player.bus = "SFX"
	siren_player.stream = siren_loop_stream
	add_child(siren_player)

	# Register for EventBus signals
	subscribe_to_events()


func _process(delta: float) -> void:
	time_passed += delta

	# Modulate Wind Ambient
	if wind_player and wind_player.playing:
		# LFO at 0.08 Hz (12.5s cycle) simulates wind gusts
		var gust = sin(time_passed * 2.0 * PI * 0.08) * 0.15
		wind_player.pitch_scale = current_wind_pitch * (1.0 + gust)
		
		# Volume scaling with speed: base 0.04 up to 0.09 (represented in linear scale)
		var base_vol = 0.04 + current_wind_intensity * 0.05
		var linear_gust_vol = base_vol * (1.0 + gust * 0.5)
		wind_player.volume_db = linear_to_db(linear_gust_vol) + tuning.wind_volume_db

	# Modulate Wave Ambient
	if waves_player and waves_player.playing:
		# Low LFO at 0.2 Hz (5.0s cycle) simulates ocean swells/crests
		var swell = 0.08 + sin(time_passed * 2.0 * PI * 0.2) * 0.04
		waves_player.volume_db = linear_to_db(swell) + tuning.waves_volume_db


# Helper to dynamically map/add Mixer Buses
func setup_audio_buses() -> void:
	var buses = ["SFX", "Music", "Ambient"]
	for bus_name in buses:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			AudioServer.add_bus()
			var idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

	# Set volume levels from tuning
	var sfx_idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_idx, tuning.sfx_volume_db)
	
	var music_idx = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_idx, tuning.music_volume_db)
	
	var ambient_idx = AudioServer.get_bus_index("Ambient")
	AudioServer.set_bus_volume_db(ambient_idx, tuning.ambient_volume_db)


# SFX Dispatch Helper
func play_sfx(stream: AudioStreamWAV, volume_offset_db: float = 0.0, pitch_val: float = 1.0) -> void:
	if not stream:
		return
	
	# Find first idle player in pool
	for p in sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_offset_db
			p.pitch_scale = pitch_val
			p.play()
			return
			
	# If all busy, steal the oldest (first pool index)
	var steal = sfx_pool[0]
	steal.stream = stream
	steal.volume_db = volume_offset_db
	steal.pitch_scale = pitch_val
	steal.play()


# --- PUBLIC API ---

func play_beep(freq: float, duration: float) -> void:
	var custom_beep = _generate_beep(freq, duration, 0.15)
	play_sfx(custom_beep, tuning.beep_volume_db)


func play_shoot() -> void:
	play_sfx(shoot_stream, tuning.shoot_volume_db)


func play_explosion() -> void:
	play_sfx(explosion_stream, tuning.explosion_volume_db)


func play_splash() -> void:
	play_sfx(splash_stream, tuning.splash_volume_db)


func play_dock_jingle() -> void:
	# Dock jingle plays on SFX or Music bus. Let's send it to Music bus player!
	var music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.stream = dock_jingle_stream
	music_player.volume_db = tuning.dock_jingle_volume_db
	add_child(music_player)
	music_player.play()
	# Clean up temporary player once done
	music_player.finished.connect(music_player.queue_free)


func play_alarm_siren() -> void:
	play_sfx(siren_oneshot_stream, tuning.siren_volume_db)


func play_coin() -> void:
	play_sfx(coin_stream, tuning.coin_volume_db)


func play_clink() -> void:
	play_sfx(clink_stream, tuning.clink_volume_db)


func play_travel_sweep(progress_pct: float = 0.0) -> void:
	# Modulate start sweep frequency by setting player pitch scale
	# JS: base_freq = 400 + progressPct * 800
	# Base sweep starts at 400Hz and sweeps to 600Hz.
	# Pitch shift by factor: (400 + progressPct * 800) / 400 = 1.0 + progressPct * 2.0
	var pitch_val = 1.0 + progress_pct * 2.0
	play_sfx(travel_sweep_stream, tuning.travel_sweep_volume_db, pitch_val)


func play_low_buzz() -> void:
	play_sfx(low_buzz_stream, tuning.low_buzz_volume_db)


func update_wind_frequency(intensity: float) -> void:
	# intensity is ship speed ratio speed/max_speed (typically 0.0 to 1.0)
	current_wind_intensity = clampf(intensity, 0.0, 1.0)
	
	# Pitch scales from wind_base_pitch (e.g. 1.0) to 1.9x
	current_wind_pitch = tuning.wind_base_pitch * (1.0 + current_wind_intensity * 0.9)


# --- EVENT MONITORING ---

func subscribe_to_events() -> void:
	if not EventBus:
		return
	
	EventBus.cannon_fired.connect(func(_side: String, _ammo_type: String, _ship: Node):
		play_shoot()
	)
	
	EventBus.ship_damaged.connect(func(_ship: Node, _amount: float, _ammo_type: String):
		play_explosion()
	)
	
	EventBus.projectile_splashed.connect(func(_x: float, _z: float):
		play_splash()
	)
	
	EventBus.port_docked.connect(func(_port: PortDef):
		play_dock_jingle()
	)
	
	EventBus.cargo_bought.connect(func(_item: String, _amount: int, _price: int):
		play_coin()
	)
	
	EventBus.cargo_sold.connect(func(_item: String, _amount: int, _price: int):
		play_coin()
	)
	
	EventBus.market_transaction_failed.connect(func(_reason: String):
		play_low_buzz()
	)
	
	EventBus.enforcer_alert_started.connect(func():
		if siren_player and not siren_player.playing:
			siren_player.volume_db = tuning.siren_volume_db
			siren_player.play()
	)
	
	EventBus.enforcer_alert_ended.connect(func():
		if siren_player and siren_player.playing:
			siren_player.stop()
	)
	
	EventBus.island_collided.connect(func(_port: PortDef, _ship: Node):
		# Collisions use a slightly pitch-raised explosion
		play_sfx(explosion_stream, tuning.explosion_volume_db, 1.3)
	)
	
	EventBus.ship_sunk.connect(func(_ship: Node, _sunk_by: Node):
		# Sinking events use the deep large explosion
		play_sfx(large_explosion_stream, tuning.explosion_volume_db)
	)
	
	EventBus.travel_started.connect(func(_target: ArchipelagoDef):
		play_travel_sweep(0.0)
	)


# --- WAVEFORM SYNTHESIS PIPELINE ---

func _create_wav(float_samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var num_samples = float_samples.size()
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	
	for i in range(num_samples):
		var val = int(float_samples[i] * 32767.0)
		val = clampi(val, -32768, 32767)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
		
	stream.data = bytes
	return stream


func generate_all_waveforms() -> void:
	shoot_stream = _generate_shoot()
	explosion_stream = _generate_explosion(0.25, false)
	large_explosion_stream = _generate_explosion(0.35, true)
	splash_stream = _generate_splash()
	dock_jingle_stream = _generate_dock_jingle()
	coin_stream = _generate_coin()
	clink_stream = _generate_clink()
	low_buzz_stream = _generate_low_buzz()
	travel_sweep_stream = _generate_travel_sweep()
	siren_loop_stream = _generate_siren_loop()
	siren_oneshot_stream = _generate_siren_oneshot()
	wind_stream = _generate_wind_loop()
	waves_stream = _generate_waves_loop()


func _generate_beep(freq: float, duration: float, volume_factor: float) -> AudioStreamWAV:
	var sr = 44100.0
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase = 0.0
	var inc = freq / sr
	
	for i in range(num_samples):
		var t = float(i) / sr
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = sin(phase * 2.0 * PI) * gain
		phase = fmod(phase + inc, 1.0)
		
	return _create_wav(float_samples)


func _generate_shoot(volume_factor: float = 0.2) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 0.35
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		var freq = 280.0 * pow(60.0 / 280.0, t / duration)
		phase = fmod(phase + (freq / sr), 1.0)
		var saw = 2.0 * phase - 1.0
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = saw * gain
		
	return _create_wav(float_samples)


func _generate_explosion(volume_factor: float, is_large: bool) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 1.2 if is_large else 0.8
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var sub_duration = 0.9 if is_large else 0.6
	var sub_phase = 0.0
	var filtered_noise = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		
		# White noise filter sweep
		var noise = randf() * 2.0 - 1.0
		var fc_start = 500.0 if is_large else 600.0
		var fc_end = 50.0 if is_large else 80.0
		var fc = fc_start * pow(fc_end / fc_start, t / duration)
		var alpha = clamp(2.0 * PI * fc / sr, 0.0, 1.0)
		filtered_noise = filtered_noise + alpha * (noise - filtered_noise)
		
		var noise_gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		var noise_contrib = filtered_noise * noise_gain
		
		# Sub sine sweep
		var sub_contrib = 0.0
		if t < sub_duration:
			var sub_freq_start = 80.0 if is_large else 100.0
			var sub_freq_end = 8.0 if is_large else 10.0
			var sub_freq = sub_freq_start * pow(sub_freq_end / sub_freq_start, t / sub_duration)
			sub_phase = fmod(sub_phase + (sub_freq / sr), 1.0)
			
			var sub_vol = 0.35 if is_large else 0.30
			var sub_gain = sub_vol * pow(0.001 / sub_vol, t / sub_duration)
			sub_contrib = sin(sub_phase * 2.0 * PI) * sub_gain
			
		float_samples[i] = noise_contrib + sub_contrib
		
	return _create_wav(float_samples)


func _generate_splash(volume_factor: float = 0.25) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 0.55
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var filtered_noise = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		var noise = randf() * 2.0 - 1.0
		var fc = 250.0 * pow(30.0 / 250.0, t / duration)
		var alpha = clamp(2.0 * PI * fc / sr, 0.0, 1.0)
		filtered_noise = filtered_noise + alpha * (noise - filtered_noise)
		
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = filtered_noise * gain
		
	return _create_wav(float_samples)


func _generate_dock_jingle(volume_factor: float = 0.18) -> AudioStreamWAV:
	var sr = 44100.0
	var notes = [261.63, 329.63, 392.00, 523.25, 392.00, 523.25, 659.25]
	var tempo = 0.12
	var duration = tempo * notes.size() + tempo * 1.8
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phases = PackedFloat32Array()
	phases.resize(notes.size())
	phases.fill(0.0)
	
	for i in range(num_samples):
		var t = float(i) / sr
		var sum_val = 0.0
		
		for idx in range(notes.size()):
			var note_start = idx * tempo
			var note_duration = tempo * 1.8
			var note_end = note_start + note_duration
			
			if t >= note_start and t < note_end:
				var rel_t = t - note_start
				var freq = notes[idx]
				phases[idx] = fmod(phases[idx] + (freq / sr), 1.0)
				
				# Triangle wave
				var p = phases[idx]
				var tri = 4.0 * p if p < 0.25 else (2.0 - 4.0 * p if p < 0.75 else 4.0 * p - 4.0)
				
				# Envelope with 0.02s attack
				var gain = 0.0
				var attack = 0.02
				if rel_t < attack:
					gain = lerp(0.0, volume_factor, rel_t / attack)
				else:
					gain = volume_factor * pow(0.001 / volume_factor, (rel_t - attack) / (note_duration - attack))
					
				sum_val += tri * gain
				
		float_samples[i] = sum_val
		
	return _create_wav(float_samples)


func _generate_coin(volume_factor: float = 0.12) -> AudioStreamWAV:
	var sr = 44100.0
	var notes = [987.77, 1318.51]
	var tempo = 0.08
	var duration = 0.23
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phases = PackedFloat32Array()
	phases.resize(notes.size())
	phases.fill(0.0)
	
	for i in range(num_samples):
		var t = float(i) / sr
		var sum_val = 0.0
		
		for idx in range(notes.size()):
			var note_start = idx * tempo
			var note_duration = 0.15
			var note_end = note_start + note_duration
			
			if t >= note_start and t < note_end:
				var rel_t = t - note_start
				var freq = notes[idx]
				phases[idx] = fmod(phases[idx] + (freq / sr), 1.0)
				
				var sqr = 1.0 if sin(phases[idx] * 2.0 * PI) >= 0.0 else -1.0
				var gain = volume_factor * pow(0.001 / volume_factor, rel_t / note_duration)
				sum_val += sqr * gain
				
		float_samples[i] = sum_val
		
	return _create_wav(float_samples)


func _generate_clink(volume_factor: float = 0.12) -> AudioStreamWAV:
	var sr = 44100.0
	var freqs = [1480.0, 1850.0]
	var duration = 0.3
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase1 = 0.0
	var phase2 = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		
		phase1 = fmod(phase1 + (freqs[0] / sr), 1.0)
		phase2 = fmod(phase2 + (freqs[1] / sr), 1.0)
		
		var p1 = phase1
		var tri1 = 4.0 * p1 if p1 < 0.25 else (2.0 - 4.0 * p1 if p1 < 0.75 else 4.0 * p1 - 4.0)
		var p2 = phase2
		var tri2 = 4.0 * p2 if p2 < 0.25 else (2.0 - 4.0 * p2 if p2 < 0.75 else 4.0 * p2 - 4.0)
		
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = (tri1 + tri2) * gain
		
	return _create_wav(float_samples)


func _generate_low_buzz(volume_factor: float = 0.15) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 0.15
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase = 0.0
	var freq = 80.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		phase = fmod(phase + (freq / sr), 1.0)
		var saw = 2.0 * phase - 1.0
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = saw * gain
		
	return _create_wav(float_samples)


func _generate_travel_sweep(volume_factor: float = 0.08) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 0.15
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase = 0.0
	var base_freq = 400.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		var freq = base_freq * pow(1.5, t / duration)
		phase = fmod(phase + (freq / sr), 1.0)
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = sin(phase * 2.0 * PI) * gain
		
	return _create_wav(float_samples)


func _generate_siren_loop(volume_factor: float = 0.08) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 0.5
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		var freq = 0.0
		if t < 0.25:
			freq = 440.0 + 1760.0 * t
		else:
			freq = 880.0 - 1760.0 * (t - 0.25)
			
		phase = fmod(phase + (freq / sr), 1.0)
		var saw = 2.0 * phase - 1.0
		float_samples[i] = saw * volume_factor
		
	var stream = _create_wav(float_samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	return stream


func _generate_siren_oneshot(volume_factor: float = 0.08) -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 0.5
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sr
		var freq = 0.0
		if t < 0.25:
			freq = 440.0 + 1760.0 * t
		else:
			freq = 880.0 - 1760.0 * (t - 0.25)
			
		phase = fmod(phase + (freq / sr), 1.0)
		var saw = 2.0 * phase - 1.0
		var gain = volume_factor * pow(0.001 / volume_factor, t / duration)
		float_samples[i] = saw * gain
		
	return _create_wav(float_samples)


func _generate_wind_loop() -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 2.0
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var filtered_noise = 0.0
	var alpha = 2.0 * PI * 250.0 / sr
	
	for i in range(5000):
		var noise = randf() * 2.0 - 1.0
		filtered_noise = filtered_noise + alpha * (noise - filtered_noise)
		
	for i in range(num_samples):
		var noise = randf() * 2.0 - 1.0
		filtered_noise = filtered_noise + alpha * (noise - filtered_noise)
		float_samples[i] = filtered_noise
		
	var fade_samples = int(sr * 0.2)
	for i in range(fade_samples):
		var w = float(i) / fade_samples
		var end_idx = num_samples - fade_samples + i
		float_samples[i] = lerp(float_samples[end_idx], float_samples[i], w)
		
	var stream = _create_wav(float_samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	return stream


func _generate_waves_loop() -> AudioStreamWAV:
	var sr = 44100.0
	var duration = 2.0
	var num_samples = int(sr * duration)
	var float_samples = PackedFloat32Array()
	float_samples.resize(num_samples)
	
	var filtered_noise = 0.0
	var alpha = 2.0 * PI * 80.0 / sr
	
	for i in range(5000):
		var noise = randf() * 2.0 - 1.0
		filtered_noise = filtered_noise + alpha * (noise - filtered_noise)
		
	for i in range(num_samples):
		var noise = randf() * 2.0 - 1.0
		filtered_noise = filtered_noise + alpha * (noise - filtered_noise)
		float_samples[i] = filtered_noise
		
	var fade_samples = int(sr * 0.2)
	for i in range(fade_samples):
		var w = float(i) / fade_samples
		var end_idx = num_samples - fade_samples + i
		float_samples[i] = lerp(float_samples[end_idx], float_samples[i], w)
		
	var stream = _create_wav(float_samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	return stream
