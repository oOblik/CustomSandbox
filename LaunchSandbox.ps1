$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

Start-Transcript -Path "C:\Windows\Temp\CustomSandbox.txt"

Import-Module ".\Modules\InteractiveMenu\InteractiveMenu.psd1"
. ".\Config\Helpers.ps1"


$Config = @{}

$ConfigPath = "$PSScriptRoot\config.json"
if(Test-Path $ConfigPath) {
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
    <MemoryInMB></MemoryInMB>
    <LogonCommand>
        <Command>C:\Config\sandbox-setup.cmd</Command>
    </LogonCommand>
</Configuration>
"@

$XML = [XML]$WSConfig

$CachePath = "$PSScriptRoot\Config\Cache"

if(!(Test-Path $CachePath)) {
    New-Item -Path $CachePath -ItemType Directory -Force | Out-Null
}

$UtilPath = "$PSScriptRoot\Config\Utilities"
if(!(Test-Path $UtilPath)) {
    New-Item -Path $UtilPath -ItemType Directory -Force | Out-Null
}

$MenuHeader = @"
CustomSandbox
If you want access to any utilities/files inside the sandbox, add them to the following directory:
$UtilPath

Choose your options:
"@

$MenuItems = @(
    Get-InteractiveMultiMenuOption `
        -Item "ProtectedMode" `
        -Label "Protected Mode" `
        -Order 0 `
        -Info "If enabled Windows sandbox will be launched in Protected Mode."  `
        -Selected:($Config.ProtectedMode)
    Get-InteractiveMultiMenuOption `
        -Item "Networking" `
        -Label "Networking" `
        -Order 1 `
        -Info "Enable networking." `
        -Selected:($Config.Networking)
    Get-InteractiveMultiMenuOption `
        -Item "vGPU" `
        -Label "vGPU" `
        -Order 2 `
        -Info "Enable vGPU." `
        -Selected:($Config.vGPU)
    Get-InteractiveMultiMenuOption `
        -Item "Clipboard" `
        -Label "Allow Clipboard" `
        -Order 3 `
        -Info "If enabled clipboard access in the sandbox will be allowed." `
        -Selected:($Config.Clipboard)
    Get-InteractiveMultiMenuOption `
        -Item "UpdateCache" `
        -Label "Update Cached Installers" `
        -Order 4 `
        -Info "If enabled all selected applications will be re-downloaded/updated."  `
        -Selected:($Config.UpdateCache)
    Get-InteractiveMultiMenuOption `
        -Item "CustomRam" `
        -Label "Set RAM amount" `
        -Order 5 `
        -Info "If enabled you will be prompted to set a value for the amount of RAM allocated for the sandbox." `
        -Selected:($Config.CustomRam)
    Get-InteractiveMultiMenuOption `
        -Item "SaveConfig" `
        -Label "Save Configuration" `
        -Order 6 `
        -Info "If enabled configuration/tasks will be saved for later runs."  `
        -Selected:($Config.SaveConfig)
)

$SelectedOptions = Get-InteractiveMenuUserSelection -Header $MenuHeader -Items $MenuItems

if($Config.MemoryInMB) {
    $XML.Configuration.MemoryInMB = $Config.MemoryInMB
} else {
    $XML.Configuration.MemoryInMB = "4096"
}

if ($SelectedOptions -contains 'CustomRam') {

    $RAMHeader = "Set RAM to allocate to sandbox in MB:"

    $MaxFreeRam = [Math]::Round((Get-CIMInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory).FreePhysicalMemory / 1024)

    $RAMItems = @()
    for($RamVal = 1024; $RamVal -le $MaxFreeRam; $RamVal += 1024) {
        $RAMItems += Get-InteractiveChooseMenuOption -Label "$RamVal" -Value "$RamVal" -Info "$RamVal"
    }

    $CustomRam = Get-InteractiveMenuChooseUserSelection -Question $RAMHeader -Answers $RAMItems

    $XML.Configuration.MemoryInMB = $CustomRam
    
    $Config | Add-Member -NotePropertyName 'CustomRam' -NotePropertyValue $True -Force
    $Config | Add-Member -NotePropertyName 'MemoryInMB' -NotePropertyValue $CustomRam -Force
} else {
    $Config | Add-Member -NotePropertyName 'CustomRam' -NotePropertyValue $False -Force
    $Config | Add-Member -NotePropertyName 'MemoryInMB' -NotePropertyValue $False -Force
}


if ($SelectedOptions -contains 'UpdateCache') {
    $ForceUpdates = $True
    $Config | Add-Member -NotePropertyName 'UpdateCache' -NotePropertyValue $True -Force
} else {
    $ForceUpdates = $False
    $Config | Add-Member -NotePropertyName 'UpdateCache' -NotePropertyValue $False -Force
}


$TaskScripts = Get-ChildItem -Path "$PSScriptRoot\Config\Tasks\*.ps1"

$TaskHeader = "Choose tasks to run:"
$TaskItems = @()

foreach($Task in $TaskScripts) {

    $Order = 1
    switch($Task.BaseName) {
        {$_ -like 'PreConfig-*'} { $Order = 0 }
        {$_ -like 'PostConfig-*'} { $Order = 2 }
    }

    $TaskItems += Get-InteractiveMultiMenuOption -Item $Task.BaseName `
        -Label $Task.BaseName `
        -Order $Order `
        -Info $Task.FullName `
        -Selected:($Config.Tasks -contains $Task.BaseName)
}

$SelectedTasks = Get-InteractiveMenuUserSelection -Header $TaskHeader -Items $TaskItems

$Config.Tasks = @()
$Config.Tasks = $SelectedTasks

$EnabledTasks = @()

ForEach ($Task in $SelectedTasks) {
    $EnabledTasks += @(
        [PSCustomObject]@{
            BaseName=$Task;
            FullName="C:\Config\Tasks\$Task.ps1"
        }
    )

    Write-Host "Running Update action for task $Task..."
    & "$PSScriptRoot\Config\Tasks\$Task.ps1" -Action Update -ForceUpdate $ForceUpdates
}

Write-Host "Writing Task Configuration..."
$EnabledTasks | Export-CSV -Path "$CachePath\EnabledTasks.csv" -NoTypeInformation -Force

Write-Host "Getting Sandbox Configuration..."
$OutConfig = Join-Path $env:TEMP "CustomSandbox.wsb"

$XML.Configuration.MappedFolders.MappedFolder.HostFolder = [string](Join-Path $PSScriptRoot "Config")

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
    $XML.Configuration.VGpu = "Enable"
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

Write-Host "Writing Sandbox Configuration..."
$XML.Save($OutConfig)

if($SelectedOptions -contains 'SaveConfig') {
    Write-Host "Writing Configuration to $ConfigPath..."
    $Config | Add-Member -NotePropertyName 'SaveConfig' -NotePropertyValue $True -Force
    $Config | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
} else {
    $Config | Add-Member -NotePropertyName 'SaveConfig' -NotePropertyValue $False -Force
}

Pause

Write-Host "Launching Sandbox..."
Invoke-Item $OutConfig

Stop-Transcript