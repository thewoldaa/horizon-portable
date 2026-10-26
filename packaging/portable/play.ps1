# Starts Horizon, with every file it reads or writes inside this folder.
#
# The game reads options.txt, horizon-mods.txt, horizon-mods\ and saves\ from
# its working folder, so the working folder is data\. HORIZON_HOME, where its
# logs and crash reports go, is data\ too.

. (Join-Path $PSScriptRoot 'common.ps1')

$client = Get-Exe 'horizon-client'

if (-not (Test-Resources)) {
    Write-Host ''
    Write-Host '  The game files are not prepared yet.' -ForegroundColor Yellow
    Write-Host ''
    $answer = Read-Host '  Run setup now? [Y/n]'
    if ($answer -and $answer.Trim().ToLower().StartsWith('n')) { exit 1 }
    & (Join-Path $PSScriptRoot 'setup.ps1')
    if (-not (Test-Resources)) { exit 1 }
}

Set-GameEnvironment

# The mods this package ships, turned on.
#
# A mod the list does not mention at all is added as on: that is what a
# player sees after the package gains a mod, and an unmentioned mod is on by
# default anyway, so writing it changes nothing they chose. A mod the list
# does mention keeps whatever the player set, so turning one off sticks.
#
# "$_" would read as a variable named `_:`, not the pipeline item, and
# `Set-Content -Encoding utf8` writes a BOM in Windows PowerShell, which the
# game's parser does not strip: the first mod would be lost. So build the
# lines by name and write them without a BOM.
$modList = Join-Path $Data 'horizon-mods.txt'
$on = @('qol_hud', 'qol_homes', 'qol_nightvision', 'coords_hud', 'fps_overlay', 'keystrokes', 'minimap', 'zoom')
if (-not (Test-Path $modList)) {
    $lines = foreach ($id in $on) { "mod.${id}:true" }
    [IO.File]::WriteAllLines($modList, $lines, [Text.UTF8Encoding]::new($false))
} else {
    $existing = [IO.File]::ReadAllText($modList)
    $missing = foreach ($id in $on) {
        if ($existing -notmatch "(?m)^\s*mod\.$([regex]::Escape($id))\s*:") { "mod.${id}:true" }
    }
    if ($missing) {
        $kept = [IO.File]::ReadAllText($modList).TrimEnd("`r", "`n")
        $text = (@($kept) + @($missing) | Where-Object { $_ }) -join "`n"
        [IO.File]::WriteAllText($modList, $text + "`n", [Text.UTF8Encoding]::new($false))
    }
}

# The mods folder the game reads: data\horizon-mods. Keep it in step with the
# mods\ folder this package ships, without touching the player's own files.
#
# Matched on the id each .hmod declares, not on its file name: a rebuilt mod
# whose file was renamed would otherwise sit beside the old copy, and the game
# loads whichever it reads second as a duplicate of the same id and refuses it.
$gameMods = Join-Path $Data 'horizon-mods'
if (-not (Test-Path $gameMods)) {
    New-Item -ItemType Directory -Path $gameMods -Force | Out-Null
}
$shipped = Join-Path $Root 'mods'
if (Test-Path $shipped) {
    $shippedIds = @{}
    Get-ChildItem -Path $shipped -Filter '*.hmod' -File | ForEach-Object {
        $id = Get-ModId $_.FullName
        if (-not $id) {
            Write-Warning "skipping $($_.Name): it has no readable horizon-mod.toml"
            return
        }
        $shippedIds[$id] = $true
        $target = Join-Path $gameMods $_.Name
        if (-not (Test-Path $target) -or
            (Get-Item $target).LastWriteTimeUtc -lt $_.LastWriteTimeUtc) {
            Copy-Item -Path $_.FullName -Destination $target -Force
        }
    }

    # An older copy of a mod this package ships, under another name: the
    # player never installed it by hand, so replacing it is right.
    Get-ChildItem -Path $gameMods -Filter '*.hmod' -File | ForEach-Object {
        $id = Get-ModId $_.FullName
        if ($id -and $shippedIds.ContainsKey($id)) {
            $same = Join-Path $shipped $_.Name
            if (-not (Test-Path $same)) {
                Remove-Item -Path $_.FullName -Force
            }
        }
    }
}

Push-Location $Data
try {
    & $client --resources $Resources @args
} finally {
    Pop-Location
}
