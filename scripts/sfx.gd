extends Node
## Sound effects, made in code so the game needs no audio files yet: each is
## a short tone or burst of noise that fades out. Anything can play one with
##     get_tree().call_group("sfx", "play", "chop")
## Press M to mute or unmute. Real sounds can replace these later by loading
## files into _sounds under the same names.

const MIX_RATE := 22050
const VOICES := 6
const VOLUME_DB := -16.0
## The same sound can't start again sooner than this, so a crowd of peasants
## doesn't turn into a roar.
const MIN_GAP := 0.09

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _last_played := {}
var _muted := false


func _ready() -> void:
	add_to_group("sfx")
	# Name: the notes in Hz played one after another, length, share of noise.
	_sounds = {
		"chop": _make([180.0], 0.07, 0.7),
		"mine": _make([520.0], 0.06, 0.5),
		"deliver": _make([660.0, 880.0], 0.09, 0.0),
		"hammer": _make([300.0], 0.05, 0.4),
		"buy": _make([520.0, 780.0], 0.10, 0.0),
		"built": _make([392.0, 523.0, 659.0], 0.32, 0.0),
		"goal": _make([523.0, 659.0, 784.0, 1047.0], 0.45, 0.0),
		"won": _make([392.0, 523.0, 784.0], 0.5, 0.0),
		"lost": _make([196.0, 147.0, 110.0], 0.6, 0.15),
	}
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)

	GameState.income_delivered.connect(func(_type: String, _amount: int) -> void: play("deliver"))
	GameState.raid_resolved.connect(func(won: bool) -> void: play("won" if won else "lost"))
	GameState.announced.connect(func(text: String) -> void:
		if text.begins_with("Goal"):
			play("goal"))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_M:
		_muted = not _muted


func play(sound: String) -> void:
	if _muted or not _sounds.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sound, -1.0) < MIN_GAP:
		return
	_last_played[sound] = now
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound]
			player.play()
			return


## Builds a sound: the notes are played in turn across the length, mixed with
## some noise (0 = pure tone, 1 = all noise), fading out towards the end.
func _make(notes: Array, length: float, noise: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * length)
	var data := PackedByteArray()
	data.resize(count)
	for i in count:
		var progress := float(i) / count
		var note: float = notes[mini(int(progress * notes.size()), notes.size() - 1)]
		var wave := sin(TAU * note * i / MIX_RATE) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		var level := wave * pow(1.0 - progress, 2.0) * 0.6
		# 8-bit sound stores each sample as a signed byte.
		data[i] = (int(level * 127.0) + 256) % 256
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
