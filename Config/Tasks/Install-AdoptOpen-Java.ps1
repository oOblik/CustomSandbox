param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceCache,
    [Parameter()]
    [object]$Vars
)

if(-not $Vars.image_type) {
    Write-Error "You must define 'image_type' var in task configuration!"
    return
}

if(-not $Vars.arch) {
    Write-Error "You must define 'arch' var in task configuration!"
    return
}

if(-not $Vars.feature_version) {
    Write-Error "You must define 'feature_version' var in task configuration!"
    return
}

$OutPath = "$PSScriptRoot\..\Cache\OpenJDK-$($Vars.image_type)_win$($Vars.arch)_$($Vars.feature_version).msi"
$RunPath = "C:\Windows\TEMP\OpenJDK-$($Vars.image_type)_win$($Vars.arch)_$($Vars.feature_version).msi"

switch($Action) {
    "cache" {
        if(!$ForceCache -and (Test-Path $OutPath)) { break; }

        $version = $Vars.feature_version

        if($Vars.feature_version -eq 'latest') {
            $JsonURL = "https://api.adoptium.net/v3/info/available_releases"
            $JsonResponse = Invoke-RestMethod -Uri $JsonURL -Method GET
            $version = $JsonResponse.most_recent_lts
        }

        $DownloadURL = "https://api.adoptium.net/v3/installer/latest/$version/ga/windows/$($Vars.arch)/$($Vars.image_type)/hotspot/normal/eclipse"
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
