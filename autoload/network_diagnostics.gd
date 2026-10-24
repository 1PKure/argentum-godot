extends Node
## RTT uses only the client's monotonic clock. No synchronized server clock required.
signal move_requested(peer_id: int, direction: int, sequence: int)
const PROBE_INTERVAL_MS := 2000
const TIMEOUT_MS := 5000
const WINDOW := 60
var ping_samples: Array[float] = []
var move_samples: Array[float] = []
var server_samples: Array[float] = []
var confirmed := 0
var blocked := 0
var move_timeouts := 0
var probe_timeouts := 0
var queued_steps := 0
var peak_queued_steps := 0
var last_ping_ms := -1
var measured_moves := false
var _pending_probes: Dictionary = {}
var _pending_moves: Dictionary = {}
var _sequence := 0
var _next_probe_ms := 0
var _last_ping_at := -1
var _suspended := false
var _probe_limits: Dictionary = {}
var _move_sequences: Dictionary = {}

func _ready() -> void:
 NetworkManager.connected_to_server.connect(reset)
 NetworkManager.server_disconnected.connect(reset)
 NetworkManager.connection_failed.connect(reset)
 NetworkManager.server_stopped.connect(reset)
 NetworkManager.peer_disconnected.connect(func(id: int) -> void:
  _probe_limits.erase(id); _move_sequences.erase(id))

func reset() -> void:
 ping_samples.clear(); move_samples.clear(); server_samples.clear()
 _pending_probes.clear(); _pending_moves.clear()
 confirmed=0; blocked=0; move_timeouts=0; probe_timeouts=0
 queued_steps=0; peak_queued_steps=0; last_ping_ms=-1; _last_ping_at=-1
 measured_moves=false; _next_probe_ms=0
 _probe_limits.clear(); _move_sequences.clear()
 # Sequence remains monotonic so late replies cannot match a new request.

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  _suspended=true
  _pending_moves.clear(); _pending_probes.clear()
 elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
  _suspended=false
  reset()

func _process(_delta: float) -> void:
 if NetworkManager.is_server(): return
 if not NetworkManager.is_network_connected():
  if _last_ping_at>=0 or not _pending_moves.is_empty() or not _pending_probes.is_empty(): reset()
  return
 if _suspended: return
 var now := Time.get_ticks_msec()
 expire(now)
 if now >= _next_probe_ms:
  _next_probe_ms=now+PROBE_INTERVAL_MS
  if _pending_probes.is_empty():
   _sequence+=1; _pending_probes[_sequence]=Time.get_ticks_usec()
   _probe.rpc_id(1,_sequence)

func expire(now_ms: int) -> void:
 for sequence: int in _pending_probes.keys():
  if now_ms*1000-int(_pending_probes[sequence]) >= TIMEOUT_MS*1000:
   _pending_probes.erase(sequence); probe_timeouts+=1
 for sequence: int in _pending_moves.keys():
  if now_ms*1000-int(_pending_moves[sequence]) >= TIMEOUT_MS*1000:
   _pending_moves.erase(sequence); move_timeouts+=1
 if _last_ping_at >= 0 and now_ms-_last_ping_at >= TIMEOUT_MS: last_ping_ms=-1

func request_move(direction: int) -> bool:
 if not measured_moves or _suspended or not NetworkManager.is_network_connected(): return false
 _sequence+=1
 if _pending_moves.size() >= 64: return false
 _pending_moves[_sequence]=Time.get_ticks_usec()
 _measured_move.rpc_id(1,direction,_sequence)
 return true

func record_queue(count: int) -> void:
 queued_steps=count; peak_queued_steps=maxi(peak_queued_steps,count)

func _append(values: Array[float], value: float) -> void:
 values.append(value)
 if values.size()>WINDOW: values.pop_front()

func accept_ping(sequence: int, supports_moves: bool, now_us: int) -> void:
 if not _pending_probes.has(sequence): return
 var elapsed := maxi(0,now_us-int(_pending_probes[sequence]))/1000.0
 _pending_probes.erase(sequence)
 _append(ping_samples,elapsed)
 last_ping_ms=roundi(elapsed); _last_ping_at=now_us/1000
 measured_moves=supports_moves

func accept_move(sequence: int, accepted: bool, server_us: int, now_us: int) -> void:
 if not _pending_moves.has(sequence): return
 var elapsed := maxi(0,now_us-int(_pending_moves[sequence]))/1000.0
 _pending_moves.erase(sequence)
 if accepted:
  confirmed+=1; _append(move_samples,elapsed)
  _append(server_samples,clampf(server_us/1000.0,0.0,elapsed))
 else: blocked+=1

func percentile(values: Array[float], fraction: float) -> float:
 if values.is_empty(): return -1.0
 var ordered := values.duplicate(); ordered.sort()
 return ordered[clampi(ceili(ordered.size()*fraction)-1,0,ordered.size()-1)]

func ping_text() -> String:
 if not NetworkManager.is_network_connected(): return "Ping: desconectado"
 if last_ping_ms < 0: return "Ping: sin respuesta" if probe_timeouts>0 else "Ping: midiendo…"
 return "Ping RTT: %d ms · p95 %.0f ms" % [last_ping_ms,percentile(ping_samples,0.95)]

func movement_text() -> String:
 if not measured_moves: return "Movimiento: esperando diagnóstico"
 var timing := "sin muestras" if move_samples.is_empty() else "p50 %.0f / p95 %.0f ms · servidor p95 %.1f ms" % [percentile(move_samples,0.5),percentile(move_samples,0.95),percentile(server_samples,0.95)]
 return "Movimiento: %s\nConfirmados %d · bloqueados %d · sin confirmar %d · pendientes %d · cola visual %d (máx %d)" % [timing,confirmed,blocked,move_timeouts,_pending_moves.size(),queued_steps,peak_queued_steps]

@rpc("any_peer", "call_remote", "reliable")
func _probe(sequence: int) -> void:
 if not NetworkManager.is_server() or sequence<1: return
 var sender := multiplayer.get_remote_sender_id()
 if sender<=1: return
 var now := Time.get_ticks_msec()
 if now-int(_probe_limits.get(sender,-1000))<500: return
 _probe_limits[sender]=now
 _pong.rpc_id(sender,sequence,move_requested.has_connections())

@rpc("authority", "call_remote", "reliable")
func _pong(sequence: int, supports_moves: bool) -> void:
 if multiplayer.get_remote_sender_id()!=1: return
 accept_ping(sequence,supports_moves,Time.get_ticks_usec())

@rpc("any_peer", "call_remote", "reliable")
func _measured_move(direction: int, sequence: int) -> void:
 if not NetworkManager.is_server() or direction<0 or direction>3 or sequence<1: return
 var sender := multiplayer.get_remote_sender_id()
 if sender<=1 or sequence<=int(_move_sequences.get(sender,0)): return
 _move_sequences[sender]=sequence
 move_requested.emit(sender,direction,sequence)

func send_move_receipt(peer_id: int, sequence: int, accepted: bool, server_us: int) -> void:
 if NetworkManager.is_server() and multiplayer.get_peers().has(peer_id):
  _move_receipt.rpc_id(peer_id,sequence,accepted,server_us)

@rpc("authority", "call_remote", "reliable")
func _move_receipt(sequence: int, accepted: bool, server_us: int) -> void:
 if multiplayer.get_remote_sender_id()!=1: return
 accept_move(sequence,accepted,server_us,Time.get_ticks_usec())
