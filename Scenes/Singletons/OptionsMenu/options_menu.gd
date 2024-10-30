extends CanvasLayer

var screen_resolutions = [
		Vector2(640, 480), 
		Vector2(720, 480), 
		Vector2(800, 1200), 
		Vector2(1280, 720), 
		Vector2(1280, 1024), 
		Vector2(1280, 800), 
		Vector2(1360, 768), 
		Vector2(1366, 768), 
		Vector2(1440, 900), 
		Vector2(1600, 900), 
		Vector2(1680, 1050), 
		Vector2(1920, 1200), 
		Vector2(1920, 1080), 
		Vector2(2560, 1080), 
		Vector2(2560, 1600), 
		Vector2(2560, 1440), 
		Vector2(2880, 1800), 
		Vector2(3440, 1440), 
		Vector2(3840, 2160), 
		Vector2(5120, 1440)]

var restart_required = false
var save_timer = 3
var mouse_sens = 0.03
var mouse_invert = 0
var open = false

var fade_audio_des = 1.0
var fade_audio_cur = 0.0

var resolution_old = Vector2(1600, 900)
var resolution_timer = 0
var resolution_confirm = false

var punchable = true

onready var buttons = $Control / Panel / buttons
onready var tabmain = $Control / Panel / tabs_main

signal _options_update
signal _rebinding_key(action)

func _ready():
	for res in screen_resolutions:
		$"%res".add_item(str(res.x) + "x" + str(res.y))
	
	$"%fs".add_item("Windowed")
	$"%fs".add_item("Windowed Borderless")
	$"%fs".add_item("Fullscreen")
	
	$"%vync".add_item("Vsync Disabled")
	$"%vync".add_item("VSync Enabled")
	
	$"%fpslmit".add_item("30")
	$"%fpslmit".add_item("60")
	$"%fpslmit".add_item("120")
	$"%fpslmit".add_item("Unlimited")
	
	$"%waterq".add_item("Low Quality")
	$"%waterq".add_item("High Quality")
	
	$"%viewd".add_item("Unlimited")
	$"%viewd".add_item("Medium")
	$"%viewd".add_item("Low")
	$"%viewd".add_item("Scary")
	
	$"%pixel".add_item("No Pixelization")
	$"%pixel".add_item("Default Pixelization")
	$"%pixel".add_item("Extreme Pixelization")
	$"%pixel".add_item("WTF Pixelization")
	
	$"%invert".add_item("No Invert")
	$"%invert".add_item("X Invert")
	$"%invert".add_item("Y Invert")
	$"%invert".add_item("XY Invert")
	
	$"%resizeable".add_item("Disabled")
	$"%resizeable".add_item("Enabled")
	
	$"%punchable".add_item("Allowed")
	$"%punchable".add_item("Disallowed")
	
	_close()
	_open_tab(0)

func _physics_process(delta):
	fade_audio_cur = lerp(fade_audio_cur, fade_audio_des, 0.1)
	
	var index = AudioServer.get_bus_index("FadeBus")
	var final = linear2db(stepify(fade_audio_cur, 0.1))
	AudioServer.set_bus_volume_db(index, final)


func _set_selections_to_save():
	$"%res".selected = screen_resolutions.find(PlayerData.player_options.res)
	$"%fs".selected = PlayerData.player_options.fullscreen
	$"%pixel".selected = PlayerData.player_options.pixel
	$"%vync".selected = PlayerData.player_options.vsync
	$"%fpslmit".selected = [30, 60, 120, 0].find(PlayerData.player_options.fps_limit)
	$"%waterq".selected = PlayerData.player_options.water
	$"%viewd".selected = PlayerData.player_options.view_distance
	$"%main_vol".value = PlayerData.player_options.main_vol
	$"%sfx_vol".value = PlayerData.player_options.sfx_vol
	$"%music_vol".value = PlayerData.player_options.music_vol
	$"%sens_val".value = PlayerData.player_options.mouse_sens * 1000.0
	$"%invert".selected = PlayerData.player_options.mouse_invert
	$"%resizeable".selected = PlayerData.player_options.resizeable
	$"%punchable".selected = PlayerData.player_options.punchable
	
	for remap in PlayerData.player_options.key_rebindings:
		for button in get_tree().get_nodes_in_group("input_remap"):
			if button.action == remap[0]:
				var ek = InputEventKey.new()
				ek.scancode = remap[1]
				button.queued_action = ek
	get_tree().call_group("input_remap", "_remap_key")


func _reset():
	$"%res".selected = 9
	$"%fs".selected = 0
	$"%pixel".selected = 1
	$"%vync".selected = 1
	$"%fpslmit".selected = 3
	$"%waterq".selected = 1
	$"%viewd".selected = 0
	$"%main_vol".value = 0.7
	$"%sfx_vol".value = 1.0
	$"%music_vol".value = 1.0
	$"%sens_val".value = 50
	$"%invert".selected = 0
	$"%resizeable".selected = 0
	$"%punchable".selected = 0
	
	for button in get_tree().get_nodes_in_group("input_remap"):
		button.queued_action = button.default_action
		button._on_input_forward_toggled(false)


