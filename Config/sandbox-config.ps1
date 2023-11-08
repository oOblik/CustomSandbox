$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$CSMountPath = "$Env:SYSTEMDRIVE\Config"

. "$CSMountPath\Tasks.ps1"
. "$CSMountPath\Helpers.ps1"


Start-Transcript -Path "$Env:TEMP\CustomSandboxConfig.txt"

Write-Host 'Importing Tasks...'
$TaskCollection = New-CustomSandboxTaskCollection -Path "$CSMountPath\Tasks"
$TaskOptions = Get-Content -Path "$CSMountPath\Cache\EnabledTasks.json" | ConvertFrom-Json

$TaskCollection.Tasks = $TaskCollection.Tasks | Where-Object {$_.ID -in $TaskOptions}


$PreConfigTasks = $TaskCollection.Tasks | Where-Object {$_.Type -eq 'preconfig'}
$PostConfigTasks = $TaskCollection.Tasks | Where-Object {$_.Type -eq 'postconfig'}
$ConfigTasks = $TaskCollection.Tasks | Where-Object {$_.Type -ne 'preconfig' -and $_.Type -ne 'postconfig'}

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
New-Shortcut -Path "$Env:USERPROFILE\Desktop\Utilities.lnk" -TargetPath "$CSMountPath\Utilities"

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
