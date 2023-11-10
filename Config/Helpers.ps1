$CSMountPath = "$Env:SYSTEMDRIVE\Config"
$CSCachePath = "$Env:SYSTEMDRIVE\Config\Cache"

function Get-FriendlySize {
    param([int]$MBytes)

    $bytes = $MBytes*1024*1024

    $result = "{0} B " -f $bytes

    switch($bytes) {
        { $_ -ge 1tb } { 
            $result = "{0:n2} TB" -f ($_ / 1tb)
            break;
        }
        { $_ -ge 1gb } { 
            $result = "{0:n2} GB" -f ($_ / 1gb) 
            break;
        }
        { $_ -ge 1mb } { 
            $result = "{0:n2} MB" -f ($_ / 1mb) 
            break;
        }
        { $_ -ge 1kb } { 
            $result = "{0:n2} KB" -f ($_ / 1Kb)
            break;
        }
    }

    return $result;
}

function Invoke-ExecuteTaskList {
    param(
        [object]$TaskList,
        [string]$Type
    )

    if($TaskList) {

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
        $Dictionary.Add('progressStatus', $Type)
        $ToastNotification.Data = [Windows.UI.Notifications.NotificationData]::New($Dictionary)
        $ToastNotification.Data.SequenceNumber = 1
        $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($ToastNotification)

        for ($Task = 0; $Task -lt $TaskList.Count; $Task++) {
            Write-Host "Running Task $($TaskList[$Task].Name)..."
            $Dictionary = [System.Collections.Generic.Dictionary[String, String]]::New()
            $Dictionary.Add('progressTitle', $TaskList[$Task].Name)
            $Dictionary.Add('progressValue', ($Task+1) / $TaskList.Count)
            $Dictionary.Add('progressValueString', "Task $($Task+1)/$($TaskList.Count)")
            $NotificationData = [Windows.UI.Notifications.NotificationData]::New($Dictionary)
            $NotificationData.SequenceNumber = 2
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Update($NotificationData, 'CustomSandbox')
        
            $TaskList[$Task].ExecuteAction("execute", $false)
        }
        
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Hide($ToastNotification)

    }

}

function Update-Wallpaper {
[cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Position = 0,HelpMessage="The path to the wallpaper file.")]
        [alias("wallpaper")]
        [ValidateScript({Test-Path $_})]
        [string]$Path = $(Get-ItemPropertyValue -Path 'HKCU:\Control Panel\Desktop\' -Name Wallpaper)
    )

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    using Microsoft.Win32;

    namespace Wallpaper
    {
        public class UpdateImage
        {
            [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]

            private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);

            public static void Refresh(string path)
            {
                SystemParametersInfo( 20, 0, path, 0x01 | 0x02 );
            }
        }
    }
"@

    Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperOriginX' -Value 0 -Force
    Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperOriginY' -Value 0 -Force
    Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperStyle' -Value 2 -Force
    Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'JPEGImportQuality' -Value 100 -Force

    if ($PSCmdlet.shouldProcess($path)) {
        [Wallpaper.UpdateImage]::Refresh($Path)
    }
}

function Hide-Icons {
	Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDesktop' -Value 1
}

function Show-Icons {
	Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDesktop' -Value 0
}

function Hide-Taskbar {
    $v=(Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3').Settings
    $v[8]=3
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3' -Name 'Settings' -Value $v
}

function Show-Taskbar {
    $v=(Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3').Settings
    $v[8]=2
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3' -Name 'Settings' -Value $v
}

function New-Shortcut {
	param(
		[string]$Path,
		[string]$TargetPath
	)

	$WshShell = New-Object -comObject WScript.Shell
	$Shortcut = $WshShell.CreateShortcut($Path)
	$Shortcut.TargetPath = $TargetPath
	$Shortcut.Save()
}

function Restart-Explorer {
	Get-Process explorer | Stop-Process -Force
}

function Show-Notification {
    [cmdletbinding()]
    param (
		[string]$Title = "CustomSandbox",
        [string][parameter(ValueFromPipeline)]$Text
    )

    $TemplateXML = @"
<toast>
	<visual>
		<binding template="ToastGeneric">
			<text id="0"></text>
			<text id="1"></text>
		</binding>
	</visual>
</toast>
"@

	$TemplateContent = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
	$TemplateContent.loadXml($TemplateXML)
	$TemplateContent.SelectSingleNode('//text[@id="0"]').InnerText = $Title
	$TemplateContent.SelectSingleNode('//text[@id="1"]').InnerText = $Text
	$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

	return [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($TemplateContent)
}

function Invoke-BlindFileDownload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$FolderPath
    )

    $Request = [System.Net.HttpWebRequest]::Create($Url)
    $Request.Method = "HEAD"
    $Response = $Request.GetResponse()

    $FileUri = $Response.ResponseUri
    $Filename = [System.IO.Path]::GetFileName($FileUri.LocalPath);
    $Response.Close()
    
    $Destination = Join-Path $FolderPath $Filename

    Invoke-WebRequest -Uri $FileUri.AbsoluteUri -OutFile $Destination

    return $Filename
}
