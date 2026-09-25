"""Generates data/tower_tree.json and the tree's i18n strings.

Every tower gets the same 13-node shape so the UI stays readable, but each
tower's specialty node, its two specialisation paths, their mid-tier choices
and the capstones are authored per tower and change how the tower works.

Shape (x, y are normalised 0..1 screen positions):
  core_dmg                     trunk (1 pt each, level 1)
  core_rate    core_range
  core_cost          core_spec (2 pts, level 3)
     a1            b1           path entry, mutually exclusive (2 pts, level 4)
   a2   a2b     b2   b2b        either/or choice inside a path (3 pts, level 6)
     a3            b3           capstone: special behaviour (5 pts, level 9)

Run: python3 tools/design/gen_tower_tree.py
"""
import json

LAYOUT = {
    "core_dmg": (0.5, 0.04), "core_rate": (0.36, 0.2), "core_range": (0.64, 0.2),
    "core_cost": (0.17, 0.36), "core_spec": (0.83, 0.36),
    "a1": (0.3, 0.52), "b1": (0.7, 0.52),
    "a2": (0.15, 0.7), "a2b": (0.4, 0.7), "b2": (0.6, 0.7), "b2b": (0.85, 0.7),
    "a3": (0.27, 0.9), "b3": (0.73, 0.9),
}
REQ = {
    "core_dmg": [], "core_rate": ["core_dmg"], "core_range": ["core_dmg"],
    "core_cost": ["core_rate"], "core_spec": ["core_range"],
    "a1": ["core_rate", "core_range"], "b1": ["core_rate", "core_range"],
    "a2": ["a1"], "a2b": ["a1"], "b2": ["b1"], "b2b": ["b1"],
    "a3": ["a2", "a2b"], "b3": ["b2", "b2b"],
}
EXCL = {"a1": "path", "b1": "path", "a2": "a_mid", "a2b": "a_mid", "b2": "b_mid", "b2b": "b_mid"}
COST = {"core_dmg": 1, "core_rate": 1, "core_range": 1, "core_cost": 2, "core_spec": 2,
        "a1": 3, "b1": 3, "a2": 4, "a2b": 4, "b2": 4, "b2b": 4, "a3": 6, "b3": 6}

# Balance: path nodes are authored at full strength and scaled here (tested
# with tools/tower_tree_combat.gd and autoplay on the boss stages).
PATH_POWER = 0.6
SPECIAL_DMG = 0.7
SPECIAL_EVERY_ADD = 2
SCALED = {"dmg", "rate", "range", "crit", "crit_mult", "pen", "splash", "stun", "freeze", "fear", "knockback",
          "ramp", "status_power", "status_duration", "air_bonus", "heal_allies", "execute", "soldier_hp",
          "armor", "respawn", "lifesteal", "trap_splash"}


def scale_path(fx):
    out = {}
    for k, v in fx.items():
        if k in SCALED and isinstance(v, (int, float)):
            out[k] = round(v * PATH_POWER, 3)
        elif k == "special":
            sp = dict(v)
            sp["every"] = int(sp["every"]) + SPECIAL_EVERY_ADD
            sp["dmg_mult"] = round(float(sp["dmg_mult"]) * SPECIAL_DMG, 3)
            out[k] = sp
        elif k == "mark":
            out[k] = {"power": round(v["power"] * PATH_POWER, 3), "duration": v["duration"]}
        else:
            out[k] = v
    return out
LEVEL = {"core_dmg": 1, "core_rate": 1, "core_range": 2, "core_cost": 3, "core_spec": 3,
         "a1": 4, "b1": 4, "a2": 6, "a2b": 6, "b2": 6, "b2b": 6, "a3": 9, "b3": 9}

# Shared trunk (names are generic, effects identical for every tower).
CORE = {
    "core_dmg": (["Empowered Core", "النواة المُمكّنة"], {"dmg": 0.06}),
    "core_rate": (["Quickened Gears", "التروس المتسارعة"], {"rate": 0.05}),
    "core_range": (["Far Watch", "المراقبة البعيدة"], {"range": 0.06}),
    "core_cost": (["Guild Contracts", "عقود النقابة"], {"cost": 0.10}),
}

