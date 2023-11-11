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
  hidden [int]$maxHeight = 10

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
        if ($this.CurrentIndex -ge $this.Items.length) {
          $this.CurrentIndex = $this.Items.length - 1;
        }
      }
      $([ConsoleKey]::PageDown) {
        $this.CurrentIndex += $this.maxHeight
        if ($this.CurrentIndex -ge $this.Items.length) {
          $this.CurrentIndex = $this.Items.length - 1;
        }
      }
      $([ConsoleKey]::UpArrow) {
        $this.CurrentIndex --
        if ($this.CurrentIndex -lt 0) {
          $this.CurrentIndex = 0;
        }
      }
      $([ConsoleKey]::PageUp) {
        $this.CurrentIndex -= $this.maxHeight
        if ($this.CurrentIndex -lt 0) {
          $this.CurrentIndex = 0;
        }
      }
      $([ConsoleKey]::Spacebar) {
        if ($this.Mode -eq 'Multi') {
          $CurrentItem = $this.GetCurrentItem()
          if (-not ($CurrentItem.ReadOnly -or $CurrentItem.Value -in $this.DependencyList)) {
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
      Default {

      }
    }
    return $false
  }

  hidden Draw () {
    $DefaultForegroundColor = (Get-Host).UI.RawUI.ForegroundColor
    $DefaultBackgroundColor = (Get-Host).UI.RawUI.BackgroundColor

    $HeaderColor = [ConsoleColor]::Magenta

    $WindowSize = (Get-Host).UI.RawUI.WindowSize

    $this.maxHeight = $WindowSize.Height - ($this.Header | Measure-Object -Line).Lines - 6
    if ($this.maxHeight -lt 1) {
      $this.maxHeight = 1
    }

    Write-Host $this.Header -ForegroundColor $HeaderColor
    Write-Host

    if ($this.CurrentIndex -gt $this.maxHeight) {
      Write-Host (" {0} More {0} " -f [char]9650) -ForegroundColor Yellow
    } else {
      Write-Host
    }

    $ShowMore = $False

    for ($i = 0; $i -lt $this.Items.Count; $i++) {

      $ForegroundColor = $DefaultForegroundColor
      $BackgroundColor = $DefaultBackgroundColor

      if ($this.CurrentIndex -gt $this.maxHeight) {
        if ($i -lt ($this.CurrentIndex - $this.maxHeight)) {
          continue;
        }

        if ($i -gt $this.CurrentIndex) {
          $ShowMore = $True
          continue;
        }
      } else {
        if ($i -gt $this.maxHeight) {
          $ShowMore = $True
          continue;
        }
      }

      $CurrentItem = ($i -eq $this.CurrentIndex)
      $Dependency = ($this.Items[$i].Value -in $this.DependencyList)
      $Selected = ($this.Items[$i].Selected)
      $ReadOnly = ($this.Items[$i].ReadOnly)

      $Prefix = " "

      if ($this.Mode -eq "Multi") {
        if ($Dependency) {
          $Prefix = "[*]"
        } elseif ($Selected) {
          $Prefix = "[X]"
        } else {
          $Prefix = "[ ]"
        }
      } else {
        if ($CurrentItem) {
          $Prefix = ">"
        }
      }

      $ItemString = "$Prefix $($this.Items[$i].Label)"

      if ($ItemString.length -gt $WindowSize.Width) {
        $ItemString = $ItemString.Substring(0,($WindowSize.Width - 3)) + '...'
      }

      if ($CurrentItem) {
        $BackgroundColor = [ConsoleColor]::DarkRed
      }

      if ($this.Mode -eq "Multi" -and ($ReadOnly)) {
        $ForegroundColor = [ConsoleColor]::DarkGray
      }

      if ($this.Mode -eq "Multi" -and ($Dependency)) {
        $ForegroundColor = [ConsoleColor]::DarkYellow
      }

      Write-Host $ItemString -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor

    }

    if ($ShowMore) {
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
      if($this.SelectionChanged) {
        $this.CalcDependencies()
      }

      Clear-Host

      $this.Draw()

      $this.SelectionChanged = $False
      $Finished = $this.ProcessInput([Console]::ReadKey("NoEcho,IncludeKeyDown"))
    } while (-not $Finished)

    [System.Console]::CursorVisible = $True



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
