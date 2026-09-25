@echo off
setlocal EnableExtensions
title ALIREZA SHAFAATI ADMINISTRATOR
color 0F

rem ---------- Administrator check (real UAC elevation) ----------
fltmc >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo  ADMINISTRATOR PRIVILEGES REQUIRED
  echo  Requesting elevation through Windows UAC...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try{Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop}catch{exit 1}"
  if errorlevel 1 (
    echo.
    echo  PROGRAM CANNOT CONTINUE WITHOUT ADMINISTRATOR PRIVILEGES
    echo.
    pause
  )
  exit /b
)

mode con cols=110 lines=50 >nul 2>&1

rem ---------- Extract embedded PowerShell engine to a temp file ----------
set "ASA_PS=%TEMP%\ASA_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText('%~f0');$m=[string][char]58+[char]58+'PSBEGIN';$i=$t.LastIndexOf($m);if($i -lt 0){exit 2};$b=$t.Substring($i+$m.Length);[IO.File]::WriteAllText('%ASA_PS%',$b,(New-Object Text.UTF8Encoding($true)))"
if errorlevel 1 (
  echo  ERROR: could not prepare the PowerShell engine.
  pause
  exit /b 1
)
if not exist "%ASA_PS%" (
  echo  ERROR: engine file was not created.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ASA_PS%"
del /f /q "%ASA_PS%" >nul 2>&1
endlocal
exit /b 0

::PSBEGIN
# ============================================================================
#  ALIREZA SHAFAATI ADMINISTRATOR - PowerShell engine (embedded in the BAT)
#  Pure ASCII. Uses only built-in Windows tools.
# ============================================================================
$ErrorActionPreference = 'Continue'
$script:Quit   = $false
$script:GoHome = $false
$script:Jump   = $null
$script:SI     = $null
$script:Pos    = $null
$script:NS     = $null
$script:Pub    = 'NOT CHECKED - press R to refresh'
try { $Host.UI.RawUI.WindowTitle = 'ALIREZA SHAFAATI ADMINISTRATOR' } catch {}
try { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'White' } catch {}

# ------------------------------------------------------------------ basics
function W([string]$t,[string]$c='White',[switch]$n){
  if($n){ Write-Host $t -ForegroundColor $c -NoNewline } else { Write-Host $t -ForegroundColor $c }
}
function Line([string]$c='Blue'){ W ('=' * 78) $c }
function Test-Admin{
  try{ return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }catch{ return $false }
}
function Head([string]$Sub){
  Clear-Host
  Line Red
  W '   ALIREZA SHAFAATI  -  ADMINISTRATOR CONTROL CENTER' White
  Line Blue
  if($Sub -eq 'MAIN MENU'){ Show-Status }
  elseif($script:SI){ W ('   HOST: {0}   OS: {1}   ADMIN: {2}' -f $script:SI['Computer Name'],$script:SI['Windows Edition'],$script:SI['Administrator']) Cyan }
  W ('   PATH: ' + $Sub) Yellow
  Line Blue
}
function Wait-Key([string]$m='PRESS ANY KEY TO RETURN'){
  W ''
  W ('  ' + $m) Yellow
  try{ $Host.UI.RawUI.FlushInputBuffer() }catch{}
  [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
function Ask-YN([string]$q){
  Write-Host ($q + ' [Y/N] ') -ForegroundColor Yellow -NoNewline
  try{ $Host.UI.RawUI.FlushInputBuffer() }catch{}
  while($true){
    $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    $c = ([string]$k.Character).ToUpper()
    if($c -eq 'Y'){ Write-Host 'Y'; return $true }
    if($c -eq 'N' -or $k.VirtualKeyCode -eq 27){ Write-Host 'N'; return $false }
  }
}
function Confirm-Exit{
  W ''
  if(Ask-YN '  Are you sure you want to exit?'){ $script:Quit = $true; return $true }
  return $false
}
function Ask-Host([string]$p='Target host or IP'){
  $v = (Read-Host ('  ' + $p)).Trim()
  if($v -match '^[A-Za-z0-9][A-Za-z0-9\.\-:]{0,253}$'){ return $v }
  return $null
}
function Show($o,[switch]$Paged){
  if($Paged){ $o | Out-Host -Paging }
  else { $s = ($o | Out-String -Width 118).TrimEnd(); if($s){ Write-Host $s } else { W '  (nothing to show)' Yellow } }
}
function Safe([scriptblock]$b,[string]$d='NOT AVAILABLE'){
  try{ $v = & $b; if($null -eq $v){ return $d }; $s = (@($v) -join ', ').Trim(); if($s -eq ''){ return $d }; return $s }catch{ return $d }
}
function Show-Result([string]$Action,[string]$Status,[string]$Msg='',$Code=$null){
  W ''
  Line Blue
  W '  ALIREZA SHAFAATI ADMINISTRATOR' White
  Line Blue
  W '  ACTION:' Cyan; W ('     ' + $Action) White
  $col = 'Yellow'
  if($Status -eq 'SUCCESS'){ $col = 'Green' } elseif($Status -eq 'ERROR'){ $col = 'Red' }
  W '  STATUS:' Cyan; W ('     ' + $Status) $col
  if($Status -eq 'ERROR'){
    if($null -ne $Code){ W '  ERROR CODE:' Cyan; W ('     ' + $Code) Red }
    W '  ERROR MESSAGE:' Cyan; W ('     ' + $Msg) Red
  } else {
    if($null -ne $Code){ W '  EXIT CODE:' Cyan; W ('     ' + $Code) White }
    if($Msg){ W '  DETAILS:' Cyan; W ('     ' + $Msg) White }
  }
  Wait-Key
}

# ------------------------------------------------------------------ system info
function Get-VMwareInfo{
  $o = @{ Installed=$false; Services=@(); Products=@(); Workstation=$null; VmRun=$null }
  try{ $o.Services = @(Get-Service -Name 'VMware*','VMTools','vmnet*' -ErrorAction SilentlyContinue) }catch{}
  try{
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $o.Products = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'VMware*' } | Select-Object DisplayName,DisplayVersion)
  }catch{}
  foreach($p in @(("${env:ProgramFiles(x86)}\VMware\VMware Workstation"),("$env:ProgramFiles\VMware\VMware Workstation"))){
    if(Test-Path -LiteralPath (Join-Path $p 'vmware.exe')){
      $o.Workstation = Join-Path $p 'vmware.exe'
      if(Test-Path -LiteralPath (Join-Path $p 'vmrun.exe')){ $o.VmRun = Join-Path $p 'vmrun.exe' }
      break
    }
  }
  $o.Installed = (($o.Services.Count -gt 0) -or ($o.Products.Count -gt 0) -or ($null -ne $o.Workstation))
  return $o
}
function Get-SysInfo{
  $r = [ordered]@{}
  $os=$null; $cs=$null; $nic=$null
  try{ $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop }catch{}
  try{ $cs  = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }catch{}
  try{ $nic = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop | Select-Object -First 1 }catch{}
  $r['Computer Name']   = $env:COMPUTERNAME
  $r['Username']        = $env:USERNAME
  $r['Windows Edition'] = Safe { $os.Caption }
  $r['Windows Version'] = Safe { $os.Version }
  $r['Build']           = Safe { $os.BuildNumber + '.' + (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).UBR }
  $r['Architecture']    = Safe { $os.OSArchitecture }
  if($cs -and $cs.PartOfDomain){ $r['Domain'] = [string]$cs.Domain; $r['Workgroup'] = 'NOT AVAILABLE (domain joined)' }
  else { $r['Domain'] = 'NOT DOMAIN JOINED'; $r['Workgroup'] = Safe { $cs.Workgroup } }
  $r['CPU']             = Safe { Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name | Select-Object -Unique }
  $r['RAM']             = Safe { '{0:N1} GB' -f ($cs.TotalPhysicalMemory / 1GB) }
  $r['GPU']             = Safe { Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name }
  $r['Disk']            = Safe { Get-CimInstance Win32_DiskDrive | ForEach-Object { '{0} ({1:N0} GB)' -f $_.Model,($_.Size / 1GB) } }
  $r['Free Disk Space'] = Safe { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { '{0} {1:N1} GB free of {2:N1} GB' -f $_.DeviceID,($_.FreeSpace / 1GB),($_.Size / 1GB) } }
  $r['Network Adapter'] = Safe { $nic.Description }
  $r['IPv4']            = Safe { $nic.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } }
  $r['IPv6']            = Safe { $nic.IPAddress | Where-Object { $_ -match ':' } }
  $r['MAC']             = Safe { $nic.MACAddress }
  $r['DNS']             = Safe { $nic.DNSServerSearchOrder }
  $r['Gateway']         = Safe { $nic.DefaultIPGateway }
  $r['Subnet / Prefix'] = Safe { $nic.IPSubnet }
  $r['DHCP Server']     = Safe { $nic.DHCPServer }
  $r['Link Speed']      = Safe { $m = ([string]$nic.MACAddress) -replace ':','-'; (Get-NetAdapter -ErrorAction Stop | Where-Object { $_.MacAddress -eq $m } | Select-Object -First 1).LinkSpeed }
  $r['DHCP Enabled']    = Safe { $nic.DHCPEnabled }
  $r['PowerShell']      = $PSVersionTable.PSVersion.ToString()
  $r['.NET Framework']  = Safe {
    $rel = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction Stop).Release
    $v = '4.x'
    if($rel -ge 533320){ $v='4.8.1' } elseif($rel -ge 528040){ $v='4.8' } elseif($rel -ge 461808){ $v='4.7.2' } elseif($rel -ge 461308){ $v='4.7.1' } elseif($rel -ge 460798){ $v='4.7' } elseif($rel -ge 394802){ $v='4.6.2' }
    ('{0} (release {1})' -f $v,$rel)
  }
  $r['UAC']             = Safe { if((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop).EnableLUA -eq 1){ 'ON' } else { 'OFF' } }
  if(Test-Admin){ $r['Administrator'] = 'YES' } else { $r['Administrator'] = 'NO' }
  $r['Firewall']        = Safe { Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object { $s='OFF'; if("$($_.Enabled)" -eq 'True'){ $s='ON' }; '{0}={1}' -f $_.Name,$s } }
  $r['Hyper-V']         = Safe { $s = Get-Service vmms -ErrorAction Stop; 'INSTALLED (vmms ' + ("$($s.Status)").ToUpper() + ')' } 'NOT INSTALLED'
  $vm = Get-VMwareInfo
  if($vm.Installed){ $r['VMware'] = 'DETECTED' } else { $r['VMware'] = 'NOT INSTALLED' }
  if(Get-Command wsl.exe -ErrorAction SilentlyContinue){ $r['WSL'] = 'AVAILABLE (wsl.exe present)' } else { $r['WSL'] = 'NOT INSTALLED' }
  return $r
}
function Page-SysInfo{
  Page 'SYSTEM INFORMATION' {
    $script:SI = Get-SysInfo
    Update-NetStatus
    foreach($k in $script:SI.Keys){
      $v = [string]$script:SI[$k]
      $col = 'White'
      if($v -like 'NOT *'){ $col = 'Yellow' } elseif($v -eq 'ON' -or $v -eq 'YES'){ $col = 'Green' } elseif($v -eq 'OFF' -or $v -eq 'NO'){ $col = 'Red' }
      W ('  {0,-18}: ' -f $k) Cyan -n
      W $v $col
    }
    $pv = [string]$script:Pub
    $pc = 'Green'; if($pv -like 'NOT *'){ $pc = 'Yellow' }
    W ('  {0,-18}: ' -f 'Public IP') Cyan -n
    W $pv $pc
    W '                      (Public IP comes from an Internet service and is checked at startup / on Refresh from the Main Menu.)' DarkGray
  }
}

# ------------------------------------------------------------------ input / navigation
function Read-Nav{
  while($true){
    $k  = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    $vk = [int]$k.VirtualKeyCode
    $ch = [string]$k.Character
    switch($vk){
      27  { return 'back' }
      13  { return 'enter' }
      38  { return 'up' }
      40  { return 'down' }
      36  { return 'first' }
      35  { return 'last' }
      33  { return 'pgup' }
      34  { return 'pgdn' }
      112 { return 'help' }
      116 { return 'refresh' }
    }
    if($vk -ge 113 -and $vk -le 123){ return ('F' + ($vk - 111)) }
    if($ch -match '^[0-9]$'){ return ('d' + $ch) }
    switch -regex ($ch){
      '^[bB]$' { return 'back' }
      '^[hH]$' { return 'home' }
      '^[rR]$' { return 'refresh' }
      '^[qQ]$' { return 'quit' }
      '^[sS]$' { return 'sample' }
      '^[aA]$' { return 'about' }
    }
  }
}
function Set-Jump([string]$k){
  switch($k){
    'F2'  { $script:Jump = { Page-SysInfo } }
    'F3'  { $script:Jump = { Menu-Network } }
    'F4'  { $script:Jump = { Menu-Firewall } }
    'F6'  { $script:Jump = { Menu-Services } }
    'F7'  { $script:Jump = { Menu-Processes } }
    'F8'  { $script:Jump = { Page-Roles } }
    'F9'  { $script:Jump = { Menu-GPO } }
    'F10' { $script:Jump = { Menu-WinTools } }
    'F11' { $script:Jump = $null }
    'F12' { $script:Jump = { Menu-CmdCenter } }
    default { $script:Jump = $null }
  }
  $script:GoHome = $true
}
function Page-Help{
  Head 'HELP'
  W '  KEYBOARD' Yellow
  W '  F1  Help            F2  System Information   F3  Network Center' White
  W '  F4  Firewall        F5  Refresh              F6  Services' White
  W '  F7  Processes       F8  Server Roles         F9  Group Policy' White
  W '  F10 Windows Tools   F11 Full Menu (Home)     F12 Command Center' White
  W '  ESC / B = Back      H = Home     R = Refresh     Q = Exit (asks Y/N)' White
  W '  A = About MCSA (from the Main Menu)     0 + ENTER = Back (inside About MCSA)' White
  W '  ENTER = Select      UP / DOWN / HOME / END / PAGE UP / PAGE DOWN = Move' White
  W '  Type the item number (two digits for menus with 10+ items, e.g. 07).' White
  W '  BASICS / EXPLAIN = last item of most menus: what each topic is, an example, and a real SAMPLE.' White
  W '  S = run the SAMPLE command shown on a BASICS page (risky samples ask Y/N first).' White
  W ''
  W '  NOTE: F11 may be captured by some terminals (fullscreen). Use H instead.' DarkGray
  W '  STATUS COLORS: green = success/ON, red = error/OFF, yellow = warning/NOT AVAILABLE, cyan = info.' DarkGray
  Wait-Key 'PRESS ANY KEY TO CLOSE HELP'
}
function Page([string]$Title,[scriptblock]$Body){
  while($true){
    if($script:Quit -or $script:GoHome){ return }
    Head $Title
    try{ & $Body | Out-Host }catch{ W ('  ERROR: ' + $_.Exception.Message) Red }
    W ''
    W '  [R/F5] Refresh   [B/ESC] Back   [H] Home   [F1] Help   [Q] Exit' Cyan
    $wait = $true
    while($wait){
      $a = Read-Nav
      switch -regex ($a){
        '^refresh$' { $wait = $false }
        '^back$'    { return }
        '^home$'    { $script:GoHome = $true; return }
        '^quit$'    { [void](Confirm-Exit); if($script:Quit){ return } }
        '^help$'    { Page-Help; $wait = $false }
        '^F\d+$'    { Set-Jump $a; return }
      }
    }
  }
}
function Show-Menu([string]$Title,[scriptblock]$Build,[switch]$Main){
  $sel = 0; $top = 0; $buf = ''
  $items = @(& $Build)
  $full = $true
  while($true){
    if($Main){
      if($script:Jump){ $j = $script:Jump; $script:Jump = $null; $script:GoHome = $false; & $j | Out-Host; $full = $true }
      $script:GoHome = $false
    }
    if($script:Quit){ return }
    if((-not $Main) -and $script:GoHome){ return }
    $w = ([string]$items.Count).Length
    if($full){ Head $Title; $script:Pos = $Host.UI.RawUI.CursorPosition; $full = $false }
    $vis = [Math]::Max(6,[Console]::WindowHeight - $script:Pos.Y - 7)
    if($items.Count -lt $vis){ $vis = $items.Count }
    if($sel -lt $top){ $top = $sel }
    if($sel -ge ($top + $vis)){ $top = $sel - $vis + 1 }
    $Host.UI.RawUI.CursorPosition = $script:Pos
    for($i = $top; $i -lt ($top + $vis); $i++){
      $txt = ('  [{0:D2}] {1}' -f ($i + 1),$items[$i].L)
      if($txt.Length -gt 76){ $txt = $txt.Substring(0,76) }
      $txt = $txt.PadRight(78)
      if($i -eq $sel){ Write-Host $txt -ForegroundColor Black -BackgroundColor Cyan }
      elseif($items[$i].L -like '*NOT AVAILABLE*'){ Write-Host $txt -ForegroundColor Yellow -BackgroundColor Black }
      else { Write-Host $txt -ForegroundColor White -BackgroundColor Black }
    }
    Write-Host (('=' * 78)) -ForegroundColor Blue
    Write-Host (('  Items {0}-{1} of {2}   Type number   UP/DOWN/HOME/END/PGUP/PGDN   ENTER=Select' -f ($top + 1),($top + $vis),$items.Count).PadRight(100)) -ForegroundColor Cyan
    Write-Host ('  [B/ESC] Back  [H] Home  [R/F5] Refresh  [F1] Help  [Q] Exit'.PadRight(100)) -ForegroundColor Cyan
    if($Main){ Write-Host ('  F2 SysInfo  F3 Network  F4 Firewall  F6 Services  F7 Processes  F8 Roles  F9 GPO  F10 Tools  F12 CMD  A About'.PadRight(100)) -ForegroundColor DarkGray }
    else     { Write-Host (''.PadRight(100)) }
    Write-Host (('  Input: ' + $buf).PadRight(100)) -ForegroundColor Yellow

    $run = $false
    $a = Read-Nav
    switch -regex ($a){
      '^up$'      { if($sel -gt 0){ $sel-- } else { $sel = $items.Count - 1 }; $buf = '' }
      '^down$'    { if($sel -lt ($items.Count - 1)){ $sel++ } else { $sel = 0 }; $buf = '' }
      '^first$'   { $sel = 0; $buf = '' }
      '^last$'    { $sel = $items.Count - 1; $buf = '' }
      '^pgup$'    { $sel = [Math]::Max(0,$sel - $vis); $buf = '' }
      '^pgdn$'    { $sel = [Math]::Min($items.Count - 1,$sel + $vis); $buf = '' }
      '^enter$'   { $run = $true; $buf = '' }
      '^d\d$'     {
        $buf += $a.Substring(1)
        if($buf.Length -ge $w){
          $n = [int]$buf; $buf = ''
          if($n -ge 1 -and $n -le $items.Count){ $sel = $n - 1; $run = $true }
        }
      }
      '^back$'    { if(-not $Main){ return } }
      '^home$'    { if(-not $Main){ $script:GoHome = $true; return } }
      '^refresh$' { $items = @(& $Build); if($Main){ W '  Refreshing system and network information...' Yellow; $script:SI = Get-SysInfo; Update-NetStatus -WithPublic }; $full = $true; $buf = '' }
      '^quit$'    { [void](Confirm-Exit); $full = $true }
      '^help$'    { Page-Help; $full = $true }
      '^about$'   { if($Main){ for($j = 0; $j -lt $items.Count; $j++){ if($items[$j].L -eq 'ABOUT MCSA'){ $sel = $j; $run = $true; break } }; $buf = '' } }
      '^F\d+$'    { Set-Jump $a; $full = $true; $buf = '' }
    }
    if($run){
      try{ $Host.UI.RawUI.FlushInputBuffer() }catch{}
      try{ & $items[$sel].A | Out-Host }catch{ Show-Result 'MENU ACTION' 'ERROR' $_.Exception.Message $_.Exception.HResult }
      $items = @(& $Build)
      if($sel -ge $items.Count){ $sel = 0 }
      $full = $true
    }
  }
}

# ------------------------------------------------------------------ execution engine
function Resolve-Tool([string]$f){
  $dirs = @("$env:windir\System32","$env:windir","$env:windir\System32\inetsrv","$env:windir\System32\wbem")
  foreach($d in $dirs){ $p = Join-Path $d $f; if(Test-Path -LiteralPath $p){ return $p } }
  $c = Get-Command $f -ErrorAction SilentlyContinue | Select-Object -First 1
  if($c -and $c.Source){ return $c.Source }
  return $null
}
# CHECK -> EXECUTE -> WAIT -> RETURN for MSC / CPL / EXE tools
function Invoke-Tool([string]$Kind,[string]$File){
  $act = 'OPEN ' + $File
  Head $act
  $p = Resolve-Tool $File
  if(-not $p){ Show-Result $act 'NOT AVAILABLE' ($File + ' was not found on this Windows edition / installed role set.'); return }
  W ('  Launching: ' + $p) Cyan
  W '  Close the tool window to return to the menu...' Yellow
  try{
    $pr = $null
    switch($Kind){
      'msc'   { $pr = Start-Process -FilePath "$env:windir\System32\mmc.exe" -ArgumentList ('"' + $p + '"') -Wait -PassThru -ErrorAction Stop }
      'cpl'   { $pr = Start-Process -FilePath "$env:windir\System32\rundll32.exe" -ArgumentList ('shell32.dll,Control_RunDLL "' + $p + '"') -Wait -PassThru -ErrorAction Stop }
      default { $pr = Start-Process -FilePath $p -Wait -PassThru -ErrorAction Stop }
    }
    $code = 0; if($pr){ $code = $pr.ExitCode }
    Show-Result $act 'SUCCESS' '' $code
  }catch{ Show-Result $act 'ERROR' $_.Exception.Message $_.Exception.HResult }
}
# Console command (cmd.exe) with validation, optional confirmation, real exit code
function Invoke-Con([string]$Name,[string]$Cmd,[switch]$Ask,[string]$Risk='',[switch]$NoHead){
  if(-not $NoHead){ Head ('ACTION: ' + $Name) }
  $exe = ($Cmd -split '\s+')[0]
  if(-not (Get-Command $exe -ErrorAction SilentlyContinue)){ Show-Result $Name 'NOT AVAILABLE' ($exe + ' was not found on this system.'); return }
  W ('  COMMAND: ' + $Cmd) Cyan
  $kbi = $script:KB[($exe.ToLower() -replace '\.exe$','')]
  if($kbi -and -not $NoHead){ W ('  WHAT IT DOES: ' + $kbi[0]) White }
  if($Risk){ W ('  RISK: ' + $Risk) Yellow }
  if($Ask){ if(-not (Ask-YN '  Run this command?')){ Show-Result $Name 'CANCELLED' 'Cancelled by user.'; return } }
  W ''
  try{
    & cmd.exe /c $Cmd | Out-Host
    $code = $LASTEXITCODE
  }catch{ Show-Result $Name 'ERROR' $_.Exception.Message $_.Exception.HResult; return }
  if($code -eq 0){ Show-Result $Name 'SUCCESS' '' $code }
  else { Show-Result $Name 'ERROR' 'The command returned a non-zero exit code (see output above).' $code }
}
# PowerShell action with cmdlet detection, optional confirmation and real error reporting
function Invoke-Ps([string]$Name,[scriptblock]$Do,[string]$Need='',[switch]$Ask,[string]$Desc='',[string]$Risk=''){
  Head ('ACTION: ' + $Name)
  if($Need -and -not (Get-Command $Need -ErrorAction SilentlyContinue)){ Show-Result $Name 'NOT AVAILABLE' ($Need + ' is not available on this system.'); return }
  if($Desc){ W ('  ' + $Desc) Cyan }
  if($Risk){ W ('  RISK: ' + $Risk) Yellow }
  if($Ask){ if(-not (Ask-YN '  Continue?')){ Show-Result $Name 'CANCELLED' 'Cancelled by user.'; return } }
  W ''
  try{
    $ErrorActionPreference = 'Stop'
    & $Do | Out-Host
    Show-Result $Name 'SUCCESS'
  }catch{ Show-Result $Name 'ERROR' $_.Exception.Message $_.Exception.HResult }
}
function Open-Url([string]$Name,[string]$Url){
  Head ('DOCUMENTATION: ' + $Name)
  W ('  URL: ' + $Url) Cyan
  try{ Start-Process $Url -ErrorAction Stop; Show-Result ('OPEN ' + $Name) 'SUCCESS' 'Opened in the default browser.' }
  catch{ Show-Result ('OPEN ' + $Name) 'ERROR' $_.Exception.Message $_.Exception.HResult }
}

