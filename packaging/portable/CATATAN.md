# Horizon Portable — catatan pemasangan

Dokumen ini bahasa Indonesia. Untuk pemakaian sehari-hari, `README.md` sudah
cukup; ini catatan teknis dan hal-hal yang perlu Anda tahu.

## Struktur

```
  Play.bat            mulai main
  Setup.bat           siapkan file game (sekali saja)
  Host-Server.bat     jalankan server
  README.md
  game/               Horizon sendiri + file game hasil prepare
                      (file game ada di game/.local/horizon-client/26.3/)
  mods/               mod .hmod (8 buah)
  data/               dunia, setelan, log, nama pemain
  servers/            server yang Anda buat
  scripts/            isi batch file, kalau mau dibaca
```

Tidak ada satu pun file yang ditulis di luar folder ini. `%APPDATA%` tidak
disentuh.

## Yang harus ada di komputer pemakai

- **Minecraft Java Edition 26.3**, sudah pernah dijalankan sekali dari
  launcher apa pun (resmi, Prism, MultiMC, SKLauncher, Freesm).
- **Java 25** (untuk `Setup.bat` saja, saat prepare).
- **GPU dengan Vulkan** (Windows/Linux) atau Mac Apple Silicon.

Horizon tidak mengunduh file Minecraft. `Setup.bat` membacanya dari
instalasi Minecraft milik pemakai. Ini bukan kemalasan: paket ini tidak
boleh dan tidak bisa membagikan aset Mojang.

## Cara main

1. `Setup.bat` — sekali. Sekitar 5 menit, ~700 MB.
2. `Play.bat` — selamanya.

## Nama pemain

Tersimpan di `data/horizon-player.txt`. Bisa diedit langsung, atau dihapus
supaya game membuat yang baru. Format: 3–16 karakter, huruf/angka/garis bawah.

`Play.bat` meneruskan argumen apa pun ke game, jadi:

```
Play.bat --name Budi
Play.bat --world Survival --creative
Play.bat --render-distance 8
```

## Mod

Delapan mod, semua aktif:

| Mod | Fungsi |
|---|---|
| QoL: HUD | satu panel: koordinat, arah, waktu, FPS — bisa dipindah dan diatur |
| QoL: Homes | `/sethome`, `/home`, `/back` |
| QoL: Night Vision | terang lokal, tombol **N** untuk on/off |
| Coordinates HUD | koordinat, arah hadap, waktu |
| FPS Counter | FPS, frame terberat, 1% low |
| Keystrokes | tombol gerak + klik |
| Minimap | peta sekitar |
| Zoom | tahan tombol untuk zoom |

Lima di antaranya mod resmi Horizon. Tiga yang teratas ditulis khusus untuk
paket ini, source-nya di `mods/qol-hud/`, `mods/qol-homes/`, dan
`mods/qol-nightvision/` di dalam repo.

`QoL: HUD` dan `Coordinates HUD` sama-sama menampilkan koordinat. Kalau
memakai keduanya, matikan `Coordinates HUD` di **Options > Mods** —
`QoL: HUD` bisa dipindah dan diatur ukurannya.

### Night Vision lokal

Tekan **N** untuk menerangkan layar, tekan lagi untuk mematikan. Atur
tombolnya dan tingkat terangnya di **Options > Mods > QoL: Night Vision >
Settings** (30% sampai 100%).

Ini bukan efek potion. Potion night vision dipegang server, jadi butuh
cheat di dunia single player dan butuh jadi operator di server — dua-duanya
justru tidak ada di tempat orang paling butuh: dunia hardcore (cheat mati
sejak awal) dan server orang lain. Mod ini menerangkan lightmap klien
sendiri, sama seperti **Options > Extras > Fullbright**, jadi tidak mengirim
apa pun ke server dan tetap jalan di hardcore maupun di server tanpa op.
Pemain lain tidak melihat apa-apa, dan tingkat kesulitan dunia tidak berubah.

### Mengatur HUD

**Options > Mods > QoL: HUD > Settings**:

