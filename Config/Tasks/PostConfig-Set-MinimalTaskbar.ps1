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

        Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Force
        Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Force
        Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 -Force
        Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAVolume' -Value 1 -Force
        Set-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCANetwork' -Value 1 -Force

        break;
    }

    default {
        Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
    }
}
