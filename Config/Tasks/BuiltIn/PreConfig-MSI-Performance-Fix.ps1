param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

# https://github.com/microsoft/Windows-Sandbox/issues/68#issuecomment-2684406010

switch ($Action) {
  "cache" {
    break;
  }

  "execute" {
    Write-Host 'Applying MSI Install Performance Fix...'
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "VerifiedAndReputablePolicyState" -Value "0" -Type DWord
    CiTool.exe --refresh --json
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
