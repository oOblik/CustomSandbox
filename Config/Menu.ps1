#Requires -Version 5

class MenuItem{
  [ValidateNotNullOrEmpty()] [string]$Label
  [ValidateNotNullOrEmpty()] [string]$Value
  [switch]$Selected
  [string]$Info
  [int]$Order
  [switch]$ReadOnly
  [string[]]$Depends

  MenuItem ([string]$Label,[string]$Value,[switch]$Selected,[string]$Info,[int]$Order,[switch]$ReadOnly,[string[]]$Depends) {
    $this.Init($Label,$Value,$Selected,$Info,$Order,$ReadOnly,$Depends);
  }

  hidden Init (
    [string]$Label,
    [string]$Value,
    [switch]$Selected,
    [string]$Info,
    [int]$Order,
    [switch]$ReadOnly,
    [string[]]$Depends
  ) {
    $this.Label = $Label
    $this.Value = $Value
    $this.Selected = $Selected
    $this.Info = $Info
    $this.Order = $Order
    $this.ReadOnly = $ReadOnly
    $this.Depends = $Depends
  }

  [int] length () {
    return $this.Label.length
  }
}

class Menu{
  [ValidateNotNullOrEmpty()] [string]$Header
  [ValidateNotNullOrEmpty()] [MenuItem[]]$Items
  [ValidateNotNullOrEmpty()] [string]$Mode

  hidden [object[]]$SelectedItems = @()
  hidden [string[]]$DependencyList = @()
  hidden [int]$CurrentIndex = 0
  hidden [bool]$SelectionChanged = $True
  hidden [int]$MaxHeight = 10
  hidden [int]$ScrollTop = 0
  hidden [int]$ScrollBottom = 0

  $DefaultForegroundColor = (Get-Host).UI.RawUI.ForegroundColor
  $DefaultBackgroundColor = (Get-Host).UI.RawUI.BackgroundColor

  $WindowSize = (Get-Host).UI.RawUI.WindowSize

  Menu ([string]$Header,[MenuItem[]]$Items,[string]$Mode) {
    $this.Header = $Header
    $this.Items = $Items | Sort-Object -Property @{ Expression = "Order"; Descending = $false },@{ Expression = "Label"; Descending = $false }
    $this.Mode = $Mode
  }

  hidden Init (
    [string]$Header,
    [MenuItem[]]$Items,
    [string]$Mode
  ) {
    $this.Items = $Items
    $this.Header = $Header
    $this.Mode = $Mode
  }

  hidden [MenuItem] GetCurrentItem () {
    return $this.Items[$this.CurrentIndex];
  }

  hidden [bool] ProcessInput ($keyPress) {

    switch ($keyPress.Key) {
      $([ConsoleKey]::DownArrow) {
        $this.CurrentIndex++
        if($this.CurrentIndex -gt $this.ScrollTop + $this.MaxHeight) {
          $this.ScrollTop++
        }
      }
      $([ConsoleKey]::PageDown) {
        $this.CurrentIndex += $this.MaxHeight
        $this.ScrollTop += $this.MaxHeight
      }
      $([ConsoleKey]::UpArrow) {
        $this.CurrentIndex--
        if($this.CurrentIndex -lt $this.ScrollTop) {
          $this.ScrollTop--
        }
      }
      $([ConsoleKey]::PageUp) {
        $this.CurrentIndex -= $this.MaxHeight
        $this.ScrollTop -= $this.MaxHeight
      }
      $([ConsoleKey]::Spacebar) {
        if ($this.Mode -eq 'Multi') {
          $CurrentItem = $this.GetCurrentItem()
          if (-not $CurrentItem.ReadOnly) {
            $CurrentItem.Selected = !$CurrentItem.Selected;
          }
          $this.SelectionChanged = $True
        } else {
          return $true
        }
      }
      $([ConsoleKey]::Enter) {
        return $true
      }
      $([ConsoleKey]::Escape) {
        exit
      }
      Default {}
    }

    if ($this.CurrentIndex -gt $this.Items.Count - 1) {
      $this.CurrentIndex = $this.Items.Count - 1;
      $this.ScrollTop = $this.Items.Count - 1 - $this.MaxHeight;
    }
    if ($this.CurrentIndex -lt 0) {
      $this.CurrentIndex = 0;
      $this.ScrollTop = 0;
    }

    return $false
  }

  hidden ScrollingCalculations () {

    $this.MaxHeight = $this.WindowSize.Height - ($this.Header | Measure-Object -Line).Lines - 6

    if ($this.MaxHeight -lt 1) {
      $this.MaxHeight = 1
    }

    if($this.MaxHeight -gt $this.Items.Count - 1) {
      $this.MaxHeight = $this.Items.Count - 1
    }

    if($this.ScrollTop -gt $this.CurrentIndex -or ($this.ScrollTop + $this.MaxHeight) -lt $this.CurrentIndex) {
      $this.ScrollTop = $this.CurrentIndex
    }

    if($this.ScrollTop -lt 0) {
      $this.ScrollTop = 0
    }

    if($this.ScrollTop -gt $this.Items.Count - 1 - $this.MaxHeight) {
      $this.ScrollTop = $this.Items.Count - 1 - $this.MaxHeight
    }

    $this.ScrollBottom = $this.ScrollTop + $this.MaxHeight

    if($this.ScrollBottom -lt 0) {
      $this.ScrollBottom = 0
    }

    if($this.ScrollBottom -gt $this.Items.Count - 1) {
      $this.ScrollBottom = $this.Items.Count - 1
    }

  }

