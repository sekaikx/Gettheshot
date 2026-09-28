extends Node
## Connections, lobby and message routing (autoload "Net"). Host-authoritative: the host is
## peer 1 and runs Game and the world simulation; clients send requests and draw what the host
## sends. Solo play uses an OfflineMultiplayerPeer, so the same code path runs everywhere.
## Adapted from Keep Rolling's net.gd (ENet part; Steam lobbies can be added the same way).
##
##   Net.solo()                         just you and the AI families
##   Net.host_lan(port)                 open a game on your machine (LAN or port forwarding)
##   Net.join_lan(ip, port)             join a friend
##   Net.to_host(method, args)          ask the host to do something (runs locally on the host)
##   Net.to_all / Net.to_peer           host -> clients events

signal roster_changed
signal joined_lobby
signal connection_failed(reason: String)
signal left_lobby(reason: String)
signal game_started
signal request(peer: int, method: String, args: Array)     # host side
signal event(name: String, args: Array)                    # everyone (host included)
signal snapshot(data: PackedByteArray)                     # clients
signal pose(peer: int, data: PackedFloat32Array)           # host: a player's own body

const DEFAULT_PORT := 24880
const MAX_PLAYERS := 8

var roster: Dictionary = {}     # peer id -> {name, family_name, color, join}
var is_solo := false
var in_lobby := false
var in_game := false
var my_info := {"name": "Player", "family_name": "", "color": "", "join": -1}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail("Could not reach that host."))
	multiplayer.server_disconnected.connect(func() -> void: leave("The host closed the game."))


func _peer_ok() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and (p is OfflineMultiplayerPeer or p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)


func is_host() -> bool:
	var p := multiplayer.multiplayer_peer
	if p == null or p is OfflineMultiplayerPeer:
		return true
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if _peer_ok() else 1


func is_online() -> bool:
	return in_lobby and not is_solo


# ------------------------------------------------------------------ open / close

func solo() -> void:
	_reset()
	is_solo = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_enter_as_host()


func host_lan(port: int = DEFAULT_PORT) -> Error:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_fail("Could not open port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_enter_as_host()
	return OK


func join_lan(ip: String, port: int = DEFAULT_PORT) -> Error:
	_reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), port)
	if err != OK:
		_fail("Could not connect (%s)." % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave(reason: String = "") -> void:
	var was := in_lobby or in_game
	_reset()
	if was:
		left_lobby.emit(reason)


func _reset() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()
	is_solo = false
	in_lobby = false
	in_game = false


func _enter_as_host() -> void:
	in_lobby = true
	roster[1] = my_info.duplicate()
	joined_lobby.emit()
	roster_changed.emit()


func _fail(reason: String) -> void:
	_reset()
	connection_failed.emit(reason)


# ------------------------------------------------------------------ lobby

func _on_connected() -> void:
	in_lobby = true
	_hello.rpc_id(1, my_info)
	joined_lobby.emit()


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if roster.erase(id):
		if is_host():
			_roster.rpc(roster)
		roster_changed.emit()
		event.emit("left", [id])


@rpc("any_peer", "reliable")
func _hello(info: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if roster.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	roster[id] = {"name": String(info.get("name", "Player")).left(20),
		"family_name": String(info.get("family_name", "")).left(16),
		"color": String(info.get("color", "")), "join": int(info.get("join", -1))}
	_roster.rpc(roster)
	roster_changed.emit()
	if in_game:
		# a campaign is already running: seat them, then send everything
		request.emit(id, "join_running", [roster[id]])


@rpc("authority", "reliable", "call_local")
func _roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()


## Host: everyone into the world.
func start_game() -> void:
	if not is_host():
		return
	in_game = true
	_start.rpc()


func start_peer(peer: int) -> void:
	if is_host() and peer != my_id():
		_start.rpc_id(peer)


@rpc("authority", "reliable", "call_local")
func _start() -> void:
	if OS.get_cmdline_user_args().has("--mptest"):
		print("start received")
	in_game = true
	game_started.emit()


# ------------------------------------------------------------------ messages

func to_host(method: String, args: Array = []) -> void:
	if is_host():
		request.emit(1, method, args)
	else:
		_req.rpc_id(1, method, args)


@rpc("any_peer", "reliable")
func _req(method: String, args: Array) -> void:
	if is_host():
		request.emit(multiplayer.get_remote_sender_id(), method, args)


## Host -> everyone (the host gets it too, synchronously).
func to_all(name: String, args: Array = []) -> void:
	if not is_host():
		return
	event.emit(name, args)
	if not is_solo:
		_ev.rpc(name, args)


## Host -> one peer (peer 1 = the host itself).
func to_peer(peer: int, name: String, args: Array = []) -> void:
	if peer == my_id():
		event.emit(name, args)
	elif is_host() and roster.has(peer):
		_ev.rpc_id(peer, name, args)


@rpc("authority", "reliable")
func _ev(name: String, args: Array) -> void:
	event.emit(name, args)


func send_state(state: Dictionary, peer: int = 0) -> void:
	if not is_host() or is_solo:
		return
	var bytes := var_to_bytes(state).compress(FileAccess.COMPRESSION_GZIP)
	if OS.get_cmdline_user_args().has("--mptest"):
		print("state sent ", bytes.size(), " to ", peer)
	if peer == 0:
		_state.rpc(bytes)
	else:
		_state.rpc_id(peer, bytes)


@rpc("authority", "reliable")
func _state(bytes: PackedByteArray) -> void:
	if OS.get_cmdline_user_args().has("--mptest"):
		print("state received ", bytes.size())
	var raw := bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var s = bytes_to_var(raw)
	if s is Dictionary:
		Game.apply_state(s)


func send_snapshot(data: PackedByteArray) -> void:
	if is_host() and not is_solo and multiplayer.get_peers().size() > 0:
		_snap.rpc(data)


@rpc("authority", "unreliable_ordered")
func _snap(data: PackedByteArray) -> void:
	snapshot.emit(data)


## A client's own body (position, yaw, anim, vehicle) to the host.
func send_pose(data: PackedFloat32Array) -> void:
	if is_host():
		pose.emit(1, data)
	else:
		_pose.rpc_id(1, data)


@rpc("any_peer", "unreliable_ordered")
func _pose(data: PackedFloat32Array) -> void:
	if is_host():
		pose.emit(multiplayer.get_remote_sender_id(), data)
