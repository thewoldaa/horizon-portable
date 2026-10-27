# Horizon Portable

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

## Notes

- Not an official Minecraft product. Not approved by or associated with Mojang
  or Microsoft.
- No Minecraft code, textures or sounds are in this repository or in the
  release. `Setup.bat` derives them from your own Minecraft install, on your
  machine.
- Horizon itself is MIT licensed; see [LICENSE](LICENSE) and
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
