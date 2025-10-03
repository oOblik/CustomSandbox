#Requires -Version 5

class MenuItem{
  [ValidateNotNullOrEmpty()] [string]$Label
  [ValidateNotNullOrEmpty()] [string]$Value
  [switch]$Selected
  [string]$Info
  [int]$Order
  [switch]$ReadOnly
  [switch]$Disabled
  [string[]]$Depends
  [string[]]$Requirements

  MenuItem ([string]$Label,[string]$Value,[switch]$Selected,[string]$Info,[int]$Order,[switch]$ReadOnly,[switch]$Disabled,[string[]]$Depends,[string[]]$Requirements) {
    $this.Init($Label,$Value,$Selected,$Info,$Order,$ReadOnly,$Disabled,$Depends,$Requirements);
  }

  hidden Init (
    [string]$Label,
    [string]$Value,
    [switch]$Selected,
    [string]$Info,
    [int]$Order,
    [switch]$ReadOnly,
    [switch]$Disabled,
    [string[]]$Depends,
    [string[]]$Requirements
  ) {
    $this.Label = $Label
    $this.Value = $Value
    $this.Selected = $Selected
    $this.Info = $Info
    $this.Order = $Order
    $this.ReadOnly = $ReadOnly
    $this.Disabled = $Disabled
    $this.Depends = $Depends
    $this.Requirements = $Requirements
  }

  [int] length () {
    return $this.Label.length
  }
}

class Menu{
  [string]$Title = $null
  [string]$Subtitle  = $null
  [string]$Prompt  = $null
  [ValidateNotNullOrEmpty()] [MenuItem[]]$Items
  [ValidateNotNullOrEmpty()] [string]$Mode

  hidden [object[]]$SelectedItems = @()
  hidden [string[]]$DependencyList = @()
  hidden [int]$CurrentIndex = 0
  hidden [bool]$SelectionChanged = $True
  hidden [int]$MaxHeight = 10
  hidden [int]$ScrollTop = 0
  hidden [int]$ScrollBottom = 0
  hidden [char[]]$ScrollBarBuffer
  hidden [bool]$ShowScroll = $false
  hidden [int]$IndexState = !$CurrentIndex


  $TitleColor = [ConsoleColor]::Magenta
  $SubtitleColor = [ConsoleColor]::Gray
  $PromptColor = [ConsoleColor]::White

  $InfoTextColor = [ConsoleColor]::Magenta

  $HighlightColor = [ConsoleColor]::DarkRed
  $SelectedColor = [ConsoleColor]::Green
  $DependencyColor = [ConsoleColor]::DarkYellow
  $ReadOnlyColor = [ConsoleColor]::DarkGray
  $DisabledColor = [ConsoleColor]::DarkMagenta

  $ScrollArrowColor = [ConsoleColor]::Yellow

  $DefaultForegroundColor = (Get-Host).UI.RawUI.ForegroundColor
  $DefaultBackgroundColor = (Get-Host).UI.RawUI.BackgroundColor

  $WindowSize = (Get-Host).UI.RawUI.WindowSize

  Menu ([string]$Title,[string]$Subtitle,[string]$Prompt,[MenuItem[]]$Items,[string]$Mode) {
    $this.Init($Title,$Subtitle,$Prompt,$Items,$Mode)
  }

