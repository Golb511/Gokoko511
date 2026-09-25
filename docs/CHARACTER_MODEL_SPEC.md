# Character model spec (professional hero models)

Drop-in spec for replacing a hero's placeholder model with a professional
3D character in Godot 4.3. The game loads it automatically through
`scripts/core/external_character.gd` — no code changes needed.

## Where to put it
`assets/models/heroes/<hero_id>/<hero_id>.glb` — e.g.
`assets/models/heroes/hell_knight/hell_knight.glb`
(the Hell Knight entry in `data/heroes.json` already points there; the
placeholder is used until the file exists).

## File
- **Format:** `.glb` (glTF 2.0 binary) with textures embedded. FBX is also
  fine; we convert it to GLB.
- **One file** containing mesh + skeleton + materials + animations.
- **Scale:** real-world metres, character ~1.8–2.0 m tall, feet at 0,
  facing +Z or -Z (either works; set `yaw`).
- **Polycount:** 15k–40k triangles for the hero (a LOD at ~40–50% is a plus).
- **Bones:** ≤ 100, humanoid (Mixamo / Unreal / Unity Humanoid naming all fine).

## Materials (PBR, metallic/roughness workflow)
- Base Color (Albedo), Normal (OpenGL / Y+ preferred), Metallic, Roughness
  (or packed ORM), Emission (lava cracks, eyes, blade glow).
- 2K textures (4K is downscaled automatically), ≤ 3 materials per character.

## Animations (inside the same file, one clip each)
Required: `Idle`, `Run`, `Attack` (1–3 variants), `Hit`, `Death`.
Recommended: `Walk`, `Attack_Heavy` (ability), `Cast`/`Roar` (abilities /
ultimate), `Victory`.
Names can be anything — we map them in `data/heroes.json` →
`model.external.anims`, and common names (idle/run/attack/slash/hit/death/
cast/roar…) are detected automatically.
All clips must use the same skeleton. Run/Idle must loop; "In Place"
(no root motion) is required for Run/Walk.

## Weapon
Either modelled into the character file (preferred, parented to the right
hand bone) or as a separate GLB we attach to the hand.

## License
Must allow commercial use in a game (CC0, CC-BY, or a purchased
store licence such as Unity Asset Store / Fab / Sketchfab Standard or
Editorial-free licence). Keep the licence file next to the model.

## Configuration example (`data/heroes.json`)
```json
"external": {
  "path": "res://assets/models/heroes/hell_knight/hell_knight.glb",
  "height": 1.95,
  "yaw": 0,
  "anims": {"idle": "Idle", "run": "Run_InPlace", "attack": ["Slash_1", "Slash_2"],
            "special": "Heavy_Slash", "cast": "Roar", "hit": "Hit_React", "death": "Death"}
}
```
Settings → "Classic characters" always switches back to the old models.