# ------------------------------------------------------------------ menu item builders
function It([string]$l,[scriptblock]$a){ return @{ L = $l; A = $a } }
function mTool([string]$l,[string]$kind,[string]$file){
  $tag = ''; if(-not (Resolve-Tool $file)){ $tag = '   [NOT AVAILABLE]' }
  $sb = { Invoke-Tool $kind $file }.GetNewClosure()
  return @{ L = ($l + '  (' + $file + ')' + $tag); A = $sb }
}
function mCon([string]$l,[string]$cmd,[switch]$c,[string]$risk=''){
  $exe = ($cmd -split '\s+')[0]; $tag = ''
  if(-not (Get-Command $exe -ErrorAction SilentlyContinue)){ $tag = '   [NOT AVAILABLE]' }
  $ask = $c.IsPresent
  $sb = { if($ask){ Invoke-Con $l $cmd -Ask -Risk $risk } else { Invoke-Con $l $cmd -Risk $risk } }.GetNewClosure()
  return @{ L = ($l + $tag); A = $sb }
}
function mConHost([string]$l,[string]$fmt){
  $exe = ($fmt -split '\s+')[0]; $tag = ''
  if(-not (Get-Command $exe -ErrorAction SilentlyContinue)){ $tag = '   [NOT AVAILABLE]' }
  $sb = {
    Head ('ACTION: ' + $l)
    $h = Ask-Host 'Target host or IP'
    if($h){ Invoke-Con $l ($fmt -f $h) } else { Show-Result $l 'CANCELLED' 'No valid host given.' }
  }.GetNewClosure()
  return @{ L = ($l + $tag); A = $sb }
}
function mPs([string]$l,[string]$need,[scriptblock]$do,[switch]$c,[string]$desc='',[string]$risk=''){
  $tag = ''; if($need -and -not (Get-Command $need -ErrorAction SilentlyContinue)){ $tag = '   [NOT AVAILABLE]' }
  $ask = $c.IsPresent
  $sb = { if($ask){ Invoke-Ps $l $do $need -Ask -Desc $desc -Risk $risk } else { Invoke-Ps $l $do $need -Desc $desc -Risk $risk } }.GetNewClosure()
  return @{ L = ($l + $tag); A = $sb }
}
function mPage([string]$l,[scriptblock]$body,[string]$need=''){
  $tag = ''; if($need -and -not (Get-Command $need -ErrorAction SilentlyContinue)){ $tag = '   [NOT AVAILABLE]' }
  $sb = { Page $l $body }.GetNewClosure()
  return @{ L = ($l + $tag); A = $sb }
}
function mDoc([string]$l,[string]$u){
  $sb = { Open-Url $l $u }.GetNewClosure()
  return @{ L = $l; A = $sb }
}
function mNoop([string]$l){ return @{ L = $l; A = { } } }

# ------------------------------------------------------------------ WINDOWS TOOLS / CONTROL PANEL
function Menu-WinTools{ Show-Menu 'WINDOWS TOOLS' {
  @(
    (mTool 'Services' 'msc' 'services.msc'),
    (mTool 'Event Viewer' 'msc' 'eventvwr.msc'),
    (mTool 'Computer Management' 'msc' 'compmgmt.msc'),
    (mTool 'Disk Management' 'msc' 'diskmgmt.msc'),
    (mTool 'Device Manager' 'msc' 'devmgmt.msc'),
    (mTool 'Task Scheduler' 'msc' 'taskschd.msc'),
    (mTool 'Local Security Policy' 'msc' 'secpol.msc'),
    (mTool 'Local Group Policy Editor' 'msc' 'gpedit.msc'),
    (mTool 'Group Policy Management' 'msc' 'gpmc.msc'),
    (mTool 'Performance Monitor' 'msc' 'perfmon.msc'),
    (mTool 'Resource Monitor' 'exe' 'resmon.exe'),
    (mTool 'Component Services (DCOM)' 'exe' 'dcomcnfg.exe'),
    (mTool 'Certificates (current user)' 'msc' 'certmgr.msc'),
    (mTool 'Local Users and Groups' 'msc' 'lusrmgr.msc'),
    (mTool 'Shared Folders' 'msc' 'fsmgmt.msc'),
    (mTool 'WMI Control' 'msc' 'wmimgmt.msc'),
    (mTool 'Firewall with Advanced Security' 'msc' 'wf.msc'),
    (mTool 'IIS Manager' 'exe' 'inetmgr.exe'),
    (mTool 'Registry Editor' 'exe' 'regedit.exe'),
    (mTool 'System Configuration' 'exe' 'msconfig.exe'),
    (mTool 'Task Manager' 'exe' 'taskmgr.exe')
  )
}}
function Menu-CPL{ Show-Menu 'CONTROL PANEL' {
  @(
    (mTool 'Windows Firewall' 'cpl' 'firewall.cpl'),
    (mTool 'Network Connections' 'cpl' 'ncpa.cpl'),
    (mTool 'Programs and Features' 'cpl' 'appwiz.cpl'),
    (mTool 'Internet Options' 'cpl' 'inetcpl.cpl'),
    (mTool 'System Properties' 'cpl' 'sysdm.cpl'),
    (mTool 'Power Options' 'cpl' 'powercfg.cpl'),
    (mTool 'Mouse Properties' 'cpl' 'main.cpl'),
    (mTool 'Date and Time' 'cpl' 'timedate.cpl'),
    (mTool 'Region and Language' 'cpl' 'intl.cpl'),
    (mTool 'Display (classic)' 'cpl' 'desk.cpl'),
    (mTool 'Sound' 'cpl' 'mmsys.cpl'),
    (mTool 'Add Hardware Wizard' 'cpl' 'hdwwiz.cpl'),
    (mTool 'Control Panel (all items)' 'exe' 'control.exe')
  )
}}

# ------------------------------------------------------------------ NETWORK
function Page-NetDiag{
  Page 'NETWORK DIAGNOSTICS' {
    $cfgs = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')
    if($cfgs.Count -eq 0){ W '  No IP-enabled network adapter found.' Red }
    foreach($c in $cfgs){
      W ('  ADAPTER : ' + $c.Description) Cyan
      W ('  IP      : ' + ($c.IPAddress -join ', ')) White
      W ('  GATEWAY : ' + ($c.DefaultIPGateway -join ', ')) White
      W ('  DNS     : ' + ($c.DNSServerSearchOrder -join ', ')) White
      foreach($g in @($c.DefaultIPGateway)){
        if($g){ $ok = Test-Connection -ComputerName $g -Count 2 -Quiet -ErrorAction SilentlyContinue; if($ok){ W ('  Gateway ' + $g + ' : REACHABLE') Green } else { W ('  Gateway ' + $g + ' : NOT REACHABLE') Red } }
      }
      foreach($d in @($c.DNSServerSearchOrder)){
        if($d){ $ok = Test-Connection -ComputerName $d -Count 2 -Quiet -ErrorAction SilentlyContinue; if($ok){ W ('  DNS ' + $d + ' : REACHABLE') Green } else { W ('  DNS ' + $d + ' : NOT REACHABLE') Red } }
      }
      W ''
    }
    try{ $ips = [Net.Dns]::GetHostAddresses('microsoft.com'); W ('  DNS resolution microsoft.com : OK (' + ($ips[0].ToString()) + ')') Green }
    catch{ W '  DNS resolution microsoft.com : FAILED' Red }
  }
}
function Menu-Network{ Show-Menu 'NETWORK CENTER' {
  @(
    (mPage 'Show Network Adapters' { Show (Get-NetAdapter | Format-Table Name,InterfaceDescription,Status,LinkSpeed,MacAddress -AutoSize) } 'Get-NetAdapter'),
    (mPage 'Show IP Configuration' { ipconfig /all }),
    (mPage 'Show DNS' { Show (Get-DnsClientServerAddress | Format-Table InterfaceAlias,AddressFamily,ServerAddresses -AutoSize) } 'Get-DnsClientServerAddress'),
    (mPage 'Show Gateway' { Show (Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Format-Table InterfaceAlias,NextHop,RouteMetric -AutoSize) } 'Get-NetRoute'),
    (mPage 'Show MAC' { getmac /v }),
    (mConHost 'Ping' 'ping -n 4 {0}'),
    (mConHost 'Tracert' 'tracert {0}'),
    (mConHost 'PathPing' 'pathping {0}'),
    (mConHost 'NSLookup' 'nslookup {0}'),
    (mPage 'Netstat' { netstat -ano }),
    (mPage 'ARP' { arp -a }),
    (mPage 'Route Table' { route print }),
    (mPage 'DNS Cache' { ipconfig /displaydns }),
    (mCon 'Flush DNS' 'ipconfig /flushdns'),
    (mCon 'Release IP' 'ipconfig /release' -c -risk 'HIGH - network connection drops until renewed (remote sessions may be lost).'),
    (mCon 'Renew IP' 'ipconfig /renew' -c -risk 'MEDIUM - IP address may change.'),
    (mTool 'Network Connections' 'cpl' 'ncpa.cpl'),
    (mCon 'Winsock Reset' 'netsh winsock reset' -c -risk 'HIGH - resets Winsock catalog; reboot required.'),
    (mCon 'TCP/IP Reset' 'netsh int ip reset' -c -risk 'HIGH - resets TCP/IP stack; reboot required.'),
    (mSub 'Network Diagnostics' { Page-NetDiag }),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'NET' 'NETWORK CENTER' })
  )
}}
function mSub([string]$l,[scriptblock]$go){ return @{ L = $l; A = $go } }

# ------------------------------------------------------------------ FIREWALL
function Menu-Firewall{ Show-Menu 'FIREWALL AND SECURITY' {
  @(
    (mPage 'Firewall Status' { Show (Get-NetFirewallProfile | Format-Table Name,Enabled,DefaultInboundAction,DefaultOutboundAction -AutoSize) } 'Get-NetFirewallProfile'),
    (mPage 'Domain Profile' { Show (Get-NetFirewallProfile -Name Domain | Format-List Name,Enabled,DefaultInboundAction,DefaultOutboundAction,LogFileName,LogAllowed,LogBlocked) } 'Get-NetFirewallProfile'),
    (mPage 'Private Profile' { Show (Get-NetFirewallProfile -Name Private | Format-List Name,Enabled,DefaultInboundAction,DefaultOutboundAction,LogFileName,LogAllowed,LogBlocked) } 'Get-NetFirewallProfile'),
    (mPage 'Public Profile' { Show (Get-NetFirewallProfile -Name Public | Format-List Name,Enabled,DefaultInboundAction,DefaultOutboundAction,LogFileName,LogAllowed,LogBlocked) } 'Get-NetFirewallProfile'),
    (mPs 'Enable Firewall (all profiles)' 'Set-NetFirewallProfile' { Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True; Get-NetFirewallProfile | Format-Table Name,Enabled -AutoSize } -c -desc 'Turns Windows Firewall ON for Domain, Private and Public profiles.'),
    (mPs 'Disable Firewall (all profiles)' 'Set-NetFirewallProfile' { Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False; Get-NetFirewallProfile | Format-Table Name,Enabled -AutoSize } -c -desc 'Turns Windows Firewall OFF for all profiles.' -risk 'HIGH - the machine is exposed without firewall protection.'),
    (mTool 'Open firewall.cpl' 'cpl' 'firewall.cpl'),
    (mTool 'Open Advanced Firewall' 'msc' 'wf.msc'),
    (mPage 'Inbound Rules (enabled)' { Show (Get-NetFirewallRule -Direction Inbound -Enabled True | Sort-Object DisplayName | Format-Table DisplayName,Profile,Action -AutoSize) -Paged } 'Get-NetFirewallRule'),
    (mPage 'Outbound Rules (enabled)' { Show (Get-NetFirewallRule -Direction Outbound -Enabled True | Sort-Object DisplayName | Format-Table DisplayName,Profile,Action -AutoSize) -Paged } 'Get-NetFirewallRule'),
    (mPs 'Search Rule' 'Get-NetFirewallRule' {
        $q = (Read-Host '  Text to search in rule names').Trim()
        if($q -eq ''){ throw 'Empty search text.' }
        Show (Get-NetFirewallRule -DisplayName ('*' + $q + '*') | Format-Table DisplayName,Enabled,Direction,Action -AutoSize) -Paged
      }),
    (mPs 'Enable Rule' 'Enable-NetFirewallRule' {
        $n = (Read-Host '  Exact rule DisplayName').Trim()
        if(-not (Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue)){ throw ('Rule not found: ' + $n) }
        if(Ask-YN ('  Enable rule "' + $n + '"?')){ Enable-NetFirewallRule -DisplayName $n; W '  Rule enabled.' Green } else { W '  Cancelled.' Yellow }
      }),
    (mPs 'Disable Rule' 'Disable-NetFirewallRule' {
        $n = (Read-Host '  Exact rule DisplayName').Trim()
        if(-not (Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue)){ throw ('Rule not found: ' + $n) }
        if(Ask-YN ('  Disable rule "' + $n + '"?')){ Disable-NetFirewallRule -DisplayName $n; W '  Rule disabled.' Green } else { W '  Cancelled.' Yellow }
      } -risk 'MEDIUM'),
    (mPs 'Delete Rule' 'Remove-NetFirewallRule' {
        $n = (Read-Host '  Exact rule DisplayName').Trim()
        if(-not (Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue)){ throw ('Rule not found: ' + $n) }
        if(Ask-YN ('  PERMANENTLY delete rule "' + $n + '"?')){ Remove-NetFirewallRule -DisplayName $n; W '  Rule deleted.' Green } else { W '  Cancelled.' Yellow }
      } -risk 'HIGH - deletion cannot be undone.'),
    (mPs 'Add Port Rule' 'New-NetFirewallRule' {
        $n  = (Read-Host '  Rule name').Trim()
        $pr = (Read-Host '  Protocol (TCP/UDP)').Trim().ToUpper()
        $pt = (Read-Host '  Port (1-65535 or range like 8000-8100)').Trim()
        $d  = (Read-Host '  Direction (Inbound/Outbound)').Trim()
        $ac = (Read-Host '  Action (Allow/Block)').Trim()
        if($n -eq ''){ throw 'Rule name is empty.' }
        if($pr -ne 'TCP' -and $pr -ne 'UDP'){ throw 'Protocol must be TCP or UDP.' }
        if($pt -notmatch '^\d{1,5}(-\d{1,5})?$'){ throw 'Invalid port.' }
        if($d -notin @('Inbound','Outbound')){ throw 'Direction must be Inbound or Outbound.' }
        if($ac -notin @('Allow','Block')){ throw 'Action must be Allow or Block.' }
        if(-not (Ask-YN ('  Create rule "' + $n + '" (' + $pr + ' ' + $pt + ' ' + $d + ' ' + $ac + ')?'))){ W '  Cancelled.' Yellow; return }
        if($d -eq 'Inbound'){ New-NetFirewallRule -DisplayName $n -Direction Inbound -Protocol $pr -LocalPort $pt -Action $ac | Out-Null }
        else { New-NetFirewallRule -DisplayName $n -Direction Outbound -Protocol $pr -RemotePort $pt -Action $ac | Out-Null }
        W '  Rule created.' Green
      }),
    (mPs 'Add Program Rule' 'New-NetFirewallRule' {
        $n  = (Read-Host '  Rule name').Trim()
        $pg = (Read-Host '  Full path of the program (.exe)').Trim().Trim('"')
        $d  = (Read-Host '  Direction (Inbound/Outbound)').Trim()
        $ac = (Read-Host '  Action (Allow/Block)').Trim()
        if($n -eq ''){ throw 'Rule name is empty.' }
        if(-not (Test-Path -LiteralPath $pg -PathType Leaf)){ throw ('Program not found: ' + $pg) }
        if($d -notin @('Inbound','Outbound')){ throw 'Direction must be Inbound or Outbound.' }
        if($ac -notin @('Allow','Block')){ throw 'Action must be Allow or Block.' }
        if(-not (Ask-YN ('  Create program rule "' + $n + '"?'))){ W '  Cancelled.' Yellow; return }
        New-NetFirewallRule -DisplayName $n -Direction $d -Program $pg -Action $ac | Out-Null
        W '  Rule created.' Green
      }),
    (mPs 'Export Rules (to Desktop .wfw)' 'netsh' {
        $f = Join-Path ([Environment]::GetFolderPath('Desktop')) ('FirewallRules_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.wfw')
        netsh advfirewall export $f
        if($LASTEXITCODE -ne 0){ throw ('netsh returned exit code ' + $LASTEXITCODE) }
        W ('  Exported to: ' + $f) Green
      }),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'FW' 'FIREWALL AND SECURITY' })
  )
}}

# ------------------------------------------------------------------ SERVICES
function Menu-Services{ Show-Menu 'SERVICES' {
  @(
    (mPage 'All Services' { Show (Get-Service | Sort-Object Name | Format-Table Status,Name,DisplayName -AutoSize) -Paged } 'Get-Service'),
    (mPage 'Running Services' { Show (Get-Service | Where-Object { "$($_.Status)" -eq 'Running' } | Sort-Object Name | Format-Table Status,Name,DisplayName -AutoSize) -Paged } 'Get-Service'),
    (mPage 'Stopped Services' { Show (Get-Service | Where-Object { "$($_.Status)" -eq 'Stopped' } | Sort-Object Name | Format-Table Status,Name,DisplayName -AutoSize) -Paged } 'Get-Service'),
    (mPs 'Search Service' 'Get-Service' {
        $q = (Read-Host '  Text to search (name or display name)').Trim()
        if($q -eq ''){ throw 'Empty search text.' }
        Show (Get-Service | Where-Object { $_.Name -like ('*' + $q + '*') -or $_.DisplayName -like ('*' + $q + '*') } | Format-Table Status,Name,DisplayName -AutoSize) -Paged
      }),
    (mPs 'Start Service' 'Start-Service' {
        $n = (Read-Host '  Service name').Trim()
        $s = Get-Service -Name $n -ErrorAction Stop
        Start-Service -Name $s.Name -ErrorAction Stop
        Show (Get-Service -Name $s.Name | Format-Table Status,Name,DisplayName -AutoSize)
      }),
    (mPs 'Stop Service' 'Stop-Service' {
        $n = (Read-Host '  Service name').Trim()
        $s = Get-Service -Name $n -ErrorAction Stop
        if(-not (Ask-YN ('  Stop service "' + $s.Name + '" (' + $s.DisplayName + ')?'))){ W '  Cancelled.' Yellow; return }
        Stop-Service -Name $s.Name -ErrorAction Stop
        Show (Get-Service -Name $s.Name | Format-Table Status,Name,DisplayName -AutoSize)
      } -risk 'MEDIUM - dependent services/features may stop working.'),
    (mPs 'Restart Service' 'Restart-Service' {
        $n = (Read-Host '  Service name').Trim()
        $s = Get-Service -Name $n -ErrorAction Stop
        if(-not (Ask-YN ('  Restart service "' + $s.Name + '"?'))){ W '  Cancelled.' Yellow; return }
        Restart-Service -Name $s.Name -ErrorAction Stop
        Show (Get-Service -Name $s.Name | Format-Table Status,Name,DisplayName -AutoSize)
      } -risk 'MEDIUM'),
    (mPs 'Service Details' 'Get-CimInstance' {
        $n = (Read-Host '  Service name').Trim()
        $s = Get-CimInstance Win32_Service -Filter ("Name='" + ($n -replace "'","''") + "'")
        if(-not $s){ throw ('Service not found: ' + $n) }
        Show ($s | Format-List Name,DisplayName,State,StartMode,StartName,ProcessId,PathName,Description)
      }),
    (mTool 'Open services.msc' 'msc' 'services.msc'),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'SVC' 'SERVICES' })
  )
}}

# ------------------------------------------------------------------ PROCESSES
function Menu-Processes{ Show-Menu 'PROCESSES' {
  @(
    (mPage 'All Processes' { Show (Get-Process | Sort-Object ProcessName | Format-Table Id,ProcessName,@{n='CPU(s)';e={[math]::Round($_.CPU,1)}},@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize) -Paged } 'Get-Process'),
    (mPs 'Search Process' 'Get-Process' {
        $q = (Read-Host '  Process name (part of it)').Trim()
        if($q -eq ''){ throw 'Empty search text.' }
        Show (Get-Process | Where-Object { $_.ProcessName -like ('*' + $q + '*') } | Format-Table Id,ProcessName,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize)
      }),
    (mPs 'Process by ID' 'Get-Process' {
        $t = (Read-Host '  Process ID').Trim()
        if($t -notmatch '^\d+$'){ throw 'Process ID must be a number.' }
        Show (Get-Process -Id ([int]$t) -ErrorAction Stop | Format-List Id,ProcessName,Path,StartTime,Responding,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}})
      }),
    (mPage 'Top 25 by CPU' { Show (Get-Process | Where-Object { $_.CPU } | Sort-Object CPU -Descending | Select-Object -First 25 | Format-Table Id,ProcessName,@{n='CPU(s)';e={[math]::Round($_.CPU,1)}},@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize) } 'Get-Process'),
    (mPage 'Top 25 by RAM' { Show (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 25 | Format-Table Id,ProcessName,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize) } 'Get-Process'),
    (mPs 'Kill Process' 'Stop-Process' {
        $t = (Read-Host '  Process ID to kill').Trim()
        if($t -notmatch '^\d+$'){ throw 'Process ID must be a number.' }
        $p = Get-Process -Id ([int]$t) -ErrorAction Stop
        if($p.ProcessName -in @('System','Idle','csrss','wininit','winlogon','lsass','services','smss')){ throw ('Refusing to kill critical system process: ' + $p.ProcessName) }
        if(-not (Ask-YN ('  Kill ' + $p.ProcessName + ' (PID ' + $p.Id + ')?'))){ W '  Cancelled.' Yellow; return }
        Stop-Process -Id $p.Id -Force -ErrorAction Stop
        W '  Process terminated.' Green
      } -risk 'HIGH - unsaved data in that process is lost.'),
    (mTool 'Open Task Manager' 'exe' 'taskmgr.exe'),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'PROC' 'PROCESSES' })
  )
}}

