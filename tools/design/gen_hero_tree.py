"""Generates data/hero_tree.json and the Hero Mastery i18n strings.

Every hero gets the Tower Mastery shape (13 nodes) so both screens read the
same way, but the content is authored per hero:
  trunk (5)   role stats + upgrades to two of the hero's own abilities
  path A/B    mutually exclusive specialisations, each with an either/or
              mid-tier choice and a capstone that changes how the hero plays.

Points ("Hero Marks") come from the hero's own level (see HeroTree), and the
level requirements below are hero levels.

Effect keys (handled in scripts/core/hero_tree.gd and scripts/battle/hero.gd):
  stats     damage_pct health_pct defense_pct attack_speed move_speed range_add
            crit crit_dmg lifesteal cdr energy_regen ult_mult dr thorns regen
  attacks   splash multishot pierce chain on_hit{status,chance} on_hit_execute
            bonus_status{id,mult}
  abilities ab: [{slot, dmg, radius, range, cooldown, energy, count, hits,
            duration, execute, heal, lifesteal, status, status_power,
            buff_duration, buff_mult, summon_hp, summon_dmg}]
  aura      {radius, dps, element, status, drain}
  on_kill   [{type: explode|heal|energy|raise|rampage|reset_cd, ...}]
  on_ult    {damage, attack_speed, dr, duration, scale}   (transformation)
  ult_echo  {delay, mult}                                 (ultimate recasts)
  revive    fraction of health (once per battle)
  special   {type: periodic|every_attacks, every, ab: <synthetic ability>}

Run: python3 tools/design/gen_hero_tree.py
"""
import json

LAYOUT = {
    "core_1": (0.5, 0.04), "core_2": (0.36, 0.2), "core_3": (0.64, 0.2),
    "core_4": (0.17, 0.36), "core_5": (0.83, 0.36),
    "a1": (0.3, 0.52), "b1": (0.7, 0.52),
    "a2": (0.15, 0.7), "a2b": (0.4, 0.7), "b2": (0.6, 0.7), "b2b": (0.85, 0.7),
    "a3": (0.27, 0.9), "b3": (0.73, 0.9),
}
REQ = {
    "core_1": [], "core_2": ["core_1"], "core_3": ["core_1"],
    "core_4": ["core_2"], "core_5": ["core_3"],
    "a1": ["core_2", "core_3"], "b1": ["core_2", "core_3"],
    "a2": ["a1"], "a2b": ["a1"], "b2": ["b1"], "b2b": ["b1"],
    "a3": ["a2", "a2b"], "b3": ["b2", "b2b"],
}
EXCL = {"a1": "path", "b1": "path", "a2": "a_mid", "a2b": "a_mid", "b2": "b_mid", "b2b": "b_mid"}
COST = {"core_1": 1, "core_2": 1, "core_3": 1, "core_4": 2, "core_5": 2,
        "a1": 2, "b1": 2, "a2": 3, "a2b": 3, "b2": 3, "b2b": 3, "a3": 5, "b3": 5}
LEVEL = {"core_1": 2, "core_2": 3, "core_3": 3, "core_4": 4, "core_5": 4,
         "a1": 5, "b1": 5, "a2": 8, "a2b": 8, "b2": 8, "b2b": 8, "a3": 12, "b3": 12}


def ab(slot, **kw):
    d = {"slot": slot}
    d.update(kw)
    return d


def burn(p, d=3.0):
    return {"id": "burn", "duration": d, "power": p}


H = {}

