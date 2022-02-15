param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\VSCodeUserSetup-x64-latest.exe"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $DownloadURL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath

        break;
    }

    "execute" {
        if(Test-Path $OutPath) {

            Start-Process -FilePath $OutPath -ArgumentList "/verysilent /suppressmsgboxes /mergetasks=`"!runCode`"" -Wait     

        } else {
            Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
