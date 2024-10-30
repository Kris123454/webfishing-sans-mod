extends Node

const MAX_PLAYERS = 12
const PACKET_READ_LIMIT = 128

var STEAM_ENABLED = true
var PLAYING_OFFLINE = false
var IS_OWNED = false
var IS_ONLINE = false
var GAME_MASTER = false
var STEAM_ID = 0
var STEAM_USERNAME = ""
var PACK
var JOIN_ID_PROMPT = - 1

var STEAM_LOBBY_ID = 0
var LOBBY_CODE = ""
var LOBBY_MEMBERS = []
var GAMECHAT = ""
var LOCAL_GAMECHAT = ""
var OWNED_ACTORS = []
var ACTOR_ACTIONS = {}
var ACTOR_DATA = {}
var ACTOR_ANIMATION_DATA = {}
var SERVER_CREATION_TYPE = 0
var PING_DICTIONARY = {}
var LOBBY_CHUNK_SIZE = 50

var BULK_PACKET_READ_TIMER = 0

var KNOWN_GAME_MASTER = - 1

var MESSAGE_ORIGIN = Vector3.ZERO
var MESSAGE_ZONE = ""

var CONNECTED_TO_LOBBY_PROPER = false
var HANDSHAKES_RECIEVED = 0
var REPLICATIONS_RECIEVED = []

signal _connected_to_lobby
signal _actors_recieved
signal _user_disconnected(id)
signal _user_connected(id)
signal _all_user_data_obtained
signal _instance_actor
signal _handshake_recieved
signal _members_updated
signal _tent_update
signal _chat_update
signal _new_player_join(id)
signal _new_player_join_empty
signal _webfishing_lobbies_returned(lobbies)

func _ready():
	if not STEAM_ENABLED: return 
	var INIT = Steam.steamInit()
	
	if INIT["status"] != 1: get_tree().quit()
	
	IS_OWNED = Steam.isSubscribed()
	IS_ONLINE = Steam.loggedOn()
	STEAM_ID = Steam.getSteamID()
	STEAM_USERNAME = Steam.getPersonaName()
	print("Steam Active under username: ", STEAM_USERNAME, " ID: ", STEAM_ID)
	
	if IS_OWNED == false: get_tree().quit()
	
	Steam.connect("lobby_created", self, "_on_Lobby_Created")
	Steam.connect("lobby_joined", self, "_on_Lobby_Joined")
	Steam.connect("join_requested", self, "_on_Lobby_Join_Requested")
	Steam.connect("p2p_session_request", self, "_on_P2P_Session_Request")
	Steam.connect("persona_state_change", self, "_on_Persona_Change")
	Steam.connect("lobby_chat_update", self, "_on_Lobby_Chat_Update")
	
	_check_command_line()

func _check_command_line():
	var these_arguments: Array = OS.get_cmdline_args()
	if these_arguments.size() > 0:
		if these_arguments[0] == "+connect_lobby":
			if int(these_arguments[1]) > 0:
				print("Command line lobby ID: %s" % these_arguments[1])
				JOIN_ID_PROMPT = int(these_arguments[1])

func _process(delta):
	if not STEAM_ENABLED: return 
	Steam.run_callbacks()
	if STEAM_LOBBY_ID > 0:
		for i in 24: _read_P2P_Packet()
		for i in 4: _read_P2P_Packet(1)
		for i in 12: _read_P2P_Packet(2)

func _physics_process(delta):
	if not STEAM_ENABLED: return 
	BULK_PACKET_READ_TIMER -= 1
	if BULK_PACKET_READ_TIMER <= 0:
		print("Bulk Reading Packets.")
		_read_all_P2P_packets(0)
		_read_all_P2P_packets(1)
		_read_all_P2P_packets(2)
		BULK_PACKET_READ_TIMER = 700

