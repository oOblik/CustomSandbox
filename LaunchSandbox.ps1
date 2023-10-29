$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

Start-Transcript -Path "C:\Windows\Temp\CustomSandbox.txt"

Import-Module ".\Modules\InteractiveMenu\InteractiveMenu.psd1"
. ".\Config\Helpers.ps1"

$InConfig = @"
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
    <MemoryInMB>4096</MemoryInMB>
    <LogonCommand>
     <Command>C:\Config\sandbox-setup.cmd</Command>
    </LogonCommand>
</Configuration>
"@

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
        -Info "If enabled Windows sandbox will be launched in Protected Mode."
    Get-InteractiveMultiMenuOption `
        -Item "Networking" `
        -Label "Networking" `
        -Order 1 `
        -Info "Enable networking." `
        -Selected
    Get-InteractiveMultiMenuOption `
        -Item "vGPU" `
        -Label "vGPU" `
        -Order 2 `
        -Info "Enable vGPU." `
        -Selected
    Get-InteractiveMultiMenuOption `
        -Item "Clipboard" `
        -Label "Allow Clipboard" `
        -Order 3 `
        -Info "If enabled clipboard access in the sandbox will be allowed." `
        -Selected
    Get-InteractiveMultiMenuOption `
        -Item "UpdateCache" `
        -Label "Update Cached Installers" `
        -Order 4 `
        -Info "If enabled all selected applications will be re-downloaded/updated."
)

$SelectedOptions = Get-InteractiveMenuUserSelection -Header $MenuHeader -Items $MenuItems

if ($SelectedOptions -contains 'UpdateCache') { 
    $ForceUpdates = $True
} else {
    $ForceUpdates = $False
}

$TaskOptions = Get-ChildItem -Path "$PSScriptRoot\Config\Tasks\*.ps1" -Exclude "Set-*.ps1" | Select-Object BaseName, FullName | Out-GridView -OutputMode Multiple -Title '[Ctrl + Click] to choose tasks to run:'

$EnabledTasks = @()

ForEach ($Task in $TaskOptions) {
    $EnabledTasks += @(
        [PSCustomObject]@{
            BaseName=$Task.BaseName;
            FullName="C:\Config\Tasks\$($Task.BaseName).ps1"
        }
    )

    Write-Host "Running Update action for task $($Task.BaseName)..."
    & "$($Task.FullName)" -Action Update -ForceUpdate $ForceUpdates
}

Write-Host "Running Update action for task Set-BGInfo..."
& "$PSScriptRoot\Config\Tasks\Set-BGInfo.ps1" -Action Update -ForceUpdate $ForceUpdates

Write-Host "Writing Task Configuration..."
$EnabledTasks | Export-CSV -Path "$CachePath\EnabledTasks.csv" -NoTypeInformation -Force

Write-Host "Getting Sandbox Configuration..."
$OutConfig = Join-Path $env:TEMP "CustomSandbox.wsb"

$XML = [XML]$InConfig
$XML.Configuration.MappedFolders.MappedFolder.HostFolder = [string](Join-Path $PSScriptRoot "Config")

if ($SelectedOptions -contains 'ProtectedMode') { 
    $XML.Configuration.ProtectedClient = "Enable"
}

if ($SelectedOptions -contains 'Networking') { 
     $XML.Configuration.Networking = "Enable"
}

if ($SelectedOptions -contains 'vGPU') { 
     $XML.Configuration.VGpu = "Enable"
}

if ($SelectedOptions -contains 'Clipboard') { 
    $XML.Configuration.ClipboardRedirection = "true"
}

Write-Host "Writing Sandbox Configuration..."
$XML.Save($OutConfig)

Pause

Write-Host "Launching Sandbox..."
Invoke-Item $OutConfig

Stop-Transcript