H["hell_knight"] = {
    "core": [(["Infernal Might", "قوة جهنمية"], {"damage_pct": 0.08}),
             (["Battle Rhythm", "إيقاع المعركة"], {"attack_speed": 0.06}),
             (["Hellforged Body", "جسد مصهور"], {"health_pct": 0.08}),
             (["Crushing Strike", "الضربة الساحقة"], {"ab": [ab(0, dmg=0.2, radius=0.5)]}),
             (["Blazing Dash", "الاندفاع المتوهج"], {"ab": [ab(1, dmg=0.2, cooldown=0.2)]})],
    "a": ["Infernal Juggernaut", "العملاق الجهنمي"], "b": ["Hellfire Herald", "بشير نار الجحيم"],
    "a_desc": ["Unstoppable melee: armour, cleaving blows and a burning blade.", "قتال مباشر لا يُوقف: دروع وضربات قاطعة ونصل مشتعل."],
    "b_desc": ["Hellfire everywhere: burning auras, fire storms and hellspawn.", "نار الجحيم في كل مكان: هالات حارقة وعواصف نار ومخلوقات الجحيم."],
    "a1": (["Hellforged Plate", "الدرع المصهور"], {"defense_pct": 0.15, "health_pct": 0.1}),
    "a2": (["Searing Blade", "النصل الحارق"], {"on_hit": {"status": burn(0.15)}}),
    "a2b": (["Brutal Cleave", "الشق الوحشي"], {"splash": 0.8, "damage_pct": 0.08}),
    "a3": (["Avatar of Wrath", "تجسيد الغضب"], {"thorns": 0.2, "on_ult": {"damage": 0.35, "attack_speed": 0.3, "dr": 0.3, "duration": 8, "scale": 1.3}}),
    "b1": (["Kindled Soul", "الروح المتقدة"], {"ab": [ab(4, dmg=0.2, radius=1.0)]}),
    "b2": (["Aura of Cinders", "هالة الرماد"], {"aura": {"radius": 2.8, "dps": 0.25, "element": "fire", "status": burn(0.1, 2.0)}}),
    "b2b": (["Hellspawn Pact", "ميثاق الجحيم"], {"ab": [ab(3, count=1, summon_hp=0.3, summon_dmg=0.3)]}),
    "b3": (["Hellstorm", "عاصفة الجحيم"], {"special": {"type": "periodic", "every": 6.0, "ab": {"type": "nova", "element": "fire", "radius": 4.0, "dmg": 1.2, "status": burn(0.25)}}}),
}
H["poison_sorcerer"] = {
    "core": [(["Toxic Mastery", "إتقان السموم"], {"damage_pct": 0.08}),
             (["Swift Incantation", "التعويذة السريعة"], {"cdr": 0.05}),
             (["Hardy Alchemist", "الخيميائي الصلب"], {"health_pct": 0.08}),
             (["Potent Flask", "القارورة الفتاكة"], {"ab": [ab(0, dmg=0.2, radius=0.4)]}),
             (["Thick Cloud", "السحابة الكثيفة"], {"ab": [ab(1, duration=2.0, radius=0.5)]})],
    "a": ["Plaguebringer", "جالب الطاعون"], "b": ["Corrosive Alchemist", "الخيميائي الأكّال"],
    "a_desc": ["Lingering poison that spreads from enemy to enemy.", "سم دائم ينتشر من عدو إلى آخر."],
    "b_desc": ["Toxic explosions that dissolve armour.", "انفجارات سامة تذيب الدروع."],
    "a1": (["Virulence", "الضراوة"], {"on_hit": {"status": {"id": "poison", "duration": 4.0, "power": 0.35}}}),
    "a2": (["Contagion", "العدوى"], {"on_kill": [{"type": "explode", "radius": 3.0, "dmg": 0.5, "element": "poison", "status": {"id": "poison", "duration": 4.0, "power": 0.3}}]}),
    "a2b": (["Lingering Miasma", "الوباء الدائم"], {"ab": [ab(4, duration=3.0, radius=1.0)]}),
    "a3": (["Pandemic", "الجائحة"], {"aura": {"radius": 4.5, "dps": 0.15, "element": "poison", "status": {"id": "poison", "duration": 3.0, "power": 0.2}},
                                    "on_kill": [{"type": "explode", "radius": 4.0, "dmg": 0.8, "element": "poison", "status": {"id": "poison", "duration": 5.0, "power": 0.4}}]}),
    "b1": (["Volatile Flask", "القارورة المتفجرة"], {"ab": [ab(0, dmg=0.3, radius=0.6)]}),
    "b2": (["Acid Burn", "حرق الحمض"], {"on_hit": {"status": {"id": "armor_break", "duration": 4.0, "power": 0.25}}}),
    "b2b": (["Venom Surge", "فوران السم"], {"ab": [ab(2, radius=1.0, dmg=0.3, cooldown=0.2)]}),
    "b3": (["Chain Reaction", "التفاعل المتسلسل"], {"special": {"type": "every_attacks", "every": 3, "ab": {"type": "blast", "element": "poison", "radius": 2.5, "dmg": 1.0, "status": {"id": "armor_break", "duration": 4.0, "power": 0.3}}}}),
}
H["raven_archer"] = {
    "core": [(["Sharpened Arrows", "السهام المسنونة"], {"damage_pct": 0.08}),
             (["Eagle Sight", "بصر النسر"], {"range_add": 1.0}),
             (["Light Armour", "الدرع الخفيف"], {"health_pct": 0.08}),
             (["Denser Volley", "الوابل الكثيف"], {"ab": [ab(0, count=3)]}),
             (["Deeper Pierce", "الاختراق العميق"], {"ab": [ab(2, dmg=0.25)]})],
    "a": ["Deadeye Sniper", "القناص الفتاك"], "b": ["Shadow Murder", "سرب غربان الظل"],
    "a_desc": ["Extreme range, critical hits and killing shots.", "مدى هائل وضربات حرجة وطلقات قاتلة."],
    "b_desc": ["Many arrows at once and flocks of shadow ravens.", "سهام متعددة وأسراب من غربان الظل."],
    "a1": (["Hawk's Reach", "مدى الصقر"], {"range_add": 2.0, "crit": 0.06}),
    "a2": (["Lethal Aim", "التصويب القاتل"], {"crit_dmg": 0.5}),
    "a2b": (["Heartpiercer", "مخترق القلوب"], {"pierce": 2, "damage_pct": 0.08}),
    "a3": (["Kill Shot", "الطلقة القاتلة"], {"special": {"type": "every_attacks", "every": 5, "ab": {"type": "line", "element": "physical", "range": 18, "radius": 1.2, "dmg": 4.0, "execute": 0.15}}}),
    "b1": (["Twin Fletching", "الريش المزدوج"], {"multishot": 1}),
    "b2": (["Raven Kin", "أقارب الغربان"], {"ab": [ab(3, count=2, duration=4.0)]}),
    "b2b": (["Swift Wings", "الأجنحة السريعة"], {"attack_speed": 0.12}),
    "b3": (["Unkindness of Ravens", "سرب الغربان الأسود"], {"ab": [ab(4, count=10)], "special": {"type": "periodic", "every": 7.0, "ab": {"type": "summon", "element": "shadow", "target": "self", "count": 2, "unit": "raven", "duration": 8}}}),
}
H["bone_king"] = {
    "core": [(["Bone Fortress", "حصن العظام"], {"health_pct": 0.1}),
             (["Calcified Hide", "الجلد المتكلس"], {"defense_pct": 0.1}),
             (["Grave Strength", "قوة القبر"], {"damage_pct": 0.06}),
             (["Skull Crusher", "ساحق الجماجم"], {"ab": [ab(0, radius=0.4, cooldown=0.15)]}),
             (["Grave Summons", "استدعاء القبور"], {"ab": [ab(3, count=1)]})],
    "a": ["Lord of the Legion", "سيد الفيلق"], "b": ["Death Sorcerer", "ساحر الموت"],
    "a_desc": ["Command an ever-growing army of the dead.", "قُد جيشًا من الموتى يكبر بلا توقف."],
    "b_desc": ["Drain life, wither and weaken the living.", "امتصاص الحياة وإذبال الأحياء وإضعافهم."],
    "a1": (["Grave Call", "نداء القبر"], {"ab": [ab(3, summon_hp=0.25, summon_dmg=0.25), ab(4, summon_hp=0.25, summon_dmg=0.25)]}),
    "a2": (["Endless Ranks", "الصفوف التي لا تنتهي"], {"ab": [ab(3, cooldown=0.25, duration=6.0)]}),
    "a2b": (["Bone Giants", "عمالقة العظام"], {"ab": [ab(3, summon_hp=0.5), ab(4, summon_hp=0.4)]}),
    "a3": (["Undying Legion", "الفيلق الخالد"], {"ab": [ab(4, count=4)], "on_kill": [{"type": "raise", "chance": 0.35, "unit": "risen_skeleton", "duration": 12, "max": 6}]}),
    "b1": (["Soul Siphon", "سحب الأرواح"], {"lifesteal": 0.1}),
    "b2": (["Withering Touch", "لمسة الذبول"], {"on_hit": {"status": {"id": "weaken", "duration": 3.0, "power": 0.2}}}),
    "b2b": (["Grave Chill", "برد القبر"], {"on_hit": {"status": {"id": "slow", "duration": 2.0, "power": 0.25}}}),
    "b3": (["Death's Embrace", "عناق الموت"], {"revive": 0.5, "aura": {"radius": 4.0, "dps": 0.3, "element": "shadow", "drain": 0.5, "status": {"id": "weaken", "duration": 2.0, "power": 0.15}}}),
}
H["frost_mage"] = {
    "core": [(["Winter's Edge", "حد الشتاء"], {"damage_pct": 0.08}),
             (["Cold Focus", "التركيز البارد"], {"cdr": 0.05}),
             (["Frozen Heart", "القلب المتجمد"], {"health_pct": 0.08}),
             (["Frost Surge", "موجة الصقيع"], {"ab": [ab(0, dmg=0.2)]}),
             (["Long Winter", "الشتاء الطويل"], {"ab": [ab(1, duration=2.0)]})],
    "a": ["Glacial Archon", "حاكم الجليد"], "b": ["Frostfire Sorcerer", "ساحر النار الجليدية"],
    "a_desc": ["Freezes the battlefield and shatters the frozen.", "يجمّد ساحة المعركة ويحطم المتجمدين."],
    "b_desc": ["Ice shards, brittle armour and falling comets.", "شظايا جليد ودروع هشة ومذنبات ساقطة."],
    "a1": (["Deep Freeze", "التجميد العميق"], {"ab": [ab(2, radius=0.8, status={"id": "freeze", "duration": 4.0, "power": 1})]}),
    "a2": (["Shatter", "التحطيم"], {"bonus_status": {"id": "slow", "mult": 1.3}}),
    "a2b": (["Frozen Ground", "الأرض المتجمدة"], {"ab": [ab(1, radius=1.0, status={"id": "slow", "duration": 1.0, "power": 0.7})]}),
    "a3": (["Eternal Winter", "الشتاء الأبدي"], {"ab": [ab(4, radius=2.0)], "special": {"type": "periodic", "every": 8.0, "ab": {"type": "nova", "element": "ice", "radius": 5.0, "dmg": 0.6, "status": {"id": "freeze", "duration": 1.5, "power": 1}}}}),
    "b1": (["Ice Shards", "شظايا الجليد"], {"multishot": 1}),
    "b2": (["Frostbite", "عضة الصقيع"], {"crit": 0.08, "crit_dmg": 0.3}),
    "b2b": (["Brittle Bones", "العظام الهشة"], {"on_hit": {"status": {"id": "armor_break", "duration": 3.0, "power": 0.2}}}),
    "b3": (["Comet Storm", "عاصفة المذنبات"], {"special": {"type": "every_attacks", "every": 4, "ab": {"type": "blast", "element": "ice", "radius": 2.5, "dmg": 1.5, "status": {"id": "freeze", "duration": 0.6, "power": 1}, "ultimate": True}}}),
}
H["blueflame_warlock"] = {
    "core": [(["Azure Power", "القوة اللازوردية"], {"damage_pct": 0.08}),
             (["Quick Sigils", "الأختام السريعة"], {"cdr": 0.05}),
             (["Warded Robes", "الأردية المحصنة"], {"health_pct": 0.08}),
             (["Focused Blast", "الانفجار المركز"], {"ab": [ab(0, dmg=0.2)]}),
             (["Lasting Surge", "الفوران الدائم"], {"ab": [ab(3, buff_duration=3.0)]})],
    "a": ["Azure Pyromancer", "ساحر اللهب اللازوردي"], "b": ["Arcane Channeler", "قناة السحر"],
    "a_desc": ["Blue fire that burns, spreads and rises again.", "نار زرقاء تحرق وتنتشر وتنهض من جديد."],
    "b_desc": ["Endless mana and spells that echo twice.", "طاقة سحرية لا تنضب وتعاويذ تتردد مرتين."],
    "a1": (["Blue Flames", "اللهب الأزرق"], {"on_hit": {"status": burn(0.2)}}),
    "a2": (["Inferno Pools", "برك الجحيم"], {"ab": [ab(1, radius=1.0, duration=2.0)]}),
    "a2b": (["Wave of Ruin", "موجة الخراب"], {"ab": [ab(2, dmg=0.4, radius=0.6)]}),
    "a3": (["Phoenix Flame", "لهب العنقاء"], {"on_kill": [{"type": "explode", "radius": 3.0, "dmg": 0.8, "element": "fire", "status": burn(0.25)}],
                                             "special": {"type": "periodic", "every": 7.0, "ab": {"type": "nova", "element": "fire", "radius": 4.0, "dmg": 1.0, "status": burn(0.2)}}}),
    "b1": (["Mana Font", "ينبوع الطاقة"], {"energy_regen": 0.8}),
    "b2": (["Overload", "الحمل الزائد"], {"ab": [ab(0, cooldown=0.3)]}),
    "b2b": (["Glass Cannon", "المدفع الزجاجي"], {"crit": 0.1, "crit_dmg": 0.25}),
    "b3": (["Arcane Echo", "صدى السحر"], {"ult_echo": {"delay": 1.5, "mult": 0.6}, "ab": [ab(4, energy=-20)]}),
}
H["giant_executioner"] = {
    "core": [(["Heavy Blade", "النصل الثقيل"], {"damage_pct": 0.08}),
             (["Momentum", "الزخم"], {"attack_speed": 0.06}),
             (["Giant's Frame", "هيكل العملاق"], {"health_pct": 0.08}),
             (["Deeper Chop", "القطع الأعمق"], {"ab": [ab(1, dmg=0.2, execute=0.05)]}),
             (["Relentless Charge", "الاندفاع العنيد"], {"ab": [ab(2, cooldown=0.2)]})],
    "a": ["Headsman", "قاطع الرؤوس"], "b": ["Bloodbath", "حمام الدم"],
    "a_desc": ["Critical strikes and executions that chain into each other.", "ضربات حرجة وإعدامات يتبع بعضها بعضًا."],
    "b_desc": ["Drinks blood, shrugs off wounds and rampages.", "يشرب الدماء ويتجاهل الجراح ويهيج."],
    "a1": (["Keen Edge", "الحد القاطع"], {"crit": 0.08}),
    "a2": (["Merciless", "بلا رحمة"], {"on_hit_execute": 0.1}),
    "a2b": (["Heavy Swing", "الأرجحة الثقيلة"], {"splash": 0.8, "damage_pct": 0.08}),
    "a3": (["Reaper's Toll", "ضريبة الحاصد"], {"ab": [ab(4, execute=0.1)], "on_kill": [{"type": "reset_cd", "slot": 1}, {"type": "energy", "amount": 8}]}),
    "b1": (["Thirst", "العطش"], {"lifesteal": 0.08}),
    "b2": (["Frenzied", "المسعور"], {"ab": [ab(3, buff_duration=3.0, lifesteal=0.1)]}),
    "b2b": (["Unyielding", "الصامد"], {"dr": 0.12}),
    "b3": (["Rampage", "الهياج"], {"on_kill": [{"type": "rampage", "attack_speed": 0.08, "damage": 0.05, "duration": 6.0, "max": 5}]}),
}
H["dragon_lord"] = {
    "core": [(["Draconic Blood", "الدم التنيني"], {"damage_pct": 0.06, "health_pct": 0.06}),
             (["Wyrm Vigor", "حيوية الأفعى"], {"health_pct": 0.08}),
             (["Scaled Hide", "الجلد المحرشف"], {"defense_pct": 0.08}),
             (["Scorching Breath", "النَّفَس الحارق"], {"ab": [ab(0, dmg=0.25, radius=0.4)]}),
             (["Larger Brood", "حضنة أكبر"], {"ab": [ab(2, count=1)]})],
    "a": ["Wyrm Rider", "فارس التنين"], "b": ["Brood Master", "سيد الحضنة"],
    "a_desc": ["Fights at the front and takes on dragon form.", "يقاتل في المقدمة ويتحول إلى هيئة التنين."],
    "b_desc": ["Leads an endless brood of dragon whelps.", "يقود حضنة لا تنتهي من صغار التنانين."],
    "a1": (["Dragon Scales", "حراشف التنين"], {"defense_pct": 0.15}),
    "a2": (["Wing Buffet", "ضربة الجناح"], {"ab": [ab(1, dmg=0.3, status={"id": "stun", "duration": 1.0, "power": 1})]}),
    "a2b": (["Molten Blood", "الدم المنصهر"], {"thorns": 0.2}),
    "a3": (["Dragonform", "هيئة التنين"], {"on_ult": {"damage": 0.3, "attack_speed": 0.2, "dr": 0.35, "duration": 10, "scale": 1.35}, "splash": 0.8}),
    "b1": (["Whelp Bond", "رابطة الصغار"], {"ab": [ab(2, summon_hp=0.3, summon_dmg=0.3)]}),
    "b2": (["Brood Call", "نداء الحضنة"], {"ab": [ab(2, cooldown=0.25, duration=6.0)]}),
    "b2b": (["Wyrm's Fury", "غضب التنين"], {"ab": [ab(4, dmg=0.4)]}),
    "b3": (["Dragon Brood", "حضنة التنين"], {"special": {"type": "periodic", "every": 10.0, "ab": {"type": "summon", "element": "fire", "target": "self", "count": 1, "unit": "dragon_whelp", "duration": 12}}}),
}
H["stone_beast"] = {
    "core": [(["Mountain Body", "جسد الجبل"], {"health_pct": 0.1}),
             (["Bedrock", "الصخر الأساسي"], {"defense_pct": 0.1}),
             (["Heavy Fists", "القبضات الثقيلة"], {"damage_pct": 0.06}),
             (["Wider Quake", "الزلزال الأوسع"], {"ab": [ab(0, radius=0.5)]}),
             (["Hurled Stone", "الحجر المقذوف"], {"ab": [ab(1, dmg=0.25)]})],
    "a": ["Living Fortress", "الحصن الحي"], "b": ["Earthshaker", "هازّ الأرض"],
    "a_desc": ["An unbreakable wall that returns every blow.", "جدار لا ينكسر يرد كل ضربة."],
    "b_desc": ["Stuns, boulders and quakes with every step.", "شلّ وصخور وزلازل مع كل خطوة."],
    "a1": (["Granite Hide", "جلد الجرانيت"], {"dr": 0.1}),
    "a2": (["Rebound", "الارتداد"], {"thorns": 0.25}),
    "a2b": (["Taunting Roar", "الزئير المستفز"], {"ab": [ab(3, radius=2.0, cooldown=0.2)]}),
    "a3": (["Unbreakable", "الذي لا ينكسر"], {"revive": 0.6, "dr": 0.1, "ab": [ab(2, buff_duration=4.0)]}),
    "b1": (["Crushing Blows", "الضربات الساحقة"], {"damage_pct": 0.12, "splash": 0.6}),
    "b2": (["Aftershock", "الهزة الارتدادية"], {"on_hit": {"status": {"id": "stun", "duration": 0.8, "power": 1}, "chance": 0.12}}),
    "b2b": (["Boulder Barrage", "وابل الصخور"], {"ab": [ab(1, cooldown=0.3, radius=0.6)]}),
    "b3": (["Seismic Fury", "الغضب الزلزالي"], {"special": {"type": "every_attacks", "every": 4, "ab": {"type": "nova", "element": "earth", "radius": 3.5, "dmg": 1.0, "status": {"id": "stun", "duration": 0.8, "power": 1}}}}),
}
H["shadow_knight"] = {
    "core": [(["Shadow Edge", "حد الظل"], {"damage_pct": 0.08}),
             (["Fleet Shadow", "الظل الخاطف"], {"move_speed": 0.06, "crit": 0.04}),
             (["Night Cloak", "عباءة الليل"], {"health_pct": 0.08}),
             (["Extra Strike", "الضربة الإضافية"], {"ab": [ab(0, hits=1)]}),
             (["Wider Blades", "الشفرات الأوسع"], {"ab": [ab(2, radius=0.5, dmg=0.2)]})],
    "a": ["Phantom Blade", "النصل الشبح"], "b": ["Umbral Puppeteer", "محرّك الظلال"],
    "a_desc": ["Teleporting strikes and deadly critical hits.", "ضربات انتقالية وضربات حرجة قاتلة."],
    "b_desc": ["Commands shadow clones that fight at his side.", "يقود نسخًا ظلية تقاتل إلى جانبه."],
    "a1": (["Assassin's Mark", "علامة القاتل"], {"crit": 0.08, "crit_dmg": 0.3}),
    "a2": (["Blade Dance", "رقصة الشفرات"], {"ab": [ab(0, hits=2, cooldown=0.15)]}),
    "a2b": (["Dash Strike", "ضربة الاندفاع"], {"ab": [ab(1, cooldown=0.3, dmg=0.5)]}),
    "a3": (["Thousand Cuts", "الألف جرح"], {"special": {"type": "every_attacks", "every": 4, "ab": {"type": "blink_strike", "element": "shadow", "range": 8, "dmg": 1.2, "hits": 3}}}),
    "b1": (["Twin Shadows", "الظلان التوأم"], {"ab": [ab(3, count=1)]}),
    "b2": (["Dark Pact", "الميثاق المظلم"], {"ab": [ab(3, summon_hp=0.4, summon_dmg=0.4)]}),
    "b2b": (["Weakening Blades", "الشفرات المُضعفة"], {"on_hit": {"status": {"id": "weaken", "duration": 3.0, "power": 0.15}}}),
    "b3": (["Legion of Shadows", "فيلق الظلال"], {"ab": [ab(4, hits=3)], "special": {"type": "periodic", "every": 9.0, "ab": {"type": "summon", "element": "shadow", "target": "self", "count": 1, "unit": "shadow_clone", "duration": 10}}}),
}
H["night_sniper"] = {
    "core": [(["Tungsten Bolts", "مسامير التنغستن"], {"damage_pct": 0.08}),
             (["Scope", "المنظار"], {"range_add": 1.0}),
             (["Padded Coat", "المعطف المبطن"], {"health_pct": 0.08}),
             (["Piercing Power", "قوة الاختراق"], {"ab": [ab(0, dmg=0.25)]}),
             (["Deep Mark", "العلامة العميقة"], {"ab": [ab(3, status_power=0.2)]})],
    "a": ["Ghost Marksman", "الرامي الشبح"], "b": ["Demolitionist", "خبير التفجير"],
    "a_desc": ["One perfect shot at a time.", "طلقة مثالية في كل مرة."],
    "b_desc": ["Explosive and incendiary bolts that clear crowds.", "مسامير متفجرة وحارقة تنظف الحشود."],
    "a1": (["Steady Hands", "اليد الثابتة"], {"crit": 0.08}),
    "a2": (["Hollow Point", "الرأس المجوف"], {"crit_dmg": 0.5}),
    "a2b": (["Long Barrel", "الماسورة الطويلة"], {"range_add": 2.5, "damage_pct": 0.06}),
    "a3": (["One Shot", "طلقة واحدة"], {"ab": [ab(4, hits=2)], "special": {"type": "every_attacks", "every": 4, "ab": {"type": "execute", "element": "physical", "range": 16, "dmg": 3.0, "status": {"id": "armor_break", "duration": 5.0, "power": 0.4}}}}),
    "b1": (["Blast Powder", "بارود التفجير"], {"ab": [ab(2, radius=0.8, dmg=0.3)]}),
    "b2": (["Incendiary Bolts", "المسامير الحارقة"], {"on_hit": {"status": burn(0.15)}}),
    "b2b": (["Smoke Screen", "ستار الدخان"], {"ab": [ab(1, radius=1.0, cooldown=0.25)]}),
    "b3": (["Carpet Bombing", "القصف الشامل"], {"special": {"type": "every_attacks", "every": 3, "ab": {"type": "blast", "element": "fire", "radius": 2.2, "dmg": 0.9}}}),
}
H["storm_warden"] = {
    "core": [(["Storm Blood", "دم العاصفة"], {"damage_pct": 0.06, "health_pct": 0.06}),
             (["Charged Mind", "العقل المشحون"], {"energy_regen": 0.4}),
             (["Thunder Hide", "جلد الرعد"], {"health_pct": 0.08}),
             (["Forked Lightning", "البرق المتشعب"], {"ab": [ab(0, count=2)]}),
             (["Wide Overcharge", "الشحن الواسع"], {"ab": [ab(3, radius=2.0, buff_duration=3.0)]})],
    "a": ["Thunder Lord", "سيد الرعد"], "b": ["Storm Shepherd", "راعي العاصفة"],
    "a_desc": ["Becomes a living storm of chain lightning.", "يصبح عاصفة حية من البرق المتسلسل."],
    "b_desc": ["Empowers towers and shelters allies.", "يقوي الأبراج ويحمي الحلفاء."],
    "a1": (["Conduction", "التوصيل"], {"chain": 1}),
    "a2": (["Static Charge", "الشحنة الساكنة"], {"on_hit": {"status": {"id": "stun", "duration": 0.6, "power": 1}, "chance": 0.1}}),
    "a2b": (["Arc Surge", "فوران القوس"], {"ab": [ab(0, dmg=0.35)]}),
    "a3": (["Living Storm", "العاصفة الحية"], {"aura": {"radius": 4.5, "dps": 0.3, "element": "lightning"},
                                            "special": {"type": "periodic", "every": 3.0, "ab": {"type": "chain", "element": "lightning", "range": 8, "dmg": 0.8, "count": 3}}}),
    "b1": (["Battery", "البطارية"], {"ab": [ab(3, buff_mult=0.2)]}),
    "b2": (["Guardian Winds", "رياح الحماية"], {"ab": [ab(2, buff_duration=3.0)], "regen": 0.005}),
    "b2b": (["Charged Towers", "الأبراج المشحونة"], {"ab": [ab(3, cooldown=0.3)]}),
    "b3": (["Eye of the Storm", "عين العاصفة"], {"special": {"type": "periodic", "every": 8.0, "ab": {"type": "tower_buff", "element": "lightning", "radius": 9, "buff": {"stat": "tower_rate", "mult": 1.3, "duration": 4}, "ally_heal": 0.08}}}),
}