# ------------------------------------------------------------------ USERS & GROUPS
function Menu-Users{ Show-Menu 'USERS AND GROUPS' {
  @(
    (mPage 'List Users' { Show (Get-LocalUser | Format-Table Name,Enabled,LastLogon,PasswordRequired,Description -AutoSize) } 'Get-LocalUser'),
    (mPs 'User Details' 'Get-LocalUser' { $n = (Read-Host '  User name').Trim(); Show (Get-LocalUser -Name $n -ErrorAction Stop | Format-List *) }),
    (mPage 'Local Groups' { Show (Get-LocalGroup | Format-Table Name,Description -AutoSize) } 'Get-LocalGroup'),
    (mPs 'Group Members' 'Get-LocalGroupMember' { $n = (Read-Host '  Group name (e.g. Administrators)').Trim(); Show (Get-LocalGroupMember -Group $n -ErrorAction Stop | Format-Table Name,ObjectClass,PrincipalSource -AutoSize) }),
    (mPs 'Create User' 'New-LocalUser' {
        $n = (Read-Host '  New user name').Trim()
        if($n -notmatch '^[A-Za-z0-9._-]{1,20}$'){ throw 'Invalid name (letters, digits, . _ - ; max 20).' }
        if(Get-LocalUser -Name $n -ErrorAction SilentlyContinue){ throw ('User already exists: ' + $n) }
        $p1 = Read-Host '  Password' -AsSecureString
        $p2 = Read-Host '  Confirm password' -AsSecureString
        $s1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
        $s2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
        $same = ($s1 -ceq $s2); $s1 = $null; $s2 = $null
        if(-not $same){ throw 'Passwords do not match.' }
        if(-not (Ask-YN ('  Create local user "' + $n + '"?'))){ W '  Cancelled.' Yellow; return }
        New-LocalUser -Name $n -Password $p1 | Out-Null
        W '  User created.' Green
      } -risk 'MEDIUM - creates a new account. The password is never displayed or logged.'),
    (mPs 'Enable User' 'Enable-LocalUser' { $n = (Read-Host '  User name').Trim(); Get-LocalUser -Name $n -ErrorAction Stop | Out-Null; Enable-LocalUser -Name $n -ErrorAction Stop; W '  User enabled.' Green }),
    (mPs 'Disable User' 'Disable-LocalUser' {
        $n = (Read-Host '  User name').Trim(); Get-LocalUser -Name $n -ErrorAction Stop | Out-Null
        if(-not (Ask-YN ('  Disable user "' + $n + '"?'))){ W '  Cancelled.' Yellow; return }
        Disable-LocalUser -Name $n -ErrorAction Stop; W '  User disabled.' Green
      } -risk 'MEDIUM'),
    (mPs 'Delete User' 'Remove-LocalUser' {
        $n = (Read-Host '  User name').Trim(); Get-LocalUser -Name $n -ErrorAction Stop | Out-Null
        if($n -ieq $env:USERNAME){ throw 'Refusing to delete the account you are logged in with.' }
        if(-not (Ask-YN ('  PERMANENTLY delete user "' + $n + '"?'))){ W '  Cancelled.' Yellow; return }
        Remove-LocalUser -Name $n -ErrorAction Stop; W '  User deleted.' Green
      } -risk 'HIGH - cannot be undone.'),
    (mPs 'Change Password' 'Set-LocalUser' {
        $n = (Read-Host '  User name').Trim(); Get-LocalUser -Name $n -ErrorAction Stop | Out-Null
        $p1 = Read-Host '  New password' -AsSecureString
        $p2 = Read-Host '  Confirm new password' -AsSecureString
        $s1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
        $s2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
        $same = ($s1 -ceq $s2); $s1 = $null; $s2 = $null
        if(-not $same){ throw 'Passwords do not match.' }
        if(-not (Ask-YN ('  Change password of "' + $n + '"?'))){ W '  Cancelled.' Yellow; return }
        Set-LocalUser -Name $n -Password $p1 -ErrorAction Stop; W '  Password changed.' Green
      } -risk 'MEDIUM - the password is never displayed or logged.'),
    (mTool 'Open lusrmgr.msc' 'msc' 'lusrmgr.msc'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'USR' 'USERS AND GROUPS' })
  )
}}

# ------------------------------------------------------------------ GROUP POLICY
function Menu-GPO{ Show-Menu 'GROUP POLICY' {
  @(
    (mTool 'Local Group Policy Editor' 'msc' 'gpedit.msc'),
    (mTool 'Group Policy Management' 'msc' 'gpmc.msc'),
    (mCon 'gpupdate /force' 'gpupdate /force' -c -risk 'LOW - refreshes policies; may log you off if required.'),
    (mCon 'gpresult /r' 'gpresult /r'),
    (mPs 'gpresult /h (HTML report on Desktop)' 'gpresult' {
        $f = Join-Path ([Environment]::GetFolderPath('Desktop')) ('GPResult_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.html')
        gpresult /h $f /f
        if($LASTEXITCODE -ne 0){ throw ('gpresult returned exit code ' + $LASTEXITCODE) }
        W ('  Report saved: ' + $f) Green
      }),
    (mTool 'Resultant Set of Policy' 'msc' 'rsop.msc'),
    (mPage 'Group Policy Status (computer scope)' { gpresult /scope computer /r } 'gpresult'),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'GPO' 'GROUP POLICY' })
  )
}}

# ------------------------------------------------------------------ ACTIVE DIRECTORY / DNS / DHCP / IIS
function Menu-AD{ Show-Menu 'ACTIVE DIRECTORY' {
  @(
    (mPage 'Active Directory Status' {
        $ntds = Get-Service NTDS -ErrorAction SilentlyContinue
        $tools = @('dsa.msc','dssite.msc','domain.msc','dsac.exe') | Where-Object { Resolve-Tool $_ }
        if(-not $ntds -and -not $tools){ W '  ACTIVE DIRECTORY NOT INSTALLED' Yellow }
        if($ntds){ W ('  NTDS (AD DS) service : ' + ("$($ntds.Status)").ToUpper()) Green } else { W '  NTDS (AD DS) service : NOT INSTALLED' Yellow }
        if($tools){ W ('  AD tools present     : ' + ($tools -join ', ')) Green } else { W '  AD management tools  : NOT INSTALLED' Yellow }
        try{ $cs = Get-CimInstance Win32_ComputerSystem; if($cs.PartOfDomain){ W ('  Domain membership    : ' + $cs.Domain) White } else { W '  Domain membership    : NOT DOMAIN JOINED' Yellow } }catch{}
      }),
    (mTool 'AD Users and Computers' 'msc' 'dsa.msc'),
    (mTool 'AD Sites and Services' 'msc' 'dssite.msc'),
    (mTool 'AD Domains and Trusts' 'msc' 'domain.msc'),
    (mTool 'AD Administrative Center' 'exe' 'dsac.exe'),
    (mTool 'Group Policy Management' 'msc' 'gpmc.msc'),
    (mCon 'dcdiag' 'dcdiag' -c -risk 'LOW - read-only diagnostics (domain controllers only).'),
    (mCon 'repadmin /replsummary' 'repadmin /replsummary'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'AD' 'ACTIVE DIRECTORY' })
  )
}}
function Menu-DNS{ Show-Menu 'DNS' {
  @(
    (mPage 'DNS Status' {
        $s = Get-Service DNS -ErrorAction SilentlyContinue
        if(-not $s){ W '  DNS SERVER NOT INSTALLED' Yellow } else {
          W ('  DNS Server service: ' + ("$($s.Status)").ToUpper()) Green
          if(Get-Command Get-DnsServerZone -ErrorAction SilentlyContinue){ Show (Get-DnsServerZone | Format-Table ZoneName,ZoneType,IsDsIntegrated -AutoSize) }
        }
        $c = Get-Service Dnscache -ErrorAction SilentlyContinue
        if($c){ W ('  DNS Client service: ' + ("$($c.Status)").ToUpper()) White }
      }),
    (mTool 'DNS Manager' 'msc' 'dnsmgmt.msc'),
    (mPage 'DNS Service' { Show (Get-Service DNS,Dnscache -ErrorAction SilentlyContinue | Format-Table Status,Name,DisplayName,StartType -AutoSize) } 'Get-Service'),
    (mPage 'DNS Cache' { ipconfig /displaydns }),
    (mConHost 'NSLookup' 'nslookup {0}'),
    (mPage 'DNS Information' { Show (Get-DnsClientServerAddress | Format-Table InterfaceAlias,AddressFamily,ServerAddresses -AutoSize); Show (Get-DnsClient | Format-Table InterfaceAlias,ConnectionSpecificSuffix,RegisterThisConnectionsAddress -AutoSize) } 'Get-DnsClient'),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'DNS' 'DNS' })
  )
}}
function Menu-DHCP{ Show-Menu 'DHCP' {
  @(
    (mPage 'DHCP Status' {
        $s = Get-Service DHCPServer -ErrorAction SilentlyContinue
        if(-not $s){ W '  DHCP SERVER NOT INSTALLED' Yellow } else {
          W ('  DHCP Server service: ' + ("$($s.Status)").ToUpper()) Green
          if(Get-Command Get-DhcpServerv4Scope -ErrorAction SilentlyContinue){ Show (Get-DhcpServerv4Scope | Format-Table ScopeId,Name,State,StartRange,EndRange -AutoSize) }
        }
        $c = Get-Service Dhcp -ErrorAction SilentlyContinue
        if($c){ W ('  DHCP Client service: ' + ("$($c.Status)").ToUpper()) White }
      }),
    (mTool 'DHCP Manager' 'msc' 'dhcpmgmt.msc'),
    (mPage 'DHCP Service' { Show (Get-Service DHCPServer,Dhcp -ErrorAction SilentlyContinue | Format-Table Status,Name,DisplayName,StartType -AutoSize) } 'Get-Service'),
    (mPage 'DHCP Information (client)' { ipconfig /all | Select-String -Pattern 'Description|DHCP' }),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'DHCP' 'DHCP' })
  )
}}
function Test-IIS{
  $s = Get-Service W3SVC -ErrorAction SilentlyContinue
  if(-not $s){ W '  IIS NOT INSTALLED' Yellow; return $false }
  try{ Import-Module WebAdministration -ErrorAction Stop }catch{ W '  IIS management module (WebAdministration) NOT AVAILABLE' Yellow; return $false }
  return $true
}
function Menu-IIS{ Show-Menu 'IIS' {
  @(
    (mTool 'IIS Manager' 'exe' 'inetmgr.exe'),
    (mPage 'Sites' { if(Test-IIS){ Show (Get-Website | Format-Table Name,Id,State,PhysicalPath -AutoSize) } }),
    (mPage 'Applications' { if(Test-IIS){ Show (Get-WebApplication | Format-Table Path,ApplicationPool,PhysicalPath -AutoSize) } }),
    (mPage 'Application Pools' { if(Test-IIS){ Show (Get-ChildItem IIS:\AppPools | Format-Table Name,State,managedRuntimeVersion -AutoSize) } }),
    (mPage 'Bindings' { if(Test-IIS){ Show (Get-WebBinding | Format-Table protocol,bindingInformation -AutoSize) } }),
    (mPage 'IIS Services' { $s = Get-Service W3SVC,WAS,IISADMIN -ErrorAction SilentlyContinue; if($s){ Show ($s | Format-Table Status,Name,DisplayName -AutoSize) } else { W '  IIS NOT INSTALLED' Yellow } }),
    (mPage 'IIS Status' { if(Test-IIS){ $s = Get-Service W3SVC; W ('  World Wide Web Publishing Service: ' + ("$($s.Status)").ToUpper()) Green; W ('  Sites: ' + @(Get-Website).Count) White } }),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'IIS' 'IIS' })
  )
}}

# ------------------------------------------------------------------ SERVER ROLES / FEATURES
function Page-Roles{
  Page 'SERVER ROLES' {
    W '  Querying installed roles and features (may take a few seconds)...' Yellow
    $isSrv = [bool](Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue)
    $state = @{}
    $all = $null
    if($isSrv){
      try{ $all = Get-WindowsFeature -ErrorAction Stop; foreach($f in $all){ $state[$f.Name] = ("$($f.InstallState)" -eq 'Installed') } }
      catch{ W ('  Get-WindowsFeature failed: ' + $_.Exception.Message) Red; $isSrv = $false }
    }
    if(-not $isSrv){
      try{ Get-WindowsOptionalFeature -Online -ErrorAction Stop | ForEach-Object { $state[$_.FeatureName] = ("$($_.State)" -eq 'Enabled') } }
      catch{ W ('  Get-WindowsOptionalFeature failed: ' + $_.Exception.Message) Red }
    }
    $roles = @(
      @('AD DS','AD-Domain-Services',''),
      @('DNS','DNS',''),
      @('DHCP','DHCP',''),
      @('IIS','Web-Server','IIS-WebServerRole'),
      @('File Services','FS-FileServer',''),
      @('Print Services','Print-Services','Printing-Foundation-Features'),
      @('Hyper-V','Hyper-V','Microsoft-Hyper-V-All'),
      @('Remote Desktop Services','Remote-Desktop-Services',''),
      @('NPS','NPAS',''),
      @('Routing','Routing',''),
      @('Remote Access','RemoteAccess',''),
      @('Windows Server Backup','Windows-Server-Backup',''),
      @('Failover Clustering','Failover-Clustering',''),
      @('Storage Replica','Storage-Replica',''),
      @('Data Deduplication','FS-Data-Deduplication',''),
      @('BitLocker','BitLocker',''),
      @('Containers','Containers','Containers'),
      @('Multipath I/O','Multipath-IO',''),
      @('RSAT','RSAT','')
    )
    if($isSrv){ W '  Edition type: WINDOWS SERVER' Cyan } else { W '  Edition type: WINDOWS CLIENT (server roles need Windows Server)' Cyan }
    W ''
    foreach($r in $roles){
      $id = $r[1]; if(-not $isSrv){ $id = $r[2] }
      $st = 'NOT AVAILABLE'; $col = 'Yellow'
      if($id -and $state.ContainsKey($id)){
        if($state[$id]){ $st = 'INSTALLED'; $col = 'Green' } else { $st = 'NOT INSTALLED'; $col = 'Yellow' }
      } elseif(-not $isSrv){
        if($r[0] -eq 'BitLocker' -and (Get-Command manage-bde -ErrorAction SilentlyContinue)){ $st = 'AVAILABLE (see Storage > BitLocker)'; $col = 'Cyan' }
        if($r[0] -eq 'RSAT'){
          try{ $cap = @(Get-WindowsCapability -Online -Name 'Rsat*' -ErrorAction Stop | Where-Object { "$($_.State)" -eq 'Installed' }); if($cap.Count -gt 0){ $st = ('INSTALLED (' + $cap.Count + ' tools)'); $col = 'Green' } else { $st = 'NOT INSTALLED'; $col = 'Yellow' } }catch{}
        }
      }
      W ('  {0,-28}' -f $r[0]) Cyan -n
      W $st $col
    }
    if($isSrv -and $all){
      W ''
      W '  OTHER INSTALLED ROLES:' Yellow
      $known = @($roles | ForEach-Object { $_[1] })
      $other = @($all | Where-Object { "$($_.InstallState)" -eq 'Installed' -and "$($_.FeatureType)" -eq 'Role' -and ($known -notcontains $_.Name) })
      if($other.Count -eq 0){ W '  (none)' White } else { foreach($o in $other){ W ('  ' + $o.DisplayName + '  [' + $o.Name + ']') Green } }
    }
  }
}
function Page-Features{
  Page 'WINDOWS FEATURES' {
    if(Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue){
      W '  Source: Get-WindowsFeature (Windows Server)' Cyan
      Show (Get-WindowsFeature | Select-Object DisplayName,Name,@{n='State';e={ switch("$($_.InstallState)"){ 'Installed'{'INSTALLED'} 'Available'{'AVAILABLE'} default{'NOT AVAILABLE'} } }} | Format-Table -AutoSize) -Paged
    } elseif(Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue){
      W '  Source: Get-WindowsOptionalFeature -Online (Windows client / DISM)' Cyan
      Show (Get-WindowsOptionalFeature -Online | Sort-Object FeatureName | Select-Object FeatureName,@{n='State';e={ switch("$($_.State)"){ 'Enabled'{'INSTALLED'} 'Disabled'{'AVAILABLE'} default{'NOT AVAILABLE'} } }} | Format-Table -AutoSize) -Paged
    } else { W '  NOT AVAILABLE - no feature query cmdlet exists on this system.' Yellow }
  }
}
function Menu-WinServer{ Show-Menu 'WINDOWS SERVER' {
  @(
    (mPage 'Windows Server Detection' {
        $os = Get-CimInstance Win32_OperatingSystem
        W ('  Edition : ' + $os.Caption) White
        W ('  Version : ' + $os.Version + '  Build ' + $os.BuildNumber) White
        if($os.ProductType -eq 1){ W '  Type    : WINDOWS CLIENT - Server Manager / roles NOT AVAILABLE' Yellow }
        else {
          $n = 'Windows Server'
          if([int]$os.BuildNumber -ge 26100){ $n = 'Windows Server 2025 (or later)' } elseif([int]$os.BuildNumber -ge 20348){ $n = 'Windows Server 2022' } elseif([int]$os.BuildNumber -ge 17763){ $n = 'Windows Server 2019' }
          W ('  Type    : ' + $n) Green
        }
      }),
    (mTool 'Server Manager' 'exe' 'ServerManager.exe'),
    (mSub 'Server Roles' { Page-Roles }),
    (mSub 'Server Features' { Page-Features }),
    (mSub 'Services' { Menu-Services }),
    (mTool 'Event Viewer' 'msc' 'eventvwr.msc'),
    (mTool 'Computer Management' 'msc' 'compmgmt.msc'),
    (mTool 'Open PowerShell (new window)' 'exe' 'powershell.exe'),
    (mSub 'Storage' { Menu-Storage }),
    (mSub 'Networking' { Menu-Network }),
    (mSub 'Security' { Menu-Security }),
    (mSub 'Remote Management' { Menu-Remote }),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'SRV' 'WINDOWS SERVER' })
  )
}}

# ------------------------------------------------------------------ HYPER-V / VMWARE
function Menu-HyperV{ Show-Menu 'HYPER-V' {
  @(
    (mPage 'Hyper-V Status' {
        $s = Get-Service vmms -ErrorAction SilentlyContinue
        if(-not $s){ W '  HYPER-V NOT INSTALLED' Yellow } else {
          W ('  Hyper-V Virtual Machine Management: ' + ("$($s.Status)").ToUpper()) Green
          try{ W ('  Hypervisor present: ' + (Get-CimInstance Win32_ComputerSystem).HypervisorPresent) White }catch{}
        }
      }),
    (mPage 'Hyper-V Services' { $s = Get-Service vmms,vmcompute,vmicheartbeat,vmicshutdown -ErrorAction SilentlyContinue; if($s){ Show ($s | Format-Table Status,Name,DisplayName -AutoSize) } else { W '  HYPER-V NOT INSTALLED' Yellow } }),
    (mPage 'Virtual Machines (Get-VM)' { if(Get-Command Get-VM -ErrorAction SilentlyContinue){ Show (Get-VM | Format-Table Name,State,CPUUsage,MemoryAssigned,Uptime -AutoSize) } else { W '  HYPER-V NOT INSTALLED (Get-VM not available)' Yellow } }),
    (mPage 'Virtual Switches' { if(Get-Command Get-VMSwitch -ErrorAction SilentlyContinue){ Show (Get-VMSwitch | Format-Table Name,SwitchType,NetAdapterInterfaceDescription -AutoSize) } else { W '  HYPER-V NOT INSTALLED (Get-VMSwitch not available)' Yellow } }),
    (mTool 'Hyper-V Manager' 'msc' 'virtmgmt.msc'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'HV' 'HYPER-V' })
  )
}}
function Menu-VMware{ Show-Menu 'VMWARE' {
  @(
    (mPage 'VMware Status' {
        $v = Get-VMwareInfo
        if(-not $v.Installed){ W '  VMWARE NOT INSTALLED' Yellow } else {
          W '  VMware components DETECTED' Green
          if($v.Workstation){ W ('  Workstation: ' + $v.Workstation) White }
          if($v.Products.Count -gt 0){ Show ($v.Products | Format-Table DisplayName,DisplayVersion -AutoSize) }
        }
      }),
    (mPage 'VMware Services' { $v = Get-VMwareInfo; if($v.Services.Count -gt 0){ Show ($v.Services | Format-Table Status,Name,DisplayName -AutoSize) } else { W '  VMWARE NOT INSTALLED (no VMware services)' Yellow } }),
    (mPage 'VMware Installed Products' { $v = Get-VMwareInfo; if($v.Products.Count -gt 0){ Show ($v.Products | Format-Table DisplayName,DisplayVersion -AutoSize) } else { W '  VMWARE NOT INSTALLED' Yellow } }),
    (mPs 'Open VMware Workstation' '' {
        $v = Get-VMwareInfo
        if(-not $v.Workstation){ throw 'VMWARE WORKSTATION NOT INSTALLED' }
        W '  Close VMware Workstation to return...' Yellow
        Start-Process -FilePath $v.Workstation -Wait
      }),
    (mPs 'vmrun list (running VMs)' '' {
        $v = Get-VMwareInfo
        if(-not $v.VmRun){ throw 'vmrun.exe NOT AVAILABLE (VMware Workstation not installed)' }
        & $v.VmRun list
        if($LASTEXITCODE -ne 0){ throw ('vmrun returned exit code ' + $LASTEXITCODE) }
      })
  )
}}

# ------------------------------------------------------------------ STORAGE
function Menu-Storage{ Show-Menu 'STORAGE AND DISK' {
  @(
    (mTool 'Disk Management' 'msc' 'diskmgmt.msc'),
    (mPage 'Disk Information' { Show (Get-Disk | Format-Table Number,FriendlyName,PartitionStyle,OperationalStatus,@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}} -AutoSize); Show (Get-PhysicalDisk | Format-Table FriendlyName,MediaType,HealthStatus,@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}} -AutoSize) } 'Get-Disk'),
    (mPage 'Volume Information' { Show (Get-Volume | Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus,@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}},@{n='Free(GB)';e={[math]::Round($_.SizeRemaining/1GB,1)}} -AutoSize) } 'Get-Volume'),
    (mPs 'DiskPart (new window)' 'diskpart' { W '  Close the DiskPart window to return...' Yellow; Start-Process diskpart.exe -Wait } -c -desc 'Opens the interactive DiskPart tool.' -risk 'HIGH - wrong commands can erase disks.'),
    (mPs 'CHKDSK (read-only scan, optional repair)' 'chkdsk' {
        $d = (Read-Host '  Drive letter (e.g. C)').Trim().ToUpper()
        if($d -notmatch '^[A-Z]$'){ throw 'Invalid drive letter.' }
        if(-not (Test-Path ($d + ':\'))){ throw ('Drive not found: ' + $d + ':') }
        cmd.exe /c ('chkdsk ' + $d + ':') | Out-Host
        if(Ask-YN ('  Also run repair (chkdsk ' + $d + ': /f)?')){ cmd.exe /c ('chkdsk ' + $d + ': /f') | Out-Host }
      } -c -risk 'MEDIUM - /f repair may require a reboot.'),
    (mCon 'SFC /scannow' 'sfc /scannow' -c -risk 'MEDIUM - takes a long time and may repair system files.'),
    (mCon 'DISM CheckHealth' 'DISM /Online /Cleanup-Image /CheckHealth'),
    (mCon 'DISM ScanHealth' 'DISM /Online /Cleanup-Image /ScanHealth' -c -risk 'LOW - takes several minutes.'),
    (mCon 'DISM RestoreHealth' 'DISM /Online /Cleanup-Image /RestoreHealth' -c -risk 'MEDIUM - repairs the component store; may need internet/Windows Update.'),
    (mPage 'Storage Spaces' { if(Get-Command Get-StoragePool -ErrorAction SilentlyContinue){ Show (Get-StoragePool | Format-Table FriendlyName,HealthStatus,IsPrimordial,@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}} -AutoSize); Show (Get-VirtualDisk | Format-Table FriendlyName,ResiliencySettingName,HealthStatus -AutoSize) } else { W '  NOT AVAILABLE' Yellow } } 'Get-StoragePool'),
    (mCon 'BitLocker Status' 'manage-bde -status'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'STO' 'STORAGE AND DISK' })
  )
}}