func _apply_selections(deny = false):
	if PlayerData.player_options.res != screen_resolutions[$"%res".selected]:
		resolution_old = PlayerData.player_options.res
		PlayerData.player_options.res = screen_resolutions[$"%res".selected]
		resolution_timer = 20
		resolution_confirm = true
		$confirm_screen.show()
		_confirm_res_timer()
	
	if not deny: PlayerData.player_options.res = screen_resolutions[$"%res".selected]
	else : PlayerData.player_options.res = resolution_old
	
	PlayerData.player_options.fullscreen = $"%fs".selected
	PlayerData.player_options.pixel = $"%pixel".selected
	PlayerData.player_options.fps_limit = [30, 60, 120, 0][$"%fpslmit".selected]
	PlayerData.player_options.vsync = $"%vync".selected
	PlayerData.player_options.water = $"%waterq".selected
	PlayerData.player_options.view_distance = $"%viewd".selected
	PlayerData.player_options.resizeable = $"%resizeable".selected
	
	PlayerData.player_options.main_vol = $"%main_vol".value
	PlayerData.player_options.sfx_vol = $"%sfx_vol".value
	PlayerData.player_options.music_vol = $"%music_vol".value
	
	PlayerData.player_options.mouse_sens = $"%sens_val".value / 1000.0
	PlayerData.player_options.mouse_invert = $"%invert".selected
	
	PlayerData.player_options.punchable = $"%punchable".selected
	
	PlayerData.player_options.key_rebindings.clear()
	
	get_tree().call_group("input_remap", "_remap_key")
	yield (get_tree().create_timer(0.1), "timeout")
	for button in get_tree().get_nodes_in_group("input_remap"):
		if button.set_action != button.default_action:
			PlayerData.player_options.key_rebindings.append([button.action, button.set_action.scancode])
	print("Remapped Keys: ", PlayerData.player_options.key_rebindings)
	
	_update_options()
	$Control / Label.visible = restart_required
	
	yield (get_tree().create_timer(0.2), "timeout")
	PlayerData._save_game()



func _update_options():
	print(PlayerData.player_options)
	
	var res = PlayerData.player_options.res
	OS.window_size = res
	
	OS.window_fullscreen = PlayerData.player_options.fullscreen == 2
	OS.window_borderless = PlayerData.player_options.fullscreen == 1
	OS.set_window_always_on_top(PlayerData.player_options.fullscreen == 1)
	if PlayerData.player_options.fullscreen == 1:
		OS.window_size = OS.window_size + Vector2(0, 1)
		OS.set_window_position(Vector2(0, 0))
		OS.window_maximized = true
	if PlayerData.player_options.fullscreen == 0:
		OS.window_size = OS.window_size + Vector2(0, 1)
	
	OS.window_resizable = PlayerData.player_options.resizeable == 1
	
	Globals.pixelize_amount = [1.0, 2.25, 6.0, 16.0][PlayerData.player_options.pixel]
	
	Engine.target_fps = PlayerData.player_options.fps_limit
	
	OS.vsync_enabled = bool(PlayerData.player_options.vsync)
	
	var index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(index, linear2db(PlayerData.player_options.main_vol))
	
	index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(index, linear2db(PlayerData.player_options.sfx_vol))
	index = AudioServer.get_bus_index("FadeBypass")
	AudioServer.set_bus_volume_db(index, linear2db(PlayerData.player_options.sfx_vol))
	
	index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(index, linear2db(PlayerData.player_options.music_vol))
	
	mouse_sens = PlayerData.player_options.mouse_sens
	mouse_invert = PlayerData.player_options.mouse_invert
	punchable = PlayerData.player_options.punchable
	
	get_tree().get_root().emit_signal("size_changed")
	emit_signal("_options_update")

func _open():
	_set_selections_to_save()
	_open_tab(0)
	visible = true
	open = true

func _close():
	visible = false
	open = false

func _open_tab(tab):
	for child in buttons.get_children():
		child.modulate = Color(0.6, 0.5, 0.4)
	for child in tabmain.get_children():
		child.visible = false
	
	save_timer = 11
	_update_reset()
	
	buttons.get_child(tab).modulate = Color(1, 1, 1)
	tabmain.get_child(tab).visible = true


func _on_reset_pressed():
	save_timer -= 1
	if save_timer <= 0:
		save_timer = 11
		PlayerData._reset_save()
	_update_reset()

func _update_reset():
	$"%reset".text = "Reset Save Data"
	if save_timer < 11: $"%reset".text = "Reset Save Data In " + str(save_timer)
	if save_timer == 1: $"%reset".text = "Reset Save Data? Last call..."

func _on_main_vol_value_changed(value): $"%main_label".text = str(value * 100.0) + "%"
func _on_sfx_vol_value_changed(value): $"%sfx_label".text = str(value * 100.0) + "%"
func _on_music_vol_value_changed(value): $"%music_label".text = str(value * 100.0) + "%"
func _on_sens_val_value_changed(value): $"%sens_label".text = str(value) + ""

func _confirm_res_timer():
	if not resolution_confirm: return 
	
	resolution_timer -= 1
	$confirm_screen / Panel / Label.text = "Confirm Resolution Changes?\n" + str(resolution_timer)
	
	if resolution_timer <= - 1:
		_deny_res()

func _deny_res():
	if not resolution_confirm: return 
	resolution_confirm = false
	$confirm_screen.hide()
	_apply_selections(true)
	PlayerData.player_options.res = resolution_old
	$"%res".selected = screen_resolutions.find(resolution_old)

func _con_res():
	if not resolution_confirm: return 
	resolution_confirm = false
	$confirm_screen.hide()
