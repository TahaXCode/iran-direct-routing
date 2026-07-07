<#
    IranSplitRouting.ps1  -  Beautiful WPF control panel for Iran split-routing.
    Works with any VPN (IKEv2, WireGuard UDP, Amnezia WireGuard, OpenVPN, ...).
    Self-elevates, then dot-sources IranRouting.Core.ps1 for the engine.
#>
[CmdletBinding()]
param()

# ---- Self-elevate (adding routes needs admin) -----------------------------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

$CorePath = Join-Path $PSScriptRoot 'IranRouting.Core.ps1'
. $CorePath

Add-Type -AssemblyName PresentationFramework

# ---------------------------------------------------------------------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Iran Split Routing" Height="700" Width="500"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#0B1220" FontFamily="Segoe UI" Foreground="#E2E8F0">
  <Window.Resources>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#111C31"/>
      <Setter Property="CornerRadius" Value="14"/>
      <Setter Property="Padding" Value="18"/>
      <Setter Property="Margin" Value="0,0,0,14"/>
    </Style>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="#E2E8F0"/>
      <Setter Property="Background" Value="#1E293B"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="14,11"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" CornerRadius="10" Background="{TemplateBinding Background}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Opacity" Value="0.88"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="b" Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="22">
    <StackPanel>
      <!-- Header -->
      <TextBlock Text="Iran Split Routing" FontSize="24" FontWeight="Bold" Foreground="#F1F5F9"/>
      <TextBlock Text="Keep your VPN on. Iranian sites go direct." FontSize="13"
                 Foreground="#7C8BA3" Margin="0,2,0,16"/>

      <!-- Status card -->
      <Border Style="{StaticResource Card}">
        <StackPanel>
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="StatusDot" Width="13" Height="13" Fill="#EF4444"
                     VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusBig" Text="OFF" FontSize="20" FontWeight="Bold"
                       Margin="10,0,0,0" Foreground="#F1F5F9" VerticalAlignment="Center"/>
          </StackPanel>
          <TextBlock x:Name="StatusDesc" Text="All traffic goes through the VPN."
                     FontSize="13" Foreground="#94A3B8" Margin="0,8,0,4" TextWrapping="Wrap"/>
          <TextBlock x:Name="RoutesText" Text="0 / 0 Iranian ranges routed direct"
                     FontSize="12" Foreground="#64748B" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>

      <!-- Primary action -->
      <Button x:Name="PrimaryBtn" Style="{StaticResource Btn}" Content="Enable Iran-Direct Routing"
              Background="#22C55E" Foreground="#062312" FontSize="16" FontWeight="Bold"
              Padding="14,16" Margin="0,0,0,10"/>
      <ProgressBar x:Name="Progress" Height="8" Foreground="#38BDF8" Background="#1E293B"
                   BorderThickness="0" Visibility="Collapsed" Margin="0,0,0,14"/>

      <!-- Connection card -->
      <Border Style="{StaticResource Card}">
        <StackPanel>
          <TextBlock Text="CONNECTION" FontSize="11" FontWeight="Bold" Foreground="#475569"/>
          <Grid Margin="0,10,0,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Grid.Column="0" Text="Active VPN" Foreground="#7C8BA3"
                       FontSize="13" Margin="0,0,16,6"/>
            <TextBlock Grid.Row="0" Grid.Column="1" x:Name="VpnText" Text="-" FontSize="13"
                       Foreground="#E2E8F0" Margin="0,0,0,6" TextAlignment="Right"/>
            <TextBlock Grid.Row="1" Grid.Column="0" Text="Direct gateway" Foreground="#7C8BA3"
                       FontSize="13" Margin="0,0,16,0"/>
            <TextBlock Grid.Row="1" Grid.Column="1" x:Name="GwText" Text="-" FontSize="13"
                       Foreground="#E2E8F0" TextAlignment="Right"/>
          </Grid>
        </StackPanel>
      </Border>

      <!-- Firewall warning -->
      <Border Background="#2A1F08" CornerRadius="12" Padding="14" Margin="0,0,0,14">
        <TextBlock TextWrapping="Wrap" FontSize="12.5" Foreground="#FBBF24">
          <Run FontWeight="Bold">Required:</Run>
          <Run Text=" turn your VPN app's kill-switch / firewall OFF, or it will block the direct traffic and Iranian sites will fail."/>
        </TextBlock>
      </Border>

      <!-- Secondary actions -->
      <Grid Margin="0,0,0,10">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="10"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="UpdateBtn" Grid.Column="0" Style="{StaticResource Btn}" Content="Update IP list"/>
        <Button x:Name="RefreshBtn" Grid.Column="2" Style="{StaticResource Btn}" Content="Refresh"/>
      </Grid>
      <Button x:Name="AutoBtn" Style="{StaticResource Btn}" Content="Auto-start at boot: OFF"
              HorizontalAlignment="Stretch" Margin="0,0,0,14"/>

      <!-- Status line -->
      <TextBlock x:Name="LogText" Text="Ready." FontSize="12" Foreground="#64748B"
                 TextWrapping="Wrap"/>
    </StackPanel>
  </Grid>
