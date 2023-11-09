#Requires -Version 5

Class MenuItem {
    [ValidateNotNullOrEmpty()][string]$Label
    [ValidateNotNullOrEmpty()][string]$Value
    [switch]$Selected
    [string]$Info
    [int]$Order
    [switch]$ReadOnly
    [string[]]$Depends

    MenuItem([string]$Label, [string]$Value, [switch]$Selected, [string]$Info, [int]$Order, [switch]$ReadOnly, [string[]]$Depends) {
        $this.Init($Label, $Value, $Selected, $Info, $Order, $ReadOnly, $Depends);
    }

    hidden Init(
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

    [int] length() {
        return  $this.Label.length
    }
}

Class Menu {
    [ValidateNotNullOrEmpty()][string]$Header
    [ValidateNotNullOrEmpty()][MenuItem[]]$Items
    [ValidateNotNullOrEmpty()][string]$Mode

    hidden [object[]]$SelectedItems = @()
    hidden [string[]]$DependencyList = @()
    hidden [int]$CurrentIndex = 0
    hidden [int]$maxHeight = 10

    Menu([string]$Header, [MenuItem[]]$Items, [string]$Mode) {
        $this.Header = $Header
        $this.Items = $Items | Sort-Object -Property @{Expression = "Order"; Descending = $false}, @{Expression = "Label"; Descending = $false}
        $this.Mode = $Mode
    }

    hidden Init(
        [string]$Header,
        [MenuItem[]]$Items,
        [string]$Mode
    ) {
        $this.Items = $Items
        $this.Header = $Header
        $this.Mode = $Mode
    }

    hidden [MenuItem] GetCurrentItem() {
        return $this.Items[$this.CurrentIndex];
    }

    hidden [bool] ProcessInput($keyPress) {
        switch ($keyPress.Key) {
            $([ConsoleKey]::DownArrow) {
                $this.CurrentIndex++
                if ($this.CurrentIndex -ge $this.Items.Length) {
                    $this.CurrentIndex = $this.Items.Length -1;
                }
            }
            $([ConsoleKey]::PageDown) {
                $this.CurrentIndex+=$this.maxHeight
                if ($this.CurrentIndex -ge $this.Items.Length) {
                    $this.CurrentIndex = $this.Items.Length -1;
                }
            }
            $([ConsoleKey]::UpArrow) {
                $this.CurrentIndex--
                if ($this.CurrentIndex -lt 0) {
                    $this.CurrentIndex = 0;
                }
            }
            $([ConsoleKey]::PageUp) {
                $this.CurrentIndex-=$this.maxHeight
                if ($this.CurrentIndex -lt 0) {
                    $this.CurrentIndex = 0;
                }
            }
            $([ConsoleKey]::Spacebar) {
                if($this.Mode -eq 'Multi') {
                    $CurrentItem = $this.GetCurrentItem()
                    if (-not ($CurrentItem.Readonly -or $CurrentItem.Value -in $this.DependencyList)) {
                        $CurrentItem.Selected=!$CurrentItem.Selected;
                    }
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

    hidden Draw() {
        $DefaultForegroundColor = (Get-Host).UI.RawUI.ForegroundColor
        $DefaultBackgroundColor = (Get-Host).UI.RawUI.BackgroundColor

        $HeaderColor = [ConsoleColor]::Magenta

        $WindowSize = (Get-Host).UI.RawUI.WindowSize

        $this.maxHeight = $WindowSize.Height - ($this.Header | Measure-Object -Line).Lines - 6
        if($this.maxHeight -lt 1) {
            $this.maxHeight = 1
        }

        Write-Host $this.Header -ForegroundColor $HeaderColor
        Write-Host

        if($this.CurrentIndex -gt $this.maxHeight) {
            Write-Host (" {0} More {0} " -f [char]9650) -ForegroundColor Yellow
        } else {
            Write-Host
        }

        $ShowMore = $False

        for($i = 0; $i -lt $this.Items.count; $i++) {

            $ForegroundColor = $DefaultForegroundColor
            $BackgroundColor = $DefaultBackgroundColor

            if($this.CurrentIndex -gt $this.maxHeight) {
                if($i -lt ($this.CurrentIndex - $this.maxHeight)) {
                    continue;
                }

                if($i -gt $this.CurrentIndex) {
                    $ShowMore = $True
                    continue;
                }
            } else {
                if($i -gt $this.maxHeight) {
                    $ShowMore = $True
                    continue;
                }
            }

            $CurrentItem = ($i -eq $this.CurrentIndex)
            $Dependency = ($this.Items[$i].Value -in $this.DependencyList)
            $Selected = ($this.Items[$i].Selected)
            $ReadOnly = ($this.Items[$i].ReadOnly)

            $Prefix = " "

            if($this.Mode -eq "Multi") {
                if($Dependency) {
                    $Prefix = "[*]"
                } elseif ($Selected) {
                    $Prefix = "[X]"
                } else {
                    $Prefix = "[ ]"
                }
            } else {
                if($CurrentItem) {
                    $Prefix = ">"
                }
            }

            $ItemString = "$Prefix $($this.Items[$i].Label)"

            if($ItemString.Length -gt $WindowSize.Width) {
                $ItemString = $ItemString.Substring(0,($WindowSize.Width-3)) + '...'
            }

            if($CurrentItem) {
                $BackgroundColor = [ConsoleColor]::DarkGreen
            }

            if($this.Mode -eq "Multi" -and ($ReadOnly -or $Dependency)) {
                $ForegroundColor = [ConsoleColor]::DarkGray
            }

            Write-Host $ItemString -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor

        }

        if($ShowMore) {
            Write-Host (" {0} More {0} " -f [char]9660) -ForegroundColor Yellow
        } else {
            Write-Host
        }

        if($this.Mode -eq "Multi") {
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

    [object[]] GetSelectedItems() {
        if($this.Mode -eq 'Multi') {
            $this.SelectedItems = @()
            foreach ($Item in $this.Items) {
                if ($Item.Selected -or $Item.Value -in $this.DependencyList) {
                    $this.SelectedItems += $Item.Value
                }
            }
        } else {
            $this.SelectedItems = $this.Items[$this.CurrentIndex].Value
        }

        return $this.SelectedItems
    }

    [object[]] GetSelections() {
        
        [System.Console]::CursorVisible = $False

        $Finished = $False

        do {
            Clear-Host
            
            $this.DependencyList = @()
            $this.Items | ForEach-Object {
                if($_.Selected -and $_.Depends) {
                    $this.DependencyList += $_.Depends
                }
            }

            $this.Draw()

            $Finished = $this.ProcessInput([Console]::ReadKey("NoEcho,IncludeKeyDown"))
        } while (-not $Finished)

        [System.Console]::CursorVisible = $True

        

        return $this.GetSelectedItems()
    }
}

function Get-MenuItem {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Value, 
        [switch]$Selected,
        [string]$Info = "",
        [int]$Order = 0,
        [switch]$ReadOnly,
        [string[]]$Depends = @()
        
    )
    [MenuItem]::New($Label, $Value, $Selected.IsPresent, $Info, $Order, $ReadOnly.IsPresent, $Depends)
}

function Get-MenuSelection {
    param(
        [Parameter(Mandatory)][string]$Header,
        [Parameter(Mandatory)][object[]]$Items,
        [ValidateSet("Single","Multi")]$Mode
    )
    $menu = [Menu]::New($Header, $Items, $Mode)
    return $menu.GetSelections()
}