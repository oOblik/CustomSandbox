param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\OpenJDK11U-jre_winx64_latest.msi"
$RunPath = "C:\Windows\TEMP\OpenJDK11U-jre_winx64_latest.msi"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $JsonURL = "https://api.adoptopenjdk.net/v3/assets/latest/11/hotspot?release=latest&jvm_impl=hotspot&vendor=adoptopenjdk"
        $JsonResponse = Invoke-WebRequest -Uri $JsonURL

        if($JsonResponse.Content) {
            $JSON = ConvertFrom-Json $JsonResponse.Content

            $DownloadURL = ($JSON | Where-Object {$_.binary.os -eq 'windows' -and $_.binary.image_type -eq 'jre' -and $_.binary.architecture -eq 'x64'}).binary.installer.link
        }

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