func _read_all_P2P_packets(channel = 0):
	var PACKET = Steam.getAvailableP2PPacketSize(channel)
	for pack in PACKET:
		_read_P2P_Packet(channel)
	









func _update_chat(text, local = false):
	if not local:
		GAMECHAT = GAMECHAT + "\n" + text
	else :
		LOCAL_GAMECHAT = LOCAL_GAMECHAT + "\n" + "[color=#a4756a][​local​] [/color]" + text
	emit_signal("_chat_update")





func _unlock_achievement(id):
	var achievement = Steam.getAchievement(id)
	if not achievement.ret:
		print("Achievement ", id, " does not exist.")
		return 
	if achievement.achieved:
		print("Achievement ", id, " already obtained.")
		return 
	Steam.setAchievement(id)
	Steam.storeStats()

func _update_stat(id, new):
	Steam.setStatInt(id, int(new))
	Steam.storeStats()





func set_rich_presence(token):
	
	var setting_presence = Steam.setRichPresence("steam_display", token)





func _create_Lobby(type):
	SERVER_CREATION_TYPE = type
	HANDSHAKES_RECIEVED = 0
	REPLICATIONS_RECIEVED.clear()
	LOBBY_MEMBERS.clear()
	OWNED_ACTORS.clear()
	
	if STEAM_LOBBY_ID == 0:
		GAME_MASTER = true
		
		var lobby_type = 2
		match type:
			0: lobby_type = 2
			1: lobby_type = 3
			2: lobby_type = 3
		
		PlayerData.players_blocked.clear()
		Steam.createLobby(lobby_type, MAX_PLAYERS)

func _join_Lobby(lobby_id):
	_leave_lobby()
	HANDSHAKES_RECIEVED = 0
	REPLICATIONS_RECIEVED.clear()
	GAME_MASTER = false
	GAMECHAT = ""
	LOCAL_GAMECHAT = ""
	LOBBY_MEMBERS.clear()
	OWNED_ACTORS.clear()
	
	Steam.joinLobby(lobby_id)

func _connect_to_lobby(id):
	var ver = Steam.getLobbyData(id, "version")
	print("GAME VER: ", ver)
	
	if ver:
		if ver != str(Globals.GAME_VERSION):
			_update_chat("Game version does not match host!")
			PopupMessage._show_popup("Game Version: " + str(Globals.GAME_VERSION) + ", does not match lobby's version: " + str(ver))
			Globals._exit_game()
			return 
	
	var blocked_players = Steam.getLobbyData(id, "banned_players")
	var split = blocked_players.split(",")
	for i in split:
		if int(i) == STEAM_ID:
			_update_chat("You have been banned from this lobby.")
			PopupMessage._show_popup("You have been banned from this lobby.")
			Globals._exit_game()
			return 
	
	_join_Lobby(id)
	Globals._enter_game()

func _leave_lobby():
	if STEAM_LOBBY_ID != 0:
		if GAME_MASTER:
			_host_left_lobby()
			yield (get_tree().create_timer(1.0), "timeout")
		
		_update_chat("Leaving lobby.")
		Steam.leaveLobby(STEAM_LOBBY_ID)
		STEAM_LOBBY_ID = 0
		
		for MEMBER in LOBBY_MEMBERS:
			Steam.closeP2PSessionWithUser(MEMBER["steam_id"])
		LOBBY_MEMBERS.clear()

