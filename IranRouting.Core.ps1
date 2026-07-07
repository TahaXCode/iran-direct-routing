<#
    IranRouting.Core.ps1
    Shared engine for Iran split-routing. Dot-sourced by the GUI and by the
    silent auto-start script. No side effects on load.

    Approach is VPN-agnostic: it adds a more-specific route for every Iranian
    IP block pointing at your physical gateway. Those routes win over ANY
    VPN's default route (0.0.0.0/0 or the 0.0.0.0/1 + 128.0.0.0/1 split that
    WireGuard / Amnezia / OpenVPN use), so it works with IKEv2, WireGuard UDP,
    Amnezia WireGuard, OpenVPN, etc. without configuring the VPN client.
#>

$script:CoreDir     = $PSScriptRoot
$script:IranListFile = Join-Path $PSScriptRoot 'ir.cidr'
$script:TaskName     = 'IranSplitRouting'

function Test-IsAdmin {
    $p = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# The real internet gateway (never the VPN), used as the direct next-hop.
function Get-PhysicalGateway {
    $phys    = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
    $physIdx = @($phys | Select-Object -ExpandProperty InterfaceIndex)
    if ($physIdx) {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                 Where-Object { $physIdx -contains $_.ifIndex -and $_.NextHop -ne '0.0.0.0' } |
                 Sort-Object RouteMetric | Select-Object -First 1
        if ($route) {
            $ad = Get-NetAdapter -InterfaceIndex $route.ifIndex -ErrorAction SilentlyContinue
            return [PSCustomObject]@{ Gateway = $route.NextHop; IfIndex = [int]$route.ifIndex; Adapter = $ad.Name }
        }
    }
    # Fallback: read the adapter's configured default gateway directly.
    foreach ($a in $phys) {
        $cfg = Get-NetIPConfiguration -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue
        if ($cfg.IPv4DefaultGateway) {
            return [PSCustomObject]@{ Gateway = $cfg.IPv4DefaultGateway.NextHop; IfIndex = [int]$a.InterfaceIndex; Adapter = $a.Name }
        }
    }
    return $null
}

# Detect which VPN (if any) is currently carrying the default route, and its type.
function Get-VpnInfo {
    $physIdx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Select-Object -ExpandProperty InterfaceIndex)
    $vpnRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0','0.0.0.0/1','128.0.0.0/1' -ErrorAction SilentlyContinue |
                Where-Object { $physIdx -notcontains $_.ifIndex } |
                Sort-Object RouteMetric | Select-Object -First 1
    if (-not $vpnRoute) {
        return [PSCustomObject]@{ Connected = $false; Name = 'Not connected'; Type = '-'; IfIndex = $null }
    }
    # Get-NetAdapter does not return RAS/native VPN interfaces (e.g. IKEv2), so
    # fall back to the route's InterfaceAlias for the name/description.
    $alias = $vpnRoute.InterfaceAlias
    $ad    = Get-NetAdapter -InterfaceIndex $vpnRoute.ifIndex -ErrorAction SilentlyContinue
    $name  = if ($ad) { $ad.Name } else { $alias }
    $desc  = if ($ad) { $ad.InterfaceDescription } else { $alias }
    $hay   = "$desc $alias".ToLower()
    $type = switch -Regex ($hay) {
        'amnezia'                              { 'Amnezia WireGuard'; break }
        'wireguard'                            { 'WireGuard'; break }
        'openvpn|tap-window|tap-win|ovpn'      { 'OpenVPN'; break }
        'ikev2'                                { 'IKEv2'; break }
        'wintun'                               { 'WireGuard / OpenVPN'; break }
        'wan miniport|agile|sstp|l2tp|pptp|ras'{ 'IKEv2 / native'; break }
        default                                { 'VPN' }
    }
    [PSCustomObject]@{ Connected = $true; Name = $name; Type = $type; IfIndex = [int]$vpnRoute.ifIndex; Desc = $desc }
}

function Get-IranCidrs {
    if (-not (Test-Path $script:IranListFile)) { return @() }
    Get-Content $script:IranListFile | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$' }
}

