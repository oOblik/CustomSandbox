param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$PackageName = $Vars.packagename

$APIBaseURL = "https://chocolatey.org/api/v2"
$PkgURL = "$APIBaseURL/package/$PackageName"

$CacheDir = Join-Path "$CSCachePath\Chocolatey" $PackageName

$PkgPath = Join-Path $CacheDir "$PackageName.zip"
$CheckPath = Join-Path $CacheDir "$PackageName.nupkg"

$PgkWorkDir = Join-Path $CacheDir "package"
$PkgInstallFile = "tools\chocolateyInstall.ps1"

$InternalizedDir = Join-Path "$CSMountPath\Cache\Chocolatey" $PackageName

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $CheckPath)) { break; }

    if (Test-Path $CacheDir) {
      Remove-Item -Path $CacheDir -Recurse -Force
    }

    New-Item -Path $CacheDir -ItemType Directory -Force | Out-Null
    New-Item -Path $PgkWorkDir -ItemType Directory -Force | Out-Null

    Invoke-WebRequest -Uri $PkgURL -OutFile $PkgPath

    if (!(Test-Path $PkgPath)) {
      Write-Error "Failed to download package $PackageName"
    }

    Expand-Archive -Path $PkgPath -DestinationPath $PgkWorkDir

    $PkgInstallFilePath = Join-Path $PgkWorkDir $PkgInstallFile

    if (Test-Path $PkgInstallFilePath) {

      $InstallFile = Get-Content -Path $PkgInstallFilePath

      $URLPattern = "(?<=['`"])(http[s]?)(:\/\/)([^\s,]+)(?<!['`"])"

      $InstallFile | Select-String -AllMatches $URLPattern | ForEach-Object {
        $DLFileName = Invoke-BlindFileDownload -Url $_.Matches.Value -FolderPath $CacheDir
        $InternalizedPath = Join-Path $InternalizedDir $DLFileName
        $InstallFile = $InstallFile.Replace($_.Matches.Value,$InternalizedPath)
      }

      $InstallFile | Set-Content -Path $PkgInstallFilePath -Force

      Compress-Archive -Path ($PgkWorkDir + "\*") -DestinationPath $PkgPath -Force

    }

    Get-Item -Path $PkgPath | Rename-Item -NewName { [IO.Path]::ChangeExtension($_.Name,"nupkg") }

    Remove-Item -Path $PgkWorkDir -Recurse -Force

    break;
  }

  "execute" {

    $ExtraArgs = ""

    if ($Vars.args) {
      $ExtraArgs = $Vars.args
    }

    choco install $PackageName -y --acceptlicense $ExtraArgs -s "$InternalizedDir"

    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
