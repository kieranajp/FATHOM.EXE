# GUT unit tests for FATHOM.EXE T10 Audio System
extends GutTest


func test_audio_tuning_loaded() -> void:
	assert_not_null(AudioBus.tuning, "Audio tuning should be loaded.")
	assert_eq(AudioBus.tuning.wind_base_pitch, 1.0, "Default wind base pitch should be 1.0.")
	assert_eq(AudioBus.tuning.beep_volume_db, -6.0, "Default beep volume should be -6 dB.")


func test_waveforms_generated() -> void:
	var streams = [
		AudioBus.shoot_stream,
		AudioBus.explosion_stream,
		AudioBus.large_explosion_stream,
		AudioBus.splash_stream,
		AudioBus.dock_jingle_stream,
		AudioBus.coin_stream,
		AudioBus.clink_stream,
		AudioBus.low_buzz_stream,
		AudioBus.travel_sweep_stream,
		AudioBus.siren_loop_stream,
		AudioBus.siren_oneshot_stream,
		AudioBus.wind_stream,
		AudioBus.waves_stream
	]
	
	for s in streams:
		assert_not_null(s, "Stream should be pre-generated and not null.")
		assert_true(s is AudioStreamWAV, "Stream should be of type AudioStreamWAV.")
		assert_eq(s.mix_rate, 44100, "WAV mix rate should be 44.1 kHz.")
		assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS, "WAV format should be signed 16-bit PCM.")


func test_loop_points_configured() -> void:
	# Wind loop
	assert_eq(AudioBus.wind_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Wind stream should loop forward.")
	assert_eq(AudioBus.wind_stream.loop_begin, 0, "Wind stream loop begin should be 0.")
	assert_true(AudioBus.wind_stream.loop_end > 0, "Wind stream loop end should be > 0.")
	
	# Waves loop
	assert_eq(AudioBus.waves_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Waves stream should loop forward.")
	
	# Siren loop
	assert_eq(AudioBus.siren_loop_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Siren loop stream should loop forward.")
	
	# One-shots should not loop
	assert_eq(AudioBus.shoot_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "Shoot stream should not loop.")
	assert_eq(AudioBus.explosion_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "Explosion stream should not loop.")


func test_sfx_pool_initialized() -> void:
	assert_eq(AudioBus.sfx_pool.size(), AudioBus.POOL_SIZE, "SFX pool size should match POOL_SIZE.")
	for p in AudioBus.sfx_pool:
		assert_not_null(p, "SFX player should not be null.")
		assert_true(p is AudioStreamPlayer, "SFX player should be an AudioStreamPlayer.")
		assert_eq(p.bus, "SFX", "SFX player should route to SFX bus.")
		assert_true(p.is_inside_tree(), "SFX player should be added to the scene tree.")


func test_ambient_players_initialized() -> void:
	assert_not_null(AudioBus.wind_player, "Wind player should not be null.")
	assert_eq(AudioBus.wind_player.bus, "Ambient", "Wind player should route to Ambient bus.")
	assert_true(AudioBus.wind_player.playing, "Wind player should be playing continuously.")
	
	assert_not_null(AudioBus.waves_player, "Waves player should not be null.")
	assert_eq(AudioBus.waves_player.bus, "Ambient", "Waves player should route to Ambient bus.")
	assert_true(AudioBus.waves_player.playing, "Waves player should be playing continuously.")


func test_wind_pitch_modulation() -> void:
	AudioBus.update_wind_frequency(0.0)
	assert_almost_eq(AudioBus.current_wind_pitch, 1.0, 0.01, "Wind pitch should be 1.0 at 0.0 intensity.")
	
	AudioBus.update_wind_frequency(1.0)
	assert_almost_eq(AudioBus.current_wind_pitch, 1.9, 0.01, "Wind pitch should be 1.9 at 1.0 intensity.")


func test_siren_start_stop() -> void:
	assert_not_null(AudioBus.siren_player, "Siren player should not be null.")
	assert_false(AudioBus.siren_player.playing, "Siren player should not start playing by default.")
	
	# Start enforcer alert
	EventBus.enforcer_alert_started.emit()
	assert_true(AudioBus.siren_player.playing, "Siren player should start playing on enforcer alert start.")
	
	# End enforcer alert
	EventBus.enforcer_alert_ended.emit()
	assert_false(AudioBus.siren_player.playing, "Siren player should stop playing on enforcer alert end.")
