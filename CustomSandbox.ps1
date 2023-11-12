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

. "$PSScriptRoot\Config\Tasks.ps1"
. "$PSScriptRoot\Config\Menu.ps1"
. "$PSScriptRoot\Config\Helpers.ps1"

$LauncherRootPath = $PSScriptRoot
$LauncherMountPath = Join-Path $LauncherRootPath "Config"
$LauncherCachePath = Join-Path $LauncherMountPath "Cache"

$CSMountPath = "C:\Config"
$CSCachePath = $LauncherCachePath

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

$Config = @{}
$Config.Tasks = @()

$ConfigPath = "$LauncherRootPath\config.json"
if (Test-Path $ConfigPath) {
  try {
    $Config = Get-Content -Path $ConfigPath | ConvertFrom-Json
    Write-Host "Configuration loaded from $ConfigPath"
  } catch {
    Write-Error "Failed to load configuration found at $ConfigPath"
  }
}

$WSConfig = @"
<Configuration>
    <VGpu>Disable</VGpu>
    <Networking>Disable</Networking>
    <ProtectedClient>Disable</ProtectedClient>
    <MappedFolders>
        <MappedFolder>
            <HostFolder></HostFolder>
            <SandboxFolder>C:\Config</SandboxFolder>
            <ReadOnly>true</ReadOnly>
        </MappedFolder>
    </MappedFolders>
    <ClipboardRedirection>false</ClipboardRedirection>
    <PrinterRedirection>Disable</PrinterRedirection>
    <AudioInput>Enable</AudioInput>
    <VideoInput>Enable</VideoInput>
    <MemoryInMB></MemoryInMB>
    <LogonCommand>
        <Command>PowerShell -ExecutionPolicy Unrestricted -WindowStyle Hidden -Command "if(Test-Path C:\Config\sandbox-config.ps1) { start powershell -WindowStyle Hidden {-file C:\Config\sandbox-config.ps1 } } else { start powershell -WindowStyle Hidden {-file C:\Users\WDAGUtilityAccount\Desktop\Config\sandbox-config.ps1 } }"</Command>
    </LogonCommand>
</Configuration>
"@

$XML = [xml]$WSConfig

if (!(Test-Path $LauncherCachePath)) {
  New-Item -Path $LauncherCachePath -ItemType Directory -Force | Out-Null
}

$UtilPath = Join-Path $LauncherMountPath "Utilities"
if (!(Test-Path $UtilPath)) {
  New-Item -Path $UtilPath -ItemType Directory -Force | Out-Null
}

$CacheFiles = Get-ChildItem -Path $LauncherCachePath -File -Recurse
$CacheSize = Get-FriendlySize -MBytes (($CacheFiles | Measure-Object Length -Sum).Sum / 1024 / 1024)


$MenuHeader = @"
$AppName v$AppVersion
If you want access to any utilities/files inside the sandbox, add them to the following directory:
$UtilPath

Choose your options:
"@

$MenuItems = @(
  Get-MenuItem `
     -Label "Protected Mode" `
     -Value "ProtectedMode" `
     -Order 0 `
     -Selected:($Config.ProtectedMode)
  Get-MenuItem `
     -Label "Networking" `
     -Value "Networking" `
     -Order 1 `
     -Selected:($Config.Networking)
  Get-MenuItem `
     -Label "vGPU" `
     -Value "vGPU" `
     -Order 2 `
     -Selected:($Config.vGPU)
  Get-MenuItem `
     -Label "Set RAM amount" `
     -Value "CustomRam" `
     -Order 3 `
     -Selected:($Config.CustomRam)
  Get-MenuItem `
     -Label "Enable Clipboard Redirection" `
     -Value "Clipboard" `
     -Order 4 `
     -Selected:($Config.Clipboard)
  Get-MenuItem `
     -Label "Enable Printer Redirection" `
     -Value "PrinterRedirection" `
     -Order 5 `
     -Selected:($Config.PrinterRedirection)
  Get-MenuItem `
     -Label "Disable Audio Input" `
     -Value "DisableAudioInput" `
     -Order 6 `
     -Selected:($Config.DisableAudioInput)
  Get-MenuItem `
     -Label "Disable Video Input" `
     -Value "DisableVideoInput" `
     -Order 7 `
     -Selected:($Config.DisableVideoInput)
  Get-MenuItem `
     -Label "Update Cached Installers" `
     -Value "UpdateCache" `
     -Order 8 `
     -Selected:($Config.UpdateCache)
  Get-MenuItem `
     -Label "Clear Cache (Size: $CacheSize)" `
     -Value "ClearCache" `
     -Order 9 `
     -Selected:($Config.ClearCache)
  Get-MenuItem `
     -Label "Save Configuration" `
     -Value "SaveConfig" `
     -Order 10 `
     -Selected:($Config.SaveConfig)
)

$SelectedOptions = Get-MenuSelection -Header $MenuHeader -Items $MenuItems -Mode Multi

if ($Config.MemoryInMB) {
  $XML.Configuration.MemoryInMB = $Config.MemoryInMB
} else {
  $XML.Configuration.MemoryInMB = "4096"
}

