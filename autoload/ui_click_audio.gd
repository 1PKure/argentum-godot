extends Node
## One reusable PCM click for all current and dynamically created game buttons.
var _player: AudioStreamPlayer
var _last_click := -1000
var played_count := 0
func _ready() -> void:
	# The dedicated has no UI or sound device; native Dummy audio is used by QA.
	if OS.get_cmdline_user_args().has("--server"): return
	_player=AudioStreamPlayer.new()
	_player.name="UIClickPlayer"
	_player.stream=_make_click()
	_player.volume_db=-10
	add_child(_player)
	ArenaAudioMix.route(_player,3)
	get_tree().node_added.connect(_node_added)
	_scan(get_tree().root)
func _scan(node: Node) -> void:
	_wire(node)
	for child in node.get_children(): _scan(child)
func _node_added(node: Node) -> void:
	if node is BaseButton or node is PopupMenu: _wire(node)
func _wire(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is BaseButton:
		var callback:=_play
		if not node.pressed.is_connected(callback):node.pressed.connect(callback)
	elif node is PopupMenu:
		if not node.id_pressed.is_connected(_popup_clicked):node.id_pressed.connect(_popup_clicked)
func _popup_clicked(_id: int)->void:
	_play()
func _play()->void:
	var now:=Time.get_ticks_msec()
	# One physical action may also notify a popup; do not double that click.
	if _player==null or now-_last_click<25:return
	_last_click=now
	played_count+=1
	_player.play()
func _make_click()->AudioStreamWAV:
	var rate:=44100
	var samples:=int(rate*.045)
	var data:=PackedByteArray();data.resize(samples*2)
	var rng:=RandomNumberGenerator.new();rng.seed=2711
	for i in range(samples):
		var t:=i/float(rate)
		var attack:=minf(1,t/.0015)
		var tail:=clampf((.045-t)/.009,0,1)
		var tone:=sin(TAU*720*t)*.32+sin(TAU*1430*t)*.13
		var grain:=rng.randf_range(-1,1)*.18*exp(-t*280)
		var value:=(tone*exp(-t*110)+grain)*attack*tail
		data.encode_s16(i*2,roundi(clampf(value,-1,1)*32767))
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate;stream.stereo=false;stream.data=data
	return stream
