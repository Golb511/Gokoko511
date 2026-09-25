# SHADOW CROWN: ETERNAL SIEGE

A dark-fantasy **3D tower-defense RPG** built with **Godot 4.3** (GDScript).
Heroes, branching towers, enemy AI, multi-phase bosses, loot, inventory, shop and
progression. Menus are in Arabic and English, and the controls work with mouse,
keyboard or touch.

> **New in 0.5 — Region 4, the Poison Forest, fully hand-designed**, with
> road shapes, obstacles, enemies and a boss unlike the earlier regions:
> 4-1 *Rotwood Hollow* (two roads that cross in an X, mud bogs that slow
> everyone, toxic pools, giant trees and fallen logs), 4-2 *Spore Cathedral*
> (a ring road around an overgrown cathedral, **spore pods** that burst into
> poison clouds, and a bat route that takes the short way over the ring),
> 4-3 *Blightwater Braids* (two roads that split and swap lanes three times,
> **strangling roots** at the junctions that pin everything in place, acid
> rain) and 4-4 *Heart of the Blight* (the citadel stands in the middle of the
> map, three roads spiral in from three sides, the Blight Heart pulses on the
> horizon). New enemies: **Spore Bearer** (dies in a poison cloud that mends
> nearby enemies), **Plague Bat** (flying swarm), **Venom Spitter** (ranged,
> poisons its target) and **Rotwood Brute** (armoured, regrows its bark when
> left alone). The **Plague Colossus** now vents spore bursts that poison the
> defenders and heal its horde. Also: smarter hero AUTO bot (see Key systems)
> and fixes to taunt and stuns.
>
> **New in 0.4 — Region 3, the Inferno Tower, fully hand-designed:** four
> stages, each with its own map, obstacles, enemies and atmosphere:
> 3-1 *Ashen Causeway* (two roads crossing a flowing lava river on stone
> bridges, lava pools, basalt fields, falling ash), 3-2 *Forge of Chains* (a
> long switchback through a forge, lava channels that split the build space,
> and **fire vents** on the road that erupt and burn anything standing on them),
> 3-3 *Caldera Ascent* (a road that spirals round an erupting **volcano** which
> lobs telegraphed lava bombs onto the road, and a flyer route over the crater),
> 3-4 *Summit of the Inferno Tower* (three roads, three bridges over a lava
> moat, vents at the junctions, the Inferno Tower on the horizon and the
> Inferno Titan boss, whose horde is made of magma imps and flame callers).
> New enemies: **Magma Imp** (fast; bursts into flame when slain, hurting
> nearby defenders), **Obsidian Golem** (heavily armoured tank that splits into
> two imps) and **Flame Caller** (fire mage that scorches towers). The AUTO hero
> steps out of erupting vents and incoming bomb zones. Graphics: animated lava
> shader, iron braziers along the roads, glowing basalt columns, volcano shader.
>
> **New in 0.3 — Region 2, the Shadow Lands, fully hand-designed:** four
> stages, each with its own authored map (roads, flyer air-routes, curated
> tower slots, landmarks), its own waves and its own atmosphere:
> 2-1 *Moonlit Marsh* (blue moonlight, marsh pools, ground mist, fireflies),
> 2-2 *Road of Crypts* (two roads, graveyard rows, purple candle-lit road),
> 2-3 *Raven Spire* (stormy slate sky, lightning, circling ravens, a flyer
> route that cuts across the map) and 2-4 *Throne of Shadows* (three routes,
> a distant gothic castle, soul-fire storm and the Shadow Reaper boss).
> Graphics: torch-lined roads, animated water shader, cinematic vignette and
> worn-metal detail normals on every character. Map-design helper:
> `python3 tools/design/map_tool.py <stage> [--propose N]`.
>
> **New in 0.2:** hand-designed stages 1-2 to 1-4 and 4 new map layouts
> (labyrinth, crossroads, horseshoe, gauntlet), an interactive first-battle
> tutorial, **Endless Siege** through the Gate (unlocks after stage 1-4; a boss
> every 10 waves; best wave is saved), a hero-specific **Abilities** branch in
> the skill tree, towers that rise out of the ground when built, enemies that
> emerge from the portal, and an aura on heroes wearing epic-or-better gear.
>
> Status: **Vertical slice is complete and playable** (main menu → world map →
> stage 1-1 with 5 waves and a boss → victory/defeat, rewards, loot, inventory,
> saving). All 12 heroes, 14 towers, 12 enemy types, 8 bosses and 32 stages
> across 8 regions are wired in as data and can be played. Content past stage 1-1
> uses generated waves and shared layouts, so it still needs hand-tuning.

## نظرة عامة (بالعربية)

**تاج الظل: الحصار الأبدي** لعبة دفاع أبراج ثلاثية الأبعاد بطابع خيالي مظلم مبنية على **Godot 4.3**.

