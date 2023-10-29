param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\npp.latest.Installer.x64.exe"
$ThemeOutPath = "$PSScriptRoot\..\Cache\VS2015-Dark.xml"
$ConfigPath = "$PSScriptRoot\..\Assets\NppConfig.xml"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $Repo = "notepad-plus-plus/notepad-plus-plus"
        $Releases = "https://api.github.com/repos/$Repo/releases"

        $DownloadURL = (((Invoke-WebRequest $Releases | ConvertFrom-Json) | Where-Object {$_.prerelease -eq $false } | Select-Object -First 1).assets | Where-Object {$_.browser_download_url -like '*npp.*.Installer.x64.exe'}).browser_download_url

        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath

        $ThemeDownloadURL = "https://raw.githubusercontent.com/hellon8/VS2019-Dark-Npp/master/VS2019-Dark.xml"
        Invoke-WebRequest -Uri $ThemeDownloadURL -OutFile $ThemeOutPath

        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Start-Process -FilePath $OutPath -ArgumentList "/S" -WindowStyle Hidden -Wait

            $LocalConfigPath = Join-Path $env:APPDATA "Notepad++"
            $ThemePath = Join-Path $LocalConfigPath "themes"

            if(!(Test-Path $ThemePath)) {
                New-Item -Path $ThemePath -ItemType Directory -Force | Out-Null
            }

            $ThemeFullPath = Join-Path $ThemePath "VS2019-Dark.xml"
            $LocalConfigFullPath = Join-Path $LocalConfigPath "config.xml"

            Copy-Item $ThemeOutPath -Destination $ThemeFullPath | Out-Null
            Copy-Item $ConfigPath -Destination $LocalConfigFullPath | Out-Null

            if(([Environment]::OSVersion.Version).Build -ge 22000) {
                $NPPExe = "$env:LOCALAPPDATA\Programs\Notepad++\notepad++.exe"
            
                if (-not (Test-Path $NPPExe)) {
                    $NPPExe = "$env:ProgramFiles\Notepad++\notepad++.exe"
                }
                if (-not (Test-Path $NPPExe)) {
                    $NPPExe = "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
                }
            
                if(Test-Path $NPPExe) {
                    $Path = 'HKCU:\Software\Classes\*\shell\pintohome'
                    New-Item -Path "$Path\command" -Force | Out-Null
                    Set-ItemProperty -LiteralPath $Path -Name 'MUIVerb' -Value 'Edit with Notepad++'
                    Set-ItemProperty -LiteralPath "$Path\command" -Name '(Default)' -Value ('"{0}" "%1"' -f $NPPExe)
                }
            }
            
        } else {
            Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
