param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\gg.cmd"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://github.com/eirikb/gg/releases/latest/download/gg.cmd"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Copy-Item -Path $OutPath -Destination "$HOME\gg.cmd"
      & "$HOME\gg.cmd"
    } else {
      Write-Host "Utility not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
