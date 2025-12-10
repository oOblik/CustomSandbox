param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$StartSnapshotPath = "$Env:TEMP\StartSnapshot.json"
$StartLayoutPath = "$Env:TEMP\TaskbarLayout.xml"

switch ($Action) {
  "cache" {
    break;
  }

  "execute" {
    
    if (Test-Path $StartSnapshotPath) {

      $StartSnapshot = Get-Content -Path $StartSnapshotPath | ConvertFrom-Json
      $StartItems = Get-ChildItem -Path "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Include "*.lnk" -Recurse | Select-Object FullName

      $StartLayout = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
Version="1">
<CustomTaskbarLayoutCollection PinListPlacement="Replace">
<defaultlayout:TaskbarLayout>
<taskbar:TaskbarPinList>
"@

      foreach ($Item in $StartItems) {
        if ($StartSnapshot -notcontains $Item.FullName) {
          $StartLayout += "<taskbar:DesktopApp DesktopApplicationLinkPath=`"$($Item.FullName)`" />`n"
        }
      }

      $StartLayout += @"
</taskbar:TaskbarPinList>
</defaultlayout:TaskbarLayout>
</CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

      Set-Content -Path $StartLayoutPath -Value $StartLayout -Force

      # Generate and apply here

      Write-Host 'Pinning apps to taskbar...'
      $TaskbarLayoutRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
      if (-not (Test-Path $TaskbarLayoutRegPath)) {
          New-Item -Path $TaskbarLayoutRegPath -Force | Out-Null
      }
      Set-ItemProperty -Path $TaskbarLayoutRegPath -Name "StartLayoutFile" -Value $StartLayoutPath -Type ExpandString
      Set-ItemProperty -Path $TaskbarLayoutRegPath -Name "LockedStartLayout" -Value 1 -Type DWord
      
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