# How many of our Iran ranges are currently routed direct (via the given gateway).
function Get-ActiveIranRouteCount {
    param([string]$Gateway)
    if (-not $Gateway) { return 0 }
    $set = @{}
    foreach ($c in (Get-IranCidrs)) { $set[$c] = $true }
    if ($set.Count -eq 0) { return 0 }
    $cnt = 0
    Get-NetRoute -NextHop $Gateway -ErrorAction SilentlyContinue | ForEach-Object {
        if ($set.ContainsKey($_.DestinationPrefix)) { $cnt++ }
    }
    $cnt
}

# Add direct routes for every Iran range. $Progress is an optional synchronized
# hashtable the GUI polls for live progress.
function Enable-IranRoutes {
    param([hashtable]$Progress)
    $gw = Get-PhysicalGateway
    if (-not $gw) { throw 'No physical internet gateway found. Are you online?' }
    $cidrs = Get-IranCidrs
    if ($cidrs.Count -eq 0) { throw 'The Iran IP list (ir.cidr) is empty. Use "Update IP list" first.' }

    $existing = @{}
    Get-NetRoute -InterfaceIndex $gw.IfIndex -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -eq $gw.Gateway } |
        ForEach-Object { $existing[$_.DestinationPrefix] = $true }

    $added = 0; $skipped = 0; $failed = 0; $i = 0; $total = $cidrs.Count
    if ($Progress) { $Progress.Total = $total; $Progress.Value = 0 }
    foreach ($c in $cidrs) {
        $i++
        if ($existing.ContainsKey($c)) { $skipped++ }
        else {
            try {
                New-NetRoute -DestinationPrefix $c -InterfaceIndex $gw.IfIndex `
                    -NextHop $gw.Gateway -RouteMetric 1 -PolicyStore ActiveStore `
                    -ErrorAction Stop | Out-Null
                $added++
            } catch { $failed++ }
        }
        if ($Progress -and ($i % 25 -eq 0)) { $Progress.Value = $i }
    }
    if ($Progress) { $Progress.Value = $total }
    [PSCustomObject]@{ Added = $added; Skipped = $skipped; Failed = $failed; Gateway = $gw.Gateway }
}

function Disable-IranRoutes {
    param([hashtable]$Progress)
    $physIdx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Select-Object -ExpandProperty InterfaceIndex)
    $cidrs = Get-IranCidrs
    $removed = 0; $i = 0; $total = $cidrs.Count
    if ($Progress) { $Progress.Total = $total; $Progress.Value = 0 }
    foreach ($c in $cidrs) {
        $i++
        $routes = Get-NetRoute -DestinationPrefix $c -ErrorAction SilentlyContinue |
                  Where-Object { $physIdx -contains $_.ifIndex }
        foreach ($r in $routes) {
            try { Remove-NetRoute -InputObject $r -Confirm:$false -ErrorAction Stop; $removed++ } catch {}
        }
        if ($Progress -and ($i % 25 -eq 0)) { $Progress.Value = $i }
    }
    if ($Progress) { $Progress.Value = $total }
    [PSCustomObject]@{ Removed = $removed }
}

function Update-IranList {
    $urls = @(
        'https://www.ipdeny.com/ipblocks/data/aggregated/ir-aggregated.zone',
        'https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/ir.cidr'
    )
    foreach ($u in $urls) {
        try {
            $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 30
            $count = ($r.Content -split "`n" | Where-Object { $_.Trim() -match '^\d' }).Count
            if ($count -lt 100) { throw 'list too small' }
            $r.Content | Out-File -FilePath $script:IranListFile -Encoding ascii
            return $count
        } catch { }
    }
    throw 'Could not download the Iran IP list (all sources failed). Check your connection.'
}

function Test-AutoStart { [bool](Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) }

function Install-AutoStart {
    $apply = Join-Path $script:CoreDir 'Apply-Silent.ps1'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$apply`""
    $triggers = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -AtLogOn))
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                 -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $triggers `
        -Principal $principal -Settings $settings -Force `
        -Description 'Re-applies Iran direct routes that bypass the VPN at boot/logon.' | Out-Null
}

function Uninstall-AutoStart {
    if (Test-AutoStart) { Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false }
}
