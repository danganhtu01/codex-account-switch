#!/usr/bin/env pwsh
#
# install.ps1 — install codex-switch on Windows.
#
# Copies bin\codex-switch.ps1 and bin\codex-switch.cmd to a bin directory and
# (unless -NoPath) adds that directory to your user PATH. No admin / sudo needed.
#
#   .\install.ps1                       # install to %LOCALAPPDATA%\codex-switch
#   .\install.ps1 -BinDir C:\tools\bin  # install to an explicit directory
#   .\install.ps1 -NoPath               # install but don't touch PATH

param(
    [string] $BinDir = (Join-Path $env:LOCALAPPDATA 'codex-switch'),
    [switch] $NoPath
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here 'bin'

foreach ($f in @('codex-switch.ps1', 'codex-switch.cmd')) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $f) -PathType Leaf)) {
        Write-Error "missing $f — run this from the cloned repo root."
        exit 1
    }
}

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $src 'codex-switch.ps1') -Destination $BinDir -Force
Copy-Item -LiteralPath (Join-Path $src 'codex-switch.cmd') -Destination $BinDir -Force
Write-Host "Installed codex-switch -> $BinDir"

if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $parts = @($userPath -split ';' | Where-Object { $_ -ne '' })
    if ($parts -notcontains $BinDir) {
        $newPath = (@($parts) + $BinDir) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Added $BinDir to your user PATH."
        Write-Host "Open a NEW terminal for it to take effect."
    } else {
        Write-Host "$BinDir is already on your user PATH."
    }
} else {
    Write-Host "Skipped PATH update (-NoPath). Run with the full path, or add $BinDir to PATH yourself."
}

Write-Host ""
Write-Host "Done. Try:  codex-switch help"
