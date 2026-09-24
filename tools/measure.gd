extends Node

func _ready() -> void:
	for b in ["Knight", "Barbarian", "Skeleton_Minion", "Skeleton_Warrior", "Mage"]:
		var m := ModelLib.character({"base": b})
		add_child(m)
		print(b, " aabb=", _aabb(m))
		m.queue_free()
	for p in ["env/building_tower_A_red", "env/building_tower_B_red", "env/building_tower_catapult_red", "env/building_barracks_red", "env/building_castle_red", "graveyard/crypt", "graveyard/shrine", "env/mountain_A", "graveyard/tree_dead_large", "env/building_windmill_red", "env/building_well_red", "env/building_mine_red", "env/building_archeryrange_red", "env/building_scaffolding", "env/hex_grass"]:
		var n := ModelLib.prop(p)
		add_child(n)
		print(p, " aabb=", _aabb(n))
	get_tree().quit()

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible: continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first: out = a; first = false
		else: out = out.merge(a)
	return out