func _on_Lobby_Created(connect, lobby_id):
	if connect != 1: return 
	
	randomize()
	var code = ""
	var characters = "abcdefghijklmnopqrstuvwxyz1234567890"
	for i in 5:
		code += characters[randi() % characters.length()]
	code = code.to_upper()
	LOBBY_CODE = code
	
	
	var lobby_type = ["public", "code_only", "offline", "friends_only"][SERVER_CREATION_TYPE]
	var joinable = lobby_type == "public" or lobby_type == "friends_only"
	var public = lobby_type == "public"
	PLAYING_OFFLINE = lobby_type == "offline"
	
	STEAM_LOBBY_ID = lobby_id
	_update_chat("Created Lobby.")
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "name", str(STEAM_USERNAME))
	Steam.setLobbyData(lobby_id, "mode", "GodotsteamLobby")
	Steam.setLobbyData(lobby_id, "ref", "webfishinglobby")
	Steam.setLobbyData(lobby_id, "version", str(Globals.GAME_VERSION))
	Steam.setLobbyData(lobby_id, "code", code)
	Steam.setLobbyData(lobby_id, "type", lobby_type)
	Steam.setLobbyData(lobby_id, "public", str("true" if public else "false"))
	Steam.setLobbyData(lobby_id, "banned_players", "")
	Steam.allowP2PPacketRelay(true)
	
	
	Steam.setLobbyData(lobby_id, "server_browser_value", str(0))

func _on_Lobby_Joined(lobby_id, _perms, _locked, response):
	if response == 1:
		STEAM_LOBBY_ID = lobby_id
		LOBBY_CODE = Steam.getLobbyData(lobby_id, "code")
		
		PlayerData.player_saved_position = Vector3.ZERO
		PlayerData.player_saved_zone = ""
		if Network.GAME_MASTER: Network.KNOWN_GAME_MASTER = Network.STEAM_ID
		else : Network.KNOWN_GAME_MASTER = - 100
		
		_update_chat("Joined Lobby.")
		_get_lobby_members(true)
		_make_P2P_handshake()
		_request_handshakes()
		emit_signal("_connected_to_lobby")
	else :
		_update_chat("Error Joining Lobby!")

func _get_lobby_members(chat = false):
	LOBBY_MEMBERS.clear()
	
	
	var user_count = 0
	
	var MEMBERS = Steam.getNumLobbyMembers(Network.STEAM_LOBBY_ID)
	for MEMBER in range(0, MEMBERS):
		var MEMBER_ID = Steam.getLobbyMemberByIndex(Network.STEAM_LOBBY_ID, MEMBER)
		var MEMBER_NAME = Steam.getFriendPersonaName(MEMBER_ID)
		_add_lobby_member(MEMBER_ID, MEMBER_NAME)
		
		if MEMBER_ID == STEAM_ID: user_count += 1
	emit_signal("_members_updated")
	
	if user_count >= 2:
		PlayerData._send_notification("Duplicate Steam ID Found. Returning to Menu.", 1)
		Globals._exit_game()
	
	if chat:
		if LOBBY_MEMBERS.size() > 1: _update_chat(str(LOBBY_MEMBERS.size() - 1) + " other player(s) found.")

func _add_lobby_member(steam_id, steam_name):
	LOBBY_MEMBERS.append({"steam_id": steam_id, "steam_name": steam_name, "ping": - 1})

func _on_Lobby_Join_Requested(lobby_id, friend_id):
	var username = Steam.getFriendPersonaName(friend_id)
	username = username.replace("[", "")
	username = username.replace("]", "")
	
	_update_chat("Joining " + str(username) + "'s lobby...")
	print(lobby_id, " TRYING TO JOIN THIS <<<<<<<")
	
	JOIN_ID_PROMPT = lobby_id
	Globals._exit_game()

func _on_P2P_Session_Request(remoteID):
	var success = Steam.acceptP2PSessionWithUser(remoteID)
	print("Accepted Session Request from ", remoteID, ": ", success)
	_make_P2P_handshake()

func _make_P2P_handshake():
	_send_P2P_Packet({"type": "handshake", "user_id": STEAM_ID}, "all", 2)

func _request_handshakes():
	_send_P2P_Packet({"type": "handshake_request", "user_id": STEAM_ID}, "all", 2)

func _on_Persona_Change(steam_id, _flag):
	_get_lobby_members()

