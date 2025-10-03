param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\npp.latest.Installer.x64.exe"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $Repo = "notepad-plus-plus/notepad-plus-plus"
    $Releases = "https://api.github.com/repos/$Repo/releases"

    $DownloadURL = (((Invoke-WebRequest $Releases -UseBasicParsing | ConvertFrom-Json) | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1).assets | Where-Object { $_.browser_download_url -like '*npp.*.Installer.x64.exe' }).browser_download_url

    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Start-Process -FilePath $OutPath -ArgumentList "/S" -WindowStyle Hidden -Wait
    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