  hidden DrawMenuItem ([MenuItem]$MenuItem, [switch]$CurrentItem) {

    $ForegroundColor = $this.DefaultForegroundColor
    $BackgroundColor = $this.DefaultBackgroundColor

    $Dependency = ($MenuItem.Value -in $this.DependencyList)
    $Selected = ($MenuItem.Selected)
    $ReadOnly = ($MenuItem.ReadOnly)

    $Prefix = " "

    if ($this.Mode -eq "Multi") {
      if ($Selected) {
        $Prefix = "[X]"
      } elseif ($Dependency) {
        $Prefix = "[*]"
      } else {
        $Prefix = "[ ]"
      }
    } else {
      if ($CurrentItem) {
        $Prefix = ">"
      }
    }

    $ItemString = "$Prefix $($MenuItem.Label)"

    if ($ItemString.length -gt $this.WindowSize.Width) {
      $ItemString = $ItemString.Substring(0,($this.WindowSize.Width - 3)) + '...'
    }

    if ($CurrentItem) {
      $BackgroundColor = [ConsoleColor]::DarkRed
    }

    if ($this.Mode -eq "Multi") {
      if ($Selected) {
        $ForegroundColor = [ConsoleColor]::Green
      } elseif ($Dependency) {
        $ForegroundColor = [ConsoleColor]::DarkYellow
      } elseif ($ReadOnly) {
        $ForegroundColor = [ConsoleColor]::DarkGray
      } 
    }

    Write-Host $ItemString -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
  }

  hidden Draw () {

    $HeaderColor = [ConsoleColor]::Magenta

    Write-Host $this.Header -ForegroundColor $HeaderColor
    Write-Host

    if ($this.ScrollTop -gt 0) {
      Write-Host (" {0} More {0} " -f [char]9650) -ForegroundColor Yellow
    } else {
      Write-Host
    }

    for ($i = $this.ScrollTop; $i -le $this.ScrollBottom; $i++) {
      $this.DrawMenuItem($this.Items[$i], ($i -eq $this.CurrentIndex))
    }

    if ($this.ScrollBottom -lt ($this.Items.Count - 1)) {
      Write-Host (" {0} More {0} " -f [char]9660) -ForegroundColor Yellow
    } else {
      Write-Host
    }

    if ($this.Mode -eq "Multi") {
      Write-Host -NoNewline "[SPACE]" -ForegroundColor Magenta
      Write-Host -NoNewline ":Select "
      Write-Host -NoNewline "[ENTER]" -ForegroundColor Magenta
      Write-Host -NoNewline ":Confirm "
    } else {
      Write-Host -NoNewline "[SPACE]/[ENTER]" -ForegroundColor Magenta
      Write-Host -NoNewline ":Confirm "
    }

    Write-Host -NoNewline "[ESC]" -ForegroundColor Magenta
    Write-Host ":Exit"

  }

  [object[]] GetSelectedItems () {
    if ($this.Mode -eq 'Multi') {
      $this.SelectedItems = @()
      foreach ($Item in $this.Items) {
        if ($Item.Selected) {
          $this.SelectedItems += $Item.Value
        }
      }
    } else {
      $this.SelectedItems = $this.Items[$this.CurrentIndex].Value
    }

    return $this.SelectedItems
  }

  [void] CalcDependencies () {
    $this.DependencyList = @()
    $this.Items | ForEach-Object {
      if ($_.Selected -and $_.Depends) {
        $_.Depends | ForEach-Object {
          $this.DependencyList += $_
        }
      }
    }

    $DepPasses = 0
    do {
      $Continue = $False

      foreach ($Dependency in $this.DependencyList) {
        $NewDeps = ($this.Items | Where-Object { $_.Value -eq $Dependency }).Depends
        foreach ($Dep in $NewDeps) {
          if ($Dep -notin $this.DependencyList) {
            $Continue = $True
            $this.DependencyList += $Dep
          }
        }
      }
      $DepPasses++
    } while ($Continue -and $DepPasses -lt $this.Items.Count)
  }

  [object[]] GetSelections () {

    [System.Console]::CursorVisible = $False

    $Finished = $False

    do {
      
      $this.WindowSize = (Get-Host).UI.RawUI.WindowSize

      if($this.SelectionChanged) {
        $this.CalcDependencies()
      }
      
      $this.ScrollingCalculations()
      
      Clear-Host

      $this.Draw()

      $this.SelectionChanged = $False
      $Finished = $this.ProcessInput([Console]::ReadKey("NoEcho,IncludeKeyDown"))
    } while (-not $Finished)

    [System.Console]::CursorVisible = $True

    Clear-Host

    return $this.GetSelectedItems()
  }
}

function Get-MenuItem {
  param(
    [Parameter(Mandatory)] [string]$Label,
    [Parameter(Mandatory)] [string]$Value,
    [switch]$Selected,
    [string]$Info = "",
    [int]$Order = 0,
    [switch]$ReadOnly,
    [string[]]$Depends = @()

  )
  [MenuItem]::new($Label,$Value,$Selected.IsPresent,$Info,$Order,$ReadOnly.IsPresent,$Depends)
}

function Get-MenuSelection {
  param(
    [Parameter(Mandatory)] [string]$Header,
    [Parameter(Mandatory)] [object[]]$Items,
    [ValidateSet("Single","Multi")] $Mode
  )
  $menu = [Menu]::new($Header,$Items,$Mode)
  return $menu.GetSelections()
}

function Get-MenuConfirmation {
  param(
    [Parameter(Mandatory)] [string]$Header
  )

  $ConfirmMenuItems = @(
    Get-MenuItem `
       -Label "Yes" `
       -Value "Yes" `
       -Order 0 `
       -Selected
    Get-MenuItem `
       -Label "No" `
       -Value "No" `
       -Order 1
    )

    $Result = Get-MenuSelection -Header $Header -Items $ConfirmMenuItems -Mode Single

    if($Result -contains "Yes") {
      return $true
    }

    return $False
}