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
    $profilePath = $PROFILE

    if (-not (Test-Path $profilePath)) {
        $profileDir = Split-Path $profilePath
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
        Write-Host "Created new PowerShell profile at $profilePath"
    }

    $debugSetting = '$DebugPreference = "Continue"'

    $profileContent = Get-Content $profilePath -ErrorAction SilentlyContinue
    if (-not ($profileContent -contains $debugSetting)) {
        Add-Content -Path $profilePath -Value "`n# Always show debug output`n$debugSetting"
        Write-Host "Debug output configuration added to your PowerShell profile."
    } else {
        Write-Host "Debug output is already configured in your PowerShell profile."
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
