param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceCache,
    [Parameter()]
    [object]$Vars
)

$OutPath = "$PSScriptRoot\..\Cache\OpenJDK-jdk_winx64_latest.msi"
$RunPath = "C:\Windows\TEMP\OpenJDK-jdk_winx64_latest.msi"

switch($Action) {
    "cache" {
        if(!$ForceCache -and (Test-Path $OutPath)) { break; }

        $JsonURL = "https://api.adoptium.net/v3/info/available_releases"
        $JsonResponse = Invoke-RestMethod -Uri $JsonURL -Method GET

        if($JsonResponse.most_recent_lts) {
            $DownloadURL = "https://api.adoptium.net/v3/installer/latest/$($JsonResponse.most_recent_lts)/ga/windows/x64/jdk/hotspot/normal/eclipse"
            Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath
        }

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