- **Corner** — pojok mana panel menggantung (4 pilihan).
- **Nudge X / Nudge Y** — geser dari pojok itu, 12 sampai 200 piksel, dua arah.
- **Spacing** — jarak antar baris; ini yang membuat panel lebih lega.
- **Padding** — batas di dalam panel.
- **Coordinates / Time / FPS** — nyalakan atau matikan tiap baris.

Semua pilihan tersimpan, jadi posisinya tetap sama lain kali main.

**Mod tidak bisa mengubah ukuran huruf.** API mod Horizon menggambar teks
pada GUI Scale game dan tidak menyediakan field skala untuk teks — hanya
`item-shape` yang punya `scale`. Untuk huruf lebih besar, naikkan
**Options > Video Settings > GUI Scale**. Spacing dan padding hanya
memperbesar ruang di sekitar teks, bukan teksnya.

**Mod Java tidak bisa jalan.** Bukan belum didukung — Horizon ditulis ulang
di Rust dan tidak punya class Java untuk dipatch. Sodium, Lithium, OptiFine,
JEI, dan sejenisnya tidak akan pernah jalan di sini. Yang bisa dibawa dari
mod Java hanyalah datanya (blok, item, resep, tekstur), bukan kodenya.

## Server

`Host-Server.bat` menanyakan: nama dunia, port, mode offline, siapa yang
boleh masuk, dan EULA. Lalu membuat folder di `servers/<nama>/` dan
menjalankannya dengan konsol.

Sekali jalan lagi untuk menyalakan server yang sudah ada.

Catatan penting: klien Horizon **belum bisa login akun Microsoft**, jadi
server harus `online_mode = false` kalau yang main pakai Horizon. Server
offline tidak memeriksa akun siapa pun — jangan taruh di internet terbuka.
Pakai LAN atau tailnet (Tailscale/ZeroTier).

## Update dari dev

Repo ini bukan fork. Isinya source Horizon yang lengkap ditambah kemasan
portable, dan upstream `ludovic111/horizon` sudah terpasang sebagai remote:

```
git fetch upstream
git merge upstream/main
```

Kalau ada konflik, biasanya di `Cargo.toml` dan
`crates/horizon-mods/src/api_level.rs`: upstream menaikkan `LEVEL` dan
menambah fungsi, sementara di sini ada `render.set-brightness` untuk mod
night vision. Ambil daftar fungsi upstream, lalu tambahkan kembali baris
itu dan naikkan `LEVEL` ke nomor sesudahnya.

Lalu build ulang program dan modnya:

```
cargo build --release --locked --features horizon-client/mods \
  -p horizon-client --bin horizon-client --bin horizon-ctl \
  -p horizon-prepare --bin horizon-prepare -p horizon-server --bin horizon-server

powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-mods.ps1
```

Salin `horizon-*.exe` baru ke `packaging/portable/game/`. Dunia, setelan dan
mod tidak tersentuh — semuanya di `data/` dan `mods/`.

Kalau ada mod yang tidak mau compile, berarti API-nya berubah di bawahnya —
itu tandanya modnya yang perlu dibetulkan, bukan update-nya yang dihindari.

Butuh **Rust 1.95** (wasmtime 48 menolak versi lebih lama). Kalau belum:

```
rustup toolchain install 1.95.0
```

Repo ini juga punya `.github/workflows/portable-release.yml`: jalankan dari
tab Actions (atau push tag `v*`) untuk membangun ulang semuanya dan
menerbitkan zip-nya di Releases.

## Kalau ada masalah

- `data/logs/latest.log` — log game
- `data/crash-reports/` — laporan kalau crash
- `Setup.bat` akan bilang apa yang tidak ketemu (biasanya Minecraft 26.3
  belum pernah dijalankan, atau Java 25 tidak ada)
- Mod tidak muncul: cek `data/horizon-mods.txt` dan `data/horizon-mods/`

## Lisensi dan kredit

Horizon oleh ludovic111 dan kontributornya, lisensi MIT:
<https://github.com/ludovic111/horizon>

Kemasan portable ini bukan bagian dari proyek itu. Minecraft adalah merek
dagang Mojang/Microsoft; proyek ini tidak berafiliasi dengan mereka.
