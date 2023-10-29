$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$CSMountPath = "$Env:SYSTEMDRIVE\Config"

. "$CSMountPath\Helpers.ps1"

Start-Transcript -Path "$Env:TEMP\CustomSandboxConfig.txt"

#Set limited GUI for configuration mode
Write-Host 'Setting Initial Wallpaper...'
Update-WallPaper -Path "$CSMountPath\Assets\Wait.jpg"
Hide-Taskbar
Hide-Icons
Restart-Explorer

Write-Host 'Setting Dark Mode...'
Set-DarkMode

Write-Host 'Set Show Hidden Files...'
Show-HiddenFiles

Write-Host 'Set Show File Extensions...'
Show-FileExtensions

Write-Host 'Running Optional Tasks...'
$TaskOptions = Import-Csv -Path "$CSMountPath\Cache\EnabledTasks.csv"
ForEach ($Task in $TaskOptions) {
    Write-Host "Running Task $($Task.BaseName)..."
    Show-Notification -Text "Running Task $($Task.BaseName)..."
    & "$($Task.FullName)" -Action execute
}

Write-Host 'Adding Utilities Shortcut...'
Create-Shortcut -Path "$Env:USERPROFILE\Desktop\Utilities.lnk" -TargetPath "$CSMountPath\Utilities"

#Configure the Taskbar and Hide Icons
Write-Host 'Setting Taskbar...'
Import-StartLayout -LayoutPath "$CSMountPath\Assets\TaskbarLayout.xml" -MountPath "$Env:SYSTEMDRIVE\"
Set-MinimalTaskbar

Write-Host 'Setting Final Wallpaper...'
Update-WallPaper -Path "$CSMountPath\Wallpaper.jpg"
Show-Taskbar
Show-Icons

Write-Host 'Running BGInfo...'
& "$CSMountPath\Tasks\Set-BGInfo.ps1" -Action execute

Write-Host 'Resetting Explorer...'
Restart-Explorer

Write-Host 'Done'

Stop-Transcript
