extends Node
## Procedurally synthesized sound effects and ambient music (no external
## audio files needed). Sounds are generated once at startup.

const RATE := 22050
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams.click = _tone(0.06, 900.0, 0.0, 0.4, 0.0)
	_streams.hit = _noise_burst(0.12, 0.6, 1800.0)
	_streams.slash = _noise_burst(0.18, 0.5, 3500.0)
	_streams.arrow = _sweep(0.12, 1600.0, 600.0, 0.25)
	_streams.magic = _sweep(0.35, 400.0, 1400.0, 0.3, true)
	_streams.explosion = _noise_burst(0.7, 0.9, 500.0)
	_streams.lightning = _noise_burst(0.35, 0.8, 6000.0)
	_streams.coin = _chime([1318.5, 1760.0], 0.25)
	_streams.build = _noise_burst(0.3, 0.6, 900.0)
	_streams.levelup = _chime([523.25, 659.25, 783.99, 1046.5], 0.7)
	_streams.death = _sweep(0.4, 300.0, 80.0, 0.4)
	_streams.boss = _sweep(1.4, 90.0, 45.0, 0.9)
	_streams.freeze = _sweep(0.6, 2400.0, 3600.0, 0.25, true)
	_streams.victory = _chime([392.0, 523.25, 659.25, 783.99, 1046.5], 1.4)
	_streams.defeat = _chime([392.0, 311.13, 261.63, 196.0], 1.6)
	_music = AudioStreamPlayer.new()
	_music.stream = _ambient_loop()
	_music.volume_db = -14.0
	add_child(_music)
	Events.settings_changed.connect(_apply_volume)
	_apply_volume()
	_music.play()


func _apply_volume() -> void:
	var m := float(Game.setting("music", 0.7)) if is_instance_valid(Game) and not Game.profile.is_empty() else 0.7
	_music.volume_db = linear_to_db(maxf(0.0005, m)) - 12.0


func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, 0)) < 45:   # avoid stacking identical sounds
		return
	_last_play[name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = volume_db - 6.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


# ---------------------------------------------------------------- synthesis
func _make(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = samples.size()
	return s


func _env(t: float, dur: float, attack := 0.005) -> float:
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / maxf(0.0001, dur - attack), 2.0)


func _tone(dur: float, freq: float, freq_end: float, vol: float, noise: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(freq, freq_end if freq_end > 0.0 else freq, t / dur)
		ph += TAU * f / RATE
		out[i] = (sin(ph) + randf_range(-noise, noise)) * vol * _env(t, dur)
	return _make(out)


func _noise_burst(dur: float, vol: float, cutoff: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	var y := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		y += a * (randf_range(-1.0, 1.0) - y)
		ph += TAU * lerpf(120.0, 40.0, t / dur) / RATE
		out[i] = (y * 1.6 + sin(ph) * 0.5) * vol * _env(t, dur, 0.002)
	return _make(out)


func _sweep(dur: float, f0: float, f1: float, vol: float, shimmer := false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var ph2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		ph += TAU * f / RATE
		ph2 += TAU * f * 1.5 / RATE
		var v := sin(ph) + (sin(ph2) * 0.5 if shimmer else 0.0)
		out[i] = v * vol * _env(t, dur, 0.01)
	return _make(out)


func _chime(freqs: Array, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := dur / (freqs.size() + 1)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			var st := k * step * 0.6
			if t >= st:
				var lt := t - st
				v += sin(TAU * float(freqs[k]) * lt) * exp(-lt * 4.0) * 0.25
		out[i] = v
	return _make(out)


func _ambient_loop() -> AudioStreamWAV:
	# Dark drone: detuned low fifths with slow swells and a distant bell.
	var dur := 12.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var roots := [55.0, 55.0 * 1.4983, 55.0 * 1.1892, 55.0 * 0.8909]
	for i in n:
		var t := float(i) / RATE
		var seg := int(t / 3.0) % roots.size()
		var f: float = roots[seg]
		var sw := 0.5 - 0.5 * cos(TAU * t / dur * 4.0)
		var v := sin(TAU * f * t) * 0.35 + sin(TAU * f * 1.003 * 2.0 * t) * 0.15 + sin(TAU * f * 1.5 * t) * 0.12 * sw
		var bt := fmod(t, 6.0)
		v += sin(TAU * 440.0 * t) * exp(-bt * 1.5) * 0.05
		var ts := fmod(t, 3.0)
		out[i] = v * 0.6 * clampf(minf(ts, 3.0 - ts) / 0.25, 0.15, 1.0)
	return _make(out, true)
