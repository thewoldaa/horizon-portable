# Horizon Portable - shared helpers.
#
# Everything here is relative to the package root, so the folder can be moved
# or copied anywhere. Nothing is written outside it.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The package root: the folder holding this scripts\ folder.
$script:Root = Split-Path -Parent $PSScriptRoot
$script:Game = Join-Path $Root 'game'
$script:Data = Join-Path $Root 'data'
# horizon-prepare writes its output here, relative to the release folder it
# runs from: .local\horizon-client\<version>.
$script:Resources = Join-Path $Game '.local\horizon-client\26.3'

function Write-Step([string]$Text) {
    Write-Host ''
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host "    $Text" -ForegroundColor Green
}

function Write-Warn([string]$Text) {
    Write-Host "    $Text" -ForegroundColor Yellow
}

function Fail([string]$Text) {
    Write-Host ''
    Write-Host "Cannot continue: $Text" -ForegroundColor Red
    Write-Host ''
    exit 1
}

# The game's working folder, and the home its logs and crash reports go to.
# Both point at data\ so every file the game writes stays in the package.
function Set-GameEnvironment {
    if (-not (Test-Path $Data)) {
        New-Item -ItemType Directory -Path $Data -Force | Out-Null
    }
    $env:HORIZON_HOME = $Data
}

function Get-Exe([string]$Name) {
    $path = Join-Path $Game "$Name.exe"
    if (-not (Test-Path $path)) {
        Fail "$path is missing. The package is incomplete: game\ should hold the Horizon programs."
    }
    return $path
}

# The id a .hmod declares, from the `horizon-mod.toml` inside it, or $null
# when the file is not a readable mod.
#
# The id is what the game keys a mod by: two files carrying the same one are
# the same mod, and the second is refused with "another running mod already
# uses id ...". File names are not the id, so a copy has to be matched on this.
function Get-ModId([string]$Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $zip = $null
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'horizon-mod.toml' } |
            Select-Object -First 1
        if (-not $entry) { return $null }
        $reader = New-Object IO.StreamReader($entry.Open())
        try {
            $text = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
        $match = [regex]::Match($text, '(?m)^\s*id\s*=\s*"([^"]+)"')
        if ($match.Success) { return $match.Groups[1].Value }
        return $null
    } catch {
        return $null
    } finally {
        if ($zip) { $zip.Dispose() }
    }
}

# Whether game\resources holds a prepared game.
function Test-Resources {
    return (Test-Path (Join-Path $Resources 'horizon-resources.json'))
}

# The official launcher's game folder, or the one the player chose last time.
function Find-Minecraft {
    $record = Join-Path $Data 'minecraft-dir.txt'
    if (Test-Path $record) {
        $saved = (Get-Content $record -Raw).Trim()
        if ($saved -and (Test-Path (Join-Path $saved 'versions\26.3'))) {
            return $saved
        }
    }
    $candidates = @(
        (Join-Path $env:APPDATA '.minecraft'),
        (Join-Path $env:USERPROFILE '.minecraft')
    )
    foreach ($dir in $candidates) {
        if ($dir -and (Test-Path (Join-Path $dir 'versions\26.3'))) {
            return $dir
        }
    }
    return $null
}

