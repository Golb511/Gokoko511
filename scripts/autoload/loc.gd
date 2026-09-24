extends Node
## Localization: builds Translation resources from data/i18n.json so the
## standard tr() / auto-translate pipeline works for both English and Arabic.

const LOCALES := ["en", "ar"]
var _translations: Array[Translation] = []


func _ready() -> void:
	var f := FileAccess.open("res://data/i18n.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for i in LOCALES.size():
		var t := Translation.new()
		t.locale = LOCALES[i]
		for key in data:
			var pair: Array = data[key]
			t.add_message(key, pair[min(i, pair.size() - 1)])
		TranslationServer.add_translation(t)
		_translations.append(t)
	TranslationServer.set_locale("ar")


func set_language(locale: String) -> void:
	if locale not in LOCALES:
		locale = "en"
	TranslationServer.set_locale(locale)
	Events.language_changed.emit(locale)


func is_rtl() -> bool:
	return TranslationServer.get_locale().begins_with("ar")


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
