#!/usr/bin/env pwsh
#
# codex-switch.ps1 — switch between N OpenAI Codex CLI accounts (Windows / PowerShell port).
#
# Native port of bin/codex-switch (bash). Runs on Windows PowerShell 5.1+ and PowerShell 7+.
# No WSL or bash required.
#
# Codex caches login details in a plaintext file at $CODEX_HOME\auth.json
# (CODEX_HOME defaults to %USERPROFILE%\.codex). This tool snapshots that file under
# named profiles and swaps the active one in, so you can keep an arbitrary number of
# Codex accounts side by side and switch between them with one command.
#
# Docs: https://developers.openai.com/codex/auth

$ErrorActionPreference = 'Stop'

$VERSION = '1.0.0'
$PROG    = 'codex-switch'

# --- Layout -----------------------------------------------------------------
$CodexHome = if ($env:CODEX_HOME)        { $env:CODEX_HOME }        else { Join-Path $HOME '.codex' }
$AuthFile  = Join-Path $CodexHome 'auth.json'
$Store     = if ($env:CODEX_SWITCH_HOME) { $env:CODEX_SWITCH_HOME } else { Join-Path $CodexHome 'account-switch' }
$Profiles  = Join-Path $Store 'profiles'
$ActivePtr = Join-Path $Store 'active'
$Backup    = Join-Path $Store '.auth.json.bak'

# --- Helpers ----------------------------------------------------------------
function Err($msg)  { [Console]::Error.WriteLine("${PROG}: $msg") }
function Die($msg)  { Err $msg; exit 1 }
function Info($msg) { Write-Output $msg }

# Best-effort: lock a directory down to the current user (the Windows analogue of
# chmod 700). Mirrors the bash `chmod ... 2>/dev/null || true` — never fatal.
function LockDown($path) {
    try {
        $acl = Get-Acl -LiteralPath $path
        $acl.SetAccessRuleProtection($true, $false)   # disable inheritance, drop inherited ACEs
        $me  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $me, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $path -AclObject $acl
    } catch { }
}

function EnsureStore {
    if (-not (Test-Path -LiteralPath $Profiles)) {
        New-Item -ItemType Directory -Path $Profiles -Force | Out-Null
    }
    LockDown $Store
}

# Reject anything that could escape the profiles dir.
function TestName($n) {
    if ([string]::IsNullOrEmpty($n))       { return $false }
    if ($n -eq '.' -or $n -eq '..')        { return $false }
    if ($n.StartsWith('-'))                { return $false }   # no leading dash (flag confusion)
    if ($n -notmatch '^[A-Za-z0-9._-]+$')  { return $false }   # allowed: letters, digits, . _ -
    return $true
}

function RequireName($n) {
    if ([string]::IsNullOrEmpty($n)) { Die "missing account name. See: $PROG help" }
    if (-not (TestName $n)) { Die "invalid account name '$n' (allowed: letters, digits, '.', '_', '-')." }
}

# Hash a file's contents (used to detect which profile is currently active).
function HashFile($path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}

function ProfileDir($name)    { Join-Path $Profiles $name }
function ProfileAuth($name)   { Join-Path (Join-Path $Profiles $name) 'auth.json' }
function ProfileExists($name) { Test-Path -LiteralPath (ProfileAuth $name) -PathType Leaf }

function ListProfiles {
    if (-not (Test-Path -LiteralPath $Profiles)) { return @() }
    Get-ChildItem -LiteralPath $Profiles -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'auth.json') -PathType Leaf } |
        Select-Object -ExpandProperty Name |
        Sort-Object
}

function ReadPtr {
    if (Test-Path -LiteralPath $ActivePtr -PathType Leaf) {
        $c = Get-Content -LiteralPath $ActivePtr -Raw -ErrorAction SilentlyContinue
        if ($null -eq $c) { return '' }
        return ([string]$c).Trim()
    }
    return ''
}

function SetActive($name) { Set-Content -LiteralPath $ActivePtr -Value $name -NoNewline -Encoding ascii }

# Name of the profile whose auth.json matches the live auth.json, if any.
function DetectActive {
    $live = HashFile $AuthFile
    if (-not $live) { return (ReadPtr) }
    foreach ($name in (ListProfiles)) {
        if ((HashFile (ProfileAuth $name)) -eq $live) { return $name }
    }
    # No content match — fall back to the recorded pointer (may be stale).
    return (ReadPtr)
}

# --- Commands ---------------------------------------------------------------
function CmdAdd($rest) {
    $force = $false; $name = ''
    foreach ($a in $rest) {
        if     ($a -eq '-f' -or $a -eq '--force') { $force = $true }
        elseif ($a -like '-*')                    { Die "unknown option '$a'" }
        elseif ($name -eq '')                     { $name = $a }
        else                                      { Die "unexpected argument '$a'" }
    }
    RequireName $name
    if (-not (Test-Path -LiteralPath $AuthFile -PathType Leaf)) {
        Die "no active Codex auth at $AuthFile.`n  Log in first:  codex login   (then re-run: $PROG add $name)"
    }
    EnsureStore
    $dest = ProfileDir $name
    if ((ProfileExists $name) -and (-not $force)) {
        Die "account '$name' already exists. Overwrite with: $PROG add $name --force"
    }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -LiteralPath $AuthFile -Destination (Join-Path $dest 'auth.json') -Force
    SetActive $name
    Info "Saved current Codex login as account '$name'."
}

function CmdList {
    $active = DetectActive
    $names  = @(ListProfiles)
    if ($names.Count -eq 0) {
        Info "No saved accounts yet."
        Info "  1) codex login            # authenticate an account"
        Info "  2) $PROG add <name>   # save it under a name"
        return
    }
    foreach ($name in $names) {
        $marker = if ($name -eq $active) { '*' } else { ' ' }
        Info (" {0} {1}" -f $marker, $name)
    }
    $label = if ($active) { $active } else { 'none' }
    Info "$label active"
}

