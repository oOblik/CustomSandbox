param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceCache,
    [Parameter()]
    [object]$Vars
)

$OutPath = "$PSScriptRoot/../Cache/Microsoft.WindowsTerminal.msixbundle"
$VCRedistOutPath = "$PSScriptRoot/../Cache/VC_redist.x64.exe"
$UiXamlZipOutPath = "$PSScriptRoot/../Cache/Microsoft.UI.XAML.2.8.5.zip"

switch($Action) {
    "cache" {
        if(!$ForceCache -and (Test-Path $OutPath)) { break; }

        $Repo = "microsoft/terminal"
        $Releases = "https://api.github.com/repos/$Repo/releases"

        $Package = ((Invoke-WebRequest $Releases | ConvertFrom-Json) | Where-Object {$_.prerelease -eq $false } `
            | Select-Object -First 1).assets | Where-Object {$_.name -like '*.msixbundle'} | Select-Object -First 1
        
        $DownloadURL = $Package.browser_download_url

        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath

        $VCRedistDownloadURL = "https://download.visualstudio.microsoft.com/download/pr/eaab1f82-787d-4fd7-8c73-f782341a0c63/917C37D816488545B70AFFD77D6E486E4DD27E2ECE63F6BBAAF486B178B2B888/VC_redist.x64.exe"
        Invoke-WebRequest -Uri $VCRedistDownloadURL -OutFile $VCRedistOutPath


        $UiXamlDownloadUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.5"
        Invoke-RestMethod -Uri $UiXamlDownloadUrl -OutFile $UiXamlZipOutPath

        break;
    }

    "execute" {
        if((Test-Path $VCRedistOutPath) -and (Test-Path $UiXamlZipOutPath) -and (Test-Path $OutPath)) {
            $IsCorrectBuild=[Environment]::OSVersion.Version.Build
            if ($IsCorrectBuild -lt "18362") {
                Write-Host "Windows Terminal requires at least Windows 10 version 1903/OS build 18362.x."
            } else {
                Write-Host "Installing Microsoft Visual C++ Redistributable for Visual Studio 2015-2022..."
                Start-Process -FilePath $VCRedistOutPath -ArgumentList "/quiet /norestart" -WindowStyle Hidden -Wait

                if (!(Get-AppxPackage -Name 'Microsoft.UI.Xaml.2.8.5')) {
                    Write-Host "Installing Microsoft.UI.Xaml.2.8.5..."

                    $UiXamlWD = Join-Path $Env:Temp "UiXaml"

                    if(!(Test-Path $UiXamlWD)) {
                        New-Item -Path $UiXamlWD -ItemType Directory -Force | Out-Null
                    }

                    Expand-Archive -Path $UiXamlZipOutPath -DestinationPath $UiXamlWD -Force
                    Add-AppxProvisionedPackage -Online -PackagePath "$UiXamlWD\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx" -SkipLicense | Out-Null
                    Remove-Item -Path "$UiXamlWD" -Force -Recurse | Out-Null
                }

                Write-Host "Installing Windows Terminal..."
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
