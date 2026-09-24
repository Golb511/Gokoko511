extends Node
## Persistent save system. JSON on disk with checksum, backup copy and
## forward-compatible merging of new default fields.

const SAVE_PATH := "user://shadow_crown_save.json"
const BACKUP_PATH := "user://shadow_crown_save.bak"
const SALT := "shadow-crown-eternal-siege"
const VERSION := 1


func load_profile() -> Dictionary:
	for path in [SAVE_PATH, BACKUP_PATH]:
		var data := _read(path)
		if not data.is_empty():
			return data
	return {}


func save_profile(profile: Dictionary) -> bool:
	var payload := {"version": VERSION, "profile": profile}
	var body := JSON.stringify(payload)
	payload["checksum"] = _checksum(body)
	var text := JSON.stringify(payload)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save: cannot write %s (%s)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	return true


func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("profile"):
		push_warning("Save: corrupted file %s" % path)
		return {}
	var check: String = parsed.get("checksum", "")
	var body := JSON.stringify({"version": parsed.get("version", VERSION), "profile": parsed.profile})
	if check != _checksum(body):
		push_warning("Save: checksum mismatch in %s — loading anyway" % path)
	return parsed.profile


func _checksum(body: String) -> String:
	return (body + SALT).sha256_text().substr(0, 24)


## Recursively fill keys missing from `target` with values from `defaults`.
static func merge_defaults(target: Dictionary, defaults: Dictionary) -> Dictionary:
	for k in defaults:
		if not target.has(k):
			target[k] = defaults[k]
		elif typeof(target[k]) == TYPE_DICTIONARY and typeof(defaults[k]) == TYPE_DICTIONARY:
			merge_defaults(target[k], defaults[k])
	return target