# Per tower: specialty, path names, and the path nodes.
# Each node: [EN, AR], effects dict (optionally "special": {...}).
T = {}

T["archer"] = {
    "spec": (["Barbed Heads", "رؤوس شائكة"], {'pen': 0.15}),
    "a": ["Shadow Sniper", "قناص الظلال"], "b": ["Raven Volley", "وابل الغربان"],
    "a1": (["Eagle Eye", "عين النسر"], {'range': 0.15, 'dmg': 0.1}),
    "a2": (["Heartseeker", "باحث القلوب"], {'crit': 0.15, 'crit_mult': 0.5}),
    "a2b": (["Armor Breaker", "كاسر الدروع"], {'pen': 0.25}),
    "a3": (["Death Mark", "علامة الموت"], {'dmg': 0.1, 'mark': {'power': 0.15, 'duration': 4}, 'execute': 0.1}),
    "b1": (["Quick Draw", "السحب الخاطف"], {'rate': 0.12}),
    "b2": (["Split Shot", "السهم المنشطر"], {'multishot': 1, 'dmg': -0.2}),
    "b2b": (["Barbed Rain", "مطر الأشواك"], {'splash': 1.0}),
    "b3": (["Storm of Ravens", "عاصفة الغربان"], {'special': {'type': 'volley', 'every': 7, 'count': 4, 'dmg_mult': 0.5, 'proj': 'raven'}}),
}
T["mage"] = {
    "spec": (["Spell Pierce", "خارق التعاويذ"], {'pen': 0.2}),
    "a": ["Archmage of Ruin", "كبير سحرة الخراب"], "b": ["Chrono Weaver", "حائك الزمن"],
    "a1": (["Ruinous Power", "قوة الخراب"], {'dmg': 0.15}),
    "a2": (["Overcharge", "الشحنة الزائدة"], {'crit': 0.12, 'crit_mult': 0.4}),
    "a2b": (["Unstable Orbs", "كرات غير مستقرة"], {'splash': 1.2}),
    "a3": (["Cataclysm", "الكارثة"], {'dmg': 0.1, 'special': {'type': 'empowered', 'every': 5, 'dmg_mult': 2.0, 'splash': 2.5}}),
    "b1": (["Slowing Hex", "لعنة البطء"], {'rate': 0.08, 'status': {'id': 'slow', 'duration': 2.0, 'power': 0.25}}),
    "b2": (["Time Lock", "قفل الزمن"], {'freeze': 0.06}),
    "b2b": (["Twin Orbs", "الكرتان التوأم"], {'multishot': 1, 'dmg': -0.2}),
    "b3": (["Temporal Rift", "صدع الزمن"], {'special': {'type': 'nova', 'every': 6, 'dmg_mult': 0.5, 'status': {'id': 'slow', 'duration': 2.0, 'power': 0.5}, 'element': 'arcane'}}),
}
T["artillery"] = {
    "spec": (["Heavy Shells", "القذائف الثقيلة"], {'splash': 0.6}),
    "a": ["Siege Master", "سيد الحصار"], "b": ["Hellfire Battery", "بطارية نار الجحيم"],
    "a1": (["Black Powder", "البارود الأسود"], {'dmg': 0.15}),
    "a2": (["Concussion", "الارتجاج"], {'stun': 0.1}),
    "a2b": (["Bunker Buster", "مخترق التحصينات"], {'pen': 0.3}),
    "a3": (["Earthshatter", "محطم الأرض"], {'special': {'type': 'empowered', 'every': 5, 'dmg_mult': 1.8, 'splash': 1.0, 'stun': 1.0}}),
    "b1": (["Rapid Loader", "التذخير السريع"], {'rate': 0.12}),
    "b2": (["Incendiary", "القذائف الحارقة"], {'status': {'id': 'burn', 'duration': 3.0, 'power_mult': 0.2}}),
    "b2b": (["Cluster Shells", "القذائف العنقودية"], {'splash': 0.8}),
    "b3": (["Rain of Fire", "مطر النار"], {'special': {'type': 'barrage', 'every': 5, 'count': 3, 'dmg_mult': 0.6}}),
}
T["soldier"] = {
    "spec": (["Drill Sergeant", "رقيب التدريب"], {'respawn': 0.2}),
    "a": ["Iron Wall", "الجدار الحديدي"], "b": ["Blood Berserkers", "هائجو الدم"],
    "a1": (["Tower Shields", "دروع البرج"], {'soldier_hp': 0.2, 'armor': 10}),
    "a2": (["Shield Wall", "جدار الدروع"], {'soldiers': 1}),
    "a2b": (["Tempered Plate", "الدروع المسقاة"], {'soldier_hp': 0.15, 'armor': 15}),
    "a3": (["Undying Legion", "الفيلق الخالد"], {'unit': 'black_guard', 'soldier_hp': 0.3, 'respawn': 0.3, 'dmg': 0.15}),
    "b1": (["Bloodlust", "شهوة الدم"], {'dmg': 0.2}),
    "b2": (["Life Drinker", "شارب الحياة"], {'lifesteal': 0.12}),
    "b2b": (["Warband", "العصبة"], {'soldiers': 1}),
    "b3": (["Warlord's Fury", "غضب أمير الحرب"], {'unit': 'berserker', 'dmg': 0.3, 'lifesteal': 0.15}),
}
T["poison"] = {
    "spec": (["Potent Toxins", "السموم الفتاكة"], {'status_power': 0.2}),
    "a": ["Plague Doctor", "طبيب الطاعون"], "b": ["Venom Specialist", "خبير السموم"],
    "a1": (["Miasma", "الوباء"], {'splash': 1.0}),
    "a2": (["Lingering Rot", "العفن الدائم"], {'status_duration': 0.4}),
    "a2b": (["Contagion", "العدوى"], {'splash': 0.8, 'dmg': 0.08}),
    "a3": (["Pandemic", "الجائحة"], {'special': {'type': 'empowered', 'every': 4, 'dmg_mult': 1.2, 'splash': 2.5, 'status_mult': 1.8}}),
    "b1": (["Concentrated Venom", "السم المركّز"], {'dmg': 0.15}),
    "b2": (["Corrosion", "التآكل"], {'pen': 0.25}),
    "b2b": (["Rapid Spit", "البصق السريع"], {'rate': 0.15}),
    "b3": (["Liquefy", "الإذابة"], {'execute': 0.12, 'status_power': 0.35}),
}
T["fire"] = {
    "spec": (["Kindling", "الإشعال"], {'ramp': 0.25}),
    "a": ["Inferno Lord", "سيد الجحيم"], "b": ["Flame Dancer", "راقص اللهب"],
    "a1": (["White Heat", "الحرارة البيضاء"], {'dmg': 0.15}),
    "a2": (["Stoked Fury", "الغضب المتأجج"], {'ramp': 0.4}),
    "a2b": (["Long Flame", "اللهب الطويل"], {'range': 0.12}),
    "a3": (["Sunfire", "نار الشمس"], {'special': {'type': 'nova', 'every': 5, 'dmg_mult': 0.9, 'radius_mult': 0.6, 'status': {'id': 'burn', 'duration': 3.0, 'power_mult': 0.25}, 'element': 'fire'}}),
    "b1": (["Fan the Flames", "تأجيج اللهب"], {'rate': 0.15}),
    "b2": (["Searing Touch", "اللمسة الحارقة"], {'status': {'id': 'burn', 'duration': 3.0, 'power_mult': 0.25}}),
    "b2b": (["Twin Flames", "اللهبان التوأم"], {'multishot': 1, 'dmg': -0.15}),
    "b3": (["Phoenix Flight", "تحليق العنقاء"], {'special': {'type': 'volley', 'every': 6, 'count': 4, 'dmg_mult': 0.6, 'proj': 'fireball'}}),
}
T["ice"] = {
    "spec": (["Deep Chill", "البرد القارس"], {'status_power': 0.25}),
    "a": ["Glacial Warden", "حارس الجليد"], "b": ["Shatter", "التحطيم"],
    "a1": (["Rime", "الصقيع"], {'freeze': 0.06}),
    "a2": (["Frostbite", "عضة الصقيع"], {'dmg': 0.15}),
    "a2b": (["Permafrost", "الجليد الدائم"], {'status_duration': 0.4}),
    "a3": (["Absolute Zero", "الصفر المطلق"], {'special': {'type': 'nova', 'every': 6, 'dmg_mult': 0.4, 'status': {'id': 'freeze', 'duration': 1.0, 'power': 1.0}, 'element': 'ice'}}),
    "b1": (["Ice Needles", "إبر الجليد"], {'dmg': 0.1, 'rate': 0.08}),
    "b2": (["Brittle", "الهشاشة"], {'bonus_status': {'id': 'slow', 'mult': 1.3}}),
    "b2b": (["Ice Pick", "معول الجليد"], {'pen': 0.25}),
    "b3": (["Ice Lances", "رماح الجليد"], {'special': {'type': 'volley', 'every': 5, 'count': 4, 'dmg_mult': 0.6, 'proj': 'frost_bolt'}}),
}
T["lightning"] = {
    "spec": (["Conductive", "الموصلية"], {'chain': 1}),
    "a": ["Tesla Master", "سيد تسلا"], "b": ["Storm Herald", "بشير العاصفة"],
    "a1": (["High Voltage", "الجهد العالي"], {'dmg': 0.12}),
    "a2": (["Arc Web", "شبكة الأقواس"], {'chain': 1}),
    "a2b": (["Paralysis", "الشلل"], {'stun': 0.06}),
    "a3": (["Overload", "الحمل الزائد"], {'special': {'type': 'nova', 'every': 6, 'dmg_mult': 0.7, 'status': {'id': 'stun', 'duration': 0.4, 'power': 1.0}, 'element': 'lightning'}}),
    "b1": (["Static Rush", "الاندفاع الساكن"], {'rate': 0.15}),
    "b2": (["Sky Reach", "مدى السماء"], {'range': 0.12}),
    "b2b": (["Ionized", "التأين"], {'crit': 0.12}),
    "b3": (["Thunderstorm", "العاصفة الرعدية"], {'special': {'type': 'barrage', 'every': 5, 'count': 3, 'dmg_mult': 0.7, 'bolt': True}}),
}
T["shadow"] = {
    "spec": (["Dread", "الرهبة"], {'pen': 0.2}),
    "a": ["Void Reaper", "حاصد الفراغ"], "b": ["Nightmare Weaver", "حائك الكوابيس"],
    "a1": (["Umbral Edge", "الحد الظلي"], {'dmg': 0.15}),
    "a2": (["Soul Harvest", "حصاد الأرواح"], {'execute': 0.08}),
    "a2b": (["Void Strike", "ضربة الفراغ"], {'crit': 0.15}),
    "a3": (["Oblivion", "العدم"], {'mark': {'power': 0.2, 'duration': 5}, 'execute': 0.06}),
    "b1": (["Deepening Dark", "الظلام المتعمق"], {'status_power': 0.3}),
    "b2": (["Terror", "الرعب"], {'fear': 0.06}),
    "b2b": (["Twin Shades", "الظلان التوأم"], {'multishot': 1, 'dmg': -0.2}),
    "b3": (["Mass Hysteria", "الهستيريا الجماعية"], {'special': {'type': 'nova', 'every': 6, 'dmg_mult': 0.4, 'status': {'id': 'fear', 'duration': 1.2, 'power': 1.0}, 'element': 'shadow'}}),
}
T["light"] = {
    "spec": (["Consecration", "التكريس"], {'pen': 0.15}),
    "a": ["Radiant Judge", "القاضي المتوهج"], "b": ["Sanctifier", "المُطهّر"],
    "a1": (["Blinding Light", "النور المُعمي"], {'dmg': 0.15}),
    "a2": (["Focused Beam", "الشعاع المركّز"], {'ramp': 0.4}),
    "a2b": (["Dawn Reach", "مدى الفجر"], {'range': 0.12}),
    "a3": (["Judgment", "الحُكم"], {'special': {'type': 'nova', 'every': 5, 'dmg_mult': 1.2, 'radius_mult': 0.6, 'element': 'holy'}}),
    "b1": (["Mending Light", "النور الشافي"], {'heal_allies': 6}),
    "b2": (["Zeal", "الحماسة"], {'dmg': 0.12}),
    "b2b": (["Holy Chains", "السلاسل المقدسة"], {'status': {'id': 'slow', 'duration': 1.5, 'power': 0.2}}),
    "b3": (["Sanctuary", "الملاذ"], {'heal_allies': 5, 'special': {'type': 'nova', 'every': 6, 'dmg_mult': 0.7, 'heal_pct': 0.08, 'element': 'holy'}}),
}
T["earth"] = {
    "spec": (["Aftershock", "الهزة الارتدادية"], {'stun': 0.05}),
    "a": ["Quake Titan", "عملاق الزلازل"], "b": ["Stone Warden", "حارس الحجر"],
    "a1": (["Tremor", "الرجفة"], {'dmg': 0.15}),
    "a2": (["Fault Line", "خط الصدع"], {'range': 0.12}),
    "a2b": (["Seismic Lock", "القفل الزلزالي"], {'stun': 0.06}),
    "a3": (["Tectonic Rift", "الصدع التكتوني"], {'special': {'type': 'empowered', 'every': 5, 'dmg_mult': 1.5, 'stun': 1.0}}),
    "b1": (["Rockslide", "الانهيار الصخري"], {'knockback': 0.6}),
    "b2": (["Crushing Weight", "الثقل الساحق"], {'pen': 0.25}),
    "b2b": (["Restless Earth", "الأرض القلقة"], {'rate': 0.15}),
    "b3": (["Mountain's Wrath", "غضب الجبل"], {'special': {'type': 'barrage', 'every': 6, 'count': 2, 'dmg_mult': 0.8}}),
}
T["wind"] = {
    "spec": (["Updraft", "التيار الصاعد"], {'air_bonus': 0.4}),
    "a": ["Tempest", "الإعصار"], "b": ["Sky Hunter", "صياد السماء"],
    "a1": (["Gale Force", "قوة العاصفة"], {'knockback': 0.6}),
    "a2": (["Wide Winds", "الرياح الواسعة"], {'range': 0.12}),
    "a2b": (["Headwind", "الريح المعاكسة"], {'status': {'id': 'slow', 'duration': 1.5, 'power': 0.25}}),
    "a3": (["Cyclone", "الزوبعة"], {'special': {'type': 'nova', 'every': 5, 'dmg_mult': 1.0, 'knockback': 2.5, 'element': 'wind'}}),
    "b1": (["Talon Winds", "رياح المخالب"], {'air_bonus': 0.8}),
    "b2": (["Razor Gusts", "هبات الشفرات"], {'dmg': 0.15}),
    "b2b": (["Swift Currents", "التيارات السريعة"], {'rate': 0.15}),
    "b3": (["Downburst", "الانقضاض الهوائي"], {'special': {'type': 'volley', 'every': 5, 'count': 4, 'dmg_mult': 0.8, 'proj': 'arcane_orb'}}),
}
T["crossbow"] = {
    "spec": (["Steel Bolts", "المسامير الفولاذية"], {'pen': 0.15}),
    "a": ["Ballista Master", "سيد المنجنيق"], "b": ["Repeater", "الرشاش"],
    "a1": (["Heavy Draw", "الشد الثقيل"], {'dmg': 0.15}),
    "a2": (["Impaler", "الخازوق"], {'pierce': 1}),
    "a2b": (["Weak Spot", "نقطة الضعف"], {'crit': 0.12, 'crit_mult': 0.4}),
    "a3": (["Skewer", "السيخ"], {'special': {'type': 'empowered', 'every': 5, 'dmg_mult': 1.8, 'pierce': 3}}),
    "b1": (["Rapid Crank", "التدوير السريع"], {'rate': 0.1}),
    "b2": (["Double Load", "التذخير المزدوج"], {'multishot': 1, 'dmg': -0.3}),
    "b2b": (["Long Stock", "المقبض الطويل"], {'range': 0.12}),
    "b3": (["Bolt Storm", "عاصفة المسامير"], {'special': {'type': 'volley', 'every': 7, 'count': 4, 'dmg_mult': 0.5, 'proj': 'bolt'}}),
}
T["trap"] = {
    "spec": (["Hidden Mechanisms", "الآليات الخفية"], {'traps': 1}),
    "a": ["Spike Lord", "سيد الأشواك"], "b": ["Snare Master", "سيد الأفخاخ"],
    "a1": (["Sharpened Spikes", "الأشواك المسنونة"], {'dmg': 0.2}),
    "a2": (["Armor Piercers", "خارقات الدروع"], {'pen': 0.35}),
    "a2b": (["Minefield", "حقل الألغام"], {'traps': 1}),
    "a3": (["Blade Field", "حقل الشفرات"], {'dmg': 0.15, 'trap_splash': 2.2}),
    "b1": (["Snare Coils", "لفائف الشرك"], {'status': {'id': 'root', 'duration': 1.2, 'power': 1.0}}),
    "b2": (["Quick Reset", "الإعادة السريعة"], {'rate': 0.15}),
    "b2b": (["Tar Pits", "حفر القار"], {'status': {'id': 'slow', 'duration': 3.0, 'power': 0.4}}),
    "b3": (["Grasping Earth", "الأرض القابضة"], {'dmg': 0.15, 'trap_splash': 1.5, 'status': {'id': 'root', 'duration': 2.0, 'power': 1.0}}),
}