# The 26.3 server jar: kept in the package, else downloaded from the address
# the player's own 26.3 version file names.
function Get-ServerJar([string]$Minecraft) {
    $kept = Join-Path $Game 'server-jars\26.3.jar'
    if (Test-Path $kept) {
        Write-Ok "using the server jar already in the package"
        return $kept
    }

    $versionFile = Join-Path $Minecraft 'versions\26.3\26.3.json'
    if (-not (Test-Path $versionFile)) {
        Fail "Minecraft 26.3 is not installed in $Minecraft (no versions\26.3\26.3.json)."
    }
    $manifest = Get-Content $versionFile -Raw | ConvertFrom-Json
    $url = $manifest.downloads.server.url
    $sha1 = $manifest.downloads.server.sha1
    if (-not $url) {
        Fail "the 26.3 version file names no server jar to download."
    }

    $folder = Split-Path -Parent $kept
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    Write-Ok "downloading the 26.3 server jar (60 MB, once)"
    $part = "$kept.part"
    try {
        Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing
    } catch {
        Fail "could not download the server jar from $url`n$($_.Exception.Message)"
    }

    $got = (Get-FileHash -Path $part -Algorithm SHA1).Hash.ToLower()
    if ($sha1 -and $got -ne $sha1.ToLower()) {
        Remove-Item $part -Force -ErrorAction SilentlyContinue
        Fail "the server jar downloaded damaged (checksum mismatch). Try again."
    }
    Move-Item -Path $part -Destination $kept -Force
    Write-Ok "server jar ready"
    return $kept
}

# The checksum of Mojang's own 26.3 version file, from research-lock.json.
# Third-party launchers (SKLauncher, PCL, HMCL) rewrite versions\26.3\26.3.json
# with their own fields, which horizon-prepare refuses. The lock file names
# the copy it accepts, so Setup can fetch Mojang's original and put it where
# prepare looks for it.
function Get-PinnedManifestSha1 {
    $lock = Join-Path $Game 'research-lock.json'
    if (-not (Test-Path $lock)) { return $null }
    $json = Get-Content $lock -Raw | ConvertFrom-Json
    return $json.minecraft.manifest_sha1
}

