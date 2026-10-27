# Builds the eight mods the portable package ships, into packaging\portable\mods\.
#
# All eight are built from this repository: five of Horizon's official mods,
# plus qol-hud, qol-homes and qol-nightvision. Nothing is downloaded, so the
# pack follows this repo's source: pull, run this, and the .hmod files match
# the commit.
#
# This is a build tool, not part of the package: packaging\portable\ is what a
# player receives.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-mods.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-mods.ps1 -Out C:\somewhere

param(
    [string]$Out = (Join-Path $PSScriptRoot 'portable\mods')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The repository root: this file is in packaging\.
$repo = Split-Path -Parent $PSScriptRoot

# id -> the folder that builds it. The id is what horizon-mods.txt names.
$mods = [ordered]@{
    'coords_hud'  = 'crates/horizon-mod-sdk/examples/coords-hud'
    'fps_overlay' = 'mods/official/fps-overlay'
    'keystrokes'  = 'mods/official/keystrokes'
    'minimap'     = 'mods/official/minimap'
    'zoom'        = 'mods/official/zoom'
    'qol_homes'   = 'mods/qol-homes'
    'qol_hud'     = 'mods/qol-hud'
    'qol_nightvision' = 'mods/qol-nightvision'
}

# The mods' own crates are ordinary wasm32 cdylibs and build on the default
# toolchain. `cargo-horizon-mod`, the packer, is not: it links wasmtime, which
# refuses anything below rustc 1.95.0.
$toolchain = '+1.95.0'

# The packer runs `cargo` from PATH, not the toolchain that built it, so the
# mods would be compiled by whichever toolchain is default. Pin it to the one
# below, so this script and CI compile the same .wasm; rustup reads this for
# the target check too.
$env:RUSTUP_TOOLCHAIN = '1.95.0'

Write-Host ''
Write-Host '==> building the mod packer' -ForegroundColor Cyan
& cargo $toolchain build --quiet --manifest-path (Join-Path $repo 'Cargo.toml') -p cargo-horizon-mod
if ($LASTEXITCODE -ne 0) { throw "cargo-horizon-mod did not build (exit $LASTEXITCODE)" }
$packer = Join-Path $repo 'target\debug\cargo-horizon-mod.exe'
if (-not (Test-Path $packer)) { throw "$packer is missing after the build" }

# The wasm target the mods compile to. `cargo build` reports a missing one as
# a confusing link error, so check it up front. $LASTEXITCODE is no use here:
# it would be the last command of the pipeline, not rustup.
$installed = & rustup target list --installed
if ($installed -notcontains 'wasm32-unknown-unknown') {
    Write-Host '    installing the wasm32-unknown-unknown target' -ForegroundColor Yellow
    & rustup target add wasm32-unknown-unknown
    if ($LASTEXITCODE -ne 0) { throw 'could not install the wasm32 target' }
}

if (-not (Test-Path $Out)) {
    New-Item -ItemType Directory -Path $Out -Force | Out-Null
}

Write-Host ''
Write-Host "==> building $($mods.Count) mods into $Out" -ForegroundColor Cyan

$failed = @()
foreach ($id in $mods.Keys) {
    $dir = Join-Path $repo $mods[$id]
    Write-Host ''
    Write-Host "    $id" -ForegroundColor Cyan
    if (-not (Test-Path (Join-Path $dir 'horizon-mod.toml'))) {
        Write-Host "      skipped: $dir has no horizon-mod.toml" -ForegroundColor Yellow
        $failed += $id
        continue
    }

    # The packer packs the manifest of the folder it is run in. It prints
    # `Built <path>`: the file lands in the workspace's target\horizon-mod,
    # not in the mod's own folder, so read the path back rather than guess it.
    #
    # No `2>&1` here: in Windows PowerShell, redirecting a native program's
    # stderr wraps each line in an ErrorRecord and, with
    # $ErrorActionPreference = 'Stop', turns cargo's progress output into a
    # terminating error. Left alone, stderr goes straight to the console.
    Push-Location $dir
    try {
        $output = & $packer build
    } finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "      FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "      $_" }
        $failed += $id
        continue
    }

    $built = $output |
        Where-Object { $_ -is [string] -and $_.Trim().StartsWith('Built ') } |
        Select-Object -Last 1
    if ($built) { $built = $built.Trim().Substring('Built '.Length) }
    if (-not $built -or -not (Test-Path $built)) {
        Write-Host "      FAILED: the packer named no file that exists" -ForegroundColor Red
        $failed += $id
        continue
    }

    # One file per id, so a rebuild replaces the previous build rather than
    # sitting beside it as a second copy the game would also load.
    Get-ChildItem -Path $Out -Filter "$id*.hmod" -File | Remove-Item -Force
    Copy-Item -Path $built -Destination (Join-Path $Out "$id.hmod") -Force
    $size = [math]::Round((Get-Item $built).Length / 1KB)
    Write-Host "      $id.hmod  ($size KiB)" -ForegroundColor Green
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "all $($mods.Count) mods built into $Out" -ForegroundColor Green
Write-Host ''
Write-Host 'Play.bat copies mods\*.hmod into data\horizon-mods, newer ones only.' -ForegroundColor DarkGray
