param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\VS2019-Dark.xml"
$ConfigPath = "$CSMountPath\Assets\NppConfig.xml"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://raw.githubusercontent.com/hellon8/VS2019-Dark-Npp/master/VS2019-Dark.xml"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      $LocalConfigPath = Join-Path $env:APPDATA "Notepad++"
      $ThemePath = Join-Path $LocalConfigPath "themes"

      if (!(Test-Path $ThemePath)) {
        New-Item -Path $ThemePath -ItemType Directory -Force | Out-Null
      }

      $ThemeFullPath = Join-Path $ThemePath "VS2019-Dark.xml"
      $LocalConfigFullPath = Join-Path $LocalConfigPath "config.xml"

      Copy-Item $OutPath -Destination $ThemeFullPath | Out-Null
      Copy-Item $ConfigPath -Destination $LocalConfigFullPath | Out-Null

    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
