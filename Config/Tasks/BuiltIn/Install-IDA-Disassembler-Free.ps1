param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\IDAFreeInstaller.exe"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $ReleasePage = Get-WebpageObject "https://hex-rays.com/ida-free/"

    if ($ReleasePage) {
      $DownloadPath = ($ReleasePage.all.tags('a') | Where-Object { $_.textContent -like '*IDA Free for Windows*' } | Select-Object -First 1).href
    }

    if ($DownloadPath) {
      Invoke-WebRequest -Uri $DownloadPath -OutFile $OutPath -UseBasicParsing
    }

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Start-Process -FilePath "$OutPath" -ArgumentList "--unattendedmodeui minimal --mode unattended --installpassword freeware" -WindowStyle Hidden -Wait
    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