</Window>
'@

[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xamlXml
$win = [Windows.Markup.XamlReader]::Load($reader)

# ---- Grab controls --------------------------------------------------------
$StatusDot  = $win.FindName('StatusDot')
$StatusBig  = $win.FindName('StatusBig')
$StatusDesc = $win.FindName('StatusDesc')
$RoutesText = $win.FindName('RoutesText')
$PrimaryBtn = $win.FindName('PrimaryBtn')
$Progress   = $win.FindName('Progress')
$VpnText    = $win.FindName('VpnText')
$GwText     = $win.FindName('GwText')
$UpdateBtn  = $win.FindName('UpdateBtn')
$RefreshBtn = $win.FindName('RefreshBtn')
$AutoBtn    = $win.FindName('AutoBtn')
$LogText    = $win.FindName('LogText')

function C([string]$hex) { (New-Object Windows.Media.BrushConverter).ConvertFromString($hex) }

# ---- Shared state for the background worker -------------------------------
$sync = [hashtable]::Synchronized(@{ Done = $true; Value = 0; Total = 0; Op = ''; Result = $null; Error = $null })
$script:jobActive = $false

function Set-Busy([bool]$busy) {
    $PrimaryBtn.IsEnabled = -not $busy
    $UpdateBtn.IsEnabled  = -not $busy
    $AutoBtn.IsEnabled    = -not $busy
    $RefreshBtn.IsEnabled = -not $busy
}

function Refresh-Ui {
    $gw     = Get-PhysicalGateway
    $vpn    = Get-VpnInfo
    $total  = (Get-IranCidrs).Count
    $active = if ($gw) { Get-ActiveIranRouteCount -Gateway $gw.Gateway } else { 0 }
    $script:enabled = ($total -gt 0 -and $active -gt [math]::Floor($total * 0.5))

    if ($script:enabled) {
        $StatusBig.Text  = 'ON'
        $StatusDesc.Text = 'Iranian sites bypass the VPN. Everything else stays tunneled.'
        $StatusDot.Fill  = C '#22C55E'
        $PrimaryBtn.Content    = 'Disable Iran-Direct Routing'
        $PrimaryBtn.Background  = C '#EF4444'
        $PrimaryBtn.Foreground  = C '#2A0A0A'
    } else {
        $StatusBig.Text  = 'OFF'
        $StatusDesc.Text = 'All traffic goes through the VPN.'
        $StatusDot.Fill  = C '#EF4444'
        $PrimaryBtn.Content    = 'Enable Iran-Direct Routing'
        $PrimaryBtn.Background  = C '#22C55E'
        $PrimaryBtn.Foreground  = C '#062312'
    }
    $RoutesText.Text = "$active / $total Iranian ranges routed direct"

    if ($vpn.Connected) { $VpnText.Text = "$($vpn.Type)  -  $($vpn.Name)"; $VpnText.Foreground = C '#E2E8F0' }
    else                { $VpnText.Text = 'No active VPN detected';        $VpnText.Foreground = C '#FBBF24' }

    if ($gw) { $GwText.Text = "$($gw.Gateway)  via  $($gw.Adapter)" } else { $GwText.Text = 'No internet gateway found' }
    $AutoBtn.Content = if (Test-AutoStart) { 'Auto-start at boot: ON' } else { 'Auto-start at boot: OFF' }
}

function Start-Op([string]$op, [string]$busyText) {
    if ($script:jobActive) { return }
    $sync.Done = $false; $sync.Value = 0; $sync.Total = 0; $sync.Op = $op; $sync.Result = $null; $sync.Error = $null
    $script:jobActive = $true
    Set-Busy $true
    $LogText.Text = $busyText
    $Progress.IsIndeterminate = ($op -eq 'Update')
    $Progress.Visibility = 'Visible'

    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'MTA'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync)
    $rs.SessionStateProxy.SetVariable('CorePath', $CorePath)
    $rs.SessionStateProxy.SetVariable('Operation', $op)
    $psw = [powershell]::Create(); $psw.Runspace = $rs
    [void]$psw.AddScript({
        try {
            . $CorePath
            switch ($Operation) {
                'Enable'  { $sync.Result = Enable-IranRoutes  -Progress $sync }
                'Disable' { $sync.Result = Disable-IranRoutes -Progress $sync }
                'Update'  { $sync.Result = [pscustomobject]@{ Count = (Update-IranList) } }
            }
        } catch { $sync.Error = $_.Exception.Message }
        finally { $sync.Done = $true }
    })
    $script:jobPS = $psw; $script:jobHandle = $psw.BeginInvoke(); $script:jobRS = $rs
}