- **ما يعمل الآن (Vertical Slice كامل):** القائمة الرئيسية ← خريطة العالم ثلاثية الأبعاد ← المرحلة 1-1 بخمس موجات وزعيم (أمير الحرب الرمادي) ← شاشة النصر أو الهزيمة ← الذهب والخبرة والغنائم ← الحقيبة ← الحفظ التلقائي.
- **المحتوى:** 12 بطلاً (لكل بطل 4 قدرات وقدرة خارقة وشجرة مهارات و6 خانات معدات)، 14 برجاً لكل منها 3 مستويات ثم مساران للتطوير، 12 نوعاً من الأعداء بذكاء اصطناعي حسب الدور، 8 زعماء متعددي المراحل، و8 مناطق فيها 32 مرحلة.
- **الأنظمة:** غنائم عشوائية بخمس درجات ندرة، تطوير المعدات حتى +15، ترصيع الجواهر، متجر فيه عروض يومية ومحدودة، مهام يومية، إنجازات، مكافآت دخول يومية، نقابة، إعدادات، ودعم العربية والإنجليزية.
- **التشغيل:** افتح `project.godot` في Godot 4.3 واضغط تشغيل. للدخول مباشرة إلى المعركة: `godot --path . -- --battle`.
- **التحكم:** اضغط على رمز البناء المتوهج لبناء برج، واضغط على البرج لتطويره أو بيعه. اختر البطل ثم اضغط على الأرض لتحريكه (أو استخدم زر الفأرة الأيمن). المفاتيح 1-4 وR للقدرات، وZ/X/C/V للقدرات العامة، والمسافة لاستدعاء الموجة التالية. على الجوال يتم كل ذلك باللمس والسحب والقرص.

---

## Running

1. Install **Godot 4.3** (standard build, no .NET needed).
2. Open `project.godot` in the editor, or run it from the command line:

```bash
godot --path .                    # full game (main menu)
godot --path . -- --battle        # jump straight into stage 1-1
godot --path . -- --map           # jump to the world map
```

Developer flags go after `--`:

| Flag | Effect |
|---|---|
| `--battle` / `--stage=r2s3` | start a battle (default `r1s1`; `--stage=endless` for Endless Siege) |
| `--hero=frost_mage` | unlock the hero and use it |
| `--hero-level=20` | set every hero's level |
| `--screen=heroes` | open a menu screen (`heroes`, `inventory`, `shop`, `missions`, `achievements`, `guild`, `settings`) |
| `--autoplay` | a bot plays the battle (builds and upgrades towers, puts the hero on AUTO, uses global powers) and prints `AUTOPLAY_RESULT {...}` |
| `--fresh` | use a new in-memory profile that is never saved |
| `--no-daily` | skip the daily-reward popup |
| `--shot=/path.png --shot-delay=20` | save a screenshot and quit |

Headless balance test (no window):

```bash
godot --headless --path . -- --battle --fresh --autoplay --hero=hell_knight
```

## Controls

| Action | PC | Touch |
|---|---|---|
| Build a tower | click a glowing rune slot | tap a slot |
| Upgrade / choose a branch / sell / set rally point | click the tower | tap the tower |
| Select the hero | click the hero or its portrait, or press `H` | tap the portrait |
| Move the hero | right-click the ground, or select the hero and left-click | select the hero, then tap the ground |
| Hero abilities | `1` `2` `3` `4`, ultimate `R` | ability buttons |
| Global powers | `Z` Meteor, `X` Freeze, `C` Tower Fury, `V` Summon Dragon | buttons |
| Call next wave (early-call bonus) | `Space` | button |
| Camera | drag, WASD/arrow keys, mouse wheel | drag, pinch |
| Pause / speed | `Esc`/`P`, `F` (x2) | buttons |
| AUTO hero (bot) | HUD button | HUD button |

## Architecture

```
project.godot
data/                 All game design as JSON (moddable, no code changes)
  heroes.json         12 heroes: stats, model, attack style, 4 abilities + ultimate, unlock rule
  abilities.json      56 abilities built from 15 ability types
  towers.json         14 towers x 3 levels + 2 branches x 2 levels
  units.json          enemies (AI role, skills), bosses (phases), allied soldiers/summons
  regions.json        shared layouts + per-stage authored maps ("map": paths/air
                      routes, slots, landmarks, water, lava rivers/pools, basalt,
                      vents, volcano, toxic pools, bogs, roots, spore pods,
                      giant trees, theme), hand-made waves for regions 1-4
  items.json          item bases, affixes, gems, runes, materials, drop weights
  meta.json           achievements, daily quests, daily rewards, shop, guild
  config.json         economy, XP curves, rarities, global powers, upgrade costs
  i18n.json           every string as [English, Arabic]
scripts/
  autoload/           Events (signal bus), DB, Loc, Save, Game (profile), Router, Sfx, DevTools
  core/               ModelLib, CharacterModel, ProceduralCreatures, GraphicsSettings
  battle/             BattleController, LevelBuilder, WaveManager, Unit, Enemy (AI), Boss,
                      AllyUnit, Hero, HeroBrain, AbilityExecutor, Tower, Projectile,
                      GlobalAbilities, DragonSweep, Trap, CameraRig, BattleInput, AutoplayBot
  loot/               LootGenerator (random rarity, stats, sockets), ItemLogic
  ui/                 UITheme, Icon (vector icons), TopBar, ScreenBase, BattleHUD,
                      Victory/Defeat screens, every menu screen, HeroStage/HeroPreview, Portraits
  world/              KeyArtScene (main menu diorama), WorldMap3D
scenes/               boot, main_menu, world_map, battle, ui/*.tscn
assets/
  models/             CC0 KayKit rigged characters (76-95 animations), weapons, buildings, graveyard
  shaders/            character (dark PBR remap), environment_prop, ground, road
  fonts/              Cinzel / Cinzel Decorative (Latin), Amiri (Arabic), all OFL
tools/                dev scenes (model gallery, smoke tests)
```

