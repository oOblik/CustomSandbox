param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

switch ($Action) {
  "cache" {
    break;
  }

  "execute" {
    Remove-Item -Path "$Env:PUBLIC\Desktop\*.lnk" -Force | Out-Null
    Remove-Item -Path "$Env:USERPROFILE\Desktop\*.lnk" -Force | Out-Null
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