  hidden Init (
    [string]$Title = $null,
    [string]$Subtitle = $null,
    [string]$Prompt = $null,
    [MenuItem[]]$Items,
    [string]$Mode
  ) {
    $this.Title = $Title
    $this.Subtitle = $Subtitle
    $this.Prompt = $Prompt
    $this.Items = $Items | Sort-Object -Property @{ Expression = "Order"; Descending = $false },@{ Expression = "Label"; Descending = $false }
    $this.Mode = $Mode
    $this.ScrollBarBuffer = [char[]]::New($Items.Count)
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
        break;
      }
      $([ConsoleKey]::PageDown) {
        $this.CurrentIndex += $this.MaxHeight
        $this.ScrollTop += $this.MaxHeight
        break;
      }
      $([ConsoleKey]::UpArrow) {
        $this.CurrentIndex--
        if($this.CurrentIndex -lt $this.ScrollTop) {
          $this.ScrollTop--
        }
        break;
      }
      $([ConsoleKey]::PageUp) {
        $this.CurrentIndex -= $this.MaxHeight
        $this.ScrollTop -= $this.MaxHeight
        break;
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
        break;
      }
      $([ConsoleKey]::Enter) {
        $InvalidItems = $this.Items | Where-Object { (($_.Selected -or ($_.Value -in $this.DependencyList)) -and $_.Disabled) }
        if($InvalidItems.Count -gt 0) {
          Clear-Host
          Write-Host "You have enabled tasks/dependancies that require disabled features:" -ForegroundColor Magenta
          Write-Host
          $InvalidItems | ForEach-Object { 
            $ReqList = $_.Requirements -join ", "
            Write-Host " - $($_.Label): $ReqList" -ForegroundColor Red 
          }
          Write-Host
          Write-Host "Press [SPACE] to Continue" | Out-Null
          $this.ProcessInput([Console]::ReadKey("NoEcho,IncludeKeyDown")) | Out-Null
          return $false
          break;
        }
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

    $HeaderLines = $null
    if($this.Title) {
      $HeaderLines += $this.Title + "`n"
    }
    if($this.Subtitle) {
      $HeaderLines += $this.Subtitle + "`n"
    }
    if($this.Prompt) {
      $HeaderLines += $this.Prompt + "`n"
    }

    $HeaderLines = $HeaderLines.Trim()

    $this.MaxHeight = $this.WindowSize.Height - ($HeaderLines | Measure-Object -Line).Lines - 6
    $ItemCount = $this.Items.Count - 1

    if ($this.MaxHeight -lt 1) {
      $this.MaxHeight = 1
    }

    if ($this.MaxHeight -gt $ItemCount) {
      $this.MaxHeight = $ItemCount
    }

    if ($this.ScrollTop -gt $this.CurrentIndex -or ($this.ScrollTop + $this.MaxHeight) -lt $this.CurrentIndex) {
      $this.ScrollTop = $this.CurrentIndex
    }

    if ($this.ScrollTop -lt 0) {
      $this.ScrollTop = 0
    }

    if ($this.ScrollTop -gt $ItemCount - $this.MaxHeight) {
      $this.ScrollTop = $ItemCount - $this.MaxHeight
    }

    $this.ScrollBottom = $this.ScrollTop + $this.MaxHeight

    if ($this.ScrollBottom -lt 0) {
      $this.ScrollBottom = 0
    }

    if ($this.ScrollBottom -gt $ItemCount) {
      $this.ScrollBottom = $ItemCount
    }

    $ListHeight = $this.MaxHeight + 1
    $ScrollRatio = $ListHeight / $ItemCount
    $this.ShowScroll = (($this.MaxHeight / $ItemCount) -lt 1)

    if ($this.ShowScroll) {
      $ScrollOffset = $this.ScrollTop * $ScrollRatio
      $ScrollCap = $ScrollOffset + ($ScrollRatio * $ListHeight)

      for ($x=0; $x -lt $ScrollOffset; $x++) {
        $this.ScrollBarBuffer[$x] = [char]9474
      }
      for ($x=$ScrollOffset; $x -lt $ScrollCap; $x++) {
        $this.ScrollBarBuffer[$x] = [char]9608
      }
      for ($x=$ScrollCap; $x -lt $ListHeight; $x++) {
        $this.ScrollBarBuffer[$x] = [char]9474
      }
    }
    
  }

