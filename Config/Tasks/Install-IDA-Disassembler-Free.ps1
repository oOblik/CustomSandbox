param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceUpdate
)

$OutPath = "$PSScriptRoot\..\Cache\IDAFreeInstaller.exe"

switch($Action.ToLower()) {
    "update" {
        if(!$ForceUpdate -and (Test-Path $OutPath)) { break; }

        $BaseURL = "https://hex-rays.com/ida-free/"
        
        $WebResponse = Invoke-WebRequest $BaseURL
        
        if($WebResponse.Content) {
            $HTML = $WebResponse.Content
        
            $comHTML = New-Object -Com "HTMLFile"

            try {
                $comHTML.IHTMLDocument2_write($HTML)
            } catch {
                $comHTML.write([System.Text.Encoding]::Unicode.GetBytes($HTML))
            }
        
            $DownloadPath = ($comHtml.all.tags('a') | Where-Object {$_.textContent -like '*IDA Free for Windows*'} | Select-Object -First 1).href
        }
        
        Invoke-WebRequest -Uri $DownloadPath -OutFile $OutPath
        break;
    }

    "execute" {
        if(Test-Path $OutPath) {
            Start-Process -FilePath "$OutPath" -ArgumentList "--unattendedmodeui minimal --mode unattended --installpassword freeware" -Wait -WindowStyle Hidden
        } else {
            Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
        }
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}