# ------------------------------------------------------------------ REMOTE
function Menu-Remote{ Show-Menu 'REMOTE MANAGEMENT' {
  @(
    (mTool 'Remote Desktop Connection' 'exe' 'mstsc.exe'),
    (mPage 'Remote Desktop (this PC) Status' {
        $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction Stop).fDenyTSConnections
        if($v -eq 0){ W '  Remote Desktop connections: ENABLED' Green } else { W '  Remote Desktop connections: DISABLED' Yellow }
        $s = Get-Service TermService -ErrorAction SilentlyContinue
        if($s){ W ('  Remote Desktop Services service: ' + ("$($s.Status)").ToUpper()) White }
      }),
    (mPage 'WinRM Service / Config' { $s = Get-Service WinRM -ErrorAction SilentlyContinue; if($s){ W ('  WinRM service: ' + ("$($s.Status)").ToUpper()) White }; winrm enumerate winrm/config/listener } 'winrm'),
    (mCon 'winrs help' 'winrs /?'),
    (mPs 'Test PowerShell Remoting (localhost)' 'Test-WSMan' { Test-WSMan -ComputerName localhost -ErrorAction Stop | Out-String | Write-Host }),
    (mPs 'Enable PowerShell Remoting' 'Enable-PSRemoting' { Enable-PSRemoting -Force -ErrorAction Stop | Out-Null; W '  PowerShell Remoting enabled.' Green } -c -risk 'HIGH - opens WinRM to the network (firewall exception).'),
    (mPs 'Computer Management (remote)' '' {
        $h = Ask-Host 'Remote computer name or IP'
        if(-not $h){ throw 'Invalid host name.' }
        $m = Resolve-Tool 'compmgmt.msc'; if(-not $m){ throw 'compmgmt.msc NOT AVAILABLE' }
        Start-Process -FilePath "$env:windir\System32\mmc.exe" -ArgumentList ('"' + $m + '" /computer=' + $h) -Wait
      }),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'REM' 'REMOTE MANAGEMENT' })
  )
}}

# ------------------------------------------------------------------ CMD COMMAND CENTER + ASSISTANT
$script:KB = @{
  'systeminfo' = @('Displays detailed OS and hardware configuration.','LOW')
  'ipconfig'   = @('Shows or manages IP configuration of adapters.','LOW')
  'ping'       = @('Tests reachability of a host.','LOW')
  'tracert'    = @('Traces the network route to a host.','LOW')
  'pathping'   = @('Combines ping and tracert statistics.','LOW')
  'nslookup'   = @('Queries DNS servers.','LOW')
  'netstat'    = @('Shows network connections and listening ports.','LOW')
  'arp'        = @('Shows or edits the ARP cache.','LOW')
  'route'      = @('Shows or edits the routing table.','MEDIUM')
  'hostname'   = @('Prints the computer name.','LOW')
  'whoami'     = @('Shows the current user, groups and privileges.','LOW')
  'tasklist'   = @('Lists running processes.','LOW')
  'taskkill'   = @('Terminates processes.','HIGH')
  'sc'         = @('Service Control: query and manage services.','MEDIUM')
  'net'        = @('Manages users, shares, services (net user, net start ...).','MEDIUM')
  'netsh'      = @('Configures network components (firewall, interfaces, winsock).','MEDIUM')
  'diskpart'   = @('Interactive disk partitioning tool.','HIGH')
  'sfc'        = @('System File Checker.','MEDIUM')
  'dism'       = @('Servicing tool for Windows images and features.','MEDIUM')
  'chkdsk'     = @('Checks (and optionally repairs) a file system.','MEDIUM')
  'gpupdate'   = @('Refreshes Group Policy.','LOW')
  'gpresult'   = @('Shows applied Group Policy results.','LOW')
  'wevtutil'   = @('Queries and manages event logs.','MEDIUM')
  'schtasks'   = @('Manages scheduled tasks.','MEDIUM')
  'powercfg'   = @('Configures and reports power settings.','LOW')
  'bcdedit'    = @('Edits boot configuration data.','HIGH')
  'manage-bde' = @('Manages BitLocker drive encryption.','HIGH')
  'cipher'     = @('Shows or changes EFS encryption of files.','MEDIUM')
  'certutil'   = @('Certificate services utility.','MEDIUM')
  'winrm'      = @('Windows Remote Management configuration.','MEDIUM')
  'winrs'      = @('Runs commands on a remote machine through WinRM.','MEDIUM')
  'getmac'     = @('Shows the MAC (physical) address of each network adapter.','LOW')
  'mstsc'      = @('Opens the Remote Desktop Connection client.','LOW')
  'icacls'     = @('Shows or changes file and folder permissions.','MEDIUM')
  'auditpol'   = @('Shows or changes the audit policy.','MEDIUM')
  'findstr'    = @('Searches text for patterns.','LOW')
}
function Invoke-Assist{
  Head 'AI ADMIN ASSISTANT (rule-based, offline)'
  W '  Enter one Windows admin command (example: ipconfig /all). Blank = cancel.' Cyan
  $line = (Read-Host '  Command').Trim()
  if($line -eq ''){ return }
  if($line -match '[&|<>^%]'){ Show-Result 'ASSISTANT' 'CANCELLED' 'Command chaining / redirection characters are not allowed (& | < > ^ %).'; return }
  if($line -match '(?i)crack|keygen|bypass|activator|kmspico|license|licence'){ Show-Result 'ASSISTANT' 'CANCELLED' 'Crack, keygen and license-bypass commands are not supported.'; return }
  $parts = $line -split '\s+'
  $name = $parts[0].ToLower() -replace '\.exe$',''
  if(-not $script:KB.ContainsKey($name)){ Show-Result 'ASSISTANT' 'NOT SUPPORTED' ('"' + $name + '" is not in the assistant command list.'); return }
  $info = $script:KB[$name]
  $risk = $info[1]
  $argText = ''; if($parts.Count -gt 1){ $argText = ($parts[1..($parts.Count - 1)] -join ' ') }
  if($argText -match '(?i)(delete|add\b|set\b|reset|stop\b|clear|create|change|release|format|/f\b|/r\b|/x\b|/scannow|/restorehealth)'){ $risk = 'HIGH' }
  Head 'AI ADMIN ASSISTANT'
  W ('  1) COMMAND     : ' + $line) White
  W ('  2) WHAT IT DOES: ' + $info[0]) White
  if(Get-Command $name -ErrorAction SilentlyContinue){ W '  3) RUNNABLE    : YES on this Windows' Green } else { W '  3) RUNNABLE    : NO - NOT AVAILABLE on this Windows' Yellow; Wait-Key; return }
  $col = 'Green'; if($risk -eq 'MEDIUM'){ $col = 'Yellow' } elseif($risk -eq 'HIGH'){ $col = 'Red' }
  W ('  4) RISK LEVEL  : ' + $risk) $col
  W ''
  if(-not (Ask-YN '  5) Confirm and run?')){ Show-Result 'ASSISTANT' 'CANCELLED' 'Cancelled by user.'; return }
  Invoke-Con ('ASSISTANT: ' + $name) $line -NoHead
}
function Menu-CmdCenter{ Show-Menu 'CMD COMMAND CENTER' {
  @(
    (mCon 'systeminfo' 'systeminfo'),
    (mCon 'ipconfig /all' 'ipconfig /all'),
    (mConHost 'ping' 'ping -n 4 {0}'),
    (mConHost 'tracert' 'tracert {0}'),
    (mConHost 'pathping' 'pathping {0}'),
    (mConHost 'nslookup' 'nslookup {0}'),
    (mCon 'netstat -ano' 'netstat -ano'),
    (mCon 'arp -a' 'arp -a'),
    (mCon 'route print' 'route print'),
    (mCon 'hostname' 'hostname'),
    (mCon 'whoami /all' 'whoami /all'),
    (mCon 'tasklist' 'tasklist'),
    (mPs 'taskkill (by PID)' 'taskkill' {
        $t = (Read-Host '  Process ID').Trim()
        if($t -notmatch '^\d+$'){ throw 'Process ID must be a number.' }
        $p = Get-Process -Id ([int]$t) -ErrorAction Stop
        if(-not (Ask-YN ('  taskkill /PID ' + $t + ' /F  (' + $p.ProcessName + ')?'))){ W '  Cancelled.' Yellow; return }
        cmd.exe /c ('taskkill /PID ' + $t + ' /F') | Out-Host
        if($LASTEXITCODE -ne 0){ throw ('taskkill exit code ' + $LASTEXITCODE) }
      } -risk 'HIGH'),
    (mCon 'sc query' 'sc query'),
    (mCon 'net start' 'net start'),
    (mCon 'netsh interface show interface' 'netsh interface show interface'),
    (mPs 'diskpart (new window)' 'diskpart' { W '  Close the DiskPart window to return...' Yellow; Start-Process diskpart.exe -Wait } -c -risk 'HIGH'),
    (mCon 'sfc /verifyonly' 'sfc /verifyonly'),
    (mCon 'DISM CheckHealth' 'DISM /Online /Cleanup-Image /CheckHealth'),
    (mCon 'chkdsk (read-only, C:)' 'chkdsk C:'),
    (mCon 'gpupdate /force' 'gpupdate /force' -c -risk 'LOW'),
    (mCon 'gpresult /r' 'gpresult /r'),
    (mCon 'wevtutil (last 20 System events)' 'wevtutil qe System /c:20 /rd:true /f:text'),
    (mCon 'schtasks /query' 'schtasks /query /fo table'),
    (mCon 'powercfg /list' 'powercfg /list'),
    (mCon 'bcdedit /enum' 'bcdedit /enum'),
    (mCon 'manage-bde -status' 'manage-bde -status'),
    (mCon 'cipher (current folder)' 'cipher'),
    (mCon 'certutil -store My' 'certutil -store My'),
    (mCon 'winrm enumerate listeners' 'winrm enumerate winrm/config/listener'),
    (mCon 'winrs /?' 'winrs /?'),
    (mSub 'CUSTOM COMMAND (validated)' { Invoke-Assist }),
    (mTool 'Open CMD (new window)' 'exe' 'cmd.exe'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'CMD' 'CMD COMMAND CENTER' })
  )
}}

# ------------------------------------------------------------------ POWERSHELL CENTER
function Menu-PSCenter{ Show-Menu 'POWERSHELL CENTER' {
  @(
    (mPage 'Get-ComputerInfo' { Show (Get-ComputerInfo | Select-Object CsName,WindowsProductName,WindowsVersion,OsBuildNumber,OsArchitecture,CsDomain,OsUptime | Format-List) } 'Get-ComputerInfo'),
    (mPage 'Get-Service' { Show (Get-Service | Sort-Object Status,Name | Format-Table Status,Name,DisplayName -AutoSize) -Paged } 'Get-Service'),
    (mPage 'Get-Process' { Show (Get-Process | Sort-Object ProcessName | Format-Table Id,ProcessName,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize) -Paged } 'Get-Process'),
    (mPage 'Get-NetAdapter' { Show (Get-NetAdapter | Format-Table Name,Status,LinkSpeed,MacAddress -AutoSize) } 'Get-NetAdapter'),
    (mPage 'Get-NetIPAddress' { Show (Get-NetIPAddress | Format-Table InterfaceAlias,AddressFamily,IPAddress,PrefixLength -AutoSize) } 'Get-NetIPAddress'),
    (mPage 'Get-NetRoute (IPv4)' { Show (Get-NetRoute -AddressFamily IPv4 | Format-Table DestinationPrefix,NextHop,RouteMetric,InterfaceAlias -AutoSize) -Paged } 'Get-NetRoute'),
    (mPage 'Get-NetFirewallProfile' { Show (Get-NetFirewallProfile | Format-Table Name,Enabled,DefaultInboundAction,DefaultOutboundAction -AutoSize) } 'Get-NetFirewallProfile'),
    (mPage 'Get-NetFirewallRule (first 60)' { Show (Get-NetFirewallRule | Select-Object -First 60 | Format-Table DisplayName,Enabled,Direction,Action -AutoSize) } 'Get-NetFirewallRule'),
    (mPage 'Get-WindowsFeature' { Show (Get-WindowsFeature | Where-Object { "$($_.InstallState)" -eq 'Installed' } | Format-Table DisplayName,Name -AutoSize) -Paged } 'Get-WindowsFeature'),
    (mPage 'Get-WindowsOptionalFeature' { Show (Get-WindowsOptionalFeature -Online | Sort-Object FeatureName | Format-Table FeatureName,State -AutoSize) -Paged } 'Get-WindowsOptionalFeature'),
    (mPage 'Get-VM' { Show (Get-VM | Format-Table Name,State,CPUUsage,MemoryAssigned -AutoSize) } 'Get-VM'),
    (mPage 'PowerShell / .NET Version' { Show ($PSVersionTable | Out-String) }),
    (mTool 'Open PowerShell (new window)' 'exe' 'powershell.exe'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'PS' 'POWERSHELL CENTER' })
  )
}}

# ------------------------------------------------------------------ SECURITY / PERFORMANCE / TROUBLESHOOTING
function Menu-Security{ Show-Menu 'SECURITY TOOLS' {
  @(
    (mPage 'Firewall' { Show (Get-NetFirewallProfile | Format-Table Name,Enabled,DefaultInboundAction,DefaultOutboundAction -AutoSize) } 'Get-NetFirewallProfile'),
    (mPage 'Windows Defender' { Show (Get-MpComputerStatus | Format-List AntivirusEnabled,RealTimeProtectionEnabled,AntispywareEnabled,AntivirusSignatureLastUpdated,AntivirusSignatureVersion) } 'Get-MpComputerStatus'),
    (mPage 'UAC' {
        $p = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        if($p.EnableLUA -eq 1){ W '  UAC: ON' Green } else { W '  UAC: OFF' Red }
        W ('  ConsentPromptBehaviorAdmin: ' + $p.ConsentPromptBehaviorAdmin) White
      }),
    (mTool 'Security Policy' 'msc' 'secpol.msc'),
    (mPage 'Local Users' { Show (Get-LocalUser | Format-Table Name,Enabled,LastLogon -AutoSize) } 'Get-LocalUser'),
    (mPage 'Local Groups' { Show (Get-LocalGroup | Format-Table Name,Description -AutoSize) } 'Get-LocalGroup'),
    (mPage 'Certificates (LocalMachine\My)' { Show (Get-ChildItem Cert:\LocalMachine\My | Format-Table Subject,NotAfter,Thumbprint -AutoSize) }),
    (mTool 'Certificate Manager' 'msc' 'certmgr.msc'),
    (mCon 'BitLocker Status' 'manage-bde -status'),
    (mPage 'Windows Update' {
        $s = Get-Service wuauserv -ErrorAction SilentlyContinue
        if($s){ W ('  Windows Update service: ' + ("$($s.Status)").ToUpper()) White }
        Show (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10 | Format-Table HotFixID,Description,InstalledOn -AutoSize)
      } 'Get-HotFix'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'FW' 'SECURITY TOOLS' })
  )
}}
function Menu-Perf{ Show-Menu 'PERFORMANCE' {
  @(
    (mPage 'CPU' { Show (Get-CimInstance Win32_Processor | Format-List Name,NumberOfCores,NumberOfLogicalProcessors,LoadPercentage,MaxClockSpeed) } 'Get-CimInstance'),
    (mPage 'RAM' {
        $o = Get-CimInstance Win32_OperatingSystem
        $t = $o.TotalVisibleMemorySize / 1MB; $f = $o.FreePhysicalMemory / 1MB
        W ('  Total : {0:N2} GB' -f $t) White
        W ('  Free  : {0:N2} GB' -f $f) White
        W ('  Used  : {0:N2} GB  ({1:N0}%)' -f ($t - $f),(($t - $f) / $t * 100)) Cyan
      } 'Get-CimInstance'),
    (mPage 'Disk' { Show (Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Format-Table DeviceID,VolumeName,@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}},@{n='Free(GB)';e={[math]::Round($_.FreeSpace/1GB,1)}} -AutoSize) } 'Get-CimInstance'),
    (mPage 'Network' { Show (Get-NetAdapterStatistics | Format-Table Name,ReceivedBytes,SentBytes -AutoSize) } 'Get-NetAdapterStatistics'),
    (mPage 'Processes (top 15 by RAM)' { Show (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | Format-Table Id,ProcessName,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize) } 'Get-Process'),
    (mTool 'Resource Monitor' 'exe' 'resmon.exe'),
    (mTool 'Performance Monitor' 'msc' 'perfmon.msc'),
    (mTool 'Task Manager' 'exe' 'taskmgr.exe'),
    (mNoop 'Refresh'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'PERF' 'PERFORMANCE' })
  )
}}
function Menu-Trouble{ Show-Menu 'TROUBLESHOOTING' {
  @(
    (mCon 'System Information' 'systeminfo'),
    (mTool 'Event Viewer' 'msc' 'eventvwr.msc'),
    (mTool 'Services' 'msc' 'services.msc'),
    (mSub 'Network Diagnostics' { Page-NetDiag }),
    (mCon 'SFC /scannow' 'sfc /scannow' -c -risk 'MEDIUM - long running; may repair system files.'),
    (mCon 'DISM CheckHealth' 'DISM /Online /Cleanup-Image /CheckHealth'),
    (mCon 'CHKDSK (read-only, C:)' 'chkdsk C:'),
    (mCon 'DNS Diagnostics (nslookup microsoft.com)' 'nslookup microsoft.com'),
    (mPage 'Firewall Diagnostics' { Show (Get-NetFirewallProfile | Format-List Name,Enabled,DefaultInboundAction,DefaultOutboundAction,LogFileName,LogBlocked) } 'Get-NetFirewallProfile'),
    (mTool 'Device Manager' 'msc' 'devmgmt.msc'),
    (mSub 'BASICS / EXPLAIN' { Menu-Learn 'TRB' 'TROUBLESHOOTING' })
  )
}}

# ------------------------------------------------------------------ LEARNING + DOCS
$script:MCSA = @(
  @{T='01 - Installation'; D='Installing Windows Server, editions, Server Core vs Desktop Experience, media and updates.'; C='systeminfo | sconfig | dism /online /get-features | Get-WindowsFeature'; X='Server Manager, sconfig, Windows Setup'; U='https://learn.microsoft.com/en-us/windows-server/get-started/install-upgrade-migrate'},
  @{T='02 - Active Directory'; D='AD DS: users, groups, computers, OUs, domains, domain controllers, sites, replication.'; C='dcdiag | repadmin /replsummary | Get-ADUser | Install-ADDSForest'; X='dsa.msc, dssite.msc, domain.msc, dsac.exe'; U='https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-domain-services'},
  @{T='03 - DNS'; D='Zones, records, forwarders, conditional forwarders and DNS troubleshooting.'; C='nslookup | ipconfig /displaydns | ipconfig /flushdns | Get-DnsServerZone'; X='dnsmgmt.msc'; U='https://learn.microsoft.com/en-us/windows-server/networking/dns/dns-top'},
  @{T='04 - DHCP'; D='Scopes, reservations, options, leases and DHCP failover.'; C='ipconfig /release | ipconfig /renew | Get-DhcpServerv4Scope'; X='dhcpmgmt.msc'; U='https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/dhcp-top'},
  @{T='05 - Group Policy'; D='GPOs, OUs, computer/user policy, security policy, gpupdate, gpresult, RSOP.'; C='gpupdate /force | gpresult /r | gpresult /h report.html'; X='gpedit.msc, gpmc.msc, rsop.msc, secpol.msc'; U='https://learn.microsoft.com/en-us/previous-versions/windows/desktop/policy/group-policy-start-page'},
  @{T='06 - File Services'; D='NTFS, shares, permissions, SMB and DFS.'; C='icacls | net share | Get-SmbShare | Get-SmbSession'; X='fsmgmt.msc, compmgmt.msc'; U='https://learn.microsoft.com/en-us/windows-server/storage/file-server/file-server-smb-overview'},
  @{T='07 - Storage'; D='Disks, volumes, Storage Spaces, deduplication, BitLocker.'; C='diskpart | Get-Disk | Get-Volume | manage-bde -status | chkdsk'; X='diskmgmt.msc'; U='https://learn.microsoft.com/en-us/windows-server/storage/storage'},
  @{T='08 - Networking'; D='IPv4, IPv6, DNS, DHCP, routing, NAT, VPN, RRAS.'; C='ipconfig /all | route print | netsh | Get-NetIPAddress | tracert'; X='ncpa.cpl, rrasmgmt.msc'; U='https://learn.microsoft.com/en-us/windows-server/networking/networking'},
  @{T='09 - Hyper-V'; D='Virtual machines, virtual switches, virtual disks, checkpoints, integration services.'; C='Get-VM | Get-VMSwitch | Checkpoint-VM | New-VHD'; X='virtmgmt.msc'; U='https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/hyper-v-on-windows-server'},
  @{T='10 - IIS'; D='Web server, sites, bindings, application pools, certificates.'; C='Get-Website | Get-WebBinding | Import-Module WebAdministration'; X='inetmgr.exe'; U='https://learn.microsoft.com/en-us/iis/get-started/introduction-to-iis/iis-web-server-overview'},
  @{T='11 - Security'; D='Firewall, Defender, UAC, auditing, certificates, security policy.'; C='Get-NetFirewallProfile | Get-MpComputerStatus | auditpol | certutil'; X='wf.msc, secpol.msc, certmgr.msc'; U='https://learn.microsoft.com/en-us/windows-server/security/security-and-assurance'},
  @{T='12 - PowerShell'; D='Cmdlets, modules, objects, pipelines, remoting, automation.'; C='Get-Command | Get-Help | Get-Member | Enter-PSSession'; X='powershell.exe, ISE'; U='https://learn.microsoft.com/en-us/powershell/scripting/overview'},
  @{T='13 - Remote Management'; D='RDP, WinRM, PowerShell Remoting, Remote Server Administration Tools.'; C='winrm quickconfig | Enable-PSRemoting | Test-WSMan | mstsc'; X='mstsc.exe, ServerManager.exe'; U='https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/welcome-to-rds'},
  @{T='14 - Troubleshooting'; D='Event Viewer, performance, networking, services, storage and boot problems.'; C='wevtutil | sfc /scannow | DISM | bcdedit | perfmon'; X='eventvwr.msc, perfmon.msc, resmon.exe'; U='https://learn.microsoft.com/en-us/troubleshoot/windows-server/welcome-windows-server'}
)
function Page-Learn($e){
  Page ('MCSA - ' + $e.T) {
    W '  LEGACY MICROSOFT CERTIFICATION (MCSA retired by Microsoft) - content is still useful as Windows Server fundamentals.' Yellow
    W ''
    W '  DESCRIPTION :' Cyan; W ('    ' + $e.D) White
    W '  REAL COMMANDS:' Cyan; W ('    ' + $e.C) White
    W '  WINDOWS TOOLS:' Cyan; W ('    ' + $e.X) White
    W '  DOCUMENTATION:' Cyan; W ('    ' + $e.U) Green
  }
}
function Menu-MCSA{ Show-Menu 'MCSA / WINDOWS SERVER LEARNING (LEGACY)' {
  $l = @()
  foreach($e in $script:MCSA){ $l += ,(mLearn $e) }
  $l += ,(mSub 'WHAT IS MCSA?' { Page-WhatMCSA })
  $l += ,(mSub 'LEARNING CENTER - ALL SECTIONS' { Menu-LearnAll })
  $l
}}
function Menu-Docs{ Show-Menu 'MICROSOFT DOCUMENTATION (learn.microsoft.com)' {
  @(
    (mDoc 'Windows Server' 'https://learn.microsoft.com/en-us/windows-server/'),
    (mDoc 'Windows Server 2022' 'https://learn.microsoft.com/en-us/windows-server/get-started/whats-new-in-windows-server-2022'),
    (mDoc 'Windows Server 2025' 'https://learn.microsoft.com/en-us/windows-server/get-started/whats-new-windows-server-2025'),
    (mDoc 'Windows 11' 'https://learn.microsoft.com/en-us/windows/whats-new/windows-11-overview'),
    (mDoc 'PowerShell' 'https://learn.microsoft.com/en-us/powershell/'),
    (mDoc 'Active Directory' 'https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-domain-services'),
    (mDoc 'DNS' 'https://learn.microsoft.com/en-us/windows-server/networking/dns/dns-top'),
    (mDoc 'DHCP' 'https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/dhcp-top'),
    (mDoc 'Group Policy' 'https://learn.microsoft.com/en-us/previous-versions/windows/desktop/policy/group-policy-start-page'),
    (mDoc 'Windows Firewall' 'https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/'),
    (mDoc 'Hyper-V' 'https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/about/'),
    (mDoc 'IIS' 'https://learn.microsoft.com/en-us/iis/'),
    (mDoc 'Networking' 'https://learn.microsoft.com/en-us/windows-server/networking/networking'),
    (mDoc 'Storage' 'https://learn.microsoft.com/en-us/windows-server/storage/storage'),
    (mDoc 'Security' 'https://learn.microsoft.com/en-us/windows/security/'),
    (mDoc 'RDP / Remote Desktop Services' 'https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/welcome-to-rds'),
    (mDoc 'WSL' 'https://learn.microsoft.com/en-us/windows/wsl/')
  )
}}

