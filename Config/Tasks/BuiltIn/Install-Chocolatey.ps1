param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = "$CSCachePath\Chocolatey.nupkg"

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://community.chocolatey.org/api/v2/package/chocolatey"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath -UseBasicParsing

    break;
  }

  "execute" {

    $ChocoInstallPath = "$($env:SystemDrive)\ProgramData\Chocolatey\bin"
    $env:ChocolateyInstall = "$($env:SystemDrive)\ProgramData\Chocolatey"
    $env:Path += ";$ChocoInstallPath"

    try {
      [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192 -bor 48
    } catch {
      Write-Output 'Unable to set PowerShell to use TLS 1.2 and TLS 1.1 due to old .NET Framework installed. If you see underlying connection closed or trust errors, you may need to upgrade to .NET Framework 4.5+ and PowerShell v3+.'
    }

    if (!(Test-Path ($OutPath))) {
      throw "No file exists at $OutPath"
    }

    $chocTempDir = Join-Path $env:TEMP "chocolatey"
    $tempDir = Join-Path $chocTempDir "chocInstall"
    if (![System.IO.Directory]::Exists($tempDir)) { [System.IO.Directory]::CreateDirectory($tempDir) }
    $file = Join-Path $tempDir "chocolatey.zip"
    Copy-Item $OutPath $file -Force

    # unzip the package
    Write-Output "Extracting $file to $tempDir..."

    if ($PSVersionTable.PSVersion.Major -lt 5) {
      try {
        $shellApplication = New-Object -Com Shell.Application
        $zipPackage = $shellApplication.Namespace($file)
        $destinationFolder = $shellApplication.Namespace($tempDir)
        $destinationFolder.CopyHere($zipPackage.Items(),0x10)
      } catch {
        throw "Unable to unzip package using built-in compression. Set `$env:chocolateyUseWindowsCompression = 'false' and call install again to use 7zip to unzip. Error: `n $_"
      }
    } else {
      Expand-Archive -Path "$file" -DestinationPath "$tempDir" -Force
    }

    # Call Chocolatey install
    Write-Output 'Installing chocolatey on this machine'
    $toolsFolder = Join-Path $tempDir "tools"
    $chocInstallPS1 = Join-Path $toolsFolder "chocolateyInstall.ps1"

    & $chocInstallPS1

    Write-Output 'Ensuring chocolatey commands are on the path'
    $chocInstallVariableName = 'ChocolateyInstall'
    $chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
    if ($chocoPath -eq $null -or $chocoPath -eq '') {
      $chocoPath = 'C:\ProgramData\Chocolatey'
    }

    $chocoExePath = Join-Path $chocoPath 'bin'

    if ($($env:Path).ToLower().Contains($($chocoExePath).ToLower()) -eq $false) {
      $env:Path = [Environment]::GetEnvironmentVariable('Path',[System.EnvironmentVariableTarget]::Machine);
    }

    Write-Output 'Ensuring chocolatey.nupkg is in the lib folder'
    $chocoPkgDir = Join-Path $chocoPath 'lib\chocolatey'
    $nupkg = Join-Path $chocoPkgDir 'chocolatey.nupkg'
    if (!(Test-Path $nupkg)) {
      Write-Output 'Copying chocolatey.nupkg is in the lib folder'
      if (![System.IO.Directory]::Exists($chocoPkgDir)) { [System.IO.Directory]::CreateDirectory($chocoPkgDir); }
      Copy-Item "$file" "$nupkg" -Force -ErrorAction SilentlyContinue
    }

    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
