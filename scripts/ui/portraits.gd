extends Node
## Renders hero portraits from the real 3D models into cached textures
## (used by hero cards and the battle HUD). Falls back gracefully when no
## renderer is available (headless).

var _cache: Dictionary = {}
var _pending: Dictionary = {}
var _queue: Array = []
var _busy := false


func request(hero_id: String, cb: Callable) -> void:
	if _cache.has(hero_id):
		cb.call(_cache[hero_id])
		return
	if DisplayServer.get_name() == "headless":
		cb.call(null)
		return
	if not _pending.has(hero_id):
		_pending[hero_id] = []
		_queue.append(hero_id)
	_pending[hero_id].append(cb)
	if not _busy:
		_process_queue()


func _process_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		var tex := await _render(id)
		_cache[id] = tex
		for cb in _pending.get(id, []):
			if cb.is_valid():
				cb.call(tex)
		_pending.erase(id)
	_busy = false


func _render(hero_id: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 320)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var stage := HeroStage.new()
	vp.add_child(stage)
	stage.setup(DB.heroes[hero_id].model, true)
	stage.frame_portrait()
	for i in 4:
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
