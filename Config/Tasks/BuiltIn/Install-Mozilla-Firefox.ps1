param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = Join-Path $CSCachePath "MozillaFirefoxInstaller.msi"
$RunPath = Join-Path $Env:TEMP "MozillaFirefoxInstaller.msi"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US"

    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Copy-Item $OutPath -Destination $RunPath | Out-Null
      Start-Process -FilePath "Msiexec.exe" -ArgumentList "/I `"$RunPath`" PREVENT_REBOOT_REQUIRED=true DESKTOP_SHORTCUT=false TASKBAR_SHORTCUT=true /qn" -WindowStyle Hidden -Wait
    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
