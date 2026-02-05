param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutArchivePath = "$CSCachePath\$($Vars.ToolArchive)"
$OutPath = "$CSCachePath\$($Vars.ToolExe)"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://download.sysinternals.com/files/$($Vars.ToolArchive)"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutArchivePath -UseBasicParsing

    if (Test-Path $OutArchivePath) {
      Expand-Archive -LiteralPath $OutArchivePath -DestinationPath $CSCachePath -Force
    }

    break;
  }

  "execute" {

    $InstallDir = "$env:ProgramFiles\Sysinternals\$($Vars.InstallFolder)"
    $InstallPath = Join-Path $InstallDir $Vars.ToolExe

    if (Test-Path $OutPath) {
      if(!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
      }

      Copy-Item -Path $OutPath -Destination $InstallPath -Force

      $ShortcutPath = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\$($Vars.ToolName).lnk"
      New-Shortcut -Path $ShortcutPath -TargetPath "$InstallPath" -IconLocation "$InstallPath,0"

    } else {
      Write-Host "Utility not found for task $($MyInvocation.MyCommand.Name)"
    }

    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
