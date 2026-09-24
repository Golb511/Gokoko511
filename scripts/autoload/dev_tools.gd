extends Node
## Developer utilities driven by command-line user args (after "--"):
##   --shot=res_or_abs_path.png  --shot-delay=8  capture a screenshot and quit
##   --battle / --map / --autoplay / --fresh are handled by other systems.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shot := ""
	var delay := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--shot-delay="):
			delay = float(a.substr(13))
	if shot != "":
		_capture(shot, delay)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--debug-script="):
			var n := Node.new()
			n.set_script(load(a.substr(15)))
			add_child(n)


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay, true, false, true).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("DEVTOOLS: saved screenshot ", path)
	get_tree().quit()
