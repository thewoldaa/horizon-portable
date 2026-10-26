# Prepares Horizon's game files from the player's own Minecraft 26.3.
#
# Horizon ships no Minecraft code, textures or sounds. It builds them from a
# copy the player already has, which is why this step exists and why it only
# has to run once.

. (Join-Path $PSScriptRoot 'common.ps1')

$prepare = Get-Exe 'horizon-prepare'

Write-Host ''
Write-Host '  Horizon Portable - setup' -ForegroundColor White
Write-Host '  ------------------------' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  This prepares the game files from your own Minecraft 26.3.'
Write-Host '  You need Minecraft Java Edition 26.3, played once from a launcher,'
Write-Host '  and Java 25. It takes a few minutes and about 700 MB.'
Write-Host ''

if (Test-Resources) {
    Write-Step 'Game files already prepared'
    Write-Ok "found $(Join-Path $Resources 'horizon-resources.json')"
    Write-Host ''
    Write-Host '  Nothing to do. Run Play.bat.' -ForegroundColor White
    Write-Host '  Run this again only if you updated Horizon and it asks for it.'
    Write-Host ''
    Read-Host '  Press Enter to close'
    exit 0
}

Write-Step 'Finding your Minecraft 26.3'
$minecraft = Find-Minecraft
if (-not $minecraft) {
    Write-Host ''
    Write-Host '  Horizon could not find Minecraft 26.3 in the usual place.' -ForegroundColor Yellow
    Write-Host '  Point it at the game folder of the launcher you use - the one'
    Write-Host '  holding versions\, libraries\ and assets\.'
    Write-Host '  Example: C:\Users\you\AppData\Roaming\.minecraft'
    Write-Host ''
    $typed = Read-Host '  Minecraft folder (leave empty to cancel)'
    $typed = $typed.Trim('"', ' ')
    if (-not $typed) { Fail 'no Minecraft folder given.' }
    if (-not (Test-Path (Join-Path $typed 'versions\26.3'))) {
        Fail "$typed does not hold versions\26.3. Play 26.3 once from your launcher first."
    }
    $minecraft = $typed
    # No BOM: Find-Minecraft trims this, but a BOM would still be part of the path.
    [IO.File]::WriteAllText(
        (Join-Path $Data 'minecraft-dir.txt'), $minecraft, [Text.UTF8Encoding]::new($false))
}
Write-Ok $minecraft

Write-Step 'Getting the 26.3 server jar'
$serverJar = Get-ServerJar $minecraft

Write-Step 'Checking your version file'
Repair-Manifest $minecraft | Out-Null

Write-Step 'Collecting the game files'
$stage = New-Staging $minecraft

Write-Step 'Preparing the game files'
Write-Host '  This is the slow part. Horizon runs Minecraft''s own exporters to'
Write-Host '  read the game''s data; it takes a few minutes.'
Write-Host ''
$env:HORIZON_MINECRAFT_DIR = $stage
# --root is the release folder: horizon-prepare writes to
# <root>\.local\horizon-client\26.3, which is where Play.bat and Host-Server.bat
# look. Running it from game\ makes the whole package relocatable.
Push-Location $Game
try {
    & $prepare --prepare --server-jar $serverJar --minecraft-dir $stage --root $Game
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($code -ne 0) {
    Write-Host ''
    Fail "horizon-prepare stopped with code $code. The lines above say why."
}

if (-not (Test-Resources)) {
    Fail "preparation finished but $(Join-Path $Resources 'horizon-resources.json') is missing."
}

Write-Step 'Done'
Write-Ok 'the game files are ready'
Write-Host ''
Write-Host '  Run Play.bat to play.' -ForegroundColor White
Write-Host ''
Read-Host '  Press Enter to close'