# ------------------------------------------------------------------ LIVE STATUS (local network + public IP)
function Get-PublicIP{
  try{ [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }catch{}
  foreach($u in @('https://api.ipify.org','https://ifconfig.me/ip')){
    try{
      $v = ([string](Invoke-RestMethod -Uri $u -TimeoutSec 4 -ErrorAction Stop)).Trim()
      if($v -match '^\d{1,3}(\.\d{1,3}){3}$'){ return $v }
      if($v -match '^[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){2,7}$'){ return $v }
    }catch{}
  }
  return 'NOT AVAILABLE'
}
function Update-NetStatus([switch]$WithPublic){
  $n = @{ V4 = @(); GW = 'NOT AVAILABLE'; ST = 'NOT AVAILABLE' }
  try{
    $cfg = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop)
    $v4 = @(); $gw = @()
    foreach($c in $cfg){
      foreach($ip in @($c.IPAddress)){
        if($ip -match '^\d{1,3}(\.\d{1,3}){3}$' -and $ip -notlike '169.254.*'){
          $d = [string]$c.Description
          if($d.Length -gt 36){ $d = $d.Substring(0,36) }
          $v4 += ,@{ IP = [string]$ip; Adapter = $d }
        }
      }
      foreach($g in @($c.DefaultIPGateway)){
        if($g -match '^\d{1,3}(\.\d{1,3}){3}$'){ $gw += [string]$g }
      }
    }
    $n.V4 = $v4
    if($gw.Count -gt 0){ $n.GW = ($gw -join ', ') }
    if($v4.Count -gt 0 -and $gw.Count -gt 0){ $n.ST = 'CONNECTED' }
    elseif($v4.Count -gt 0){ $n.ST = 'CONNECTED (LOCAL ONLY)' }
    else { $n.ST = 'DISCONNECTED' }
  }catch{}
  $script:NS = $n
  if($WithPublic){ $script:Pub = Get-PublicIP }
}
function Sval([string]$v){
  if($v -like 'NOT *' -or $v -like 'DISCONNECTED*'){ return 'Yellow' }
  if($v -eq 'NO'){ return 'Red' }
  return 'Green'
}
function Show-Status{
  if(-not $script:SI){ return }
  $s = $script:SI
  W '   USERNAME   : ' Cyan -n; W ('{0,-24}' -f $s['Username']) Green -n
  W 'COMPUTER : ' Cyan -n; W ([string]$s['Computer Name']) Green
  $ns = $script:NS
  if($ns -and @($ns.V4).Count -gt 0){
    $i = 0
    foreach($e in @($ns.V4)){
      if($i -ge 3){ W ('   {0,-11}  (+{1} more - see NETWORK CENTER)' -f '',(@($ns.V4).Count - 3)) DarkGray; break }
      $lab = 'LOCAL IPv4'; if($i -gt 0){ $lab = '' }
      W ('   {0,-11}: ' -f $lab) Cyan -n; W ($e.IP + '   [' + $e.Adapter + ']') Green
      $i++
    }
  } else { W '   LOCAL IPv4 : ' Cyan -n; W 'NOT AVAILABLE' Yellow }
  $gw = 'NOT AVAILABLE'; $st = 'NOT AVAILABLE'
  if($ns){ $gw = [string]$ns.GW; $st = [string]$ns.ST }
  W '   GATEWAY    : ' Cyan -n; W ('{0,-24}' -f $gw) (Sval $gw) -n
  W 'NETWORK  : ' Cyan -n; W $st (Sval $st)
  $pub = [string]$script:Pub
  W '   PUBLIC IP  : ' Cyan -n
  if($pub -like 'NOT *'){ W $pub 'Yellow' } else { W ($pub + '   (Internet-facing address - NOT your local IP)') Green }
  W '   ADMIN      : ' Cyan -n; W ([string]$s['Administrator']) (Sval ([string]$s['Administrator']))
}

