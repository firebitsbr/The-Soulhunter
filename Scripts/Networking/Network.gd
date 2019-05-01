extends Node

enum{STRING, U8, U16}

var client
var account
var server_delta = 0

const server_host = "127.0.0.1"
const server_port = 2412
#const server_host = "0.tcp.eu.ngrok.io"
#const server_port = 18200

signal connected
signal log_in
signal error(code)
signal chat_message(type, from, message)
signal stats(data)

func _ready():
	set_process(false)

func connect_client():
	client = StreamPeerTCP.new()
	client.connect_to_host(server_host, server_port)
	set_process(true)

func _process(delta):
	if client.get_status() == client.STATUS_CONNECTING:
		return
	
	if client.get_status() != client.STATUS_CONNECTED:
		client.connect_to_host(server_host, server_port)
	
	var packet_size = client.get_partial_data(1)
	
	if packet_size[0] == FAILED: return
	
	if packet_size[1].size() > 0 and packet_size[1][0] > 0: #to drugie nie powinno się dziać ;_;
#		print("Received data: ", packet_size[1][0]-1)
		var data = client.get_data(packet_size[1][0]-1)
#		print(client.get_status())
#		print(data[0])
		process_packet(Unpacker.new(data[1], packet_size[1][0]))

func process_packet(unpacker):
#	if data.size() <= 0: return ##inaczej zabezpieczyć
	print("Received: ", Packet.TYPE.keys()[unpacker.command], " /", unpacker.size)
	
	match unpacker.command:
		Packet.TYPE.HELLO:
			server_delta = unpacker.get_u32() - OS.get_ticks_msec()
			emit_signal("connected")
		
		Packet.TYPE.LOGIN:
			var result = unpacker.get_u8()
			
			if result == OK:
				print("Logged in sucessfully")
				
				var player = preload("res://Nodes/Player.tscn").instance()
				player.set_meta("valid", true)
				player.set_main()
				
				Com.game = preload("res://Scenes/InGame.tscn").instance()
				$"/root".add_child(Com.game)
				get_tree().current_scene = Com.game
				Com.game.add_main_player(player)
				
				emit_signal("log_in")
			else:
				emit_signal("error", result)
		Packet.TYPE.REGISTER:
			emit_signal("error", unpacker.get_u8())
		
		Packet.TYPE.CHAT:
			emit_signal("chat_message", unpacker.get_u8(), unpacker.get_string(), unpacker.get_string())
		
		Packet.TYPE.DAMAGE:
			var entity = Com.game.get_entity(unpacker.get_u16())
			var damage = unpacker.get_u16() - 10000
			
			if entity:
				preload("res://Nodes/Effects/PopupText.tscn").instance().start(entity, -damage, Color.red)
		
		"DEAD": ###
			var map = Com.game.map
			
			if [][0] == "e":
				var enemy = map.get_enemy([][1])
				if enemy:
					enemy.dead()
				else:
					printerr("WARNING: Wrong enemy id for dead: ", [][1])
			elif [][0] == "player":
				map.get_node("Players/" + [][1]).dead()
		
		"DROP": ###
			var map = Com.game.map
			var enemy = map.get_enemy([][0])
			if enemy:
				enemy.create_drop([][1])
			else:
				printerr("WARNING: Wrong enemy id for drop: ", [][0])
		
		Packet.TYPE.ENTER_ROOM:
			Com.game.change_map(unpacker.get_u16())
			Com.player.set_meta("id", unpacker.get_u16())
			Com.game.register_entity(Com.player, Com.player.get_meta("id"))
			Com.player.position = unpacker.get_position()
			Com.player.update_camera()
		
		Packet.TYPE.ADD_ENTITY:
			Com.game.add_entity(unpacker.get_u16(), unpacker.get_u16())
		
		Packet.TYPE.REMOVE_ENTITY:
			Com.game.remove_entity(unpacker.get_u16())
		
		Packet.TYPE.TICK:
			var timestamp = unpacker.get_u32()
			var entity_count = unpacker.get_u8()
			
			for i in entity_count:
#				print("_")
				var id = unpacker.get_u16()
				var diff_vector = unpacker.get_u8()
				
				var entity = Com.game.get_entity(id)
				
				if entity and is_instance_valid(entity):
					Data.apply_state_vector(timestamp, unpacker, entity, diff_vector)
		
		"EQUIPMENT": ###
			Com.game.update_equipment([])
		
		"INVENTORY": ###
			Com.game.update_inventory([])
		
		Packet.TYPE.KEY_PRESS:
			Com.controls.press_key(unpacker.get_u16(), unpacker.get_u8(), Controls.State.ACTION)
		
		Packet.TYPE.KEY_RELEASE:
			Com.controls.release_key(unpacker.get_u16(), unpacker.get_u8(), Controls.State.ACTION)
		
		Packet.TYPE.STATS:
			var vec = unpacker.get_u8()
			var vec2 = unpacker.get_u8()
			var stats = {}
			
			for i in Packet.stat_list.size():
				var stat = Packet.stat_list[i]
				
				if ((vec if i < 8 else vec2) & Data.binary[i%8]) > 0:
					stats[stat] = unpacker.get_u16()
			
			if !stats.empty():
				emit_signal("stats", stats)
		
		"MAP": ###
			Com.player.chr.update_map([])
		
		"SOUL": ###
			var enemy = Com.game.get_enemy([][0])
			if enemy: enemy.create_soul([][1])

func send_data(packet):
	client.put_data(packet.data)

func print_raw(ary): ##DEBUG
	var arr = []
	for i in range(ary.size()): arr.append(ary[i])
	print(str(arr))