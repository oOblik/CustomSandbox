$CSMountPath = "$Env:SYSTEMDRIVE\Config"

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

function Set-DarkMode {
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 0 -Type Dword -Force
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 0 -Type Dword -Force
}

function Show-HiddenFiles {
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden' -Value 1 -Type Dword -Force
}

function Show-FileExtensions {
	Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0 -Type Dword -Force
}

function Set-MinimalTaskbar {
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Force
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Force
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 -Force
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAVolume' -Value 1 -Force
    Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCANetwork' -Value 1 -Force
}

function Create-Shortcut {
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
			<text id="title"></text>
			<text id="text"></text>
		</binding>
	</visual>
</toast>
"@

	$TemplateContent = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
	$TemplateContent.loadXml($TemplateXML)
	$TemplateContent.SelectSingleNode('//text[@id="title"]').InnerText = $Title
	$TemplateContent.SelectSingleNode('//text[@id="text"]').InnerText = $Text
	$AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

	return [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($TemplateContent)
}
