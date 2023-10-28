$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

. "./Config/Helpers.ps1"

Start-Transcript -Path "C:\Windows\Temp\CustomSandbox.txt"

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
    <ClipboardRedirection>true</ClipboardRedirection>
    <MemoryInMB>4096</MemoryInMB>
    <LogonCommand>
     <Command>C:\Config\sandbox-setup.cmd</Command>
    </LogonCommand>
</Configuration>
"@

if(!(Test-Path "$PSScriptRoot\Config\Cache")) {
    New-Item -Path "$PSScriptRoot\Config\Cache" -ItemType Directory -Force | Out-Null
}

if(!(Test-Path "$PSScriptRoot\Config\Utilities")) {
    New-Item -Path "$PSScriptRoot\Config\Utilities" -ItemType Directory -Force | Out-Null
}

Write-Host "If you want access to any files/utilities inside the sandbox, add them to '$PSScriptRoot\Config\Utilities' now." -ForegroundColor Green
Write-Host -ForegroundColor White

$EnableProtectedMode = Read-Host -Prompt "Enable Protected Mode? [y/N]"
$AllowNetworking = Read-Host -Prompt "Allow Networking? [y/N]"
$AllowVGPU = Read-Host -Prompt "Allow vGPU? [y/N]"
$AskForceUpdates = Read-Host -Prompt "Update cached installers? [y/N]"

if ( $AskForceUpdates -match "[yY]" ) { 
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
$EnabledTasks | Export-CSV -Path "$PSScriptRoot\Config\Cache\EnabledTasks.csv" -NoTypeInformation -Force

Write-Host "Getting Sandbox Configuration..."
$OutConfig = Join-Path $env:TEMP "CustomSandbox.wsb"

$XML = [XML]$InConfig
$XML.Configuration.MappedFolders.MappedFolder.HostFolder = [string](Join-Path $PSScriptRoot "Config")

if ( $EnableProtectedMode -match "[yY]" ) { 
    $XML.Configuration.ProtectedClient = "Enable"
}

if ( $AllowNetworking -match "[yY]" ) { 
     $XML.Configuration.Networking = "Enable"
}

if ( $AllowVGPU -match "[yY]" ) { 
     $XML.Configuration.VGpu = "Enable"
}

Write-Host "Writing Sandbox Configuration..."
$XML.Save($OutConfig)

Pause

Write-Host "Launching Sandbox..."
Invoke-Item $OutConfig

Stop-Transcript