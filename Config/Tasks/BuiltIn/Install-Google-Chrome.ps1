param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = Join-Path $CSCachePath "GoogleChromeInstaller.msi"
$RunPath = Join-Path $Env:TEMP "GoogleChromeInstaller.msi"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi"

    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath
    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Copy-Item $OutPath -Destination $RunPath | Out-Null
      Start-Process -FilePath "Msiexec.exe" -ArgumentList "/I `"$RunPath`" /quiet /norestart" -WindowStyle Hidden -Wait
      Remove-Item -Path "$Env:PUBLIC\Desktop\Google Chrome.lnk" -Force | Out-Null
    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
