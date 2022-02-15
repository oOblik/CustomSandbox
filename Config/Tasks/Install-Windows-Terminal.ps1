param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot/../Cache/Microsoft.WindowsTerminal.msixbundle"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $Repo = "microsoft/terminal"
        $Releases = "https://api.github.com/repos/$Repo/releases"

        $DownloadURL = ((Invoke-WebRequest $Releases | ConvertFrom-Json) | Where-Object {$_.prerelease -eq $false } | Select-Object -First 1).assets.browser_download_url[0]

        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath

        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            $IsCorrectBuild=[Environment]::OSVersion.Version.Build
            if ($IsCorrectBuild -lt "18362") {
                Write-Host "Windows Terminal requires at least Windows 10 version 1903/OS build 18362.x."
            } else {
                Add-AppxPackage -Path $OutPath
            }
        } else {
            Write-Host "Utility not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
