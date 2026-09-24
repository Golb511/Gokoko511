extends Node
## Localization (English / Arabic) from data/i18n.json.
##
## The active language's messages are installed as the engine's translation so
## tr() and auto-translate work everywhere. The engine locale itself stays
## left-to-right: layouts are designed once, while Arabic strings are still
## shaped and flow right-to-left because text direction is detected from the
## content itself.

const LANGS := ["en", "ar"]
var language := "ar"
var _data: Dictionary = {}
var _active: Translation


func _ready() -> void:
	var f := FileAccess.open("res://data/i18n.json", FileAccess.READ)
	_data = JSON.parse_string(f.get_as_text())
	TranslationServer.set_locale("en")
	_install(language)


func _install(lang: String) -> void:
	if _active:
		TranslationServer.remove_translation(_active)
	var idx := LANGS.find(lang)
	var t := Translation.new()
	t.locale = "en"
	for key in _data:
		var pair: Array = _data[key]
		t.add_message(key, pair[mini(idx, pair.size() - 1)])
	TranslationServer.add_translation(t)
	_active = t


func set_language(lang: String) -> void:
	if lang not in LANGS:
		lang = "en"
	var changed := lang != language
	language = lang
	_install(lang)
	if changed:
		Events.language_changed.emit(lang)


func is_rtl() -> bool:
	return language == "ar"


func t(key: String) -> String:
	return tr(key)


## Formats numbers compactly: 125750 -> 125,750 ; 1.2M.
func num(v: float) -> String:
	var n := int(round(v))
	if absi(n) >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func stat_value(stat: String, v: float) -> String:
	if stat in ["attack_speed", "move_speed", "crit", "crit_dmg", "cdr", "lifesteal", "gold_bonus", "xp_bonus", "tower_dmg", "loot_bonus"]:
		return "+%d%%" % int(round(v * 100.0))
	if stat == "energy_regen":
		return "+%.1f/s" % v
	return "+%s" % num(v)
