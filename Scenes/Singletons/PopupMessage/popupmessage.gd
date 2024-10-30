extends CanvasLayer

func _ready():
	visible = false

func _show_popup(text, delay = 0.0):
	if delay > 0.0: yield (get_tree().create_timer(delay), "timeout")
	
	$Control / Panel / Label.text = text
	visible = true

func _on_Button_pressed():
	visible = false
