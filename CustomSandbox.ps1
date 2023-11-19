#Requires -Version 5

[CmdletBinding()]
param(
  [Parameter(Mandatory=$False)][switch]$ForceWSInstall,
  [Parameter(Mandatory=$False)][switch]$SkipCompatCheck
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$AppName = "CustomSandbox"
$AppVersion = "1.2"

try { Stop-Transcript | Out-Null } catch [System.InvalidOperationException]{}
Start-Transcript -Path "$PSScriptRoot\CustomSandbox.log"

. "$PSScriptRoot\Config\Functions\Configuration.ps1"
. "$PSScriptRoot\Config\Functions\Tasks.ps1"
. "$PSScriptRoot\Config\Functions\Menu.ps1"
. "$PSScriptRoot\Config\Functions\Common.ps1"

$LauncherRootPath = $PSScriptRoot
$LauncherMountPath = Join-Path $LauncherRootPath "Config"
$LauncherCachePath = Join-Path $LauncherMountPath "Cache"

$RAMToAllocateMin = 2048
$RAMToAllocateIdeal = 4096

$CSMountPath = "C:\Config"
$CSCachePath = $LauncherCachePath
$CSConfigPath = "$LauncherRootPath\config.json"
$WSConfigPath = Join-Path $LauncherCachePath "$AppName.wsb"

$WSConfig = New-WSConfig -Path $WSConfigPath
$WSConfig.SetHostFolder($LauncherMountPath)
$WSConfig.SetSandboxFolder($CSMountPath)
$WSConfig.SetLogonCommand("PowerShell -ExecutionPolicy Unrestricted -WindowStyle Hidden -Command `"if(Test-Path C:\Config\sandbox-config.ps1) { start powershell -WindowStyle Hidden {-file C:\Config\sandbox-config.ps1 } } else { start powershell -WindowStyle Hidden {-file C:\Users\WDAGUtilityAccount\Desktop\Config\sandbox-config.ps1 } }`"")

$CSConfig = New-CSConfig -Path $CSConfigPath

if (Test-Path $CSConfigPath) {
  $CSConfig.Import()
}

if (!(Test-Path $LauncherCachePath)) {
  New-Item -Path $LauncherCachePath -ItemType Directory -Force | Out-Null
}

$UtilPath = Join-Path $LauncherMountPath "Utilities"
if (!(Test-Path $UtilPath)) {
  New-Item -Path $UtilPath -ItemType Directory -Force | Out-Null
}

if (-not $SkipCompatCheck) {
  $OSVersion = [System.Environment]::OSVersion.Version
  $WinSKU = (Get-WmiObject Win32_OperatingSystem).OperatingSystemSKU
  $IncompatibleSKUs = @(1,2,3,5,11,19,28,34,87,89,101,104,118,123)
  if ($OSVersion.Major -lt 10 -or ($OSVersion.Major -eq 10 -and $OSVersion.Build -lt 18362) -or $WinSKU -in $IncompatibleSKUs) {
      Write-Host "Unsupported Operating System: Windows 10 Pro or Enterprise 1903 or greater is required for Windows Sandbox." -ForegroundColor Red
      Exit
  }
}

$WSPath = "$Env:WINDIR\System32\WindowsSandbox.exe"
if (!(Test-Path $WSPath)) {

  $InstallWS = $False

  if (-not $ForceWSInstall) {
    $InstallWS = Get-MenuConfirmation -Header "Windows Sandbox is not currently installed. Would you like to attempt to install it? (Elevation Required)"
  }

  if ($InstallWS -or $ForceWSInstall) {
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
      
      Write-Host "Installation requires elevated permissions."
      
      if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
          Write-Host "Attempting to elevate..."
          $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" -ForceWSInstall " + $MyInvocation.UnboundArguments
          Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
          Exit
      }
    } else {
      Write-Host "Attempting to install Windows Sandbox."
      Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online

      Write-Host "Restarting $AppName..."
      $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" -ForceWSInstall " + $MyInvocation.UnboundArguments
      Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
      Exit
    }

  } else {
    Write-Host "Cannot continue without Windows Sandbox. Exiting."
    Exit
  }
  
}

$CacheFiles = Get-ChildItem -Path $LauncherCachePath -File -Recurse
$CacheSize = Get-FriendlySize -MBytes (($CacheFiles | Measure-Object Length -Sum).Sum / 1024 / 1024)

$MaxFreeRam = [Math]::Round((Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory).FreePhysicalMemory / 1024)

if ($MaxFreeRam -lt $RAMToAllocateMin) {
  Write-Host "Not enough free memory to run Windows Sandbox." -ForegroundColor Red
  Exit
}

$RAMTarget = [int]$CSConfig.GetProperty("MemoryInMB").Value

if($RAMTarget -le $MaxFreeRam -and $RAMTarget -ge $RAMToAllocateMin) {
  $RAMToAllocateIdeal = $RAMTarget
} else {
  if ($MaxFreeRam -lt $RAMToAllocateIdeal) {
    $RAMToAllocateIdeal = $RAMToAllocateMin
  }
}

$CSConfig.SetProperty("MemoryInMB", $RAMToAllocateIdeal)
$WSConfig.SetMemoryInMB($RAMToAllocateIdeal)

$FriendlyRAMToAllocate = Get-FriendlySize -MBytes $RAMToAllocateIdeal

$MenuHeader = @"
$AppName v$AppVersion
If you want access to any utilities/files inside the sandbox, add them to the following directory:
$UtilPath

Choose your options:
"@

$MenuItems = @(
  Get-MenuItem `
     -Label "Protected Mode" `
     -Value "ProtectedClient" `
     -Order 0 `
     -Selected:($CSConfig.IsTrue("ProtectedClient"))
  Get-MenuItem `
     -Label "Networking" `
     -Value "Networking" `
     -Order 1 `
     -Selected:($CSConfig.IsTrue("Networking"))
  Get-MenuItem `
     -Label "vGPU" `
     -Value "vGPU" `
     -Order 2 `
     -Selected:($CSConfig.IsTrue("vGPU"))
  Get-MenuItem `
     -Label "Set RAM Amount (Current: $FriendlyRAMToAllocate)" `
     -Value "CustomRam" `
     -Order 3 `
     -Selected:($CSConfig.IsTrue("CustomRam"))
  Get-MenuItem `
     -Label "Enable Clipboard Redirection" `
     -Value "ClipboardRedirection" `
     -Order 4 `
     -Selected:($CSConfig.IsTrue("ClipboardRedirection"))
  Get-MenuItem `
     -Label "Enable Printer Redirection" `
     -Value "PrinterRedirection" `
     -Order 5 `
     -Selected:($CSConfig.IsTrue("PrinterRedirection"))
  Get-MenuItem `
     -Label "Enable Audio Input" `
     -Value "AudioInput" `
     -Order 6 `
     -Selected:($CSConfig.IsTrue("AudioInput"))
  Get-MenuItem `
     -Label "Enable Video Input" `
     -Value "VideoInput" `
     -Order 7 `
     -Selected:($CSConfig.IsTrue("VideoInput"))
  Get-MenuItem `
     -Label "Update Cached Installers" `
     -Value "UpdateCache" `
     -Order 8 `
     -Selected:($CSConfig.IsTrue("UpdateCache"))
  Get-MenuItem `
     -Label "Clear Cache (Size: $CacheSize)" `
     -Value "ClearCache" `
     -Order 9 `
     -Selected:($CSConfig.IsTrue("ClearCache"))
  Get-MenuItem `
     -Label "Save Configuration" `
     -Value "SaveConfig" `
     -Order 10 `
     -Selected:($CSConfig.IsTrue("SaveConfig"))
)

$SelectedOptions = Get-MenuSelection -Header $MenuHeader -Items $MenuItems -Mode Multi

if ($SelectedOptions -contains 'CustomRam') {

  $RAMHeader = "Set maximum amount of RAM to allocate to sandbox:"

  $RAMItems = @()
  $RamOrder = 0
  for ($RamVal = 2048; $RamVal -le $MaxFreeRam; $RamVal += 1024) {
    $RAMItems += Get-MenuItem -Label (Get-FriendlySize -MBytes $RamVal) -Value $RamVal -Order $RamOrder
    $RamOrder++
  }

  $CustomRam = Get-MenuSelection -Header $RAMHeader -Items $RAMItems -Mode Single

  $CSConfig.SetProperty("CustomRam", $True)
  $CSConfig.SetProperty("MemoryInMB", $CustomRam)
  $WSConfig.SetMemoryInMB($CustomRam)
} else {
  $CSConfig.SetProperty("CustomRam", $False)
}

if ($SelectedOptions -contains 'ClearCache') {
  Write-Host "Clearing cache..."
  Get-ChildItem -Path $LauncherCachePath | Remove-Item -Recurse -Force
}

$ForceCache = ($SelectedOptions -contains 'UpdateCache')
$CSConfig.SetProperty("UpdateCache", $ForceCache)

$TaskPath = Join-Path $LauncherMountPath "Tasks"
$TaskCollection = New-CustomSandboxTaskCollection -Path $TaskPath

$TaskHeader = "Choose tasks to run:"
$TaskItems = @()

foreach ($Task in $TaskCollection.Tasks) {
  $TaskItems += Get-MenuItem `
     -Label $Task.Name `
     -Value $Task.ID `
     -Depends $Task.Dependencies `
     -Selected:($CSConfig.GetProperty("Tasks").Value -contains $Task.ID)
}

$SelectedTasks = Get-MenuSelection -Header $TaskHeader -Items $TaskItems -Mode Multi

Clear-Host

$CSConfig.SetProperty("Tasks", $SelectedTasks)

$AllTasks = $TaskCollection.GetTasksWithDepFromList($SelectedTasks)

$TaskCollection.Tasks | Where-Object { $_.ID -in $AllTasks } | ForEach-Object {
  Write-Host "Running cache action for task $($_.Name)..."
  $_.ExecuteAction("cache",$ForceCache)
}

Write-Host "Writing Task Configuration..."
$SelectedTasks | ConvertTo-Json | Set-Content -Path "$LauncherCachePath\EnabledTasks.json" -Encoding UTF8

Write-Host "Getting CustomSandbox Configuration..."

$WSConfigToggles = @(
  'ProtectedClient',
  'Networking'
  'vGPU',
  'ClipboardRedirection',
  'PrinterRedirection',
  'AudioInput',
  'VideoInput'
)

$WSConfigToggles | ForEach-Object {
  $PropertyEnabled = ($SelectedOptions -contains $_) 
  $CSConfig.SetProperty($_, $PropertyEnabled)
  $WSConfig.SetPropertyToggle($_, $PropertyEnabled)
}

if ($SelectedOptions -contains 'SaveConfig') {
  Write-Host "Saving CustomSandbox Configuration..."
  $CSConfig.SetProperty("SaveConfig", $True)
  $CSConfig.SetProperty("Version", $AppVersion)
  $CSConfig.Export()
}

Write-Host "Writing Windows Sandbox Configuration..."
$WSConfig.Export()

Pause

$WSProcess = Get-Process -Name "WindowsSandbox" -ErrorAction SilentlyContinue
if($WSProcess) {

  $KillWS = Get-MenuConfirmation -Header "Windows Sandbox is currently running. Only one instance can be run at a time. Would you like to close it?"

  if($KillWS) {
    Write-Host "Killing Windows Sandbox processes..."
    @("WindowsSandbox", "WindowsSandboxClient") | ForEach-Object {
      $WSProcess = Get-Process -Name $_ -ErrorAction SilentlyContinue
      if($WSProcess) {
        $WSProcess | Stop-Process -Force | Out-Null
      }
    }
    Start-Sleep 5
  }
}

Write-Host "Launching Windows Sandbox..."
Invoke-Item $WSConfigPath

Stop-Transcript
