# Horizon Portable

[![Vanilla parity](https://img.shields.io/badge/vanilla%20parity-100%25-F0795A)](#java-parity-100)
[![Minecraft](https://img.shields.io/badge/Minecraft-Java%2026.3-5D9C3F)](#get-it)
[![License](https://img.shields.io/badge/license-MIT-3B2F7E)](LICENSE)

A ready-to-play, portable build of **Horizon** — Minecraft: Java Edition 26.3,
rewritten from scratch in Rust — with a small modpack, all in one folder.

This repository is **not a fork** of [ludovic111/horizon][upstream]. It carries
the full Horizon source (MIT licensed, by ludovic111 and its contributors)
together with the portable packaging, three QoL mods written for this pack, and
a release workflow, so that the portable build and the code it is built from
live in one place. Upstream updates are merged in here.

[upstream]: https://github.com/ludovic111/horizon

## Get it

Download `horizon-portable-windows-x64.zip` from [Releases](../../releases),
unzip it anywhere, then run **`Setup.bat`** once and **`Play.bat`** after that.
`Host-Server.bat` hosts a world.

The zip is the whole game: the programs, the mods, and the scripts. Your worlds,
settings and logs go in the same folder, so you can copy it to a USB drive and
carry on elsewhere.

[**Read the package README**](packaging/portable/README.md) — what each mod does,
what the folders hold, how to build it, how to follow upstream updates.

## What is in here

```
packaging/portable/     the package itself: batch files, scripts, programs, mods
packaging/build-mods.ps1  builds the eight .hmod files into the package
mods/qol-hud/           QoL: HUD — a movable, resizable info panel
mods/qol-homes/         QoL: Homes — /sethome, /home, /back
mods/qol-nightvision/   QoL: Night Vision — brighten your view, local, on a key
crates/                 Horizon's crates, including the mod SDK and runtime
mods/official/          Horizon's official mods (coords, FPS, keystrokes, minimap, zoom)
.github/workflows/      CI, and the portable release build
```

`packaging/portable/` **is** the package, laid out exactly as a player receives
it. Zipping its contents produces the release artifact.

## Build

```powershell
cargo build --release --locked --features horizon-client/mods `
  -p horizon-client --bin horizon-client --bin horizon-ctl `
  -p horizon-prepare --bin horizon-prepare `
  -p horizon-server --bin horizon-server

copy target\release\horizon-client.exe  packaging\portable\game\
copy target\release\horizon-ctl.exe     packaging\portable\game\
copy target\release\horizon-prepare.exe packaging\portable\game\
copy target\release\horizon-server.exe  packaging\portable\game\

powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-mods.ps1
```

Full instructions, including the mod toolchain and the release steps, are in
[`packaging/portable/README.md`](packaging/portable/README.md).

## Project status

The table below is Horizon's own audit of each subsystem, carried here because
this repository ships the code it describes. Every subsystem now matches
vanilla in every harness that compares it. 100% means 100% of what the harnesses
compare, not proof that nothing else differs. The remaining known differences
are listed below.

### Java parity: 100%

Each subsystem scores 0 (absent), 0.25 (started, not playable), 0.5 (playable,
major vanilla features missing), 0.75 (playable, mostly complete) or 1 (complete
and verified against vanilla by differential tests). The percentage is the
average; `tests/test_parity.py` keeps it in sync with this table. Last audited
2026-10-13 against the harness results: all 281 harnesses pass on Linux, each
rerun whenever one of its inputs changed, and the Mac mini now runs every one of
them too (Rust uses Java's own float maths on each platform).

| Subsystem | Score | Main gaps |
| --- | ---: | --- |
| Window, input and game loop | 1 | None: the game loop, options, camera, auto-jump, toggle sprint/sneak, local input and the frame limiter match vanilla |
| Assets and resources | 1 | None: item models match vanilla over 196,290 stacks and the client draws every item through them; the resource pack screen matches vanilla's drawing over 3,000 sessions of clicks, scrolling and searching, its incompatibility confirmation included |
| Network protocol and multiplayer | 1 | None: joins vanilla servers; the dedicated server (`--dedicated`) matches vanilla's files, status ping, login, configuration, play, chunks, chat, recipes, advancements and command tree, a client built from vanilla's packet code joins it, Horizon joins a vanilla server, and LAN discovery matches over 462 cases (offline mode only) |
| Chunk storage and palettes | 1 | None: client and saves share paletted containers, identical to vanilla over 266 scenarios |
| Section meshing | 1 | None: 112 scenes and over a million quads identical to vanilla |
| Rendering | 1 | None: entity models, block entity renderers (407 cases, End portals, gateways and the loom's banner preview included) and their animations (296 cases, End gateway beams included), the HUD overlays (2,200 states), the recipe book (600 states), the player list, subtitles and the world border match vanilla |
| Lighting | 1 | None: saved and relit light matches vanilla, slabs and stairs included |
| World generation | 1 | None: 2,352 whole chunks over 225 structure sites, in all three dimensions, identical to vanilla |
| Region files and saves | 1 | None: saves round-trip with vanilla, and worlds from 1.8 to 26.2 upgrade as vanilla's DataFixers do, superflat worlds included; old options.txt and hotbar.nbt files are upgraded too |
| Entities and physics | 1 | None: attributes, dimensions, death loot, spawn rules, natural spawning (15,500 cases), raids and patrols (1,900 cases), spawned mobs' gear, enchantments and state (`finalizeSpawn`, 24,000 cases) and mob AI (92 scenarios: villager breeding and gossip, the warden, ghastlings and copper golems included) match vanilla |
| Interaction and inventory | 1 | None: menu clicks match over 8,000 click sequences, the loom and the crafter included; recipe book placement (6,000 cases), its buttons (1,200), the saved book (1,500) and the loom and crafter screens (1,600) match vanilla |
| Menus, HUD and chat | 1 | None: every command runs as vanilla (758 commands over 39,685 parsed inputs), scoreboards and teams match (81,000 operations), the player list matches over 872,000 draw calls with heads drawn from players' skins (authlib's textures, SkinManager's lookup, legacy skin conversion), and the chat matches focused and scrolled; the resource pack screen (selection over 4,000 cases, drawing and its incompatibility confirmation over 3,000 sessions) and the chat input with its command suggestions, usage lines, Tab completion and history (3,000 sessions on vanilla's client command tree) match vanilla |
| Audio | 1 | None: the sound engine, sound events, music, situational music, ambience and subtitles match vanilla |
| Block behaviours and ticking | 1 | None: block updates, random ticks, redstone, dispensers (6,000 cases), crafters (4,000 crafts), block entity removal (containers spill, 4,000 cases), copper golem chest sorting and the sculk family (435 scenarios: shrieker warnings and warden summoning included) match vanilla |

### Known issues

Horizon can't sign in to a Microsoft account yet, so it can't join online-mode
servers (it joins offline-mode ones); skins served over https show the default
skin unless already cached; pack icons show the unknown-pack texture in game;
the creative hotbar keys (C/X) aren't wired to the hotbar loader; item tooltips
lack attribute lines.

## Notes

- Not an official Minecraft product. Not approved by or associated with Mojang
  or Microsoft.
- No Minecraft code, textures or sounds are in this repository or in the
  release. `Setup.bat` derives them from your own Minecraft install, on your
  machine.
- Horizon itself is MIT licensed; see [LICENSE](LICENSE) and
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
