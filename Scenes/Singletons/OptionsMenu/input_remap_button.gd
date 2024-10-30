extends Button

export  var action = "move_forward"

var default_action
var set_action
var queued_action

func _ready():
	OptionsMenu.connect("_rebinding_key", self, "_input_check")
	
	default_action = InputMap.get_action_list(action)[0]
	add_to_group("input_remap")
	set_process_unhandled_key_input(false)
	_display_key()

func _display_key():
	text = "%s" % InputMap.get_action_list(action)[0].as_text()

func _on_input_forward_toggled(button_pressed):
	set_process_unhandled_key_input(button_pressed)
	if button_pressed:
		text = ". . ."
		OptionsMenu.emit_signal("_rebinding_key", action)
	elif queued_action:
		text = "%s" % queued_action.as_text()
	else :
		_display_key()

func _unhandled_key_input(event):
	if event is InputEventKey and event.scancode == KEY_ESCAPE:
		pressed = false
		return 
	
	for button in get_tree().get_nodes_in_group("input_remap"):
		if button != self:
			var valid = true
			if button.set_action and button.set_action.scancode == event.scancode: valid = false
			if button.queued_action and button.queued_action.scancode == event.scancode: valid = false
			if not valid:
				if button.default_action.scancode != event.scancode:
					button.queued_action = button.default_action
				else :
					button.queued_action = set_action
				
				button._on_input_forward_toggled(false)
	
	queued_action = event
	
	pressed = false

func _input_check(new_action):
	if action == new_action: return 
	pressed = false

func _set_queued(event):
	queued_action = event
	_on_input_forward_toggled(false)

func _remap_key():
	var event = default_action
	if queued_action:
		event = queued_action
	elif set_action:
		event = set_action
	
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	
	text = "%s" % event.as_text()
	queued_action = null
	set_action = event

func _duplicate_reset(new_action):
	if set_action == new_action or queued_action == new_action:
		set_action = default_action
		queued_action = default_action
		_remap_key()
		return true
	return false