PATH_DESC = {
    "archer": (["Massive single-target damage, long range, armour piercing and crits.", "ضرر هائل لهدف واحد، مدى بعيد، اختراق للدروع وضربات حرجة."],
               ["High attack speed and several arrows at once to shred groups.", "سرعة هجوم عالية وعدة سهام معًا لتمزيق المجموعات."]),
    "mage": (["Raw arcane destruction and huge explosive blasts.", "دمار سحري خالص وانفجارات هائلة."],
             ["Slows, freezes and bends time around the enemy lines.", "إبطاء وتجميد وثني للزمن حول صفوف العدو."]),
    "artillery": (["Crushing shells that stun and break armour.", "قذائف ساحقة تشلّ وتكسر الدروع."],
                  ["Fast fire, burning ground and a rain of shells.", "إطلاق سريع وأرض مشتعلة ومطر من القذائف."]),
    "soldier": (["Tough, armoured defenders that never break.", "مدافعون أشداء مدرعون لا ينكسرون."],
                ["Savage fighters that heal by drawing blood.", "مقاتلون شرسون يشفون أنفسهم بسفك الدماء."]),
    "poison": (["Spreading clouds of plague over whole groups.", "سحب طاعون تنتشر فوق مجموعات كاملة."],
               ["Concentrated venom that melts single targets.", "سم مركّز يذيب الأهداف الفردية."]),
    "fire": (["A beam that burns hotter the longer it holds.", "شعاع يزداد حرارة كلما طال تركيزه."],
             ["Burning strikes and flights of fireballs.", "ضربات حارقة وأسراب من كرات النار."]),
    "ice": (["Freezes whole waves in their tracks.", "يجمّد موجات كاملة في مكانها."],
            ["Shatters slowed enemies with lances of ice.", "يحطم الأعداء المبطئين برماح الجليد."]),
    "lightning": (["Longer chains and overloads that stun everything.", "سلاسل أطول وحمل زائد يشلّ الجميع."],
                  ["Fast strikes and storms calling bolts from the sky.", "ضربات سريعة وعواصف تستدعي الصواعق."]),
    "shadow": (["Marks and executes the enemy's champions.", "يَسِم أبطال العدو ثم يعدمهم."],
               ["Curses and terror that send enemies fleeing.", "لعنات ورعب يجعل الأعداء يفرّون."]),
    "light": (["Searing judgment on everything in range.", "حُكم حارق على كل من في المدى."],
              ["Heals your hero and soldiers while it fights.", "يشفي بطلك وجنودك وهو يقاتل."]),
    "earth": (["Stuns and splits the ground under the enemy.", "يشلّ ويشق الأرض تحت العدو."],
              ["Pushes enemies back and drops boulders.", "يدفع الأعداء للخلف ويسقط الصخور."]),
    "wind": (["Hurls whole groups back down the road.", "يقذف مجموعات كاملة إلى الخلف."],
             ["Tears flyers out of the sky.", "يمزق الطائرين من السماء."]),
    "crossbow": (["Huge bolts that skewer lines of enemies.", "مسامير ضخمة تخترق صفوف الأعداء."],
                 ["A relentless hail of bolts.", "وابل لا يتوقف من المسامير."]),
    "trap": (["Deadly blade fields that shred groups.", "حقول شفرات قاتلة تمزق المجموعات."],
             ["Snares and tar that hold enemies in place.", "أفخاخ وقار تثبت الأعداء في مكانهم."]),
}

