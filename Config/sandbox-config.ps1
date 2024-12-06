$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Functions\Tasks.ps1"
. "$PSScriptRoot\Functions\Common.ps1"

$CSMountPath = $PSScriptRoot
$OldWSMountPath = "C:\Users\WDAGUtilityAccount\Desktop\Config"
$CSCachePath = Join-Path $CSMountPath "Cache"

Start-Transcript -Path "$Env:USERPROFILE\CustomSandbox.log"

Initialize-TLS

if(Test-Path $OldWSMountPath ) {
    New-Item -Path "C:\Config" -ItemType SymbolicLink -Value $OldWSMountPath | Out-Null
    & attrib +s +h "C:\Config" /l
}


Write-Host 'Importing Tasks...'
$TaskPath = Join-Path $CSMountPath "Tasks"
$TaskCollection = New-CustomSandboxTaskCollection -Path $TaskPath
$TaskOptions = Get-Content -Path "$CSCachePath\EnabledTasks.json" -Raw | ConvertFrom-Json

$AllTasks = $TaskCollection.GetTasksWithDepFromList($TaskOptions)
$TaskCollection.Tasks = $TaskCollection.Tasks | Where-Object { $_.ID -in $AllTasks }

$PreConfigTasks = $TaskCollection.Tasks | Where-Object { $_.Type -eq 'preconfig' }
$PostConfigTasks = $TaskCollection.Tasks | Where-Object { $_.Type -eq 'postconfig' }
$ConfigTasks = $TaskCollection.Tasks | Where-Object { $_.Type -ne 'preconfig' -and $_.Type -ne 'postconfig' }

#Set limited GUI for configuration mode
Write-Host 'Setting Initial Wallpaper...'
Update-WallPaper -Path "$CSMountPath\Assets\Wait.jpg"
Set-TaskbarVisibility -Hidden
Set-IconVisibility -Hidden
Restart-Explorer

Write-Host 'Pre-Configuration Tasks...'

Invoke-ExecuteTaskList -TaskList $PreConfigTasks -Type "Pre-Configuration Tasks"

Write-Host 'Running Configuration Tasks...'

Invoke-ExecuteTaskList -TaskList $ConfigTasks -Type "Configuration Tasks"

#Configure Taskbar Items
Write-Host 'Setting Taskbar...'
Import-StartLayout -LayoutPath "$CSMountPath\Assets\TaskbarLayout.xml" -MountPath "$Env:SYSTEMDRIVE\"

Write-Host 'Setting Final Wallpaper...'
Update-WallPaper -Path "$CSMountPath\Wallpaper.jpg"
Set-TaskbarVisibility
Set-IconVisibility

Write-Host 'Running Post-Configuration Tasks...'

Invoke-ExecuteTaskList -TaskList $PostConfigTasks -Type "Post-Configuration Tasks"

$UtilPath = Join-Path $CSMountPath "Utilities"
if((Get-ChildItem -Path $UtilPath -File -Recurse).Count -gt 0) {
    Write-Host 'Adding Utilities Shortcut...'
    New-Shortcut -Path "$Env:USERPROFILE\Desktop\Utilities.lnk" -TargetPath $UtilPath
}

Write-Host 'Resetting Explorer...'
Restart-Explorer

Write-Host 'Done'

Stop-Transcript
