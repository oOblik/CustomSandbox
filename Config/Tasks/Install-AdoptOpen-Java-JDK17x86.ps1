param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\OpenJDK17-jdk_winx86_latest.msi"
$RunPath = "C:\Windows\TEMP\OpenJDK17-jdk_winx86_latest.msi"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

            $DownloadURL = "https://api.adoptium.net/v3/installer/latest/17/ga/windows/x86/jdk/hotspot/normal/eclipse"
            Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath

        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Copy-Item $OutPath -Destination $RunPath | Out-Null
            Start-Process -FilePath "Msiexec.exe" -ArgumentList "/I `"$RunPath`" /quiet INSTALLLEVEL=1" -WindowStyle Hidden -Wait -PassThru

        } else {
            Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}