# ------------------------------------------------------------------ LEARNING ENGINE (BASICS / EXPLAIN + SAMPLES)
$script:LRN = @{}
function Add-Learn([string]$Key,[string]$Data){
  $list = @()
  foreach($ln in ($Data -split "`n")){
    $ln = $ln.Trim()
    if($ln -eq '' -or $ln.StartsWith('#')){ continue }
    $p = $ln -split '~'
    if($p.Count -lt 7){ continue }
    $k = ''; if($p.Count -ge 8){ $k = $p[7].Trim() }
    $list += ,@{ N=$p[0].Trim(); D=$p[1].Trim(); W=$p[2].Trim(); U=$p[3].Trim(); X=$p[4].Trim(); S=$p[5].Trim(); E=$p[6].Trim(); K=$k; C=''; T=''; URL='' }
  }
  $script:LRN[$Key] = $list
}
function WrapW([string]$label,[string]$text,[string]$c='White'){
  if(-not $text -or $text -eq '-'){ return }
  W ('  ' + $label) Cyan
  $ln = '    '
  foreach($wd in ($text -split '\s+')){
    if($wd -eq ''){ continue }
    if(($ln.Length + $wd.Length + 1) -gt 76 -and $ln.Trim() -ne ''){ W $ln $c; $ln = '    ' }
    $ln += ($wd + ' ')
  }
  if($ln.Trim() -ne ''){ W $ln $c }
}
# Live values read from THIS computer, shown next to a topic when available
$script:LIVE = @{
  'IPv4'                        = { $script:SI['IPv4'] }
  'IPv6'                        = { $script:SI['IPv6'] }
  'MAC Address'                 = { $script:SI['MAC'] }
  'Subnet Mask / Prefix Length' = { $script:SI['Subnet / Prefix'] }
  'Default Gateway'             = { $script:SI['Gateway'] }
  'DNS'                         = { $script:SI['DNS'] }
  'DHCP'                        = { 'DHCP enabled: ' + $script:SI['DHCP Enabled'] + '   DHCP server: ' + $script:SI['DHCP Server'] }
  'Network Adapter'             = { $script:SI['Network Adapter'] }
  'Link Speed'                  = { $script:SI['Link Speed'] }
  'Firewall'                    = { $script:SI['Firewall'] }
  'UAC'                         = { $script:SI['UAC'] }
  'Local User'                  = { 'Logged in as ' + $script:SI['Username'] + ' on ' + $script:SI['Computer Name'] }
  'Domain User'                 = { 'Domain: ' + $script:SI['Domain'] + '   Workgroup: ' + $script:SI['Workgroup'] }
  'Domain'                      = { 'Domain: ' + $script:SI['Domain'] + '   Workgroup: ' + $script:SI['Workgroup'] }
  'Hyper-V'                     = { $script:SI['Hyper-V'] }
  'Disk'                        = { $script:SI['Disk'] }
  'Free Space'                  = { $script:SI['Free Disk Space'] }
  'Windows Server'              = { $script:SI['Windows Edition'] + '  (version ' + $script:SI['Windows Version'] + ', build ' + $script:SI['Build'] + ')' }
  'Windows Service'             = { $a = @(Get-Service); 'Total ' + $a.Count + '   Running ' + @($a | Where-Object { "$($_.Status)" -eq 'Running' }).Count + '   Stopped ' + @($a | Where-Object { "$($_.Status)" -eq 'Stopped' }).Count }
  'Process'                     = { 'Running processes right now: ' + @(Get-Process).Count }
  'CPU Usage'                   = { $c = Get-CimInstance Win32_Processor | Select-Object -First 1; $c.Name + '   load ' + $c.LoadPercentage + '%' }
  'RAM Usage'                   = { $o = Get-CimInstance Win32_OperatingSystem; $t = $o.TotalVisibleMemorySize / 1MB; $f = $o.FreePhysicalMemory / 1MB; ('Total {0:N2} GB   Free {1:N2} GB   Used {2:N0}%' -f $t,$f,(($t - $f) / $t * 100)) }
}
function Run-Sample($t){
  $s = [string]$t.S
  $name = 'SAMPLE: ' + $t.N
  if($s -eq '' -or $s -eq '-'){ Show-Result $name 'NOT AVAILABLE' 'This topic has no runnable sample.'; return }
  if($s -match '\{GW\}'){
    $gw = $null
    if($script:SI){ $gw = @(([string]$script:SI['Gateway']) -split ',\s*' | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' }) | Select-Object -First 1 }
    if(-not $gw){ Show-Result $name 'NOT AVAILABLE' 'No default gateway was detected on this computer.'; return }
    $s = $s -replace '\{GW\}',[string]$gw
  }
  $risk = [string]$t.K
  if($s -match '^(Get|Test|Measure|Resolve)-[A-Za-z]+'){
    $cmdlet = ($s -split '\s+')[0]
    $sb = { Invoke-Expression $s }.GetNewClosure()
    if($risk){ Invoke-Ps $name $sb $cmdlet -Ask -Desc ('Sample: ' + $s) -Risk $risk }
    else { Invoke-Ps $name $sb $cmdlet -Desc ('Sample: ' + $s) }
  } else {
    if($risk){ Invoke-Con $name $s -Ask -Risk $risk } else { Invoke-Con $name $s }
  }
}
function Page-Topic($t,[string]$Title,[string]$Key){
  while($true){
    if($script:Quit -or $script:GoHome){ return }
    Head ($Title + ' > BASICS')
    if($Key -eq 'MCSA'){ W '  LEGACY MICROSOFT CERTIFICATION (MCSA retired by Microsoft) - still useful Windows Server fundamentals.' Yellow; W '' }
    W '  NAME:' Cyan; W ('    ' + $t.N) Yellow
    WrapW 'DEFINITION:' $t.D
    WrapW 'WHAT IT DOES:' $t.W
    WrapW 'WHEN TO USE:' $t.U
    WrapW 'REAL EXAMPLE:' $t.X
    if($script:LIVE.ContainsKey([string]$t.N)){
      W '  YOUR SYSTEM (read live from this computer):' Cyan
      $lb = $script:LIVE[[string]$t.N]
      W ('    ' + (Safe $lb)) White
    }
    if($t.S -and $t.S -ne '-'){
      W '  SAMPLE COMMAND:' Cyan
      $ask = ''; if($t.K){ $ask = '     (asks for confirmation before running)' }
      W ('    ' + $t.S + $ask) Green
    }
    WrapW 'EXPECTED RESULT:' $t.E
    WrapW 'RELATED COMMANDS:' $t.C
    WrapW 'WINDOWS TOOL:' $t.T
    if($t.URL){ W '  DOCUMENTATION:' Cyan; W ('    ' + $t.URL) Green }
    W ''
    W '  [S] Run the SAMPLE   [B/ESC] Back   [H] Home   [F1] Help   [Q] Exit' Cyan
    $wait = $true
    while($wait){
      $a = Read-Nav
      switch -regex ($a){
        '^sample$'  { Run-Sample $t; $wait = $false }
        '^refresh$' { $wait = $false }
        '^back$'    { return }
        '^home$'    { $script:GoHome = $true; return }
        '^quit$'    { [void](Confirm-Exit); if($script:Quit){ return } }
        '^help$'    { Page-Help; $wait = $false }
        '^F\d+$'    { Set-Jump $a; return }
      }
    }
  }
}
function mTopic($t,[string]$Title,[string]$Key){
  if($Key -eq 'MCSA'){
    foreach($e in $script:MCSA){ if($e.T -eq $t.N){ $t.C = [string]$e.C; $t.T = [string]$e.X; $t.URL = [string]$e.U } }
  }
  $sb = { Page-Topic $t $Title $Key }.GetNewClosure()
  return @{ L = [string]$t.N; A = $sb }
}
function Menu-Learn([string]$Key,[string]$Title){
  $rows = $script:LRN[$Key]
  if(-not $rows -or @($rows).Count -eq 0){ Show-Result ($Title + ' - BASICS') 'NOT AVAILABLE' 'No learning topics are defined for this section.'; return }
  $b = {
    $l = @()
    foreach($r in $rows){ $l += ,(mTopic $r $Title $Key) }
    $l
  }.GetNewClosure()
  Show-Menu ($Title + ' - BASICS / EXPLAIN') $b
}
$script:SECT = @(
  @('NET','NETWORK CENTER'),
  @('FW','FIREWALL AND SECURITY'),
  @('SVC','SERVICES'),
  @('PROC','PROCESSES'),
  @('USR','USERS AND GROUPS'),
  @('GPO','GROUP POLICY'),
  @('AD','ACTIVE DIRECTORY'),
  @('DNS','DNS'),
  @('DHCP','DHCP'),
  @('IIS','IIS'),
  @('SRV','WINDOWS SERVER'),
  @('HV','HYPER-V'),
  @('STO','STORAGE AND DISK'),
  @('REM','REMOTE MANAGEMENT'),
  @('PERF','PERFORMANCE'),
  @('TRB','TROUBLESHOOTING'),
  @('CMD','CMD COMMAND CENTER'),
  @('PS','POWERSHELL CENTER'),
  @('MCSA','MCSA / WINDOWS SERVER (LEGACY)')
)
function mSec([string]$k,[string]$t){
  $sb = { Menu-Learn $k $t }.GetNewClosure()
  return @{ L = ($t + '  - BASICS / EXPLAIN'); A = $sb }
}
function Menu-LearnAll{ Show-Menu 'LEARNING CENTER (ALL SECTIONS)' {
  $l = @()
  foreach($s in $script:SECT){ $l += ,(mSec $s[0] $s[1]) }
  $l
}}
function Get-McsaTopic($e){
  $t = $null
  foreach($x in @($script:LRN['MCSA'])){ if($x.N -eq $e.T){ $t = $x; break } }
  if(-not $t){ $t = @{ N=[string]$e.T; D=[string]$e.D; W=[string]$e.D; U='-'; X='-'; S='-'; E='-'; K=''; C=''; T=''; URL='' } }
  $t.C = [string]$e.C
  $t.T = [string]$e.X
  $t.URL = [string]$e.U
  return $t
}
function Page-WhatMCSA{
  Page 'WHAT IS MCSA?' {
    W '  MCSA = Microsoft Certified Solutions Associate' Yellow
    W ''
    WrapW 'WHAT IT WAS:' 'A former Microsoft certification path that proved core skills on Windows Server and related technologies. Microsoft retired it on January 31, 2021.'
    WrapW 'WHAT IT IS NOT:' 'MCSA is not a network product and not a software product. It is not something you install or run.'
    WrapW 'WHAT THE LEARNING COVERED:' 'Historical MCSA-related learning covered Windows Server, Active Directory, DNS, DHCP, Group Policy, Networking, Storage, Hyper-V and PowerShell.'
    WrapW 'HOW TO USE IT HERE:' 'Open any numbered topic in the MCSA menu to read what the topic is, what it does, a real example, and to run a real sample command on this computer.'
    WrapW 'KEY STATEMENT:' 'MCSA is retired by Microsoft, while many of the Windows Server and administration concepts remain useful for learning and system administration.' 'Green'
  }
}
function mLearn($e){
  $sb = { Page-Topic (Get-McsaTopic $e) 'MCSA / WINDOWS SERVER (LEGACY)' 'MCSA' }.GetNewClosure()
  return @{ L = $e.T; A = $sb }
}

# ------------------------------------------------------------------ LEARNING DATA (Definition / Does / When / Example / Sample / Expected)
Add-Learn 'NET' @'
IPv4~The 32-bit numeric address of a device on a network, written as four numbers (0-255) separated by dots.~Identifies your computer on the network so packets can be delivered to it.~When checking connectivity, setting a static address or finding your PC for remote access.~A home PC with an address like 192.168.1.25 talks to its router at 192.168.1.1 (format example).~ipconfig | findstr /i IPv4~Lines such as IPv4 Address . . . : x.x.x.x - this is the real local address of your adapter.
IPv6~The 128-bit successor of IPv4, written as hex groups separated by colons.~Gives a huge address space and supports automatic configuration.~When your ISP or network uses IPv6, or when troubleshooting dual-stack problems.~Addresses beginning with fe80:: are link-local and exist on almost every adapter (format example).~ipconfig | findstr /i IPv6~IPv6 Address or Link-local IPv6 Address lines. If nothing is listed, IPv6 is off or unavailable.
MAC Address~A 48-bit hardware address of a network adapter, shown as six hex pairs.~Identifies the adapter on the local link; switches, routers and DHCP use it.~For DHCP reservations, MAC filtering and hardware inventory.~Format example: 00-1A-2B-3C-4D-5E.~getmac~A table with the Physical Address of each adapter and its transport name.
Subnet Mask / Prefix Length~Defines which part of an address is the network and which part is the host; /24 equals 255.255.255.0.~Lets Windows decide whether a destination is local or must go through the gateway.~When two computers on the same LAN cannot talk, or when planning address ranges.~With 192.168.1.25/24 the addresses 192.168.1.1-254 are reachable directly (format example).~Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias,IPAddress,PrefixLength -AutoSize~Your IPv4 addresses with their PrefixLength (24 means 255.255.255.0).
Default Gateway~The router address Windows uses for every destination outside the local subnet.~Connects your LAN to other networks and the Internet.~When local devices work but the Internet does not.~A home router is usually the default gateway.~ping -n 4 {GW}~Replies from your real gateway with low times. Timeouts mean the gateway is unreachable.
DNS~Domain Name System - translates names such as microsoft.com into IP addresses.~Lets people use names instead of numbers.~When sites open by IP address but not by name.~Your PC asks its DNS server for microsoft.com and receives an IP address.~nslookup microsoft.com~The DNS server that answered and the addresses returned for microsoft.com.
DHCP~Dynamic Host Configuration Protocol - automatically gives clients an IP address, mask, gateway and DNS.~Removes manual configuration; addresses are leased for a limited time.~When a PC has no IP or shows a 169.254.x.x (APIPA) address.~A router acting as DHCP server gives your PC an address for 24 hours.~ipconfig /all | findstr /i DHCP~DHCP Enabled, DHCP Server, Lease Obtained and Lease Expires lines per adapter.
Network Adapter~The physical or virtual device (Ethernet, Wi-Fi, Hyper-V vEthernet) that connects a computer to a network.~Sends and receives frames; has a name, status, MAC address and link speed.~When checking whether a cable or Wi-Fi is connected, or which adapter carries traffic.~Ethernet, Wi-Fi and vEthernet are common adapter names.~Get-NetAdapter | Format-Table Name,Status,LinkSpeed,MacAddress -AutoSize~Each adapter with Status Up or Disconnected, its speed and its MAC address.
Link Speed~The negotiated data rate between an adapter and the switch or access point.~Shows the raw speed of the physical link.~When the network is slow - 100 Mbps on a gigabit port often means a bad cable.~A gigabit port normally negotiates 1 Gbps.~Get-NetAdapter | Where-Object Status -eq Up | Format-Table Name,LinkSpeed -AutoSize~LinkSpeed of every connected adapter.
Routing~Choosing the path packets take between networks using a routing table.~Windows checks the table to send each packet to the local network or to the gateway.~When some networks are unreachable, or with VPNs and several adapters.~The route 0.0.0.0/0 is the default route through the gateway.~route print -4~The IPv4 table: Network Destination, Netmask, Gateway, Interface and Metric.
Ping~Sends ICMP echo requests to test whether a host is reachable and how fast.~Shows reply time and packet loss.~The first test for any connection problem.~Ping the gateway first, then a public name, to see where connectivity breaks.~ping -n 4 {GW}~Reply lines with time in ms and a summary; 0% loss means healthy.
Tracert~Traces the routers (hops) a packet crosses to reach a destination.~Lists every hop with its delay.~When a destination is slow or unreachable and you need to see where it stops.~Hop 1 is normally your own gateway.~tracert -d -h 8 microsoft.com~Numbered hops with times; asterisks mean a hop did not answer (often normal).
PathPing~Combines ping and tracert and measures packet loss per hop over time.~Finds the hop that drops packets.~When you see intermittent loss or jitter.~Loss that starts at one hop and continues to the end points at that hop.~pathping -n -q 3 -p 200 -h 6 microsoft.com~The hop list followed by loss statistics per hop.
NSLookup~A tool that queries a DNS server manually.~Shows which server answered and which records it returned.~When names do not resolve or resolve to the wrong address.~Query MX records to see where mail for a domain is delivered.~nslookup -type=mx microsoft.com~Mail exchanger names with preference numbers.
ARP~Address Resolution Protocol - maps IPv4 addresses to MAC addresses on the local network.~The ARP cache lists neighbours your PC recently talked to.~When two devices conflict on the LAN or to find the MAC of a device.~Your gateway always appears in the ARP table after traffic.~arp -a~Entries of Internet Address, Physical Address and type (dynamic or static).
Netstat~Shows active connections, listening ports and, with -o, the owning process ID.~Reveals what your PC is talking to and which ports it listens on.~When investigating unknown connections or a port that is already in use.~Port 3389 LISTENING means Remote Desktop is accepting connections.~netstat -ano | findstr LISTENING~Listening ports with their PID; match the PID in Task Manager or the Processes menu.
'@
Add-Learn 'FW' @'
Firewall~Windows Defender Firewall - a host-based filter that allows or blocks traffic using rules and profiles.~Inspects inbound and outbound connections and applies the rules of the active profile.~To confirm protection is ON, or when an application cannot connect or be reached.~A web server needs an inbound rule for TCP 80 or clients are blocked.~Get-NetFirewallProfile | Format-Table Name,Enabled,DefaultInboundAction,DefaultOutboundAction -AutoSize~One row per profile (Domain, Private, Public); Enabled True means the firewall is ON.
Inbound Rule~A firewall rule for traffic coming INTO this computer.~Allows or blocks connections to a program or local port.~When a service on this PC must be reachable, such as RDP or a web server.~The Remote Desktop rule opens TCP 3389 for incoming connections.~Get-NetFirewallRule -Direction Inbound -Enabled True | Select-Object -First 10 | Format-Table DisplayName,Profile,Action -AutoSize~Enabled inbound rules with profile and Allow/Block action.
Outbound Rule~A firewall rule for traffic leaving this computer.~Allows or blocks a program or port from reaching the network.~To stop an application from calling out, or to lock down a server.~Blocking an old program from reaching the Internet.~Get-NetFirewallRule -Direction Outbound -Enabled True | Select-Object -First 10 | Format-Table DisplayName,Profile,Action -AutoSize~Enabled outbound rules with profile and action. Windows allows outbound by default.
Network Profile (Public / Private / Domain)~Each connection is classified as Public, Private or Domain, and the matching firewall profile applies.~Public is the most restrictive, Private is for trusted networks, Domain applies on an Active Directory network.~When sharing or discovery does not work, or a network is treated too strictly or too loosely.~Cafe Wi-Fi should be Public; your own home network Private.~Get-NetConnectionProfile | Format-Table Name,NetworkCategory,IPv4Connectivity -AutoSize~Each connected network with its category (Public, Private or DomainAuthenticated).
Windows Defender~Microsoft Defender Antivirus - the anti-malware engine built into Windows.~Scans files in real time, updates signatures and reports threats.~To verify protection is enabled and signatures are current.~An old signature date can mean updates are failing.~Get-MpComputerStatus | Format-List AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated~True/False flags and the last signature update. NOT AVAILABLE if another antivirus manages the system.
UAC~User Account Control - asks for approval before a program runs with administrator rights.~Limits the damage malware can do by running programs with standard rights by default.~When checking why elevation prompts appear or whether UAC was turned off.~Installing software normally shows a UAC prompt.~Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System | Format-List EnableLUA,ConsentPromptBehaviorAdmin~EnableLUA 1 means UAC is ON; ConsentPromptBehaviorAdmin selects the prompt style.
Security Policy~Local rules for passwords, account lockout, auditing and user rights (secpol.msc).~Defines how strict the machine is about sign-in and security settings.~When you must enforce password length, lockout limits or auditing.~Minimum password length and lockout after several failed sign-ins.~net accounts~Minimum password length, maximum password age and lockout settings of this computer.
Certificate~A digital document that binds a public key to an identity such as a website, person or device.~Proves identity and enables encryption such as HTTPS.~When a site shows certificate warnings or a service needs a TLS certificate.~The certificate of a secure website is issued by a trusted certificate authority.~Get-ChildItem Cert:\LocalMachine\Root | Select-Object -First 8 | Format-Table Subject,NotAfter -AutoSize~Trusted root certificate authorities with their expiry dates.
BitLocker~Full-volume encryption built into Windows Pro, Enterprise and Server.~Encrypts a drive so data is unreadable without the key or TPM.~To protect laptops and removable drives against theft.~A stolen laptop with BitLocker ON cannot be read without the recovery key.~manage-bde -status~Per volume: Conversion Status, Percentage Encrypted and Protection On/Off.
'@
Add-Learn 'SVC' @'
Windows Service~A background program managed by the Service Control Manager that can start without a user signed in.~Runs system functions such as DNS Client, Windows Update or the Print Spooler.~When a feature stops working, or to start/stop a component.~The DNS Client service (Dnscache) resolves names for every application.~Get-Service | Select-Object -First 10 | Format-Table Status,Name,DisplayName -AutoSize~The first ten services with Status, short Name and DisplayName.
Service Status~The current state of a service: Running, Stopped, Paused or a pending state.~Tells you whether the service is doing its work right now.~When a service-dependent feature fails.~Stopped means the service is not running.~Get-Service Dnscache,EventLog,Winmgmt | Format-Table Status,Name,DisplayName -AutoSize~Three core services with their live status.
Running~The service process is started and active.~Its functions are available to Windows and applications.~To confirm a needed service is up.~Windows Firewall (mpssvc) should normally be Running.~Get-Service | Where-Object Status -eq Running | Select-Object -First 10 | Format-Table Name,DisplayName -AutoSize~Ten running services.
Stopped~The service is installed but not running.~Its features are unavailable until it is started.~When a service you expect to work is not active.~Many optional services are Stopped until needed.~Get-Service | Where-Object Status -eq Stopped | Select-Object -First 10 | Format-Table Name,DisplayName -AutoSize~Ten stopped services.
Startup Type (Automatic / Manual / Disabled)~Controls when a service starts. Automatic starts at boot, Manual starts on demand, Disabled can never start.~Decides whether a service is available without your action.~When a service does not start after reboot, or to harden a machine by disabling unneeded services.~A Disabled service will refuse to start until its type is changed.~Get-Service Dnscache,EventLog,Winmgmt | Format-Table Name,Status,StartType -AutoSize~The StartType column shows Automatic, Manual or Disabled.
'@
Add-Learn 'PROC' @'
Process~A running instance of a program with its own memory and threads.~Executes the code of an application or a service.~When an application hangs or uses too many resources.~Opening Notepad starts a notepad.exe process.~Get-Process | Sort-Object CPU -Descending | Select-Object -First 8 | Format-Table Id,ProcessName,CPU -AutoSize~The eight processes that used the most CPU time, with their IDs.
PID (Process ID)~A unique number Windows assigns to each running process.~Lets tools and commands target one exact process.~When killing or inspecting a specific process, or matching a port to a program.~netstat -ano shows the PID that owns each port.~Get-Process -Id $PID | Format-Table Id,ProcessName -AutoSize~The PID and name of the PowerShell process running this program.
CPU Usage~How much processor time a process or the whole system is consuming.~Shows what is keeping the processor busy.~When the computer is slow or the fan runs loudly.~A process stuck at 100 percent CPU can freeze the system.~Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | Format-Table Id,ProcessName,CPU -AutoSize~Total CPU seconds per process; higher means more processor time used.
Memory Usage~The RAM a process holds (working set).~Shows which programs use most memory.~When free RAM is low or the system pages heavily.~A browser with many tabs can use several GB.~Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 | Format-Table Id,ProcessName,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize~The eight biggest processes by real RAM in MB.
Parent Process~The process that started another process.~Explains where a process came from and helps spot suspicious chains.~When investigating an unknown process.~explorer.exe is the parent of programs you start from the desktop.~Get-CimInstance Win32_Process -Filter "ProcessId=$PID" | Format-Table ProcessId,ParentProcessId,Name -AutoSize~ProcessId and ParentProcessId of the running PowerShell.
Critical System Processes~Core processes such as lsass, csrss, wininit, winlogon, services and smss.~Windows cannot run without them.~To understand why some processes must never be stopped.~Killing lsass or csrss crashes or reboots Windows immediately.~Get-Process lsass,csrss,winlogon | Format-Table Id,ProcessName -AutoSize~The real PIDs of critical processes. This program refuses to kill them.
'@
Add-Learn 'USR' @'
Local User~An account stored on this computer only.~Lets a person sign in and receive permissions on this machine.~When creating, disabling or checking accounts.~Your own sign-in name is a local user unless the PC is domain-joined.~Get-LocalUser | Format-Table Name,Enabled,LastLogon -AutoSize~All local accounts with Enabled and last logon time.
Administrator vs Standard User~Administrators can change the system and install software; Standard users have limited rights.~Separating rights limits what malware or mistakes can do.~When deciding which account to use daily - use Standard and elevate when needed.~Members of the Administrators group get UAC prompts.~whoami /groups~Group memberships of the current user; S-1-5-32-544 is the Administrators group.
Local Group~A collection of accounts on this computer used to assign permissions.~Permissions are granted to groups instead of individuals.~When giving several users the same access.~Administrators, Users and Remote Desktop Users are built-in local groups.~Get-LocalGroup | Format-Table Name -AutoSize~Names of all local groups.
Domain User~An account stored in Active Directory and usable on any domain computer.~Provides central sign-in and policies across the network.~In companies and schools with a domain.~A domain user is written DOMAIN\name.~Get-CimInstance Win32_ComputerSystem | Format-List Name,Domain,PartOfDomain~PartOfDomain True means the PC is joined to a domain; False means a workgroup.
Domain Group~A group stored in Active Directory used to give permissions to many domain users at once.~Central and consistent permission management.~When managing access to file shares or applications in a domain.~Domain Admins is a built-in domain group.~Get-LocalGroupMember -Group Administrators | Format-Table Name,PrincipalSource -AutoSize~Members of local Administrators; PrincipalSource shows Local or ActiveDirectory.
Current Identity (whoami)~The account and privileges of the user running the program.~Shows who you are to Windows and what you may do.~Before running sensitive commands.~If your name is not in Administrators, admin tools will fail.~whoami~DOMAIN-or-COMPUTER\username of the current user.
'@
Add-Learn 'GPO' @'
GPO~Group Policy Object - a set of settings applied automatically to computers or users.~Enforces security, desktop and software settings centrally.~In domains, or locally with gpedit.msc, to enforce configuration.~A GPO can force a password policy on all company PCs.~gpresult /r /scope computer~Applied GPOs for this computer and the last time policy was applied.
Computer Configuration~The part of a GPO that applies to the machine regardless of who signs in.~Controls startup scripts, security and services.~When a setting must apply to every user of a PC.~Firewall and password rules are computer settings.~gpresult /r /scope computer~Applied Computer Settings and their source GPOs.
User Configuration~The part of a GPO that follows the user to any computer.~Controls desktop, folder redirection and logon scripts.~When settings should follow one person or group.~A mapped drive for the Accounting group.~gpresult /r /scope user~Applied User Settings and the GPOs that provided them.
OU (Organizational Unit)~A container in Active Directory that holds users, groups and computers.~GPOs are linked to OUs so they apply to that container.~When structuring a domain for delegation and policy.~An OU called Sales holds all Sales computers and users.~Get-ADOrganizationalUnit -Filter * | Select-Object -First 10 | Format-Table Name,DistinguishedName -AutoSize~List of OUs. NOT AVAILABLE if RSAT / Active Directory tools are not installed.
Domain Policy~A policy linked to the whole domain that all domain computers receive.~Sets domain-wide rules such as password policy.~When one rule must apply everywhere.~Default Domain Policy.~Get-ADDefaultDomainPasswordPolicy~The password policy of the domain. NOT AVAILABLE without Active Directory tools.
Local Group Policy~Policy stored on one computer only and edited with gpedit.msc.~Configures a standalone PC without a domain.~On workgroup PCs or for testing settings.~Disabling an option for all users of one PC.~net accounts~Local password and lockout values, which can be set by local policy.
gpupdate~Command that refreshes Group Policy immediately.~Re-applies policy without waiting for the background refresh.~After changing a GPO and wanting it to take effect now.~gpupdate /force re-applies all settings.~gpupdate /force~Messages that Computer and User Policy updated successfully.~LOW - refreshes policy; a logoff or restart may be requested.
gpresult~Command that reports which policies were applied and from where.~Shows the Resultant Set of Policy for a user or computer.~When a setting does not apply or applies unexpectedly.~gpresult /h report.html creates a full HTML report.~gpresult /r /scope computer~Sections listing Applied Group Policy Objects and Denied objects with reasons.
'@
Add-Learn 'AD' @'
Active Directory~Microsoft directory service that stores users, computers and groups for a domain and authenticates them.~Provides central sign-in, permissions and policy for a network.~In organisations with many computers and users.~One sign-in works on every domain PC.~Get-CimInstance Win32_ComputerSystem | Format-List Name,Domain,PartOfDomain,DomainRole~Shows whether this PC is domain-joined. AD tools run only where the role or RSAT is installed.
Domain~A logical boundary of an Active Directory database with a shared name such as company.local.~Groups objects that share security policy and authentication.~When joining PCs to the company network.~Users sign in as DOMAIN\user.~Get-ADDomain | Format-List Name,DNSRoot,DomainMode~Domain name and functional level. NOT AVAILABLE if AD tools are missing.
Domain Controller~A server that runs AD DS and answers sign-in requests.~Authenticates users and stores the directory.~When sign-in fails or replication is checked.~Two domain controllers give redundancy.~Get-ADDomainController -Filter * | Format-Table Name,IPv4Address,Site -AutoSize~Domain controllers with IP and site. NOT AVAILABLE without AD tools.
OU (Organizational Unit)~A container inside a domain for users, groups and computers.~Organises objects and lets you link GPOs and delegate control.~When designing the directory structure.~OU Sales contains all Sales objects.~Get-ADOrganizationalUnit -Filter * | Select-Object -First 10 | Format-Table Name -AutoSize~List of OUs. NOT AVAILABLE without AD tools.
User (AD)~A person or service account stored in Active Directory.~Signs in and receives permissions across the domain.~When creating or troubleshooting domain accounts.~The account jsmith in the domain.~Get-ADUser -Filter * -ResultSetSize 5 | Format-Table Name,Enabled -AutoSize~Five domain users. NOT AVAILABLE without AD tools.
Group (AD)~A collection of domain accounts used for permissions.~Manages access for many users at once.~When giving a team access to a share.~Group Sales-Team has access to the Sales folder.~Get-ADGroup -Filter * -ResultSetSize 5 | Format-Table Name,GroupScope -AutoSize~Five domain groups. NOT AVAILABLE without AD tools.
Computer Object~The AD record that represents a domain-joined computer.~Lets the domain authenticate and manage the machine.~When a PC loses its trust relationship.~Each joined PC has a computer object.~Get-ADComputer -Filter * -ResultSetSize 5 | Format-Table Name,Enabled -AutoSize~Five computer accounts. NOT AVAILABLE without AD tools.
Replication~Copying directory changes between domain controllers.~Keeps every controller consistent.~When a change does not appear on another controller.~A new user created on DC1 replicates to DC2.~repadmin /replsummary~A replication summary with failures and largest delta. Only on domain controllers or with tools.
Site~An AD object representing a well-connected IP network location.~Controls replication traffic and where clients sign in.~With branch offices connected by slow links.~Head-Office and Branch sites.~Get-ADReplicationSite -Filter * | Format-Table Name -AutoSize~AD sites. NOT AVAILABLE without AD tools.
'@
Add-Learn 'DNS' @'
DNS~Domain Name System - translates names into IP addresses.~Answers name queries so you can use names instead of numbers.~When sites open by IP but not by name.~microsoft.com resolves to one or more IP addresses.~nslookup microsoft.com~The DNS server that answered and the resolved addresses.
DNS Server~A computer or role that stores DNS zones and answers queries.~Resolves names for clients and for AD.~When hosting internal names or troubleshooting resolution.~Your router or a Windows Server can be a DNS server.~Get-DnsClientServerAddress | Format-Table InterfaceAlias,AddressFamily,ServerAddresses -AutoSize~The DNS servers configured on each adapter.
DNS Zone~A portion of the DNS namespace managed by a server, such as company.local.~Holds the records of a domain.~When creating or troubleshooting a domain zone.~Forward and reverse lookup zones.~Get-DnsServerZone | Format-Table ZoneName,ZoneType,IsDsIntegrated -AutoSize~Zones on this DNS server. NOT AVAILABLE if the DNS Server role is not installed.
A Record~A DNS record that maps a name to an IPv4 address.~Lets clients find a host by name.~When a name must point to a server.~server1.company.local points to a server IPv4 address.~nslookup -type=A microsoft.com~One or more IPv4 addresses for the name.
AAAA Record~A DNS record that maps a name to an IPv6 address.~The IPv6 counterpart of the A record.~On IPv6 networks.~A site with both A and AAAA records is reachable by both protocols.~nslookup -type=AAAA microsoft.com~IPv6 addresses, or nothing if the name has no AAAA record.
CNAME~A record that makes one name an alias of another name.~Lets several names point to the same host.~When www should follow a canonical host name.~www.company.com is an alias of web01.company.com.~nslookup -type=CNAME www.microsoft.com~The canonical name that the alias points to.
MX~Mail Exchanger record - names the servers that receive email for a domain.~Directs email delivery.~When mail is not being delivered.~Lower preference numbers are tried first.~nslookup -type=MX microsoft.com~Mail exchanger host names with preference values.
Forwarder~A DNS server that receives queries your server cannot answer itself.~Sends unknown names to another DNS server.~When an internal DNS server needs to resolve Internet names.~Forward unknown names to the ISP or a public resolver.~Get-DnsServerForwarder~The forwarder IP addresses. NOT AVAILABLE without the DNS Server role.
DNS Cache~Temporary storage of recent DNS answers on the client.~Speeds up repeated lookups.~When a name resolves to an old address.~Flush the cache after a DNS record changes.~Get-DnsClientCache | Select-Object -First 10 | Format-Table Entry,Type,Data -AutoSize~Recently resolved names with record type and data.
Flush DNS Cache~The action of clearing the local DNS cache.~Forces fresh lookups.~After a DNS change or when a site resolves incorrectly.~ipconfig /flushdns removes cached entries.~ipconfig /flushdns~Message: Successfully flushed the DNS Resolver Cache.~LOW - clears cached name lookups only.
'@
Add-Learn 'DHCP' @'
DHCP~Dynamic Host Configuration Protocol - hands out IP settings automatically.~Configures IP address, mask, gateway and DNS for clients.~When a client has no or wrong IP settings.~A router gives every device an address.~ipconfig /all | findstr /i DHCP~DHCP Enabled, DHCP Server and lease lines for each adapter.
DHCP Server~The role or device that answers DHCP requests and owns the address pool.~Assigns addresses and options.~In any network using automatic addressing.~A Windows Server with the DHCP role.~Get-Service DHCPServer~The DHCP Server service status. NOT AVAILABLE if the role is not installed.
Scope~A range of IP addresses a DHCP server may lease, such as 192.168.1.100-200.~Defines the pool and options for a subnet.~When planning or fixing address exhaustion.~One scope per subnet.~Get-DhcpServerv4Scope | Format-Table ScopeId,Name,State,StartRange,EndRange -AutoSize~The scopes on this server. NOT AVAILABLE without the DHCP Server role.
Lease~The time a client may keep an address before renewing it.~Prevents addresses from being lost forever.~When a client should get a new address.~A lease of 8 days is the Windows Server default.~ipconfig /renew~Renews the lease and shows the adapter configuration.~MEDIUM - your IP address may change and connections may drop briefly.
Reservation~A fixed address that DHCP always gives to one MAC address.~Keeps servers and printers on a stable IP without manual setup.~When a device needs a permanent address.~A printer always receives the same address.~Get-DhcpServerv4Scope | Get-DhcpServerv4Reservation | Format-Table IPAddress,ClientId,Name -AutoSize~Reservations. NOT AVAILABLE without the DHCP Server role.
DHCP Option~Extra settings a DHCP server sends, such as gateway (003) and DNS (006).~Delivers network settings beyond the address.~When clients get the wrong gateway or DNS.~Option 006 gives the DNS servers.~Get-DhcpServerv4OptionValue~Configured options. NOT AVAILABLE without the DHCP Server role.
DHCP Failover~Two DHCP servers share a scope for redundancy.~Keeps DHCP working if one server fails.~When high availability is required.~Load balance or hot standby modes.~Get-DhcpServerv4Failover~Failover relationships. NOT AVAILABLE without the DHCP Server role.
'@
Add-Learn 'IIS' @'
IIS~Internet Information Services - the Windows web server.~Hosts websites and web applications.~When publishing sites or troubleshooting HTTP errors.~An intranet site hosted on a Windows Server.~Get-Service W3SVC~Status of the World Wide Web Publishing Service. NOT AVAILABLE if IIS is not installed.
Website~A site configured in IIS with content path and bindings.~Serves pages to browsers.~When adding or checking sites.~Default Web Site.~Get-Website~Each site with State and physical path. NOT AVAILABLE if IIS is not installed.
Binding~The combination of protocol, IP, port and host name a site listens on.~Decides which requests reach which site.~When a site does not answer on the expected address or port.~http *:80 and https *:443.~Get-WebBinding~Bindings with protocol and bindingInformation. NOT AVAILABLE if IIS is not installed.
Application Pool~An isolated worker process group that runs one or more web applications.~Isolates sites so one failure does not stop the others.~When a site hangs or needs recycling.~One pool per application is common.~Get-IISAppPool~Pools with state. NOT AVAILABLE if IIS management tools are not installed.
Certificate (HTTPS)~A TLS certificate bound to an HTTPS site.~Encrypts traffic and proves the server identity.~When enabling HTTPS or when browsers warn about certificates.~The site certificate lives in the LocalMachine personal store.~Get-ChildItem Cert:\LocalMachine\My | Format-Table Subject,NotAfter -AutoSize~Certificates with expiry dates.
Port 80 (HTTP)~The standard port for unencrypted web traffic.~Serves plain HTTP.~When checking if a web server is listening.~http://server opens port 80.~netstat -ano | findstr :80~Lines with :80 and LISTENING mean something accepts HTTP.
Port 443 (HTTPS)~The standard port for encrypted web traffic.~Serves HTTPS with TLS.~When checking secure sites and firewall rules.~https://server opens port 443.~netstat -ano | findstr :443~Lines with :443 and LISTENING mean HTTPS is available.
'@
Add-Learn 'SRV' @'
Windows Server~Microsoft server operating system for roles such as AD, DNS, DHCP, file and Hyper-V.~Provides infrastructure services to many clients.~When building or managing servers.~Windows Server 2022 running DNS and DHCP.~Get-CimInstance Win32_OperatingSystem | Format-List Caption,Version,BuildNumber,ProductType~ProductType 1 is Windows client; 2 or 3 is a server.
Server Role~A major function a server performs, such as AD DS, DNS or DHCP.~Installs the components for that function.~When deploying a service.~The DNS Server role.~Get-WindowsFeature | Where-Object InstallState -eq Installed | Select-Object -First 10 | Format-Table DisplayName,Name -AutoSize~Installed roles and features. NOT AVAILABLE on Windows client.
Feature~An optional Windows component that supports roles or adds capability.~Adds tools such as RSAT or Telnet Client.~When a tool or capability is missing.~Hyper-V or Windows Subsystem for Linux.~Get-WindowsOptionalFeature -Online | Select-Object -First 10 | Format-Table FeatureName,State -AutoSize~Features with Enabled or Disabled state.
Server Manager~The console for installing and managing roles on servers.~Central dashboard for local and remote servers.~When adding roles or checking server health.~ServerManager.exe.~Get-Command ServerManager.exe | Format-List Name,Source~Shows the tool path if present. NOT AVAILABLE on Windows client.
Server Core~An installation option without the desktop shell, managed by command line and remote tools.~Smaller footprint, fewer updates, less attack surface.~For production servers managed remotely.~Use sconfig locally and PowerShell remotely.~Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Format-List InstallationType,EditionID~InstallationType: Server Core, Server or Client.
Desktop Experience~The Windows Server installation option that includes the full graphical desktop.~Allows local GUI tools.~When administrators prefer graphical tools.~Server with Desktop Experience.~Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Format-List InstallationType,EditionID~InstallationType Server means Desktop Experience is installed.
'@
Add-Learn 'HV' @'
Hyper-V~Microsoft hypervisor that runs virtual machines.~Shares physical hardware among several isolated systems.~For labs, testing and server consolidation.~Run a Windows Server VM on a laptop.~Get-Service vmms~Status of the Virtual Machine Management service. NOT AVAILABLE if Hyper-V is not installed.
Virtual Machine~A software computer with its own virtual CPU, memory, disk and network.~Runs an operating system independently of the host.~When testing without a physical machine.~A Windows Server test VM.~Get-VM~VMs with State, CPU and memory. NOT AVAILABLE without Hyper-V.
Virtual Switch~A software switch connecting VMs to each other and to a network.~Provides External, Internal or Private connectivity.~When a VM needs network access.~External switch bound to a physical adapter.~Get-VMSwitch~Switches with type. NOT AVAILABLE without Hyper-V.
Virtual Disk~A VHD or VHDX file that acts as a VM hard disk.~Stores the VM operating system and data.~When creating or moving VMs.~server.vhdx.~Get-VM | Get-VMHardDiskDrive | Format-Table VMName,Path -AutoSize~Disk file paths per VM. NOT AVAILABLE without Hyper-V.
Checkpoint~A saved state of a VM at a moment in time.~Lets you roll back after a change.~Before risky updates in a lab.~Checkpoint before installing software.~Get-VM | Get-VMSnapshot~Checkpoints per VM. Empty output means none exist.
Dynamic Memory~Hyper-V feature that adjusts VM memory to demand.~Uses host RAM efficiently.~When running many VMs.~A VM starts at 2 GB and grows if needed.~Get-VM | Get-VMMemory | Format-Table VMName,DynamicMemoryEnabled,Startup -AutoSize~DynamicMemoryEnabled and startup value per VM.
'@
Add-Learn 'STO' @'
Disk~A physical or virtual storage device.~Holds partitions and volumes.~When checking size, health and layout.~An SSD or a virtual disk.~Get-Disk | Format-Table Number,FriendlyName,PartitionStyle,OperationalStatus -AutoSize~Each disk with number, partition style and status.
Partition~A section of a disk.~Divides a disk into logical parts.~When planning layout or dual boot.~EFI, system and Windows partitions.~Get-Partition | Format-Table DiskNumber,PartitionNumber,DriveLetter,Type -AutoSize~Partitions with drive letters and types.
Volume~A formatted storage area with a file system, usually with a drive letter.~What users see as C: or D:.~When checking free space or file system.~Volume C: holds Windows.~Get-Volume | Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus -AutoSize~Volumes with file system and health.
File System (NTFS)~The structure that stores files on a volume, such as NTFS, ReFS or FAT32.~Provides permissions, compression and journaling.~When choosing a format for a disk.~NTFS is the Windows default.~Get-Volume | Format-Table DriveLetter,FileSystem -AutoSize~The FileSystem column.
Free Space~The unused capacity of a volume.~Windows needs free space to update and page.~When updates fail or disks fill up.~Keep 15 percent free.~Get-Volume | Format-Table DriveLetter,@{n='Free(GB)';e={[math]::Round($_.SizeRemaining/1GB,1)}},@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}} -AutoSize~Real free and total space per volume.
Storage Spaces~Windows technology that pools disks and creates resilient virtual disks.~Combines drives with mirroring or parity.~For flexible resilient storage.~A mirror across two disks.~Get-StoragePool | Format-Table FriendlyName,HealthStatus,IsPrimordial -AutoSize~Pools. Only Primordial appears if none are configured.
BitLocker~Drive encryption built into Windows.~Protects data at rest.~To secure laptops and removable drives.~Encrypt C: with a TPM.~manage-bde -status~Conversion status and protection state per volume.
CHKDSK~Checks a file system for errors.~Reports and optionally repairs problems.~When files are corrupt or the disk misbehaves.~chkdsk C: is read-only; /f repairs.~chkdsk C:~Stages of the scan and a summary of disk space and bad sectors.
'@
Add-Learn 'REM' @'
RDP~Remote Desktop Protocol - shows a remote desktop over the network (TCP 3389).~Lets you use a computer from another location.~To administer servers or a PC remotely.~mstsc opens the Remote Desktop client.~Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' | Format-List fDenyTSConnections~fDenyTSConnections 0 means Remote Desktop is enabled, 1 means disabled.
WinRM~Windows Remote Management - the service for remote management over HTTP or HTTPS.~Allows remote PowerShell and management commands.~When managing servers remotely.~Ports 5985 and 5986.~winrm enumerate winrm/config/listener~Listener entries with address and port. An error means WinRM is not configured.
PowerShell Remoting~Running PowerShell commands on another computer using WinRM.~Manages many machines from one console.~For automation and administration.~Enter-PSSession runs an interactive session.~Test-WSMan localhost~Product and protocol details when remoting is available.
Remote Management~The practice of administering machines from a distance using RDP, WinRM and RSAT.~Avoids visiting each server.~In every larger environment.~Server Manager can manage remote servers.~Get-Service WinRM,TermService | Format-Table Status,Name,DisplayName -AutoSize~Live status of the remote-management services.
Test-WSMan~A cmdlet that tests whether WinRM answers on a computer.~Confirms remote PowerShell connectivity.~Before using PowerShell Remoting.~Test-WSMan servername.~Test-WSMan localhost~A response with ProtocolVersion when WinRM is available; an error otherwise.
'@
Add-Learn 'PERF' @'
CPU Usage~The percentage of processor capacity currently in use.~Shows how busy the processor is.~When the system is slow.~Sustained 100 percent load means the CPU is the bottleneck.~Get-CimInstance Win32_Processor | Format-List Name,LoadPercentage,NumberOfCores,NumberOfLogicalProcessors~The processor name, cores and the current LoadPercentage.
RAM Usage~How much physical memory is used and free.~Shows memory pressure.~When applications are slow or pages swap heavily.~Little free RAM makes Windows use the pagefile.~Get-CimInstance Win32_OperatingSystem | Format-List @{n='TotalGB';e={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}},@{n='FreeGB';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}}~Real total and free RAM in GB.
Disk Usage~Capacity and free space of drives.~Shows if a disk is filling up.~When updates fail or the system is slow.~Keep some free space on C:.~Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Format-Table DeviceID,@{n='Size(GB)';e={[math]::Round($_.Size/1GB,1)}},@{n='Free(GB)';e={[math]::Round($_.FreeSpace/1GB,1)}} -AutoSize~Each local drive with size and free space.
Network Traffic~Bytes received and sent by each adapter.~Shows how much data flows through a network connection.~When looking for heavy network use.~Large numbers of sent bytes may show uploads.~Get-NetAdapterStatistics | Format-Table Name,ReceivedBytes,SentBytes -AutoSize~Totals since the adapter started.
Process Memory~RAM held by individual processes.~Shows which programs use the most memory.~When RAM runs low.~A browser can use several GB.~Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | Format-Table Id,ProcessName,@{n='RAM(MB)';e={[math]::Round($_.WorkingSet64/1MB,1)}} -AutoSize~The five biggest processes by RAM.
Load Percentage~A performance counter showing current processor time as a percentage.~Live measurement of CPU load.~To sample real-time load.~Sample twice to see changes.~Get-Counter '\Processor(_Total)\% Processor Time'~A CounterSamples table with the current percentage.
'@
Add-Learn 'TRB' @'
SFC~System File Checker - verifies protected Windows files.~Finds and can repair corrupted system files.~When Windows behaves strangely or updates fail.~sfc /scannow repairs; /verifyonly only reports.~sfc /verifyonly~Windows Resource Protection reports whether integrity violations were found.~LOW - read-only, but takes several minutes.
DISM~Deployment Image Servicing and Management - checks and repairs the Windows component store.~Repairs the image that SFC uses.~When SFC cannot repair files.~DISM /Online /Cleanup-Image /CheckHealth checks quickly.~DISM /Online /Cleanup-Image /CheckHealth~The component store is repairable or No component store corruption detected.
CHKDSK~Checks a disk for file system errors.~Reports disk problems.~When files are corrupt or the disk is failing.~chkdsk C: only reads.~chkdsk C:~Stages 1-3 and a summary of space and bad sectors.
PING~Tests reachability and latency.~Shows if a host answers and how fast.~First test for connection problems.~Ping the gateway, then a name.~ping -n 4 {GW}~Replies with times and 0 percent loss when healthy.
NSLOOKUP~Queries DNS.~Shows whether a name resolves and to which address.~When sites open by IP but not by name.~Look up microsoft.com to test name resolution.~nslookup microsoft.com~The server used and the addresses returned.
TRACERT~Traces the route to a destination.~Shows where packets are delayed or stopped.~When a remote site is slow or unreachable.~Compare the last hop that answers.~tracert -d -h 8 microsoft.com~Hop list with times; asterisks mean no reply from that hop.
Event Viewer~The Windows event log.~Records errors, warnings and information from Windows and applications.~To find why something failed and when.~Look for Error events near the time of a problem.~wevtutil qe System /c:5 /rd:true /f:text~The five newest System events with level, source and message.
Services~The list of Windows services and their states.~Shows whether required services are running.~When a feature does not work.~Windows Update needs wuauserv.~sc query Dnscache~STATE 4 RUNNING means the service is running.
Device Manager~The list of hardware devices and drivers.~Shows devices with problems.~When hardware or drivers fail.~A yellow warning marks a problem device.~Get-PnpDevice -Status ERROR~Devices reporting errors. No output means none currently report an error.
Firewall Diagnostics~Checks profile state and logging of Windows Firewall.~Shows whether blocked traffic is logged and the log path.~When an application is blocked.~Enable dropped-packet logging to see blocks.~Get-NetFirewallProfile | Format-List Name,Enabled,LogBlocked,LogFileName~State and logging settings per profile.
'@
Add-Learn 'CMD' @'
SYSTEMINFO~Displays detailed OS and hardware configuration.~Reports OS version, boot time, hotfixes and network cards.~To inventory a PC or support a case.~Check OS Name and Original Install Date.~systeminfo~A long list of real values from this computer (takes several seconds).
IPCONFIG /ALL~Shows the full network configuration of every adapter.~Reports IP, mask, gateway, DNS, DHCP and MAC.~To check network settings.~Look for IPv4 Address and Default Gateway.~ipconfig /all~Each adapter block with your real IP settings.
PING~Tests reachability and time to a host.~Sends ICMP echo requests.~First connectivity test.~Ping the gateway.~ping -n 4 {GW}~Replies and a loss summary.
TRACERT~Shows the hops to a destination.~Finds where delay or loss starts.~When a site is slow.~Trace to microsoft.com.~tracert -d -h 8 microsoft.com~Numbered hops with times.
PATHPING~Ping plus tracert with per-hop loss statistics.~Finds the lossy hop.~With intermittent loss.~Run it to microsoft.com.~pathping -n -q 3 -p 200 -h 6 microsoft.com~Hops and a loss table.
NSLOOKUP~Queries DNS servers.~Shows name resolution results.~When names do not resolve.~Look up microsoft.com.~nslookup microsoft.com~Server and addresses.
NETSTAT -ANO~Shows connections and listening ports with process IDs.~Reveals which process owns a port.~When investigating connections.~Look for LISTENING ports.~netstat -ano | findstr LISTENING~Listening ports with PIDs.
ARP -A~Shows the IPv4 to MAC cache.~Lists local neighbours.~When troubleshooting LAN conflicts.~Find the gateway MAC.~arp -a~Internet Address, Physical Address, Type.
ROUTE PRINT~Shows the routing table.~Reveals how packets are routed.~When traffic uses the wrong path.~The 0.0.0.0 route is the default gateway.~route print -4~The IPv4 route table.
HOSTNAME~Prints the computer name.~Shows the name of this PC.~In scripts and support.~Confirm the machine identity.~hostname~Your real computer name.
WHOAMI /ALL~Shows the current user, groups and privileges.~Explains what the current account may do.~When permissions fail.~Check for the Administrators group.~whoami /all~User, SID, groups and privileges.
TASKLIST~Lists running processes.~Shows PID and memory of each process.~To find a process ID.~Look for a program by name.~tasklist~Image Name, PID, Session and Mem Usage.
TASKKILL~Terminates processes by PID or name.~Ends a stuck program.~When a program hangs.~taskkill /PID 1234 /F ends that process.~-~No sample is run because it changes the system. Use the PROCESSES menu, which confirms first.
SC QUERY~Service Control - queries and manages services.~Shows service state from the command line.~To check a service quickly.~sc query Dnscache~sc query Dnscache~STATE with RUNNING or STOPPED.
NET START~Lists started services (and starts one by name).~Shows running services.~To see what runs.~Check that a needed service appears in the list.~net start~The list of running services.
NETSH~Configures network components such as interfaces and firewall.~Shows or changes network settings.~When scripting network settings.~netsh interface show interface~netsh interface show interface~Interfaces with Admin State and Connect State.
DISKPART~Interactive disk partitioning tool.~Creates, deletes and formats partitions.~When managing disks from the command line.~select disk 1 then clean erases it.~-~Not run as a sample because wrong commands can erase disks. Use the confirmed option in this program.
SFC /VERIFYONLY~Checks system files without repairing.~Reports integrity violations.~To test system file health safely.~Run before /scannow.~sfc /verifyonly~Integrity report after several minutes.~LOW - read-only but slow.
DISM CHECKHEALTH~Quickly checks the component store.~Shows if corruption is flagged.~Before a deeper scan.~Repairable or not.~DISM /Online /Cleanup-Image /CheckHealth~The component store is repairable or No component store corruption detected.
CHKDSK C:~Reads the C: drive file system.~Reports errors without fixing.~When the disk might be failing.~/f would repair.~chkdsk C:~A stage-by-stage summary.
GPUPDATE /FORCE~Reapplies all Group Policy.~Refreshes computer and user policy.~After a policy change.~Run after editing a GPO.~gpupdate /force~Computer Policy and User Policy updated successfully.~LOW - a logoff may be requested.
GPRESULT /R~Shows applied policies.~Reports Resultant Set of Policy.~When a policy does not apply.~Check Applied Group Policy Objects.~gpresult /r /scope computer~Applied GPOs and security groups.
WEVTUTIL~Queries and manages event logs.~Reads events from the command line.~To read logs in scripts.~qe reads events.~wevtutil qe System /c:5 /rd:true /f:text~Five newest System events.
SCHTASKS /QUERY~Lists scheduled tasks.~Shows what runs automatically.~When investigating scheduled activity.~Look for unexpected tasks.~schtasks /query /fo table~Task Name, Next Run Time, Status.
POWERCFG /LIST~Lists power plans.~Shows available power schemes.~To check the active plan.~Balanced, High performance.~powercfg /list~Power schemes with GUIDs; the active one is starred.
BCDEDIT /ENUM~Shows boot configuration data.~Reveals boot entries.~When investigating boot problems.~Windows Boot Manager and Windows Boot Loader.~bcdedit /enum~Boot manager and loader entries.
MANAGE-BDE -STATUS~Shows BitLocker status.~Reports encryption state.~To verify drive encryption.~C: fully encrypted.~manage-bde -status~Conversion Status and Protection per volume.
CIPHER~Shows or changes EFS encryption of files.~Reports file encryption state.~When working with encrypted folders.~cipher lists the current folder.~cipher~Files marked E (encrypted) or U (unencrypted).
CERTUTIL -STORE MY~Lists certificates in the personal store.~Shows installed certificates.~When checking certificates.~Personal store of the computer account or user.~certutil -store My~Certificates with serial, issuer and expiry.
WINRM ENUMERATE~Shows WinRM listeners.~Confirms remote management listens.~When PowerShell Remoting fails.~HTTP listener on 5985.~winrm enumerate winrm/config/listener~Listener with Address and Port, or an error.
WINRS /?~Shows help for the remote shell tool.~Runs commands on a remote machine through WinRM.~When running commands remotely.~winrs -r:server ipconfig~winrs /?~Usage and options of winrs.
'@
Add-Learn 'PS' @'
Get-ComputerInfo~Cmdlet that returns detailed information about the computer.~Reports OS, BIOS, hardware and Windows details as one object.~To inventory a computer.~Show name, OS build and architecture.~Get-ComputerInfo | Select-Object CsName,WindowsProductName,OsBuildNumber,OsArchitecture | Format-List~Real values for this computer (takes a few seconds).
Get-Service~Cmdlet that lists Windows services.~Shows name, display name and status.~To check or filter services.~Get-Service Dnscache.~Get-Service | Select-Object -First 10 | Format-Table Status,Name,DisplayName -AutoSize~Ten services with status.
Get-Process~Cmdlet that lists running processes.~Shows Id, name, CPU and memory.~To find heavy processes.~Sort by WorkingSet64.~Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 | Format-Table Id,ProcessName -AutoSize~The eight biggest processes.
Get-NetAdapter~Cmdlet that lists network adapters.~Shows status, speed and MAC.~To check adapters.~Ethernet Up 1 Gbps.~Get-NetAdapter | Format-Table Name,Status,LinkSpeed,MacAddress -AutoSize~Your adapters with real status.
Get-NetIPAddress~Cmdlet that lists IP addresses.~Shows IPv4 and IPv6 addresses with prefix.~To see addresses configured.~InterfaceAlias Ethernet.~Get-NetIPAddress | Format-Table InterfaceAlias,AddressFamily,IPAddress,PrefixLength -AutoSize~Every IP address on this PC.
Get-NetRoute~Cmdlet that shows the routing table.~Lists destinations, next hops and metrics.~To check routes and the default gateway.~0.0.0.0/0 is the default route.~Get-NetRoute -AddressFamily IPv4 | Select-Object -First 10 | Format-Table DestinationPrefix,NextHop,RouteMetric -AutoSize~The first ten IPv4 routes.
Get-NetFirewallProfile~Cmdlet that shows firewall profile state.~Reports Domain, Private and Public settings.~To verify firewall is on.~Enabled True means active.~Get-NetFirewallProfile | Format-Table Name,Enabled,DefaultInboundAction -AutoSize~The three profiles with state.
Get-NetFirewallRule~Cmdlet that lists firewall rules.~Shows rule names, direction and action.~To review or search rules.~Filter by DisplayName.~Get-NetFirewallRule | Select-Object -First 10 | Format-Table DisplayName,Enabled,Direction,Action -AutoSize~Ten firewall rules.
Get-WindowsFeature~Cmdlet that lists server roles and features (Windows Server).~Shows what is installed or available.~To audit a server.~DNS or DHCP installed.~Get-WindowsFeature | Where-Object InstallState -eq Installed | Select-Object -First 10 | Format-Table DisplayName,Name -AutoSize~Installed roles. NOT AVAILABLE on Windows client.
Get-WindowsOptionalFeature~Cmdlet that lists optional features on Windows client.~Shows Enabled or Disabled features.~To check features such as Hyper-V.~Microsoft-Hyper-V-All.~Get-WindowsOptionalFeature -Online | Select-Object -First 10 | Format-Table FeatureName,State -AutoSize~Features and state.
Get-VM~Cmdlet that lists Hyper-V virtual machines.~Shows state, CPU and memory.~To manage VMs.~Running and Off VMs.~Get-VM~VM list. NOT AVAILABLE if Hyper-V is not installed.
'@
Add-Learn 'MCSA' @'
01 - Installation~Installing Windows Server, choosing editions and installation options.~Explains Server Core versus Desktop Experience, media and updates.~When deploying a new server.~Install Windows Server 2022 Standard with Desktop Experience.~Get-CimInstance Win32_OperatingSystem | Format-List Caption,Version,BuildNumber,OSArchitecture~The real edition, version and build of this computer.
02 - Active Directory~AD DS - users, groups, computers, OUs, domains, controllers, sites and replication.~Provides central identity and policy.~In organisations with many computers.~Join a PC to company.local.~Get-CimInstance Win32_ComputerSystem | Format-List Name,Domain,PartOfDomain,DomainRole~Shows whether this PC is joined to a domain.
03 - DNS~Name resolution, zones, records and forwarders.~Translates names to addresses.~When names do not resolve.~Check that microsoft.com resolves.~nslookup microsoft.com~The DNS server used and the answer.
04 - DHCP~Automatic IP addressing with scopes, leases, reservations and options.~Assigns IP settings to clients.~When clients lack an address.~Check DHCP lease information.~ipconfig /all | findstr /i DHCP~DHCP Enabled, DHCP Server and lease times.
05 - Group Policy~GPOs, OUs, computer and user policy, security policy and RSOP.~Applies settings centrally.~When enforcing settings.~Review applied computer policies.~gpresult /r /scope computer~Applied GPOs for this computer.
06 - File Services~NTFS permissions, shares, SMB and DFS.~Shares files on the network.~When publishing folders.~List shares on this PC.~Get-SmbShare | Format-Table Name,Path -AutoSize~Shares such as C$ and ADMIN$.
07 - Storage~Disks, volumes, Storage Spaces, deduplication and BitLocker.~Manages data storage.~When adding or checking disks.~Check free space.~Get-Volume | Format-Table DriveLetter,FileSystem,HealthStatus -AutoSize~Volumes with health.
08 - Networking~IPv4, IPv6, DNS, DHCP, routing, NAT, VPN and RRAS.~Connects systems.~When designing or troubleshooting networks.~Review IP addresses.~Get-NetIPAddress | Format-Table InterfaceAlias,IPAddress,PrefixLength -AutoSize~Addresses on every adapter.
09 - Hyper-V~Virtual machines, switches, disks and checkpoints.~Virtualises workloads.~In labs and data centers.~List VMs.~Get-VM~VM list. NOT AVAILABLE if Hyper-V is not installed.
10 - IIS~Web server, sites, bindings, application pools and certificates.~Hosts web content.~When publishing websites.~List sites.~Get-Website~Sites. NOT AVAILABLE if IIS is not installed.
11 - Security~Firewall, Defender, UAC, auditing, certificates and security policy.~Protects the system.~When hardening a computer.~Check firewall profiles.~Get-NetFirewallProfile | Format-Table Name,Enabled -AutoSize~Enabled state per profile.
12 - PowerShell~Cmdlets, modules, objects, pipelines, remoting and automation.~Automates administration.~When managing at scale.~Find cmdlets about services.~Get-Command -Noun Service | Format-Table CommandType,Name -AutoSize~Cmdlets that work with services.
13 - Remote Management~RDP, WinRM, PowerShell Remoting and RSAT.~Manages servers remotely.~When administering without local access.~Test that WinRM answers.~Test-WSMan localhost~Protocol details or an error when remoting is off.
14 - Troubleshooting~Event Viewer, performance, networking, services, storage and boot problems.~Finds and fixes faults.~When something fails.~Read the newest System events.~wevtutil qe System /c:5 /rd:true /f:text~The five newest System events.
'@

