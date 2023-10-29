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




$xml = @"
<toast scenario="incomingCall">
    <visual>
        <binding template="ToastGeneric">
            <text>Configuring sandbox...</text>
            <progress title="{progressTitle}" value="{progressValue}" valueStringOverride="{progressValueString}" status="{progressStatus}"/>
        </binding>
    </visual>
    <audio silent="true"/>
</toast>
"@

$XmlDocument = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
$XmlDocument.loadXml($xml)
$ToastNotification = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]::New($XmlDocument)
$ToastNotification.Tag = 'CustomSandbox'
$Dictionary = [System.Collections.Generic.Dictionary[String, String]]::New()
$Dictionary.Add('progressTitle', '')
$Dictionary.Add('progressValue', '0')
$Dictionary.Add('progressValueString', 'Task 0/0')
$Dictionary.Add('progressStatus', 'Running Task...')
$ToastNotification.Data = [Windows.UI.Notifications.NotificationData]::New($Dictionary)
$ToastNotification.Data.SequenceNumber = 1
$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($ToastNotification)


for ($Task = 0; $Task -le $TaskOptions.Count; $Task++) {
    Write-Host "Running Task $($TaskOptions[$Task].BaseName)..."
    $Dictionary = [System.Collections.Generic.Dictionary[String, String]]::New()
    $Dictionary.Add('progressTitle', $TaskOptions[$Task].BaseName)
    $Dictionary.Add('progressValue', $Task / $TaskOptions.Count)
    $Dictionary.Add('progressValueString', "Task $Task/$($TaskOptions.Count)")
    $NotificationData = [Windows.UI.Notifications.NotificationData]::New($Dictionary)
    $NotificationData.SequenceNumber = 2
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Update($NotificationData, 'CustomSandbox')

    & "$($TaskOptions[$Task].FullName)" -Action execute
}

[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Hide($ToastNotification)


Write-Host 'Adding Utilities Shortcut...'
New-Shortcut -Path "$Env:USERPROFILE\Desktop\Utilities.lnk" -TargetPath "$CSMountPath\Utilities"

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
