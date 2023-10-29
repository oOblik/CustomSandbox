param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\ApacheOpenOfficeInstaller.exe"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $VersionURL = "https://www.openoffice.org/download/globalvars.js"
        $WebResponse = Invoke-WebRequest $VersionURL
        
        if($WebResponse.Content) {
            $Version = $WebResponse.Content -match 'DL.VERSION[.\s]+= ["](.+)["];'

            if($Version -and $Matches[1]) {
                $DownloadURL = "https://downloads.apache.org/openoffice/$($Matches[1])/binaries/en-US/Apache_OpenOffice_$($Matches[1])_Win_x86_install_en-US.exe"
            }
        }
        
        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath
        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Start-Process -FilePath "$OutPath" -ArgumentList "/S RebootYesNo=No CREATEDESKTOPLINK=0 ADDLOCAL=ALL REMOVE=gm_o_Quickstart,gm_o_Onlineupdate" -WindowStyle Hidden -Wait
        } else {
            Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