# horizon-prepare wants four things in the Minecraft folder: versions\26.3\
# with both the version file and the client jar, plus libraries\ and assets\.
# No single launcher guarantees all four - SKLauncher keeps the jar elsewhere,
# Prism keeps assets in a shared folder, and the official launcher may not have
# 26.3 at all. So Setup builds a folder of its own inside the package: the two
# 26.3 files, fetched from Mojang and checked, beside junctions to whatever
# libraries and assets the player already has.
#
# Returns the staging folder, which is what HORIZON_MINECRAFT_DIR points at.
function New-Staging([string]$Minecraft) {
    $stage = Join-Path $Game '.local\minecraft-dir'
    $versionDir = Join-Path $stage 'versions\26.3'
    if (-not (Test-Path $versionDir)) {
        New-Item -ItemType Directory -Path $versionDir -Force | Out-Null
    }

    # The version file: Mojang's own, already fetched by Repair-Manifest, or
    # the player's copy when that one is already the pinned file.
    $staged = Join-Path $versionDir '26.3.json'
    $pinned = Get-PinnedManifestSha1
    if (-not $pinned) {
        Fail 'research-lock.json is missing from game\: the package is incomplete.'
    }
    $mojang = Join-Path $Game '.local\minecraft\26.3\manifest.json'
    $player = Join-Path $Minecraft 'versions\26.3\26.3.json'

    if ((Test-Path $mojang) -and
        ((Get-FileHash $mojang -Algorithm SHA1).Hash.ToLower() -eq $pinned.ToLower())) {
        Copy-Item $mojang $staged -Force
    } elseif ((Test-Path $player) -and
        ((Get-FileHash $player -Algorithm SHA1).Hash.ToLower() -eq $pinned.ToLower())) {
        Copy-Item $player $staged -Force
    } else {
        Fail 'no usable 26.3 version file: Repair-Manifest should have fetched one.'
    }

    # The client jar, from the address the version file itself names.
    $jar = Join-Path $versionDir '26.3.jar'
    $manifest = Get-Content $staged -Raw | ConvertFrom-Json
    $want = $manifest.downloads.client.sha1
    $ok = (Test-Path $jar) -and
          ((Get-FileHash $jar -Algorithm SHA1).Hash.ToLower() -eq $want.ToLower())

    if (-not $ok) {
        # A copy the player already has is worth reusing before downloading.
        $candidates = @(
            (Join-Path $Minecraft 'versions\26.3\26.3.jar'),
            (Join-Path $env:APPDATA 'horizon-launcher\linked-minecraft\versions\26.3\26.3.jar')
        )
        foreach ($candidate in $candidates) {
            if ($candidate -and (Test-Path $candidate) -and
                ((Get-FileHash $candidate -Algorithm SHA1).Hash.ToLower() -eq $want.ToLower())) {
                Copy-Item $candidate $jar -Force
                Write-Ok 'reused the 26.3 client jar already on this computer'
                $ok = $true
                break
            }
        }
    }

    if (-not $ok) {
        Write-Ok 'downloading the 26.3 client jar (41 MB, once)'
        $url = $manifest.downloads.client.url
        $part = "$jar.part"
        try {
            Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing
        } catch {
            Fail "could not download the client jar from $url`n$($_.Exception.Message)"
        }
        if ((Get-FileHash $part -Algorithm SHA1).Hash.ToLower() -ne $want.ToLower()) {
            Remove-Item $part -Force -ErrorAction SilentlyContinue
            Fail 'the client jar downloaded damaged (checksum mismatch). Try again.'
        }
        Move-Item $part $jar -Force
    }

    # libraries\, which prepare reads for the client's dependencies. It is
    # the only folder of the player's install it needs: the assets come out
    # of the client jar, and sounds are a separate optional step.
    #
    # A junction would avoid the 400 MB copy, but only NTFS has them: exFAT
    # and FAT32 - a USB stick, many external drives - refuse with "Incorrect
    # function". Where a link is impossible the folder is copied, which is
    # correct and keeps the package self-contained.
    $libLink = Join-Path $stage 'libraries'
    $libSource = Join-Path $Minecraft 'libraries'
    if (-not (Test-Path $libLink)) {
        if (-not (Test-Path $libSource)) {
            Fail "$libSource is missing: your Minecraft install is incomplete."
        }
        $linked = $false
        try {
            New-Item -ItemType Junction -Path $libLink -Target $libSource -ErrorAction Stop | Out-Null
            $linked = $true
            Write-Ok 'linked libraries\ instead of copying it'
        } catch {
            Write-Ok 'copying libraries\ (400 MB, once)'
            Copy-Item $libSource $libLink -Recurse -Force
        }
        if (-not $linked) {
            Write-Host '    This drive cannot hold links, so the copy keeps the package working.'
        }
    }

    Write-Ok "game files staged in $stage"
    return $stage
}
function Repair-Manifest([string]$Minecraft) {
    $pinned = Get-PinnedManifestSha1
    if (-not $pinned) {
        Write-Warn 'research-lock.json is missing: cannot check the version file'
        return $false
    }
    $source = Join-Path $Minecraft 'versions\26.3\26.3.json'
    if (-not (Test-Path $source)) { return $false }
    $got = (Get-FileHash -Path $source -Algorithm SHA1).Hash.ToLower()
    if ($got -eq $pinned.ToLower()) { return $false }

    Write-Warn 'your 26.3 version file was rewritten by your launcher'
    Write-Ok "fetching Mojang's own copy"

    $target = Join-Path $Game '.local\minecraft\26.3\manifest.json'
    $folder = Split-Path -Parent $target
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $url = "https://piston-meta.mojang.com/v1/packages/$pinned/26.3.json"
    $part = "$target.part"
    try {
        Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing
    } catch {
        Fail "could not download Mojang's 26.3 version file from $url`n$($_.Exception.Message)"
    }
    $check = (Get-FileHash -Path $part -Algorithm SHA1).Hash.ToLower()
    if ($check -ne $pinned.ToLower()) {
        Remove-Item $part -Force -ErrorAction SilentlyContinue
        Fail 'the downloaded version file does not match its published checksum.'
    }
    Move-Item -Path $part -Destination $target -Force
    Write-Ok 'using Mojang''s copy instead'
    return $true
}
