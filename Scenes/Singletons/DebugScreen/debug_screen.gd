extends CanvasLayer

var lines = ""

func _physics_process(delta):
	
	
	if visible:
		$Control.text = lines

func _add_line(line):
	lines = lines + "\n" + line
