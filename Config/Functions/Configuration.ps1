class CSConfig {
    [object]$Config = @{}
    [string]$Path = ".\config.json"
    [string]$Version

    CSConfig (
        [object]$Config, 
        [string]$Path,
        [string]$Version
    ) {
        $this.Init($Config,$Path,$Version);
    }

    hidden Init (
        [object]$Config, 
        [string]$Path,
        [string]$Version
    ) {
        $this.Config = $Config
        $this.Path = $Path
        $this.Version = $Version
    }

    [void] Import () {
        if (Test-Path $this.Path) {
            try {
                $this.Config = Get-Content -Path $this.Path | ConvertFrom-Json
                Write-Host "Configuration imported from $($this.Path)"
            } catch {
                Write-Error "Error importing configuration found at $($this.Path). $_"
            }
        } else {
            Write-Error "Configuration not found at $($this.Path)"
        }
    }

    [void] Export () {
        try {
            $this.SetProperty("Version", $this.Version)
            $this.Config | ConvertTo-Json | Set-Content -Path $this.Path -Encoding UTF8
        } catch {
            Write-Error "Error exporting configuration to $($this.Path). $_"
        }
    }

    [void] SetProperty ([string]$Name, $Value) {
        $this.Config | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    }

    [object] GetProperty ([string]$Name) {
        $PropValue = $null

        if($this.Config.PSObject.Properties.Name -match $Name) {
            $PropValue = $this.Config.$Name
        }

        return @{
            "Value" = $PropValue
        }
    }

    [bool] IsTrue ([string]$Name) {
        if($this.Config.PSObject.Properties.Name -match $Name) {
            if($this.Config.$Name) {
                return $True
            }
        }
        return $False
    }
}

function New-CSConfig {
    param(
        [object]$Config = @{}, 
        [string]$Path = ".\config.json",
        [string]$Version
    )

    return [CSConfig]::New($Config, $Path, $Version)
}

class WSConfig {
    [xml]$XML = @"
    <Configuration>
        <VGpu>Disable</VGpu>
        <Networking>Disable</Networking>
        <ProtectedClient>Disable</ProtectedClient>
        <MappedFolders>
            <MappedFolder>
                <HostFolder></HostFolder>
                <SandboxFolder></SandboxFolder>
                <ReadOnly>true</ReadOnly>
            </MappedFolder>
        </MappedFolders>
        <ClipboardRedirection>Disable</ClipboardRedirection>
        <PrinterRedirection>Disable</PrinterRedirection>
        <AudioInput>Disable</AudioInput>
        <VideoInput>Disable</VideoInput>
        <MemoryInMB>4096</MemoryInMB>
        <LogonCommand>
            <Command></Command>
        </LogonCommand>
    </Configuration>
"@
    [string]$Path = ".\WindowsSandbox.wsb"

    WSConfig (
        [string]$Path
    ) {
        $this.Init($Path);
    }

    hidden Init (
        [string]$Path
    ) {
        $this.Path = $Path
    }

    [void] Export () {
        try {
            $this.XML.Save($this.Path)
        } catch {
            Write-Error "Error exporting Windows Sandbox configuration to $($this.Path). $_"
        }
    }

    [void] SetPropertyToggle([string]$Name, [switch]$Enabled) {
        if($Enabled) {
            $this.XML.Configuration.$Name = "Enable"
        } else {
            $this.XML.Configuration.$Name = "Disable"
        }
    }

    [void] SetHostFolder ([string]$Value) {
        $this.XML.Configuration.MappedFolders.MappedFolder.HostFolder = $Value
    }

    [void] SetSandboxFolder ([string]$Value) {
        $this.XML.Configuration.MappedFolders.MappedFolder.SandboxFolder = $Value
    }

    [void] SetMemoryInMB ([string]$Value) {
        $this.XML.Configuration.MemoryInMB = $Value
    }

    [void] SetLogonCommand ([string]$Value) {
        $this.XML.Configuration.LogonCommand.Command = $Value
    }
}

function New-WSConfig {
    param( 
        [string]$Path = ".\WindowsSandbox.wsb"
    )

    return [WSConfig]::New($Path)
}