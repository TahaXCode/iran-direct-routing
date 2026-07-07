# Iran Direct Routing for Windows VPNs (IKEv2-safe split tunneling)

> Keep your VPN connected **all the time** while Iranian sites (banking, gov.ir, Aparat, Digikala, local hosting) still load normally — pure routing-table split tunneling that works even where the VPN app's own split tunneling can't.

![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## How it works

Iranian websites are hosted on Iranian IP ranges and usually **block foreign VPN exit IPs**. This toolkit adds a Windows routing-table entry for every Iranian IP block (~1,730 CIDR ranges) pointing at your **real ISP gateway** instead of the VPN.

Those routes are *more specific* than the VPN's catch-all `0.0.0.0/0` default route, and in IP routing the most specific match always wins:

| Destination | Path |
|---|---|
| Iranian IP ranges | Direct (no VPN) |
| Everything else | VPN |

Why routes instead of the VPN app's split tunneling? **Built-in split tunneling typically doesn't work with IKEv2** (only WireGuard/OpenVPN), and no VPN UI bulk-imports 1,730 ranges. Routes work with any protocol.

The scripts **auto-detect** your physical gateway and VPN interface on every run, so they keep working when your network changes.

> ⚠️ **Kill-switch/firewall note (Windscribe etc.):** a VPN "firewall" blocks all traffic outside the tunnel — including the direct Iranian traffic. Set it to Manual/off while using this (in Windscribe: Preferences → Connection → Firewall Mode → `Manual`). Trade-off: if the VPN drops, non-Iranian traffic briefly uses your real IP until reconnect.

## Usage

Everything is a double-click (each triggers one UAC prompt — routes need admin):

| Action | File |
|---|---|
| Turn Iran-direct **ON** | `Enable Iran Direct.cmd` |
| Turn Iran-direct **OFF** (all traffic back on VPN) | `Disable Iran Direct.cmd` |
| Auto-apply at every boot/logon (no more prompts) | `Install-AutoStart.ps1` |
| Remove the auto-start task | `Uninstall-AutoStart.ps1` |
| Refresh the Iran IP list (monthly-ish) | `Update-IranList.ps1` |

### First-time setup

1. Set your VPN's kill-switch/firewall to off (see above).
2. Double-click **`Enable Iran Direct.cmd`**, approve UAC (~30 s).
3. Test: an Iranian site (e.g. `aparat.com`) should load with the VPN connected, while foreign sites still show the VPN IP.
4. (Recommended) Run **`Install-AutoStart.ps1`** once for automatic re-apply after reboots.

## Verifying

```powershell
# Iran routes should point at your physical gateway, not the VPN (~1730 when enabled)
Get-NetRoute -NextHop <your-gateway-ip> | Measure-Object

# First hop to an Iranian host should be your local gateway
tracert -d www.aparat.com
```

## Notes & limitations

- **IPv4 only** — Iranian services are overwhelmingly IPv4; the VPN handles IPv6.
- **CDN edge cases** — a few Iranian sites sit behind foreign CDNs; those go through the VPN. Iranian hosting/ArvanCloud works fine.
- **Fully reversible** — routes are runtime entries (cleared on reboot by design); `Disable` + `Uninstall-AutoStart` leaves nothing behind.
- IP list source: public aggregated country blocks (ipdeny.com, herrbischoff/country-ip-blocks).

## Files

```
Enable Iran Direct.cmd      → double-click to turn ON
Disable Iran Direct.cmd     → double-click to turn OFF
Enable-IranDirect.ps1       → core logic (adds routes, auto-detects gateway/VPN)
Disable-IranDirect.ps1      → removes routes
Install-AutoStart.ps1       → scheduled task for boot/logon persistence
Uninstall-AutoStart.ps1     → removes that task
Update-IranList.ps1         → refreshes ir.cidr
ir.cidr                     → Iranian IP ranges (public data)
```

## License

MIT © Taha ([@TahaXCode](https://github.com/TahaXCode))