# ------------------------------------------------------------------ MAIN MENU
function Menu-Main{ Show-Menu 'MAIN MENU' {
  @(
    (mSub 'SYSTEM INFORMATION' { Page-SysInfo }),
    (mSub 'WINDOWS TOOLS' { Menu-WinTools }),
    (mSub 'CONTROL PANEL' { Menu-CPL }),
    (mSub 'NETWORK CENTER' { Menu-Network }),
    (mSub 'FIREWALL AND SECURITY' { Menu-Firewall }),
    (mSub 'SERVICES' { Menu-Services }),
    (mSub 'PROCESSES' { Menu-Processes }),
    (mSub 'USERS AND GROUPS' { Menu-Users }),
    (mSub 'GROUP POLICY' { Menu-GPO }),
    (mSub 'ACTIVE DIRECTORY' { Menu-AD }),
    (mSub 'DNS' { Menu-DNS }),
    (mSub 'DHCP' { Menu-DHCP }),
    (mSub 'IIS' { Menu-IIS }),
    (mSub 'WINDOWS SERVER' { Menu-WinServer }),
    (mSub 'SERVER ROLES' { Page-Roles }),
    (mSub 'WINDOWS FEATURES' { Page-Features }),
    (mSub 'HYPER-V' { Menu-HyperV }),
    (mSub 'VMWARE' { Menu-VMware }),
    (mSub 'STORAGE AND DISK' { Menu-Storage }),
    (mSub 'REMOTE MANAGEMENT' { Menu-Remote }),
    (mSub 'CMD COMMAND CENTER' { Menu-CmdCenter }),
    (mSub 'POWERSHELL CENTER' { Menu-PSCenter }),
    (mSub 'SECURITY TOOLS' { Menu-Security }),
    (mSub 'PERFORMANCE' { Menu-Perf }),
    (mSub 'TROUBLESHOOTING' { Menu-Trouble }),
    (mSub 'MCSA / WINDOWS SERVER LEARNING (LEGACY)' { Menu-MCSA }),
    (mSub 'MICROSOFT DOCUMENTATION' { Menu-Docs }),
    (mSub 'AI ADMIN ASSISTANT' { Invoke-Assist }),
    (mSub 'ABOUT MCSA' { Page-About }),
    (mSub 'REFRESH (re-scan system)' { $script:SI = Get-SysInfo; Update-NetStatus -WithPublic; Show-Result 'REFRESH' 'SUCCESS' 'System and network information (including public IP) was queried again.' }),
    (mSub 'EXIT' { [void](Confirm-Exit) })
  )
} -Main }

