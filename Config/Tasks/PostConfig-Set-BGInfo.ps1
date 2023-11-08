param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceCache,
    [Parameter()]
    [object]$Vars
)

$OutArchivePath = "$PSScriptRoot/../Cache/BGInfo.zip"
$OutPath = "$PSScriptRoot/../Cache/BGInfo.exe"

switch($Action) {
    "cache" {
        if(!$ForceCache -and (Test-Path $OutPath)) { break; }

        $DownloadURL = "https://download.sysinternals.com/files/BGInfo.zip"
        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutArchivePath

        if(Test-Path $OutArchivePath) {
            Expand-Archive -LiteralPath $OutArchivePath -DestinationPath "$PSScriptRoot/../Cache/" -Force
        }

        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Start-Process -FilePath "C:\Config\Cache\Bginfo64.exe" -ArgumentList "C:\Config\Assets\BGInfo.bgi /timer:0 /nolicprompt /silent" -WindowStyle Hidden
        } else {
            Write-Host "Utility not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
