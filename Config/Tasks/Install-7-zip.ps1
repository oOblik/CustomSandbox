param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\7ZipInstaller.exe"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $BaseURL = "https://www.7-zip.org"
        $WebResponse = Invoke-WebRequest "$BaseURL/download.html"
        
        if($WebResponse.Content) {
            $HTML = $WebResponse.Content
        
            $comHTML = New-Object -Com "HTMLFile"
            $comHTML.IHTMLDocument2_write($HTML)
        
            $DownloadPath = ($comHtml.all.tags('a') | Where-Object {$_.pathName -like 'a/7z*-x64.exe'} | Select-Object -First 1).pathName
        
            if($DownloadPath) {
                $DownloadURL = $BaseURL + "/" + $DownloadPath
            }
        }
        
        Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath
        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Start-Process -FilePath "$OutPath" -ArgumentList "/S" -Wait
        } else {
            Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