func _on_Lobby_Chat_Update(lobby_id, changed_id, making_change_id, chat_state):
	print("[STEAM] Lobby ID: " + str(lobby_id) + ", Changed ID: " + str(changed_id) + ", Making Change: " + str(making_change_id) + ", Chat State: " + str(chat_state))
	
	if chat_state == 1:
		_delayed_join_message(making_change_id, " joined the game.", 1.5)
		emit_signal("_user_connected", making_change_id)
	elif chat_state == 2:
		var username = _get_username_from_id(making_change_id)
		username = username.replace("[", "")
		username = username.replace("]", "")
		_update_chat(username + " left the game.")
		emit_signal("_user_disconnected", making_change_id)
		Steam.closeP2PSessionWithUser(making_change_id)
	
	_get_lobby_members()

func _delayed_join_message(id, message, delay):
	yield (get_tree().create_timer(delay), "timeout")
	var username = _get_username_from_id(id)
	username = username.replace("[", "")
	username = username.replace("]", "")
	_update_chat(username + message)


func _connect_to_valid_lobby():
	Steam.requestLobbyList()
	var lobbies = yield (Steam, "lobby_match_list")
	var valid_lobbies = []
	
	for LOBBY in lobbies:
		var LOBBY_REF = Steam.getLobbyData(LOBBY, "ref")
		var LOBBY_VERSION = Steam.getLobbyData(LOBBY, "version")
		var LOBBY_PUBLIC = Steam.getLobbyData(LOBBY, "public")
		var LOBBY_PLAYERS = Steam.getNumLobbyMembers(LOBBY)
		print(LOBBY_REF, " / ", LOBBY_VERSION, " /", LOBBY_PUBLIC, " / ", LOBBY_PLAYERS)
		print(LOBBY_REF == "webfishinglobby", " ", LOBBY_PLAYERS < Network.MAX_PLAYERS, " ", LOBBY_PUBLIC == "true", " ", LOBBY_VERSION == str(Globals.GAME_VERSION))
		
		if LOBBY_REF == "webfishinglobby" and LOBBY_PLAYERS < Network.MAX_PLAYERS and (LOBBY_PUBLIC == "true" or LOBBY_PUBLIC == str(true)) and LOBBY_VERSION == str(Globals.GAME_VERSION):
			valid_lobbies.append(LOBBY)
	
	if valid_lobbies.size() > 0:
		var new_lobby = valid_lobbies[randi() % valid_lobbies.size()]
		Network._join_Lobby(new_lobby)
		yield (Network, "_connected_to_lobby")
		yield (Network, "_handshake_recieved")
		Globals._enter_game()
		print("Joining Lobby ", new_lobby)
	
	else :
		Network._create_Lobby(0)
		yield (Network, "_connected_to_lobby")
		Globals._enter_game()
		print("Creating Lobby")

