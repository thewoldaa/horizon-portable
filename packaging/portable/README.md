# Horizon Portable

A ready-to-play, self-contained build of [Horizon](https://github.com/ludovic111/horizon)
— Minecraft Java Edition 26.3, rewritten from scratch in Rust — with a small
modpack and a portable layout: the game, its mods, your worlds, your settings
and any server you host all live inside one folder. Nothing is written to
`%APPDATA%`, and you can move or copy the folder to another computer (or a USB
drive) and carry on where you left off.

This repository is **not a fork**. It is a standalone home for the portable
package: the Horizon source it is built from, the portable scripts, the mods
this pack adds, the built programs, and the release workflow. Everything about
the portable build is worked on here.

Not an official Minecraft product. Not approved by or associated with Mojang or
Microsoft. This repository contains none of Minecraft's code, textures or
sounds: `Setup.bat` prepares them from your own copy of Minecraft. Horizon
itself is by ludovic111 and its contributors, MIT licensed.

## Play

Download the latest `horizon-portable-windows-x64.zip` from
[Releases](../../releases), unzip it anywhere, then:

1. **`Setup.bat`** — prepares the game files from your own Minecraft 26.3
   install. Needs Minecraft Java Edition 26.3 played once from a launcher, and
   Java 25. A few minutes and about 700 MB, once.
2. **`Play.bat`** — starts the game. The first run asks nothing; later runs open
   your last world.

For a server that stays up, run **`Host-Server.bat`**. It asks for the world
name, port and who may join, then starts it.

## The modpack

Eight mods, all on by default, all built from source in this repository:

| Mod | What it does |
|---|---|
| **QoL: HUD** | One panel: coordinates, facing, time, FPS. Move it to any corner, nudge it, pick its spacing and padding. |
| **QoL: Homes** | `/sethome`, `/home`, `/back`. Needs cheats: it teleports you. |
| **QoL: Night Vision** | Press **N** to brighten your view. Local to your client, so it works in hardcore and on servers where you are not an operator. |
| **Coordinates HUD** | Coordinates, facing and the time of day. |
| **FPS Counter** | Frames per second, the slowest frame and the 1% low. |
| **Keystrokes** | Movement keys and clicks in a corner. |
| **Minimap** | A map of the terrain around you. |
| **Zoom** | Hold a key to zoom. |

The last five are Horizon's own official mods; the first three were written for
this pack. Their sources are in `mods/` and `crates/horizon-mod-sdk/examples/`.

`QoL: HUD` and `Coordinates HUD` both show coordinates — turn the latter off if
you keep both.

Java mods (Sodium, Lithium, OptiFine, JEI and the rest) do not run here and
cannot be made to. Horizon is a Rust program with none of Minecraft's Java
classes to patch. `mods/` takes `.hmod` files only, which are Rust compiled to
WebAssembly.

## The folder

```
Play.bat  Setup.bat  Host-Server.bat   start here
README.md  CATATAN.md                  this file, and the same in Indonesian
game/                                  Horizon itself and its programs
  horizon-client.exe  horizon-ctl.exe  horizon-server.exe  horizon-prepare.exe
  exporters/                           Horizon's own exporter classes
  .local/horizon-client/26.3/          the game files Setup.bat prepared
mods/                                  the eight .hmod files
scripts/                               what the batch files run
data/                                  everything you make: worlds, options, logs
servers/                               servers you host
```

`data/` and `servers/` are created on first run and are not in this repository.
The package is exactly these files and nothing else: `packaging/build-mods.ps1`
and the Rust source live one level up, in the repository.

## Build it yourself

The package is assembled from this repository. Two things need building: the
programs (Rust) and the mods (Rust → WebAssembly).

```powershell
# The programs. `mods` is the code-mod runtime, on in every release build.
cargo build --release --locked --features horizon-client/mods `
  -p horizon-client --bin horizon-client --bin horizon-ctl `
  -p horizon-prepare --bin horizon-prepare `
  -p horizon-server --bin horizon-server

# Copy them into the package.
copy target\release\horizon-client.exe  packaging\portable\game\
copy target\release\horizon-ctl.exe     packaging\portable\game\
copy target\release\horizon-prepare.exe packaging\portable\game\
copy target\release\horizon-server.exe  packaging\portable\game\

# The eight mods, into packaging\portable\mods\.
powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-mods.ps1
```

`packaging/portable/` **is** the package: it holds the batch files, the scripts,
the programs, the mods and the docs, laid out exactly as a player receives it.
Zipping its contents gives the release. `packaging/build-mods.ps1` is a build
tool and stays outside it.

The mods need the `wasm32-unknown-unknown` target (`rustup target add
wasm32-unknown-unknown`). `build-mods.ps1` builds `cargo-horizon-mod`, the
packer, on Rust 1.95.0 — it links wasmtime, which refuses anything older.

## Following upstream

Horizon is updated often. This repository carries the full source, so moving to
a newer Horizon means merging from upstream:

```bash
git remote add upstream https://github.com/ludovic111/horizon.git   # once
git fetch upstream
git merge upstream/main
```

Then rebuild the programs and the mods (above) and commit the new
`packaging/portable/game/*.exe` and `packaging/portable/mods/*.hmod`. If a mod
no longer compiles, the mod API changed under it: that is the signal to fix the
mod, not to skip the update.

Your worlds, settings and mod choices are untouched by an update — they live in
`data/`, which no update replaces.

## Releasing

`.github/workflows/release.yml` builds the programs and the mods on a Windows
runner, runs a smoke test, assembles the package and attaches the zip to a
GitHub Release. Start it by hand from the Actions tab, or push a tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Credits

Horizon is by ludovic111 and its contributors, MIT licensed:
<https://github.com/ludovic111/horizon>. This portable packaging, the three QoL
mods and the release workflow are additions made here.
