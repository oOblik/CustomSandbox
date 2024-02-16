param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\7ZipInstaller.exe"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }
    
    $BaseURL = "https://www.7-zip.org"
    $ReleasePage = Get-WebpageObject "$BaseURL/download.html"

    if ($ReleasePage) {
      $DownloadPath = ($ReleasePage.all.tags('a') | Where-Object { $_.pathName -like 'a/7z*-x64.exe' } | Select-Object -First 1).pathName
    }

    if ($DownloadPath) {
      $DownloadURL = $BaseURL + "/" + $DownloadPath
      Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing
    }

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Start-Process -FilePath "$OutPath" -ArgumentList "/S" -WindowStyle Hidden -Wait
    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
