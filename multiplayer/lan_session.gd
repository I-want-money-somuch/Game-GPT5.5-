class_name LanSession
extends Node

signal hosting_started(port: int)
signal joined_server(address: String, port: int)
signal session_failed(message: String)
signal session_closed

@export var default_port := GameConstants.DEFAULT_LAN_PORT
@export var max_peers := GameConstants.MAX_LAN_PLAYERS

var peer: ENetMultiplayerPeer

func host(port: int = default_port) -> Error:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_peers)
	if error != OK:
		session_failed.emit("Could not host LAN session")
		return error

	multiplayer.multiplayer_peer = peer
	hosting_started.emit(port)
	return OK

func join(address: String, port: int = default_port) -> Error:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		session_failed.emit("Could not join LAN session")
		return error

	multiplayer.multiplayer_peer = peer
	joined_server.emit(address, port)
	return OK

func leave() -> void:
	_close_existing_peer()
	session_closed.emit()

func _close_existing_peer() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null