# ---- Poll the worker & drive the UI ---------------------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    if (-not $script:jobActive) { return }
    if ($sync.Total -gt 0) {
        $Progress.IsIndeterminate = $false
        $Progress.Maximum = $sync.Total
        $Progress.Value   = $sync.Value
    }
    if ($sync.Done) {
        $script:jobActive = $false
        try { $script:jobPS.EndInvoke($script:jobHandle) } catch {}
        try { $script:jobPS.Dispose(); $script:jobRS.Close(); $script:jobRS.Dispose() } catch {}
        $Progress.Visibility = 'Collapsed'
        if ($sync.Error) {
            $LogText.Text = 'Error: ' + $sync.Error
        } else {
            $r = $sync.Result
            switch ($sync.Op) {
                'Enable'  { $LogText.Text = "Enabled - added $($r.Added), already set $($r.Skipped), failed $($r.Failed)." }
                'Disable' { $LogText.Text = "Disabled - removed $($r.Removed) routes. All traffic back on VPN." }
                'Update'  { $LogText.Text = "IP list updated - $($r.Count) ranges. Click Enable to apply." }
            }
        }
        Set-Busy $false
        Refresh-Ui
    }
})

# ---- Wire up buttons ------------------------------------------------------
$PrimaryBtn.Add_Click({
    if ($script:enabled) { Start-Op 'Disable' 'Removing routes...' }
    else                 { Start-Op 'Enable'  'Applying routes... (about 30 seconds)' }
})
$UpdateBtn.Add_Click({  Start-Op 'Update' 'Downloading latest Iran IP list...' })
$RefreshBtn.Add_Click({ Refresh-Ui; $LogText.Text = 'Refreshed.' })
$AutoBtn.Add_Click({
    if ($script:jobActive) { return }
    try {
        if (Test-AutoStart) { Uninstall-AutoStart; $LogText.Text = 'Auto-start disabled.' }
        else                { Install-AutoStart;   $LogText.Text = 'Auto-start enabled (re-applies at boot and logon).' }
    } catch { $LogText.Text = 'Auto-start error: ' + $_.Exception.Message }
    Refresh-Ui
})

$win.Add_ContentRendered({ Refresh-Ui })
$win.Add_Closed({ $timer.Stop() })
$timer.Start()
[void]$win.ShowDialog()
