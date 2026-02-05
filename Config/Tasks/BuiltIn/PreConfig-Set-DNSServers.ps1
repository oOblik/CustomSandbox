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
    
    $NetIndex = (Get-NetAdapter -Name "Ethernet").ifIndex
    Set-DnsClientServerAddress -InterfaceIndex $NetIndex -ServerAddresses $Vars.addresses
    & ipconfig /flushdns

    $startTime = Get-Date
    $timeout = New-TimeSpan -Minutes 5
    $resolved = $false

    while ((Get-Date) - $startTime -lt $timeout -and -not $resolved) {
        try {
            $result = Resolve-DnsName -Name "google.com" -ErrorAction Stop
            if ($result) {
                Write-Host "Successfully resolved google.com at $(Get-Date)"
                $resolved = $true
            }
        } catch {
            Write-Host "Resolution failed at $(Get-Date). Retrying..."
        }
        Start-Sleep -Seconds 5
    }

    if (-not $resolved) {
        Write-Host "Failed to resolve google.com within 5 minutes."
    }

    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