if ($SelectedOptions -contains 'CustomRam') {

  $RAMHeader = "Set maximum amount of RAM to allocate to sandbox:"

  $MaxFreeRam = [math]::Round((Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory).FreePhysicalMemory / 1024)

  if ($MaxFreeRam -lt 1024) {
    Write-Error "Not enough free memory to run Windows Sandbox."
    return
  }

  $RAMItems = @()
  $RamOrder = 0
  for ($RamVal = 1024; $RamVal -le $MaxFreeRam; $RamVal += 1024) {
    $RAMItems += Get-MenuItem -Label (Get-FriendlySize -MBytes $RamVal) -Value $RamVal -Order $RamOrder
    $RamOrder++
  }

  $CustomRam = Get-MenuSelection -Header $RAMHeader -Items $RAMItems -Mode Single

  $XML.Configuration.MemoryInMB = $CustomRam

  $Config | Add-Member -NotePropertyName 'CustomRam' -NotePropertyValue $True -Force
  $Config | Add-Member -NotePropertyName 'MemoryInMB' -NotePropertyValue $CustomRam -Force
} else {
  $Config | Add-Member -NotePropertyName 'CustomRam' -NotePropertyValue $False -Force
  $Config | Add-Member -NotePropertyName 'MemoryInMB' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'ClearCache') {
  Write-Host "Clearing cache..."
  Get-ChildItem -Path $LauncherCachePath | Remove-Item -Recurse -Force
}

if ($SelectedOptions -contains 'UpdateCache') {
  $ForceCache = $True
  $Config | Add-Member -NotePropertyName 'UpdateCache' -NotePropertyValue $True -Force
} else {
  $ForceCache = $False
  $Config | Add-Member -NotePropertyName 'UpdateCache' -NotePropertyValue $False -Force
}


$TaskPath = Join-Path $LauncherMountPath "Tasks"
$TaskCollection = New-CustomSandboxTaskCollection -Path $TaskPath

$TaskHeader = "Choose tasks to run:"
$TaskItems = @()

foreach ($Task in $TaskCollection.Tasks) {
  $TaskItems += Get-MenuItem `
     -Label $Task.Name `
     -Value $Task.ID `
     -Depends $Task.Dependencies `
     -Selected:($Config.Tasks -contains $Task.ID)
}

$SelectedTasks = Get-MenuSelection -Header $TaskHeader -Items $TaskItems -Mode Multi

Clear-Host

$Config.Tasks = $SelectedTasks

$AllTasks = $TaskCollection.GetTasksWithDepFromList($SelectedTasks)

$TaskCollection.Tasks | Where-Object { $_.ID -in $AllTasks } | ForEach-Object {
  Write-Host "Running cache action for task $($_.Name)..."
  $_.ExecuteAction("cache",$ForceCache)
}

Write-Host "Writing Task Configuration..."
$SelectedTasks | ConvertTo-Json | Set-Content -Path "$LauncherCachePath\EnabledTasks.json" -Encoding UTF8

Write-Host "Getting CustomSandbox Configuration..."

$XML.Configuration.MappedFolders.MappedFolder.HostFolder = [string]$LauncherMountPath

if ($SelectedOptions -contains 'ProtectedMode') {
  $XML.Configuration.ProtectedClient = "Enable"
  $Config | Add-Member -NotePropertyName 'ProtectedMode' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'ProtectedMode' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'Networking') {
  $XML.Configuration.Networking = "Enable"
  $Config | Add-Member -NotePropertyName 'Networking' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'Networking' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'vGPU') {
  $XML.Configuration.vGPU = "Enable"
  $Config | Add-Member -NotePropertyName 'vGPU' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'vGPU' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'Clipboard') {
  $XML.Configuration.ClipboardRedirection = "true"
  $Config | Add-Member -NotePropertyName 'Clipboard' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'Clipboard' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'PrinterRedirection') {
  $XML.Configuration.PrinterRedirection = "Enable"
  $Config | Add-Member -NotePropertyName 'PrinterRedirection' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'PrinterRedirection' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'DisableAudioInput') {
  $XML.Configuration.AudioInput = "Disable"
  $Config | Add-Member -NotePropertyName 'DisableAudioInput' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'DisableAudioInput' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'DisableVideoInput') {
  $XML.Configuration.VideoInput = "Disable"
  $Config | Add-Member -NotePropertyName 'DisableVideoInput' -NotePropertyValue $True -Force
} else {
  $Config | Add-Member -NotePropertyName 'DisableVideoInput' -NotePropertyValue $False -Force
}

if ($SelectedOptions -contains 'SaveConfig') {
  Write-Host "Writing CustomSandbox Configuration to $ConfigPath..."
  $Config | Add-Member -NotePropertyName 'SaveConfig' -NotePropertyValue $True -Force
  $Config | Add-Member -NotePropertyName 'Version' -NotePropertyValue $Version -Force
  $Config | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
} else {
  $Config | Add-Member -NotePropertyName 'SaveConfig' -NotePropertyValue $False -Force
}

Write-Host "Writing Windows Sandbox Configuration..."
$WinSandboxConfig = Join-Path $LauncherCachePath "$AppName.wsb"
$XML.Save($WinSandboxConfig)

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
Invoke-Item $WinSandboxConfig

Stop-Transcript
