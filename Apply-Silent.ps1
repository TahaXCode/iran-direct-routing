# Headless re-apply of the Iran direct routes. Used by the scheduled task
# (runs as SYSTEM at boot/logon). No window, no output.
. (Join-Path $PSScriptRoot 'IranRouting.Core.ps1')
try { Enable-IranRoutes | Out-Null } catch { }