function CmdUse($rest) {
    $name = if ($rest.Count -ge 1) { $rest[0] } else { '' }
    RequireName $name
    if (-not (ProfileExists $name)) { Die "no account named '$name'. See: $PROG list" }
    EnsureStore
    if (-not (Test-Path -LiteralPath $CodexHome)) { New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null }
    # Back up whatever is currently live so a bad switch is recoverable.
    if (Test-Path -LiteralPath $AuthFile -PathType Leaf) { Copy-Item -LiteralPath $AuthFile -Destination $Backup -Force }
    Copy-Item -LiteralPath (ProfileAuth $name) -Destination $AuthFile -Force
    SetActive $name
    Info "Switched to account '$name'."
}

function CmdCurrent {
    $active = DetectActive
    if (-not $active) {
        if (Test-Path -LiteralPath $AuthFile -PathType Leaf) {
            Info "Active Codex login is not saved as a profile. Save it: $PROG add <name>"
        } else {
            Info "No active Codex login. Run: codex login"
        }
        return
    }
    Info $active
}

function CmdRemove($rest) {
    $force = $false; $name = ''
    foreach ($a in $rest) {
        if     ($a -eq '-f' -or $a -eq '--force') { $force = $true }
        elseif ($a -like '-*')                    { Die "unknown option '$a'" }
        elseif ($name -eq '')                     { $name = $a }
        else                                      { Die "unexpected argument '$a'" }
    }
    RequireName $name
    if (-not (ProfileExists $name)) { Die "no account named '$name'. See: $PROG list" }
    if (-not $force) {
        if (-not [Console]::IsInputRedirected) {
            $ans = Read-Host "Remove saved account '$name'? [y/N]"
            if ($ans -notmatch '^[yY]') { Die "Aborted." }
        } else {
            Die "refusing to remove '$name' non-interactively. Pass --force."
        }
    }
    Remove-Item -LiteralPath (ProfileDir $name) -Recurse -Force
    if ((ReadPtr) -eq $name) { Remove-Item -LiteralPath $ActivePtr -Force -ErrorAction SilentlyContinue }
    Info "Removed account '$name'. (Live $AuthFile left untouched.)"
}

function CmdRename($rest) {
    $old = if ($rest.Count -ge 1) { $rest[0] } else { '' }
    $new = if ($rest.Count -ge 2) { $rest[1] } else { '' }
    RequireName $old; RequireName $new
    if (-not (ProfileExists $old)) { Die "no account named '$old'. See: $PROG list" }
    if (ProfileExists $new)        { Die "account '$new' already exists." }
    EnsureStore
    Move-Item -LiteralPath (ProfileDir $old) -Destination (ProfileDir $new)
    if ((ReadPtr) -eq $old) { SetActive $new }
    Info "Renamed '$old' -> '$new'."
}

function Usage {
@"
$PROG — switch between N OpenAI Codex CLI accounts (v$VERSION)

USAGE
  $PROG <command> [args]

COMMANDS
  add <name> [--force]     Save the current Codex login as account <name>
  list | ls                List saved accounts (active marked with *)
  use <name>               Switch the active account to <name>
  <name>                   Shorthand for: use <name>
  current | who            Print the active account name
  remove <name> [--force]  Delete a saved account (live auth untouched)
  rename <old> <new>       Rename a saved account
  help | -h | --help       Show this help
  version | --version      Print version

TYPICAL FLOW
  codex login              # authenticate account #1, then:
  $PROG add work
  codex login              # authenticate account #2 (re-login), then:
  $PROG add personal
  $PROG list
  $PROG use work           # or just: $PROG work

NOTES
  * Profiles live in $Store (override with `$CODEX_SWITCH_HOME).
  * Operates on `$CODEX_HOME\auth.json (`$CODEX_HOME defaults to %USERPROFILE%\.codex).
  * Requires file-based credential storage. If you use the OS keyring
    (config.toml: cli_auth_credentials_store = "keyring"), set it to "file"
    so credentials live in auth.json for switching to work.
"@ | Write-Output
}

# --- Dispatch ---------------------------------------------------------------
if ($args.Count -ge 1) { $cmd = [string]$args[0] } else { $cmd = 'help' }
if ($args.Count -ge 2) { $rest = @($args[1..($args.Count - 1)]) } else { $rest = @() }

switch ($cmd) {
    'add'       { CmdAdd $rest; break }
    'list'      { CmdList; break }
    'ls'        { CmdList; break }
    'use'       { CmdUse $rest; break }
    'switch'    { CmdUse $rest; break }
    'current'   { CmdCurrent; break }
    'who'       { CmdCurrent; break }
    'active'    { CmdCurrent; break }
    'remove'    { CmdRemove $rest; break }
    'rm'        { CmdRemove $rest; break }
    'delete'    { CmdRemove $rest; break }
    'rename'    { CmdRename $rest; break }
    'mv'        { CmdRename $rest; break }
    'help'      { Usage; break }
    '-h'        { Usage; break }
    '--help'    { Usage; break }
    'version'   { Info "$PROG $VERSION"; break }
    '--version' { Info "$PROG $VERSION"; break }
    '-V'        { Info "$PROG $VERSION"; break }
    default {
        # Shorthand: `codex-switch <name>` == `codex-switch use <name>`
        if ((TestName $cmd) -and (ProfileExists $cmd)) {
            CmdUse @($cmd)
        } else {
            Err "unknown command or account '$cmd'"
            Usage | Out-Host
            exit 1
        }
    }
}