  hidden DrawMenuItem ([MenuItem]$MenuItem, [switch]$CurrentItem, [int]$VisibleIndex) {

    $ForegroundColor = $this.DefaultForegroundColor
    $BackgroundColor = $this.DefaultBackgroundColor

    $Dependency = ($MenuItem.Value -in $this.DependencyList)
    $Selected = ($MenuItem.Selected)
    $ReadOnly = ($MenuItem.ReadOnly)
    $Disabled = ($MenuItem.Disabled)

    if ($this.ShowScroll) {
      Write-Host "$($this.ScrollBarBuffer[$VisibleIndex]) " -NoNewline
    } else {
      Write-Host "  " -NoNewline
    }

    $Prefix = " "
    $Suffix = ""

    if ($this.Mode -eq "Multi") {
      if ($Selected) {
        $Prefix = "[X]"
        $ForegroundColor = $this.SelectedColor
      } elseif ($Dependency) {
        $Prefix = "[*]"
        $ForegroundColor = $this.DependencyColor
      } else {
        $Prefix = "[ ]"
      }
      if($ReadOnly) {
        $ForegroundColor = $this.ReadOnlyColor
      }
      if($Disabled -and ($Selected -or $Dependency)) {
        if($Selected) {
          $Prefix = "[!]"
        }
        if($Dependency) {
          $Prefix = "[#]"
        }
        $ForegroundColor = $this.DisabledColor
        $Requires = $MenuItem.Requirements -Join ", "
        $Suffix = " (Requires $Requires)"
      }
      if($CurrentItem) {
        $Prefix = ">$Prefix<"
      } else {
        $Prefix = " $Prefix "
      }
    } else {
      if ($CurrentItem) {
        $Prefix = ">"
      }
    }

    $ItemString = "$Prefix $($MenuItem.Label)$Suffix"

    if ($ItemString.length -gt ($this.WindowSize.Width-2)) {
      $ItemString = $ItemString.Substring(0,($this.WindowSize.Width - 5)) + '...'
    }

    if ($CurrentItem) {
      $BackgroundColor = $this.HighlightColor
    }

    Write-Host $ItemString -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
  }

  hidden Draw () {

    if($this.Title) {
      Write-Host $this.Title -ForegroundColor $this.TitleColor
    }
    if($this.Subtitle) {
      Write-Host $this.Subtitle -ForegroundColor $this.SubtitleColor
    }
    if($this.Prompt) {
      Write-Host
      Write-Host $this.Prompt -ForegroundColor $this.PromptColor
    }

    if ($this.ShowScroll) {
      Write-Host ("{0}" -f [char]9650) -ForegroundColor $this.ScrollArrowColor
    } else {
      Write-Host
    }

    $VisibleIndex = 0
    for ($Index = $this.ScrollTop; $Index -le $this.ScrollBottom; $Index++) {
      $this.DrawMenuItem($this.Items[$Index], ($Index -eq $this.CurrentIndex), $VisibleIndex)
      $VisibleIndex++
    }

    if ($this.ShowScroll) {
      Write-Host ("{0}" -f [char]9660) -ForegroundColor $this.ScrollArrowColor
    } else {
      Write-Host
    }

    if ($this.Mode -eq "Multi") {
      Write-Host -NoNewline "[SPACE]" -ForegroundColor $this.InfoTextColor
      Write-Host -NoNewline ":Select "
      Write-Host -NoNewline "[ENTER]" -ForegroundColor $this.InfoTextColor
      Write-Host -NoNewline ":Confirm "
    } else {
      Write-Host -NoNewline "[SPACE]/[ENTER]" -ForegroundColor $this.InfoTextColor
      Write-Host -NoNewline ":Confirm "
    }

    Write-Host -NoNewline "[ESC]" -ForegroundColor $this.InfoTextColor
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
      
      if ($this.CurrentIndex -ne $this.IndexState -or $this.SelectionChanged) {
        $this.IndexState = $this.CurrentIndex

        $this.WindowSize = (Get-Host).UI.RawUI.WindowSize

        if ($this.SelectionChanged) {
          $this.CalcDependencies()
        }
        
        $this.ScrollingCalculations()

        Clear-Host

        $this.Draw()

      }

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
    [switch]$Disabled,
    [string[]]$Depends = @(),
    [string[]]$Requirements = @()

  )
  [MenuItem]::New($Label,$Value,$Selected.IsPresent,$Info,$Order,$ReadOnly.IsPresent,$Disabled.IsPresent,$Depends,$Requirements)
}

function Get-MenuSelection {
  param(
    [string]$Title = $null,
    [string]$Subtitle = $null,
    [string]$Prompt = $null,
    [Parameter(Mandatory)] [object[]]$Items,
    [ValidateSet("Single","Multi")] $Mode
  )
  $menu = [Menu]::New($Title,$Subtitle,$Prompt,$Items,$Mode)
  return $menu.GetSelections()
}

function Get-MenuConfirmation {
  param(
    [string]$Prompt
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

    $Result = Get-MenuSelection -Prompt $Prompt -Items $ConfirmMenuItems -Mode Single

    if($Result -contains "Yes") {
      return $True
    }

    return $False
}