# ------------------------------------------------------------------ ABOUT MCSA PAGE
function Page-About{
  $all = New-Object System.Collections.ArrayList
  $bd  = '  +' + ('=' * 74) + '+'
  $sp  = '  |' + (' ' * 74) + '|'
  function Ab-Line([string]$t,[string]$c='White'){
    [void]$all.Add(@{ T = ('  | ' + $t.PadRight(72) + ' |'); C = $c })
  }
  function Ab-Blank{ [void]$all.Add(@{ T = $sp; C = 'Blue' }) }
  function Ab-Border{ [void]$all.Add(@{ T = $bd; C = 'Blue' }) }
  function Ab-Wrap([string]$t,[string]$c='White'){
    $cur = ''
    foreach($wd in ($t -split '\s+')){
      if($wd -eq ''){ continue }
      if($cur -ne '' -and ($cur.Length + $wd.Length + 1) -gt 72){ Ab-Line $cur $c; $cur = $wd }
      elseif($cur -eq ''){ $cur = $wd }
      else { $cur = $cur + ' ' + $wd }
    }
    if($cur -ne ''){ Ab-Line $cur $c }
  }

  Ab-Border
  Ab-Line 'ALIREZA SHAFAATI ADMINISTRATOR' 'White'
  Ab-Line 'ABOUT MCSA' 'Yellow'
  Ab-Line 'MCSA CONTROL CENTER' 'Cyan'
  Ab-Border
  Ab-Blank
  Ab-Line 'PURPOSE' 'Cyan'
  Ab-Wrap 'MCSA Control Center is a Windows Server administration and learning control panel designed to provide organized access to Windows Server administration tools, system utilities, networking tools, security tools, diagnostics, automation, and administrative commands.'
  Ab-Blank
  Ab-Line 'WHY WAS IT CREATED?' 'Cyan'
  Ab-Wrap 'This application was created to make Windows Server and Windows administration tasks easier to access, understand, and manage from one organized control center.'
  Ab-Blank
  Ab-Wrap 'It combines administration tools, commands, learning information, troubleshooting resources, and navigation into a single interface.'
  Ab-Blank
  Ab-Line ('ADMINISTRATOR'.PadRight(30) + 'ALIREZA SHAFAATI') 'Green'
  Ab-Line ('CREATED AND MAINTAINED BY'.PadRight(30) + 'ALIREZA SHAFAATI') 'Green'
  Ab-Blank
  Ab-Line 'APPLICATION ROLE' 'Cyan'
  Ab-Line ('  - Windows Server Administration'.PadRight(38) + '- Windows Administration') 'White'
  Ab-Line ('  - Network Administration'.PadRight(38) + '- System Administration') 'White'
  Ab-Line ('  - Troubleshooting'.PadRight(38) + '- Automation') 'White'
  Ab-Line '  - Learning and Training' 'White'
  Ab-Blank
  Ab-Line 'TARGET ENVIRONMENT' 'Cyan'
  Ab-Line ('  - Windows Server'.PadRight(38) + '- Windows 11') 'White'
  Ab-Line '  - Windows 10' 'White'
  Ab-Line '  - Compatible Windows administrative environments' 'White'
  Ab-Blank
  Ab-Line 'NOTICE' 'Yellow'
  Ab-Wrap 'MCSA Control Center is an independent administration and learning tool. It is not officially created, owned, certified, or endorsed by Microsoft. Microsoft and Windows tools referenced here are treated as Windows / Microsoft administration tools.' 'Yellow'
  Ab-Blank
  Ab-Wrap 'LEARNING: open MCSA / WINDOWS SERVER LEARNING (LEGACY) from the Main Menu for the Windows Server topics.' 'White'
  Ab-Border

  $top = 0; $buf = ''; $draw = $true; $vis = 20; $maxTop = 0
  while($true){
    if($script:Quit -or $script:GoHome){ return }
    if($draw){
      Head 'ABOUT MCSA'
      $y = $Host.UI.RawUI.CursorPosition.Y
      $vis = [Math]::Max(8,[Console]::WindowHeight - $y - 5)
      if($vis -gt $all.Count){ $vis = $all.Count }
      $maxTop = [Math]::Max(0,$all.Count - $vis)
      if($top -gt $maxTop){ $top = $maxTop }
      if($top -lt 0){ $top = 0 }
      for($i = $top; $i -lt ($top + $vis); $i++){ $ln = $all[$i]; W ([string]$ln.T) ([string]$ln.C) }
      W ('  Lines {0}-{1} of {2}   UP / DOWN / PAGE UP / PAGE DOWN = scroll' -f ($top + 1),($top + $vis),$all.Count) DarkGray
      W '  (0) MCSA - Back / Main Menu    [0 + ENTER / B / ESC] Back  [H] Home  [F1] Help  [Q] Exit' Cyan
      W ('  Input: ' + $buf) Yellow -n
      $draw = $false
    }
    $a = Read-Nav
    if($a -eq 'back'){ return }
    elseif($a -eq 'home'){ $script:GoHome = $true; return }
    elseif($a -eq 'quit'){ [void](Confirm-Exit); if($script:Quit){ return }; $draw = $true }
    elseif($a -eq 'help'){ Page-Help; $draw = $true }
    elseif($a -eq 'refresh'){ $draw = $true }
    elseif($a -eq 'up'){ if($top -gt 0){ $top--; $draw = $true } }
    elseif($a -eq 'down'){ if($top -lt $maxTop){ $top++; $draw = $true } }
    elseif($a -eq 'pgup'){ $top = [Math]::Max(0,$top - $vis); $draw = $true }
    elseif($a -eq 'pgdn'){ $top = [Math]::Min($maxTop,$top + $vis); $draw = $true }
    elseif($a -eq 'first'){ $top = 0; $draw = $true }
    elseif($a -eq 'last'){ $top = $maxTop; $draw = $true }
    elseif($a -eq 'd0'){ $buf = '0'; $draw = $true }
    elseif($a -eq 'enter'){
      if($buf -eq '0'){ try{ $Host.UI.RawUI.FlushInputBuffer() }catch{}; return }
      elseif($buf -ne ''){ $buf = ''; $draw = $true }
    }
    elseif($a -match '^F\d+$'){ Set-Jump $a; return }
    elseif($a -match '^d\d$'){ if($buf -ne ''){ $buf = ''; $draw = $true } }
  }
}

# ------------------------------------------------------------------ STARTUP ANIMATION (dark hacker / cyber administrator - monochrome only)
$script:AnimSkip = $false
$script:Rnd   = New-Object System.Random
$script:Clock = $null
$script:Blk   = [string][char]0x2588
$script:Lgt   = [string][char]0x2591
$script:Noise = [char[]]'#%@$&*+=<>/|01:;'
$script:Font  = @{
  'A' = @('.###.','#...#','#####','#...#','#...#')
  'L' = @('#....','#....','#....','#....','#####')
  'I' = @('#####','..#..','..#..','..#..','#####')
  'R' = @('####.','#...#','####.','#..#.','#...#')
  'E' = @('#####','#....','####.','#....','#####')
  'Z' = @('#####','...#.','..#..','.#...','#####')
  'S' = @('.####','#....','.###.','....#','####.')
  'H' = @('#...#','#...#','#####','#...#','#...#')
  'F' = @('#####','#....','####.','#....','#....')
  'T' = @('#####','..#..','..#..','..#..','..#..')
}
# Sleep that stays responsive: ESC skips the whole animation, other keys are swallowed.
function Anim-Sleep([int]$ms){
  if($script:AnimSkip){ return }
  $end = [DateTime]::UtcNow.AddMilliseconds($ms)
  while([DateTime]::UtcNow -lt $end){
    try{
      if($Host.UI.RawUI.KeyAvailable){
        $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        if($k.VirtualKeyCode -eq 27){ $script:AnimSkip = $true; return }
      }
    }catch{}
    Start-Sleep -Milliseconds ([Math]::Min(15,$ms))
  }
}
function Anim-Type([string]$t,[string]$c='White',[int]$ms=12){
  foreach($ch in $t.ToCharArray()){
    if($script:AnimSkip){ return }
    Write-Host ([string]$ch) -ForegroundColor $c -NoNewline
    Anim-Sleep $ms
  }
}
function Anim-Cut([string]$s,[int]$n){
  if([string]::IsNullOrWhiteSpace($s)){ return 'NOT AVAILABLE' }
  $s = $s.Trim()
  if($s.Length -gt $n){ $s = $s.Substring(0,$n) }
  return $s
}
# Raw memory-dump style data stream
function Anim-Hex([int]$rows){
  for($r = 0; $r -lt $rows; $r++){
    if($script:AnimSkip){ return }
    $b = New-Object 'byte[]' 16
    $script:Rnd.NextBytes($b)
    $hx  = (($b | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
    $asc = (($b | ForEach-Object { if($_ -ge 32 -and $_ -le 126){ [string][char]$_ } else { '.' } }) -join '')
    $ad  = '{0:X8}' -f ($script:Rnd.Next(268435456,2147483647))
    $c = 'DarkGray'
    $m = $r % 5
    if($m -eq 2){ $c = 'Gray' } elseif($m -eq 4){ $c = 'White' }
    W ('  0x' + $ad + '  ' + $hx + '  |' + $asc + '|') $c
    Anim-Sleep 28
  }
}
# One boot-log line: timestamp + label + progress bar + status tag
function Anim-Line([string]$ts,[string]$label,[int]$fill,[string]$tag,[bool]$warn=$false){
  Write-Host ("`r  [" + $ts.PadLeft(9) + '] ') -ForegroundColor DarkGray -NoNewline
  Write-Host ($label.PadRight(44)) -ForegroundColor Gray -NoNewline
  Write-Host ('[' + ($script:Blk * $fill) + ($script:Lgt * (14 - $fill)) + ']') -ForegroundColor White -NoNewline
  if($tag -ne ''){
    if($warn){ Write-Host (' ' + $tag + ' ') -ForegroundColor White -BackgroundColor DarkGray -NoNewline }
    else { Write-Host (' ' + $tag + ' ') -ForegroundColor Black -BackgroundColor White -NoNewline }
  }
}
function Anim-Step([string]$label,[scriptblock]$Work){
  if($script:AnimSkip){ if($Work){ try{ & $Work | Out-Null }catch{} }; return }
  $ts = $script:Clock.Elapsed.TotalSeconds.ToString('0.000000',[Globalization.CultureInfo]::InvariantCulture)
  $ok = $true
  Anim-Line $ts $label 0 ''
  if($Work){ try{ & $Work | Out-Null }catch{ $ok = $false } }
  for($i = 1; $i -le 14; $i++){
    if($script:AnimSkip){ break }
    Anim-Line $ts $label $i ''
    Anim-Sleep (6 + $script:Rnd.Next(0,14))
  }
  if($ok){ Anim-Line $ts $label 14 'OK' } else { Anim-Line $ts $label 14 'WARN' $true }
  Write-Host ''
}
function Anim-Log([string]$t){
  if($script:AnimSkip){ return }
  W ('  ' + (' ' * 14) + '> ' + $t) DarkGray
  Anim-Sleep 45
}
function Anim-Ready{
  if($script:AnimSkip){ return }
  W ''
  $line = '  ' + '  MCSA CONTROL CENTER READY'.PadRight(76)
  for($i = 0; $i -lt 3; $i++){
    if($script:AnimSkip){ return }
    Write-Host ("`r" + $line) -ForegroundColor Black -BackgroundColor White -NoNewline
    Anim-Sleep 110
    Write-Host ("`r" + $line) -ForegroundColor White -BackgroundColor Black -NoNewline
    Anim-Sleep 70
  }
  Write-Host ("`r" + $line) -ForegroundColor Black -BackgroundColor White
  Anim-Sleep 300
}
function Anim-Prompt{
  if($script:AnimSkip){ return }
  W ''
  W '  admin@mcsa:~# ' Gray -n
  Anim-Type 'start mcsa-control-center --role administrator' 'White' 18
  for($i = 0; $i -lt 3; $i++){
    if($script:AnimSkip){ return }
    Write-Host ' ' -BackgroundColor White -NoNewline
    Anim-Sleep 140
    Write-Host "`b `b" -NoNewline
    Anim-Sleep 110
  }
  W ''
}
# Big block-letter text
function Anim-BigRows([string]$text){
  $rows = @('','','','','')
  foreach($ch in $text.ToCharArray()){
    for($r = 0; $r -lt 5; $r++){
      if($ch -eq ' '){ $rows[$r] += '   ' }
      else {
        $g = $script:Font[[string]$ch]
        $rows[$r] += (($g[$r].Replace('#',$script:Blk).Replace('.',' ')) + ' ')
      }
    }
  }
  return ,$rows
}
# Draws the banner; $p = 0..1 decode progress (noise resolves to letters), glitch = horizontal tearing
function Anim-DrawBanner($lines,[int]$top,[double]$p,[string]$color,[int]$cw,[switch]$Glitch){
  for($i = 0; $i -lt $lines.Count; $i++){
    $src = [string]$lines[$i].T
    $pad = [int]$lines[$i].P
    if($Glitch -and $script:Rnd.NextDouble() -lt (0.35 * (1 - $p))){ $pad = [Math]::Max(0,$pad + $script:Rnd.Next(-5,6)) }
    $sb = New-Object System.Text.StringBuilder
    foreach($c in $src.ToCharArray()){
      if($c -eq ' ' -or $p -ge 1 -or $script:Rnd.NextDouble() -lt $p){ [void]$sb.Append($c) }
      else { [void]$sb.Append($script:Noise[$script:Rnd.Next(0,$script:Noise.Length)]) }
    }
    $s = (' ' * $pad) + $sb.ToString()
    if($s.Length -gt ($cw - 1)){ $s = $s.Substring(0,$cw - 1) }
    [Console]::SetCursorPosition(0,$top + $i)
    Write-Host ($s.PadRight($cw - 1)) -ForegroundColor $color -BackgroundColor Black -NoNewline
  }
}
# Scanline: a dark-gray bar sweeps down the banner
function Anim-Sweep($lines,[int]$top,[int]$cw){
  for($i = 0; $i -lt $lines.Count; $i++){
    if($script:AnimSkip){ return }
    $s = (' ' * [int]$lines[$i].P) + [string]$lines[$i].T
    if($s.Length -gt ($cw - 1)){ $s = $s.Substring(0,$cw - 1) }
    [Console]::SetCursorPosition(0,$top + $i)
    Write-Host ($s.PadRight($cw - 1)) -ForegroundColor White -BackgroundColor DarkGray -NoNewline
    Anim-Sleep 30
    [Console]::SetCursorPosition(0,$top + $i)
    Write-Host ($s.PadRight($cw - 1)) -ForegroundColor White -BackgroundColor Black -NoNewline
  }
}
# Text that "decrypts" left to right
function Anim-Reveal([string]$text,[int]$left,[int]$row,[string]$color){
  for($n = 0; $n -le $text.Length; $n++){
    if($script:AnimSkip){ return }
    $tail = ''
    $rest = [Math]::Min(3,$text.Length - $n)
    for($k = 0; $k -lt $rest; $k++){
      if($text.Substring($n + $k,1) -eq ' '){ $tail += ' ' }
      else { $tail += [string]$script:Noise[$script:Rnd.Next(0,$script:Noise.Length)] }
    }
    [Console]::SetCursorPosition($left,$row)
    Write-Host (($text.Substring(0,$n) + $tail).PadRight($text.Length)) -ForegroundColor $color -BackgroundColor Black -NoNewline
    Anim-Sleep 24
  }
}
function Play-Intro{
  $cw = 110
  try{ $cw = [int][Console]::WindowWidth }catch{}
  if($cw -lt 80){ $cw = 80 }
  $script:AnimSkip = $false
  $script:Clock = [Diagnostics.Stopwatch]::StartNew()
  try{ [Console]::CursorVisible = $false }catch{}
  $bar = '  ' + ('=' * 78)
  $adm = Test-Admin

  # ---- PHASE 1 : raw data stream
  Clear-Host
  W $bar DarkGray
  W '  SECURE ADMINISTRATOR TERMINAL   //   WINDOWS SERVER OPERATIONS' White
  W $bar DarkGray
  W '  (press ESC to skip)' DarkGray
  W ''
  Anim-Hex 16
  Anim-Sleep 160

  # ---- PHASE 2 : boot sequence (the two CHECKING steps really query this computer)
  Clear-Host
  W $bar DarkGray
  W '  SYSTEM INITIALIZATION   //   SECURE ADMINISTRATOR TERMINAL' White
  W $bar DarkGray
  W ''
  Anim-Step 'SYSTEM INITIALIZATION...'
  Anim-Step 'LOADING ADMINISTRATOR ENVIRONMENT...'
  Anim-Step 'INITIALIZING MCSA CONTROL CENTER...'
  Anim-Log 'interface : command line / keyboard navigation'
  Anim-Step 'CHECKING SYSTEM...' { $script:SI = Get-SysInfo }
  $h = 'NOT AVAILABLE'; $o = 'NOT AVAILABLE'
  if($script:SI){ $h = Anim-Cut ([string]$script:SI['Computer Name']) 24; $o = Anim-Cut ([string]$script:SI['Windows Edition']) 36 }
  Anim-Log ('host : ' + $h + '   os : ' + $o)
  Anim-Step 'CHECKING NETWORK...' { Update-NetStatus -WithPublic }
  $gw = 'NOT AVAILABLE'; $st = 'NOT AVAILABLE'
  if($script:NS){ $gw = Anim-Cut ([string]$script:NS.GW) 30; $st = Anim-Cut ([string]$script:NS.ST) 30 }
  Anim-Log ('gateway : ' + $gw + '   network : ' + $st)
  Anim-Step 'CHECKING ADMINISTRATOR PRIVILEGES...'
  $lv = 'STANDARD'; if($adm){ $lv = 'ELEVATED (administrator token verified)' }
  Anim-Log ('privilege level : ' + $lv)
  Anim-Step 'LOADING WINDOWS ADMINISTRATION MODULES...'
  Anim-Step 'LOADING SECURITY MODULES...'
  Anim-Step 'LOADING NETWORK MODULES...'
  Anim-Step 'LOADING DIAGNOSTIC MODULES...'
  Anim-Step 'LOADING AUTOMATION MODULES...'
  Anim-Ready
  Anim-Prompt
  Anim-Sleep 200
  if($script:AnimSkip){ return }

  # ---- PHASE 3 : identity banner (decode + glitch + scanline)
  Clear-Host
  W ''; W ''; W ''; W ''
  $top = [Console]::CursorTop
  $lines = @()
  foreach($r in (Anim-BigRows 'ALIREZA')){ $lines += @{ T = [string]$r; P = [int][Math]::Floor(($cw - $r.Length) / 2) } }
  $lines += @{ T = ''; P = 0 }
  foreach($r in (Anim-BigRows 'SHAFAATI')){ $lines += @{ T = [string]$r; P = [int][Math]::Floor(($cw - $r.Length) / 2) } }
  Anim-Sleep 120
  for($f = 0; $f -le 12; $f++){
    if($script:AnimSkip){ return }
    $p = $f / 12.0
    $col = 'DarkGray'
    if($p -ge 0.75){ $col = 'White' } elseif($p -ge 0.4){ $col = 'Gray' }
    Anim-DrawBanner $lines $top $p $col $cw -Glitch
    Anim-Sleep 55
  }
  if($script:AnimSkip){ return }
  $r1 = $top + $lines.Count + 1
  $c1 = [int][Math]::Max(0,[Math]::Floor(($cw - 78) / 2))
  $t1 = [int][Math]::Max(0,[Math]::Floor(($cw - 19) / 2))
  [Console]::SetCursorPosition($c1,$r1)
  Write-Host ('=' * 78) -ForegroundColor DarkGray -NoNewline
  Anim-Reveal 'MCSA CONTROL CENTER' $t1 ($r1 + 1) 'White'
  [Console]::SetCursorPosition($c1,$r1 + 2)
  Write-Host ('=' * 78) -ForegroundColor DarkGray -NoNewline
  $lv2 = 'STANDARD'; if($adm){ $lv2 = 'ELEVATED' }
  $stx = 'STATUS: ONLINE   //   PRIVILEGES: ' + $lv2 + '   //   WINDOWS ADMINISTRATION'
  [Console]::SetCursorPosition([int][Math]::Max(0,[Math]::Floor(($cw - $stx.Length) / 2)),$r1 + 3)
  Write-Host $stx -ForegroundColor DarkGray -NoNewline
  Anim-Sleep 200
  Anim-Sweep $lines $top $cw
  Anim-Sleep 250
  Anim-Sweep $lines $top $cw
  Anim-Sleep 650

  # ---- fade out
  foreach($col in @('Gray','DarkGray')){
    if($script:AnimSkip){ return }
    Anim-DrawBanner $lines $top 1.0 $col $cw
    Anim-Sleep 90
  }
}
function Start-Anim{
  try{ Play-Intro }catch{}
  try{ [Console]::CursorVisible = $true }catch{}
  try{ $Host.UI.RawUI.FlushInputBuffer() }catch{}
  try{ $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'White' }catch{}
  if(-not $script:SI){ $script:SI = Get-SysInfo }
  if(-not $script:NS){ Update-NetStatus }
  Clear-Host
}

# ------------------------------------------------------------------ ENTRY POINT
if(-not (Test-Admin)){
  W 'ADMINISTRATOR PRIVILEGES REQUIRED' Red
  W 'PROGRAM CANNOT CONTINUE WITHOUT ADMINISTRATOR PRIVILEGES' Red
  Start-Sleep -Seconds 3
  exit 3
}
try{
  Start-Anim
  Menu-Main
}catch{
  W ('UNEXPECTED ERROR: ' + $_.Exception.Message) Red
  Wait-Key
}
Clear-Host
W '  ALIREZA SHAFAATI ADMINISTRATOR closed.' Green
Start-Sleep -Milliseconds 600
