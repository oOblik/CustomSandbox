param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\VSCodeUserSetup-x64-latest.exe"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {

      Start-Process -FilePath $OutPath -ArgumentList "/verysilent /suppressmsgboxes /mergetasks=`"!runCode`"" -WindowStyle Hidden -Wait

    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
