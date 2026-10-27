# Mods

Drop `.hmod` files here. `Play.bat` copies them into `data\horizon-mods\` and
turns on any that are new. Turn a mod off in **Options > Mods**; it stays off.

A mod's own settings are behind the **Settings** button on its row in that
same screen.

## What is here

| File | What it does | Commands |
|---|---|---|
| `qol_hud.hmod` | One panel: coordinates, facing, time and FPS. Move it, resize its spacing | — |
| `qol_homes.hmod` | Homes and teleport-back | `/sethome`, `/home`, `/back` |
| `qol_nightvision.hmod` | Brightens your view locally; key **N** toggles it | — |
| `coords_hud.hmod` | Coordinates, facing and the time of day | `/where`, `/coords` |
| `fps_overlay.hmod` | Frames per second, slowest frame, 1% low | — |
| `keystrokes.hmod` | Movement keys and clicks in a corner | — |
| `minimap.hmod` | A map of the terrain around you | — |
| `zoom.hmod` | Hold a key to zoom; wheel changes it | — |

All eight are built from Horizon's own source: the last five are its official
mods, and `qol_hud`, `qol_homes` and `qol_nightvision` were written for this
pack. Rebuild them from a checkout of this repository with:

```
powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-mods.ps1
```

That writes these eight files, so the pack matches whatever commit you are on.

Each file is named after the id its `horizon-mod.toml` declares.
`Play.bat` matches mods on that id rather than on the file name, so a renamed
copy cannot end up loaded twice: the game keys a mod by its id and refuses a
second file carrying one it already has.

`qol_hud` and `coords_hud` both show coordinates. If you keep both, turn
`coords_hud` off in **Options > Mods**: `qol_hud` does the same and can be
moved and sized.

## Moving and sizing the QoL HUD

**Options > Mods > QoL: HUD > Settings** has:

- **Corner**: which of the four corners the panel hangs from.
- **Nudge X** / **Nudge Y**: push it further from that corner, 12 to 200
  pixels, either direction.
- **Spacing**: the gap between lines. This is how the panel gets bigger or
  smaller — see below.
- **Padding**: the border inside the panel.
- **Coordinates** / **Time** / **FPS**: turn each line on or off.

Every choice is kept, so the panel is where you left it next time.

**A mod cannot change the font size.** Horizon's mod API draws text at the
game's GUI scale and offers no scale field for it, so the only way to make
the text itself larger is **Options > Video Settings > GUI Scale**. Spacing
and padding make the panel roomier around the same text.

## Why night vision is a mod and not `/effect`

Vanilla's night vision is a status effect, and the server owns it: giving it
to yourself needs cheats in a single-player world and an operator on a server.
Both are missing exactly where players want it — a hardcore world has cheats
off by definition, and a server usually belongs to somebody else.

So `qol_nightvision` brightens the client's own lightmap instead
(`render.set-brightness`), the same lighting **Options > Extras > Fullbright**
uses. It asks no server and reads no game state, so it works in hardcore and
on any server, including as a non-operator. Nothing is sent to anyone: other
players see a normal world, and the difficulty is untouched.

## Why no Sodium, Lithium or OptiFine

Horizon is Minecraft rewritten in Rust. It has none of Minecraft's Java
classes, so a Java mod has nothing to patch and cannot run - this is not a
missing feature but the shape of the program. Horizon's mods are Rust
compiled to WebAssembly (`.hmod`), sandboxed, one file for every platform.

`horizon-port-pack` can carry over the *data* inside a Java mod - blocks,
items, recipes, loot tables, textures - but not its code. So a content mod
sometimes works; a performance mod never does.

## Writing your own

The SDK and a worked example are in Horizon's repository:

```
crates/horizon-mod-sdk/           the SDK and its WIT contract
crates/horizon-mod-sdk/examples/  coords-hud, welcome, predator-missile
mods/official/                    the five official mods' sources
mods/qol-homes/                   the source of the extra mods in this pack
mods/qol-hud/
```

Build one with `cargo horizon-mod build`, which writes
`target/horizon-mod/<id>.hmod`. Needs `rustup target add wasm32-unknown-unknown`.

A mod declares what it may do in its `horizon-mod.toml`, and the game refuses
a mod that imports a capability its manifest does not list. Options > Mods
shows that list before you turn a mod on.
