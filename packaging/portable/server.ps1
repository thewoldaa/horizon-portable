# Hosts a Horizon server from a folder inside this package.
#
# The first run asks the questions `horizon-server init` asks - the EULA,
# the world, the port, who may join - and writes servers\<name>\server.toml.
# Later runs start that server in the foreground with its console, where
# typing `stop` shuts it down cleanly.
#
# Everything is offline-mode friendly: Horizon's own client cannot sign in
# to a Microsoft account, so an online-mode server would refuse it.

. (Join-Path $PSScriptRoot 'common.ps1')

$server = Get-Exe 'horizon-server'

if (-not (Test-Resources)) {
    Fail "the game files are not prepared yet. Run Setup.bat first."
}

Write-Host ''
Write-Host '  Horizon Portable - host a server' -ForegroundColor White
Write-Host '  --------------------------------' -ForegroundColor DarkGray
Write-Host ''

$serversDir = Join-Path $Root 'servers'
if (-not (Test-Path $serversDir)) {
    New-Item -ItemType Directory -Path $serversDir -Force | Out-Null
}

# Existing servers, so a second run just picks one.
$existing = @(Get-ChildItem -Path $serversDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'server.toml') })

if ($existing.Count -gt 0) {
    Write-Host '  Servers in this package:'
    for ($i = 0; $i -lt $existing.Count; $i++) {
        Write-Host "    [$($i + 1)] $($existing[$i].Name)"
    }
    Write-Host '    [n] a new server'
    Write-Host ''
    $pick = Read-Host "  Which one? [1]"
    if (-not $pick) { $pick = '1' }

    if ($pick -ne 'n') {
        $index = 0
        if (-not [int]::TryParse($pick, [ref]$index) -or
            $index -lt 1 -or $index -gt $existing.Count) {
            Fail "'$pick' is not one of the numbers above."
        }
        $dir = $existing[$index - 1].FullName
        Write-Step "Starting $($existing[$index - 1].Name)"
        Write-Host '  The console is yours: type stop to shut it down.' -ForegroundColor DarkGray
        Write-Host ''
        Push-Location $dir
        try {
            & $server --dir $dir run
        } finally {
            Pop-Location
        }
        exit $LASTEXITCODE
    }
}

# A new server.
$name = Read-Host '  World name [world]'
if (-not $name) { $name = 'world' }
$name = $name.Trim()
if ($name -notmatch '^[A-Za-z0-9 _.-]{1,64}$') {
    Fail "'$name' is not a name a world folder can use: letters, digits, spaces, _ . - only."
}
$dir = Join-Path $serversDir $name
if (Test-Path $dir) {
    Fail "$dir already exists. Pick another name, or delete that folder first."
}

$port = Read-Host '  Port [25565]'
if (-not $port) { $port = '25565' }
if ($port -notmatch '^\d{1,5}$' -or [int]$port -lt 1 -or [int]$port -gt 65535) {
    Fail "'$port' is not a port number."
}

Write-Host ''
Write-Host '  Horizon''s own client cannot sign in to a Microsoft account yet, so'
Write-Host '  players using Horizon must join an offline-mode server. Offline mode'
Write-Host '  checks no accounts: anyone who reaches the port joins under any name.'
Write-Host '  Keep it on your LAN or a tailnet (Tailscale, ZeroTier).'
Write-Host ''
$offline = Read-Host '  Turn online mode off, so Horizon clients can join? [Y/n]'
$offlineMode = -not ($offline -and $offline.Trim().ToLower().StartsWith('n'))

$who = Read-Host '  Who may join (comma separated names, empty for anyone)'
$players = @()
if ($who) {
    $players = $who.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

Write-Host ''
Write-Host '  Horizon does not ship Minecraft''s files. By continuing you agree to'
Write-Host '  the Minecraft EULA: https://aka.ms/MinecraftEULA'
$agree = Read-Host '  Do you agree? [y/N]'
if (-not ($agree -and $agree.Trim().ToLower().StartsWith('y'))) {
    Fail 'the EULA was not accepted.'
}

Write-Step "Creating $name"
$initArgs = @(
    '--dir', $dir, 'init',
    '--eula',
    '--world', $name,
    '--port', $port,
    '--yes'
)
if ($offlineMode) { $initArgs += '--offline' }
if ($players.Count -gt 0) {
    $initArgs += '--whitelist'
    foreach ($p in $players) { $initArgs += @('--player', $p) }
    $initArgs += @('--op', $players[0])
} else {
    $initArgs += '--no-whitelist'
}

& $server @initArgs
if ($LASTEXITCODE -ne 0) {
    Fail "horizon-server init stopped with code $LASTEXITCODE."
}

# The engine looks for the prepared files in resources\ inside the server
# folder. A junction points there without copying 700 MB per server; a
# directory junction needs no administrator rights, unlike a symlink.
$link = Join-Path $dir 'resources'
if (-not (Test-Path $link)) {
    try {
        New-Item -ItemType Junction -Path $link -Target $Resources | Out-Null
        Write-Ok "linked resources to $Resources"
    } catch {
        Write-Warn "could not link resources: $($_.Exception.Message)"
        Write-Warn "setting [engine] resources in server.toml to $Resources instead"
        & $server --dir $dir config set "engine.resources=$Resources" | Out-Null
    }
}

Write-Step "Starting $name"
Write-Host '  The console is yours: type stop to shut it down.' -ForegroundColor DarkGray
Write-Host ''
Push-Location $dir
try {
    & $server --dir $dir run
} finally {
    Pop-Location
}
