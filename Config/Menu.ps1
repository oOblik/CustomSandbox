#Requires -Version 5

Class MenuItem {
    [ValidateNotNullOrEmpty()][string]$Label
    [ValidateNotNullOrEmpty()][string]$Value
    [switch]$Selected
    [string]$Info
    [int]$Order
    [switch]$ReadOnly
    [object]$Depends

    MenuItem([string]$Label, [string]$Value, [switch]$Selected, [string]$Info, [int]$Order, [switch]$ReadOnly, [object]$Depends) {
        $this.Init($Label, $Value, $Selected, $Info, $Order, $ReadOnly, $Depends);
    }

    hidden Init(
        [string]$Label,
        [string]$Value, 
        [switch]$Selected,
        [string]$Info,
        [int]$Order,
        [switch]$ReadOnly,
        [object]$Depends
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
    hidden [int]$CurrentIndex = 0

    Menu([string]$Header, [MenuItem[]]$Items, [string]$Mode) {
        $this.Header = $Header
        $this.Items = $Items | Sort-Object { $_.Label } | Sort-Object { $_.Order }
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
            $([ConsoleKey]::UpArrow) {
                $this.CurrentIndex--
                if ($this.CurrentIndex -lt 0) {
                    $this.CurrentIndex = 0;
                }
            }
            $([ConsoleKey]::Spacebar) {
                if($this.Mode -eq 'Multi') {
                    $CurrentItem = $this.GetCurrentItem()
                    if (-not $CurrentItem.Readonly) {
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
                return $true
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
        $maxHeight = $WindowSize.Height - 8

        Write-Host $this.Header -ForegroundColor $HeaderColor
        Write-Host

        if($this.CurrentIndex -gt $maxHeight) {
            Write-Host (" {0} More {0} " -f [char]9650) -ForegroundColor Yellow
        } else {
            Write-Host
        }

        $ShowMore = $False

        for($i = 0; $i -lt $this.Items.count; $i++) {

            if($this.CurrentIndex -gt $maxHeight) {
                if($i -lt ($this.CurrentIndex - $maxHeight)) {
                    continue;
                }

                if($i -gt $this.CurrentIndex) {
                    $ShowMore = $True
                    continue;
                }
            } else {
                if($i -gt $maxHeight) {
                    $ShowMore = $True
                    continue;
                }
            }

            $CurrentItem = ($i -eq $this.CurrentIndex)
            $Selected = ($this.Items[$i].Selected)
            $ReadOnly = ($this.Items[$i].ReadOnly)

            if($CurrentItem) {
                (Get-Host).UI.RawUI.BackgroundColor = [ConsoleColor]::DarkGreen
            }

            if($this.Mode -eq "Multi" -and $ReadOnly) {
                (Get-Host).UI.RawUI.ForegroundColor = [ConsoleColor]::DarkGray
            }

            $Prefix = " "

            if($this.Mode -eq "Multi") {
                if($Selected) {
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

            Write-Host $ItemString

            (Get-Host).UI.RawUI.ForegroundColor = $DefaultForegroundColor
            (Get-Host).UI.RawUI.BackgroundColor = $DefaultBackgroundColor
        }

        if($ShowMore) {
            Write-Host (" {0} More {0} " -f [char]9660) -ForegroundColor Yellow
        } else {
            Write-Host
        }

        Write-Host

    }

    [object[]] GetSelectedItems() {
        if($this.Mode -eq 'Multi') {
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

    [object[]] GetSelections() {
        
        [System.Console]::CursorVisible = $False

        $Finished = $False

        do {
            Clear-Host
            
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
        [array]$Depends = @()
        
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