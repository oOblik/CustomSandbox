param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutArchivePath = "$PSScriptRoot/../Cache/BGInfo.zip"
$OutPath = "$PSScriptRoot\..\Cache\HxDSetup.exe"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $DownloadURL = "https://mh-nexus.de/downloads/HxDSetup.zip"
        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutArchivePath

        if(Test-Path $OutArchivePath) {
            Expand-Archive -LiteralPath $OutArchivePath -DestinationPath "$PSScriptRoot/../Cache/" -Force
        }

        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Start-Process -FilePath $OutPath -ArgumentList "/silent" -Wait -WindowStyle Hidden
        } else {
            Write-Host "Utility not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}