param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutArchivePath = Join-Path $CSCachePath "BGInfo.zip"
$OutPath = Join-Path $CSCachePath "BGInfo.exe"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://download.sysinternals.com/files/BGInfo.zip"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutArchivePath -UseBasicParsing

    if (Test-Path $OutArchivePath) {
      Expand-Archive -LiteralPath $OutArchivePath -DestinationPath $CSCachePath -Force
    }

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Start-Process -FilePath $OutPath -ArgumentList "$CSMountPath\Assets\BGInfo.bgi /timer:0 /nolicprompt /silent" -WindowStyle Hidden
    } else {
      Write-Host "Utility not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
