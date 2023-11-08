param(
    [Parameter()]
    [string]$Action,
    [Parameter()]
    [bool]$ForceCache,
    [Parameter()]
    [object]$Vars
)

switch($Action) {
    "cache" {
        break;
    }

    "execute" {
        Write-Host 'Setting Show File Extensions...'
        Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0 -Type Dword -Force
        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