### Key systems

- **Enemy AI** (`enemy.gd`, `boss.gd`): each enemy has a role (attacker, tank,
  ranged, mage, support, summoner, trickster, commander, siege, flyer, elite) and
  re-evaluates its choices every 0.25–0.4 s. It only sees what is inside its own
  sight radius and follows the same rules as the player's units, so it does not
  cheat. Examples: healers pick wounded allies, mages weaken the strongest tower,
  summoners call reinforcements only when they see a threat, tricksters blink
  away from blockers and go stealthy when hurt, commanders give nearby enemies
  haste and armor, siege brutes disable towers, and flyers ignore blockers and
  ground traps.
- **Bosses**: phase changes by HP threshold, with telegraphed ground slams,
  summoned hordes, tower smashing, fire rain and an enrage phase. They drop
  guaranteed rare loot.
- **Hero AUTO bot** (`hero_brain.gd`): intercepts enemies ahead of them on the
  road instead of chasing from behind, stops to fight anything that comes into
  reach, commits to a fight and only breaks off for an unblocked enemy about to
  leak, holds enemies inside the towers' kill zone, waits at the choke point
  where the roads merge, and focuses slippery (blink/stealth) enemies. Energy
  is budgeted: summons and the ultimate come first, self-buffs only when they
  help, and summoner heroes keep energy for their next summon. It retreats to
  a fixed safe spot to recover, heals itself first, and steps out of hazards.
  `tools/hero_telemetry.gd` prints how the bot spent the battle.
- **Towers**: attack styles include projectile, artillery (with target
  prediction), chain lightning, ramping beam, pulse, storm, lance, barracks
  (soldiers with a rally point) and traps. Each tower branches at level 3 into
  two specialisations, which changes its model, color, crown and abilities.
- **Loot**: five rarities (Common → Mythic) with random affixes, quality,
  sockets, gems, runes and materials. Items can be upgraded to +15 with gold and
  materials.
- **Save**: JSON in `user://`, with a checksum, a backup copy, and missing fields
  filled from defaults when the save format grows.
- **Localization**: `data/i18n.json` is loaded into the engine's translation
  system and the language can be switched at runtime. The Arabic font (Amiri)
  is a fallback on the Latin font, so mixed text renders correctly.
- **Platforms**: export presets for Windows, Android and iOS. The desktop uses
  Forward+ and mobile uses the Mobile renderer. Graphics quality presets (Low
  to Ultra) control shadows, SSAO, volumetric fog, particle density, MSAA and
  render scale.

### Visuals

The characters are rigged and animated CC0 KayKit models. A custom
**dark-fantasy PBR shader** re-grades their stylised textures into dark metal
and stone, adding fiery rim light, glowing lava veins on stone creatures, and
hit-flash, freeze, poison and death-dissolve effects. Buildings use a world-space
triplanar stone shader. The battlefield ground and cobbled roads are procedural
shaders. Effects (fire, ice, poison, lightning, shadow, holy, explosions, weather)
use particles with dynamic lights, plus ACES tonemapping, glow, fog, SSAO and
real-time shadows.

### Credits

- 3D models: [KayKit](https://kaylousberg.itch.io/) by Kay Lousberg, CC0 1.0
  (see `assets/models/LICENSE_KayKit_CC0.txt`)
- Fonts: Cinzel, Cinzel Decorative (Natanael Gama), Amiri (Amiri Project), SIL OFL 1.1
- Sound: synthesized procedurally at runtime (`scripts/autoload/sfx.gd`)

## Roadmap

- Hand-authored stages for regions 5-8 (regions 1-4 are hand-designed; the rest still use generated waves)
- Bespoke creature models (dragon, monsters) to replace procedural assemblies
- Store plugins (Google Play Billing / StoreKit) for real gem purchases (currently a test stub)
- Online guild features (the current guild is offline, with AI companions)
- Recorded music and sound effects to replace the synthesized audio
