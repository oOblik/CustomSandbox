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
    $ExtraArgs = ""

    if($ExtraArgs -notlike "*--source*") {
      $ExtraArgs += " --source winget"
    }

    if ($Vars.args) {
      $ExtraArgs += " $($Vars.args)"
    }

    Start-Process "winget" -ArgumentList "install --id $($Vars.packagename) --silent --accept-package-agreements --accept-source-agreements$ExtraArgs" -Wait
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}