func _search_for_lobby(code):
	var lobby_found = - 1
	
	code = code.to_upper()
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("code", str(code), Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
	var lobbies = yield (Steam, "lobby_match_list")
	if lobbies.size() > 0:
		var LOBBY = lobbies[0]
		
		var LOBBY_PLAYERS = Steam.getNumLobbyMembers(LOBBY)
		var LOBBY_VERSION = Steam.getLobbyData(LOBBY, "version")
		
		lobby_found = LOBBY
		if LOBBY_PLAYERS >= Network.MAX_PLAYERS: lobby_found = - 2
		if str(LOBBY_VERSION) != str(Globals.GAME_VERSION): lobby_found = - 3
	
	if lobby_found != - 1:
		Network._connect_to_lobby(lobby_found)
		yield (Network, "_connected_to_lobby")
		Globals._enter_game()
		print("Joining Lobby ", lobby_found)
		return true
	elif lobby_found == - 2:
		PopupMessage._show_popup("Lobby " + str(code) + " is full")
		Globals._exit_game()
		return false
	elif lobby_found == - 3:
		PopupMessage._show_popup("Lobby " + str(code) + "'s version does not match your version")
		Globals._exit_game()
		return false
	else :
		PopupMessage._show_popup("No server found with code " + str(code))
		Globals._exit_game()
		return false

func _create_custom_lobby(type):
	Network.GAME_MASTER = true
	Network._create_Lobby(type)
	yield (Network, "_connected_to_lobby")
	Globals._enter_game()
	print("Creating Lobby")

func _get_username_from_id(id):
	for member in LOBBY_MEMBERS:
		if member["steam_id"] == id:
			return member["steam_name"]
	return "null"

func _closing_app():
	if GAME_MASTER: _host_left_lobby()



func _find_all_webfishing_lobbies(public_only = true):
	var total_lobbies = []
	
	var nulls = 0
	for search_filter in 21:
		print("Searching filter ", search_filter)
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
		
		search_filter -= 1
		if search_filter != - 1: Steam.addRequestLobbyListStringFilter("server_browser_value", str(search_filter), Steam.LOBBY_COMPARISON_EQUAL)
		
		Steam.requestLobbyList()
		var lobbies = yield (Steam, "lobby_match_list")
		print(lobbies.size(), " Lobbies found for Filter ", search_filter)
		
		if lobbies.size() <= 0:
			nulls += 1
			if nulls > 3: break
		
		total_lobbies.append_array(lobbies)
	
	print(total_lobbies.size(), " servers found.")
	emit_signal("_webfishing_lobbies_returned", total_lobbies)
	return total_lobbies

func _set_server_browser_value():
	
	
	var value = 0
	for search_filter in 21:
		Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
		
		search_filter -= 1
		if search_filter != - 1: Steam.addRequestLobbyListStringFilter("server_browser_value", str(search_filter), Steam.LOBBY_COMPARISON_EQUAL)
		
		Steam.requestLobbyList()
		var lobbies = yield (Steam, "lobby_match_list")
		print(lobbies.size(), " Lobbies found for Filter ", search_filter)
		
		if lobbies.size() < 50:
			value = search_filter
			break
	
	print("Setting Server Browser Value to: ", value)
	Steam.setLobbyData(STEAM_LOBBY_ID, "server_browser_value", str(value))





func _request_actors():
	if PLAYING_OFFLINE: return 
	_send_P2P_Packet({"type": "request_actors", "user_id": STEAM_ID}, "peers", 2)

func _create_replication_data(id):
	var data = []
	
	for actor in OWNED_ACTORS:
		if not is_instance_valid(actor): continue
		var new_data = actor._request_saved_data()
		data.append(new_data)
	
	print("Sending all owned Actors to ", str(id), " data: ", data)
	_send_P2P_Packet({"type": "actor_request_send", "list": data, "host": GAME_MASTER, "user_id": STEAM_ID}, str(id), 2, 1)

func _replicate_actors(list, from):
	print("Recieved actors: ", list)
	var existing_actor_ids = []
	for actor in get_tree().get_nodes_in_group("actor"):
		existing_actor_ids.append(actor.actor_id)
	REPLICATIONS_RECIEVED.append(from)
	
	for actor in list:
		if existing_actor_ids.has(actor["id"]):
			print("Actor Already Exists, skipping!")
			continue
		
		var dict = {"actor_type": actor["type"], "at": Vector3.ZERO, "zone": "", "actor_id": actor["id"], "creator_id": actor["owner"], "data": {}}
		emit_signal("_instance_actor", dict)

func _sync_create_actor(actor_type, at, zone, id = - 1, creator = STEAM_ID, data = {}):
	randomize()
	if id == - 1: id = randi()
	var dict = {"actor_type": actor_type, "at": at, "zone": zone, "actor_id": id, "creator_id": creator, "data": data}
	_send_P2P_Packet({"type": "instance_actor", "params": dict}, "peers", 2)
	emit_signal("_instance_actor", dict)
	return id

func _send_actor_update(actor_id, data):
	_send_P2P_Packet({"type": "actor_update", "actor_id": actor_id, "data": data}, "peers", 0)

func _send_actor_animation_update(actor_id, data):
	_send_P2P_Packet({"type": "actor_animation_update", "actor_id": actor_id, "data": data}, "peers", 0)

func _send_actor_action(id, action, params = [], all = true):
	var target = "all" if all else "peers"
	_send_P2P_Packet({"type": "actor_action", "actor_id": id, "action": action, "params": params}, target, 2, 2)

func _send_message(message, local = false):
	_update_chat(message, local)
	_send_P2P_Packet({"type": "message", "message": message, "sender": STEAM_ID, "local": local, "position": MESSAGE_ORIGIN, "zone": MESSAGE_ZONE, "zone_owner": PlayerData.player_saved_zone_owner}, "peers", 2)

func _update_tent(new_data):
	emit_signal("_tent_update", STEAM_ID, new_data)
	_send_P2P_Packet({"type": "tent_update", "user_id": STEAM_ID, "tent_data": new_data}, "peers", 2)

func _request_tent(id):
	print("REQUEST TENT: ", id)
	if STEAM_ID == id or PLAYING_OFFLINE:
		emit_signal("_tent_update", STEAM_ID, PlayerData.tent_layout)
	else :
		emit_signal("_tent_update", id, {0: []})
		_send_P2P_Packet({"type": "tent_request", "user_id": STEAM_ID}, str(id), 2)

func _host_left_lobby():
	print("Finding New Server Host...")
	var new_host = - 1
	for member in LOBBY_MEMBERS:
		if member["steam_id"] != STEAM_ID:
			new_host = member["steam_id"]
			break
	
	_send_P2P_Packet({"type": "server_close", "new_host": str(new_host)}, "peers", 2)

func _replication_check():
	for lobby_member in LOBBY_MEMBERS:
		if not REPLICATIONS_RECIEVED.has(lobby_member["steam_id"]):
			print("Missing Replication from: ", lobby_member["steam_id"])
			_send_P2P_Packet({"type": "request_actors", "user_id": STEAM_ID}, str(lobby_member["steam_id"]), 2, 1)
	
	print("Handshakes Recieved: ", HANDSHAKES_RECIEVED, " / ", LOBBY_MEMBERS.size())





func _send_P2P_Packet(packet_data, target = "all", type = 0, channel = 0):
	if PLAYING_OFFLINE: return 
	
	var SEND_TYPE = type
	var CHANNEL = channel
	var PACKET_DATA: PoolByteArray = []
	
	PACKET_DATA.append_array(var2bytes(packet_data).compress(File.COMPRESSION_GZIP))
	
	if target == "all":
		for MEMBER in LOBBY_MEMBERS:
			Steam.sendP2PPacket(MEMBER["steam_id"], PACKET_DATA, SEND_TYPE, CHANNEL)
	elif target == "peers":
		if LOBBY_MEMBERS.size() > 1:
			for MEMBER in LOBBY_MEMBERS:
				if MEMBER["steam_id"] != STEAM_ID:
					Steam.sendP2PPacket(MEMBER["steam_id"], PACKET_DATA, SEND_TYPE, CHANNEL)
	else :
		Steam.sendP2PPacket(int(target), PACKET_DATA, SEND_TYPE, CHANNEL)

func _read_P2P_Packet(channel = 0):
	if PLAYING_OFFLINE: return 
	
	var PACKET_SIZE = Steam.getAvailableP2PPacketSize(channel)
	if PACKET_SIZE > 0:
		var PACKET = Steam.readP2PPacket(PACKET_SIZE, channel)
		
		if PACKET.empty():
			print("Error! Empty Packet!")
		
		
		var DATA = bytes2var(PACKET.data.decompress_dynamic( - 1, File.COMPRESSION_GZIP))
		var type = DATA["type"]
		
		
		
		
		match type:
			"handshake":
				print("Handshake Recieved! :3")
				emit_signal("_handshake_recieved", DATA["user_id"])
				HANDSHAKES_RECIEVED += 1
			"handshake_request":
				print("Handshake Request Recieved! :3")
				_make_P2P_handshake()
			
			"server_close":
				PopupMessage._show_popup("Host left the game.")
				Globals._exit_game()
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
			
			"kick":
				PopupMessage._show_popup("You were kicked from the game.")
				Globals._exit_game()
			"ban":
				PopupMessage._show_popup("You were banned from this lobby.")
				Globals._exit_game()
			
			"request_actors":
				_create_replication_data(DATA["user_id"])
			"actor_request_send":
				if DATA["host"]: KNOWN_GAME_MASTER = DATA["user_id"]
				_replicate_actors(DATA["list"], DATA["user_id"])
			"instance_actor":
				emit_signal("_instance_actor", DATA["params"])
			
			"actor_update":
				ACTOR_DATA[DATA["actor_id"]] = DATA["data"]
			"actor_animation_update":
				ACTOR_ANIMATION_DATA[DATA["actor_id"]] = DATA["data"]
			"actor_action":
				if not ACTOR_ACTIONS.keys().has(DATA["actor_id"]):
					ACTOR_ACTIONS[DATA["actor_id"]] = []
				ACTOR_ACTIONS[DATA["actor_id"]].append([DATA["action"], DATA["params"]])
			
			"message":
				if PlayerData.players_muted.has(DATA["sender"]) or PlayerData.players_hidden.has(DATA["sender"]): return 
				
				if not DATA["local"]: _update_chat(DATA["message"], false)
				else :
					var dist = DATA["position"].distance_to(MESSAGE_ORIGIN)
					if DATA["zone"] == MESSAGE_ZONE and DATA["zone_owner"] == PlayerData.player_saved_zone_owner:
						if dist < 25.0:
							_update_chat(DATA["message"], true)
						
						
			
			"letter_received":
				if str(STEAM_ID) == DATA["to"]:
					PlayerData._received_letter(DATA["data"])
			"letter_was_recieved":
				PlayerData._letter_was_recieved(DATA["data"])
			"letter_was_denied":
				PlayerData._letter_was_denied(DATA["data"])
			"letter_was_accepted":
				PlayerData._letter_was_accepted()
			
			"chalk_packet":
				PlayerData.emit_signal("_chalk_recieve", DATA["data"], DATA["canvas_id"])
			"new_player_join":
				if GAME_MASTER: _send_P2P_Packet({"type": "recieve_host", "host_id": STEAM_ID}, "all", 2)
				emit_signal("_new_player_join", DATA["player_id"])
				emit_signal("_new_player_join_empty")
			
			"recieve_host":
				KNOWN_GAME_MASTER = int(DATA["host_id"])
				_get_lobby_members()
			
			"arena_join": PlayerData.emit_signal("_arena_join", DATA["data"])
			"arena_start": PlayerData.emit_signal("_arena_start")
			"arena_over": PlayerData.emit_signal("_arena_over")
			"arena_tick": PlayerData.emit_signal("_arena_tick")
			"arena_cashout": PlayerData.emit_signal("_arena_cashout", DATA["data"])
			
			"player_punch":
				if PlayerData.players_hidden.has(DATA["player"]): return 
				PlayerData.emit_signal("_punched", DATA["from"], DATA["punch_type"])
			
			"request_ping":
				_send_P2P_Packet({"type": "send_ping", "time": str(Time.get_unix_time_from_system()), "from": str(STEAM_ID)}, str(DATA["sender"]), 0, 1)
			"send_ping":
				for member in LOBBY_MEMBERS:
					if member["steam_id"] == int(DATA["from"]):
						var ping = abs(Time.get_unix_time_from_system() - int(DATA["time"])) * 10
						PING_DICTIONARY[member["steam_id"]] = floor(ping)
						break