GLYPH = {"core_dmg": "sword", "core_rate": "speed", "core_range": "mark", "core_cost": "coin", "core_spec": "rune"}


def main():
    out = {"version": 1, "respec": {"gold_per_point": 40, "min_gold": 100},
           "shape": {"layout": LAYOUT, "req": REQ, "exclusive": EXCL, "cost": COST, "level": LEVEL},
           "towers": {}}
    i18n = {}
    for tid, d in T.items():
        nodes = []
        for nid in LAYOUT:
            if nid in CORE:
                names, fx = CORE[nid]
            elif nid == "core_spec":
                names, fx = d["spec"]
            else:
                names, fx = d[nid]
                fx = scale_path(fx)
            node = {"id": nid, "x": LAYOUT[nid][0], "y": LAYOUT[nid][1], "cost": COST[nid],
                    "level": LEVEL[nid], "requires_any": REQ[nid], "effects": fx}
            if nid in EXCL:
                node["exclusive"] = EXCL[nid]
            if nid[0] in "ab":
                node["path"] = nid[0]
            if nid in ("a3", "b3"):
                node["capstone"] = True
            node["glyph"] = GLYPH.get(nid, "")
            nodes.append(node)
            i18n[f"tt.{tid}.{nid}"] = names
        out["towers"][tid] = {"nodes": nodes}
        i18n[f"tt.{tid}.path_a"] = d["a"]
        i18n[f"tt.{tid}.path_b"] = d["b"]
        i18n[f"tt.{tid}.path_a_desc"] = PATH_DESC[tid][0]
        i18n[f"tt.{tid}.path_b_desc"] = PATH_DESC[tid][1]
    json.dump(out, open("data/tower_tree.json", "w"), indent=1, ensure_ascii=False)
    loc = json.load(open("data/i18n.json"))
    loc.update(i18n)
    json.dump(loc, open("data/i18n.json", "w"), indent=1, ensure_ascii=False)
    print("towers:", len(T), "nodes:", sum(len(v["nodes"]) for v in out["towers"].values()), "strings:", len(i18n))


if __name__ == "__main__":
    main()