def main():
    out = {"version": 1, "respec": {"gold_per_point": 60, "min_gold": 150},
           "points": {"per_level": 1, "bonus_every": 5},
           "heroes": {}}
    loc = {}
    for hid, d in H.items():
        nodes = []
        for i, nid in enumerate(LAYOUT):
            if nid.startswith("core_"):
                names, fx = d["core"][int(nid[-1]) - 1]
            else:
                names, fx = d[nid]
            node = {"id": nid, "x": LAYOUT[nid][0], "y": LAYOUT[nid][1], "cost": COST[nid],
                    "level": LEVEL[nid], "requires_any": REQ[nid], "effects": fx}
            if nid in EXCL:
                node["exclusive"] = EXCL[nid]
            if nid[0] in "ab":
                node["path"] = nid[0]
            if nid in ("a3", "b3"):
                node["capstone"] = True
            nodes.append(node)
            loc[f"ht.{hid}.{nid}"] = names
        out["heroes"][hid] = {"nodes": nodes}
        loc[f"ht.{hid}.path_a"] = d["a"]
        loc[f"ht.{hid}.path_b"] = d["b"]
        loc[f"ht.{hid}.path_a_desc"] = d["a_desc"]
        loc[f"ht.{hid}.path_b_desc"] = d["b_desc"]
    json.dump(out, open("data/hero_tree.json", "w"), indent=1, ensure_ascii=False)
    i18n = json.load(open("data/i18n.json"))
    i18n.update(loc)
    json.dump(i18n, open("data/i18n.json", "w"), indent=1, ensure_ascii=False)
    print("heroes:", len(H), "nodes:", sum(len(v["nodes"]) for v in out["heroes"].values()), "strings:", len(loc))


if __name__ == "__main__":
    main()
