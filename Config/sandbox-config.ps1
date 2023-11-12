$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Tasks.ps1"
. "$PSScriptRoot\Helpers.ps1"

$CSMountPath = $PSScriptRoot
$CSCachePath = Join-Path $CSMountPath "Cache"

Start-Transcript -Path "$Env:USERPROFILE\CustomSandbox.log"

if(Test-Path "C:\Users\WDAGUtilityAccount\Desktop\Config") {
    New-Item -Path "C:\Config" -ItemType SymbolicLink -Value "C:\Users\WDAGUtilityAccount\Desktop\Config" | Out-Null
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
Hide-Taskbar
Hide-Icons
Restart-Explorer

Write-Host 'Pre-Configuration Tasks...'

Invoke-ExecuteTaskList -TaskList $PreConfigTasks -Type "Pre-Configuration Tasks"

Write-Host 'Running Configuration Tasks...'

Invoke-ExecuteTaskList -TaskList $ConfigTasks -Type "Configuration Tasks"

Write-Host 'Adding Utilities Shortcut...'
$UtilPath = Join-Path $CSMountPath "Utilities"
New-Shortcut -Path "$Env:USERPROFILE\Desktop\Utilities.lnk" -TargetPath $UtilPath

#Configure Taskbar Items
Write-Host 'Setting Taskbar...'
Import-StartLayout -LayoutPath "$CSMountPath\Assets\TaskbarLayout.xml" -MountPath "$Env:SYSTEMDRIVE\"

Write-Host 'Setting Final Wallpaper...'
Update-WallPaper -Path "$CSMountPath\Wallpaper.jpg"
Show-Taskbar
Show-Icons

Write-Host 'Running Post-Configuration Tasks...'

Invoke-ExecuteTaskList -TaskList $PostConfigTasks -Type "Post-Configuration Tasks"

Write-Host 'Resetting Explorer...'
Restart-Explorer

Write-Host 'Done'

Stop-Transcript
