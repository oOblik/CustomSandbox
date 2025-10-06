param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\WindowsTerminalPortable.zip"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $releaseApiUrl = "https://api.github.com/repos/microsoft/terminal/releases/latest"
    $releaseInfo = Invoke-RestMethod -Uri $releaseApiUrl -Headers @{ "User-Agent" = "PowerShell" } -UseBasicParsing

    $DownloadURL = ($releaseInfo.assets | Where-Object { $_.browser_download_url -like "*/Microsoft.WindowsTerminal*_x64.zip" } | Select-Object -First 1).browser_download_url
    if (-not $DownloadURL) {
      Write-Error "No x64 ZIP asset found in the latest release."
      break;
    }

    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {
    $InstallPath = "$env:PROGRAMFILES\Windows Terminal"

    if (Test-Path $OutPath) {
      Expand-Archive $OutPath -DestinationPath $InstallPath

      $ExtractedDir = Get-ChildItem -Path $InstallPath -Directory | Where-Object { $_.Name -like "terminal-*" }

      if ($ExtractedDir) {
          $ExtractedPath = $ExtractedDir.FullName
          Get-ChildItem -Path $ExtractedPath | ForEach-Object {
              Move-Item -Path $_.FullName -Destination $InstallPath -Force
          }
          Remove-Item -Path $ExtractedPath -Force
      } else {
          Write-Host "No folder matching 'terminal-*' found in $InstallPath"
      }

      if(Test-Path "$InstallPath\wt.exe") {
          $env:Path += ";$InstallPath"
          [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
          $ShortcutPath = "$Env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\Windows Terminal.lnk"
          New-Shortcut -Path $ShortcutPath -TargetPath "$InstallPath\wt.exe" -IconLocation "$InstallPath\wt.exe,0"
      } else {
          Write-Host "wt.exe not found in $InstallPath"
      }

    } else {
      Write-Host "Archive not found for task $($MyInvocation.MyCommand.Name)"
    }
    
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
