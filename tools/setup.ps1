# Installs the Godot version pinned in .godot-version (Windows).
# Puts a `godot` command on your user PATH. Safe to re-run.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File tools\setup.ps1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster

$Root       = Split-Path -Parent $PSScriptRoot
$Version    = (Get-Content (Join-Path $Root '.godot-version') -Raw).Trim()   # e.g. 4.6-stable
$Base       = "https://github.com/godotengine/godot/releases/download/$Version"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\Godot\$Version"
$BinDir     = Join-Path $env:LOCALAPPDATA 'Programs\Godot\bin'

$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'windows_arm64' } else { 'win64' }
$Zip  = "Godot_v${Version}_$Arch.exe.zip"
$Exe  = Join-Path $InstallDir "Godot_v${Version}_$Arch.exe"

if (Test-Path $Exe) {
    Write-Host "Godot $Version already installed at $InstallDir"
} else {
    $Tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid())
    New-Item -ItemType Directory -Path $Tmp | Out-Null
    try {
        Write-Host "Downloading $Zip ..."
        Invoke-WebRequest "$Base/$Zip" -OutFile (Join-Path $Tmp $Zip)
        Invoke-WebRequest "$Base/SHA512-SUMS.txt" -OutFile (Join-Path $Tmp 'SHA512-SUMS.txt')

        $Line = Get-Content (Join-Path $Tmp 'SHA512-SUMS.txt') | Where-Object { ($_ -split '\s+')[1] -eq $Zip }
        if (-not $Line) { throw "No checksum published for $Zip" }
        $Expected = ($Line -split '\s+')[0]
        $Actual   = (Get-FileHash (Join-Path $Tmp $Zip) -Algorithm SHA512).Hash.ToLower()
        if ($Actual -ne $Expected) { throw "Checksum mismatch for $Zip" }
        Write-Host 'Checksum OK'

        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        Expand-Archive (Join-Path $Tmp $Zip) -DestinationPath $InstallDir -Force
    } finally {
        Remove-Item -Recurse -Force $Tmp
    }
}

# A plain copy named godot.exe works everywhere (terminal, VS Code godot-tools).
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Copy-Item $Exe (Join-Path $BinDir 'godot.exe') -Force
Write-Host "Installed $BinDir\godot.exe"

$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($UserPath -split ';') -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable('Path', "$UserPath;$BinDir", 'User')
    Write-Host "Added $BinDir to your user PATH. Open a new terminal to use 'godot'."
}

& $Exe --version
Write-Host 'Done. From the project folder run:  godot -e'
