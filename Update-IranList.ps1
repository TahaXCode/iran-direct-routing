<#
.SYNOPSIS
    Refreshes ir.cidr with the latest aggregated Iran IPv4 block list.
    Run occasionally (e.g. monthly) to stay current, then re-run
    Enable-IranDirect.ps1 to apply any new ranges.
#>
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ListFile  = Join-Path $ScriptDir 'ir.cidr'

$urls = @(
    'https://www.ipdeny.com/ipblocks/data/aggregated/ir-aggregated.zone',
    'https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/ir.cidr'
)

foreach ($u in $urls) {
    try {
        Write-Host "Downloading from $u ..." -ForegroundColor Cyan
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 30
        $count = ($r.Content -split "`n" | Where-Object { $_.Trim() -match '^\d' }).Count
        if ($count -lt 100) { throw "Suspiciously small list ($count lines)." }
        $r.Content | Out-File -FilePath $ListFile -Encoding ascii
        Write-Host "Saved $count Iran CIDR ranges to ir.cidr" -ForegroundColor Green
        Read-Host "`nPress Enter to close"
        exit 0
    } catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
Write-Host 'All sources failed. Check your internet connection.' -ForegroundColor Red
Read-Host "`nPress Enter to close"
