$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

. "C:\Config\Helpers.ps1"

Start-Transcript -Path "C:\Windows\Temp\SandboxConfig.txt"

#Configure Wallpaper
Write-Host 'Setting Initial Wallpaper...'
Update-WallPaper -Path "C:\Config\Assets\Wait.jpg"
Hide-Taskbar
Get-Process explorer | Stop-Process -Force

Write-Host 'Setting Dark Mode...'
Set-DarkMode

Write-Host 'Set Show Hidden Files...'
Show-HiddenFiles

Write-Host 'Running Optional Tasks...'
$TaskOptions = Import-Csv -Path 'C:\Config\Cache\EnabledTasks.csv'
ForEach ($Task in $TaskOptions) {
    Write-Host "Running Task $($Task.BaseName)..."
    & "$($Task.FullName)" -Action execute
}

Write-Host 'Adding Utilities Shortcut...'
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\Utilities.lnk")
$Shortcut.TargetPath = "C:\Config\Utilities"
$Shortcut.Save()

#Configure the Taskbar and Hide Icons
Write-Host 'Setting Taskbar...'
Import-StartLayout -LayoutPath "C:\Config\Assets\TaskbarLayout.xml" -MountPath $env:SystemDrive\
Set-MinimalTaskbar

Write-Host 'Setting Final Wallpaper...'
Update-WallPaper -Path "C:\Config\Wallpaper.jpg"
Show-Taskbar

& "C:\Config\Tasks\Set-BGInfo.ps1" -Action execute

Write-Host 'Resetting Explorer...'
Get-Process explorer | Stop-Process -Force

Write-Host 'Done'

Stop-Transcript
