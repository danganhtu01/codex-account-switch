@echo off
setlocal
rem codex-switch.cmd — Windows shim for codex-switch.ps1.
rem Lets you run `codex-switch ...` from cmd.exe or PowerShell with no
rem ExecutionPolicy hassle. Calls the codex-switch.ps1 sitting next to it.
set "PS1=%~dp0codex-switch.ps1"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
)
exit /b %errorlevel%
