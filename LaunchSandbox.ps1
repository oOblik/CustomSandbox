#Requires -Version 5

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

Start-Transcript -Path "C:\Windows\Temp\CustomSandbox.txt"

. "$PSScriptRoot\Config\Tasks.ps1"
. "$PSScriptRoot\Config\Menu.ps1"
. "$PSScriptRoot\Config\Helpers.ps1"

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
    <PrinterRedirection>Disable</PrinterRedirection>
    <AudioInput>Enable</AudioInput>
    <VideoInput>Enable</VideoInput>
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

$CacheFiles = Get-ChildItem -Path $CachePath -File -Recurse
$CacheSize = Get-FriendlySize -MBytes (($CacheFiles | Measure-Object Length -Sum).Sum / 1024 / 1024)


$MenuHeader = @"
CustomSandbox
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

if($Config.MemoryInMB) {
    $XML.Configuration.MemoryInMB = $Config.MemoryInMB
} else {
    $XML.Configuration.MemoryInMB = "4096"
}

if ($SelectedOptions -contains 'CustomRam') {

    $RAMHeader = "Set maximum amount of RAM to allocate to sandbox:"

    $MaxFreeRam = [Math]::Round((Get-CIMInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory).FreePhysicalMemory / 1024)

    if($MaxFreeRam -lt 1024) {
        Write-Error "Not enough free memory to run Windows Sandbox."
        Return
    }

    $RAMItems = @()
    $RamOrder = 0
    for($RamVal = 1024; $RamVal -le $MaxFreeRam; $RamVal += 1024) {
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

if($SelectedOptions -contains 'ClearCache') {
    Write-Host "Clearing cache..."
    Get-ChildItem -Path $CachePath | Remove-Item -Recurse -Force
}

if ($SelectedOptions -contains 'UpdateCache') {
    $ForceCache = $True
    $Config | Add-Member -NotePropertyName 'UpdateCache' -NotePropertyValue $True -Force
} else {
    $ForceCache = $False
    $Config | Add-Member -NotePropertyName 'UpdateCache' -NotePropertyValue $False -Force
}



$TaskCollection = New-CustomSandboxTaskCollection -Path "$PSScriptRoot\Config\Tasks"

$TaskHeader = "Choose tasks to run:"
$TaskItems = @()

foreach($Task in $TaskCollection.Tasks) {

    $Order = 1
    switch($Task.Type) {
        {$_ -eq 'preconfig'} { $Order = 0 }
        {$_ -eq 'postconfig'} { $Order = 2 }
    }

    $TaskItems += Get-MenuItem `
        -Label $Task.Name `
        -Value $Task.ID `
        -Order $Order `
        -Depends $Task.Dependencies `
        -Selected:($Config.Tasks -contains $Task.ID)
}

$SelectedTasks = Get-MenuSelection -Header $TaskHeader -Items $TaskItems -Mode Multi

Clear-Host

$Config.Tasks = @()
$Config.Tasks = $SelectedTasks

$TaskCollection.Tasks | Where-Object {$_.ID -in $SelectedTasks} | ForEach-Object {
    Write-Host "Running cache action for task $($_.Name)..."
    $_.ExecuteAction("cache", $ForceCache)
}

Write-Host "Writing Task Configuration..."
$SelectedTasks | Export-CSV -Path "$CachePath\EnabledTasks.csv" -NoTypeInformation -Force
$SelectedTasks | ConvertTo-Json | Set-Content -Path "$CachePath\EnabledTasks.json" -Encoding UTF8

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