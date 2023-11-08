class CustomSandboxTask {
    [ValidateNotNullOrEmpty()][string]$ID
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateSet("preconfig","postconfig","config")]$Type = "config"
    [string[]]$Dependencies = @()
    [string[]]$Requirements = @()
    [string]$Script = ""
    [object[]]$Vars = @{}

    CustomSandboxTask([string]$ID, [string]$Name, [string]$Type, [string[]]$Dependencies,  [string[]]$Requirements, [string]$Script, [object]$Vars) {
        $this.Init($ID, $Name, $Type, $Dependencies, $Requirements, $Script, $Vars);
    }

    hidden Init(
        [string]$ID, 
        [string]$Name,          
        [string]$Type, 
        [string[]]$Dependencies, 
        [string[]]$Requirements, 
        [string]$Script,
        [object]$Vars
    ) {
        $this.ID = $ID
        $this.Name = $Name
        $this.Type = $Type
        $this.Dependencies = $Dependencies
        $this.Requirements = $Requirements
        $this.Script = $Script
        $this.Vars = $Vars
    }

    [void] ExecuteAction(
        [string]$Action,
        [switch]$ForceCache
    ) {
        & "$($this.Script)" -Action $Action -ForceCache:$ForceCache -Vars $this.Vars
    }
}

class CustomSandboxTaskCollection {
    [CustomSandboxTask[]]$Tasks

    CustomSandboxTask(){}

    [void] Add([CustomSandboxTask]$Task) {
        $this.Tasks += $Task
    }

    [void] LoadFromDirectory([string]$Path) {
        if(!(Test-Path $Path)) {
            Write-Error "Directory not found"
            return
        }

        $TaskFiles = Get-ChildItem -Path $Path -Include "*.json" -File -Recurse

        foreach($TaskFile in $TaskFiles) {
            $TaskJson = Get-Content -Path $TaskFile.FullName | ConvertFrom-Json
            $ScriptPath = Join-Path $TaskFile.Directory $TaskJson.script

            if(!(Test-Path $ScriptPath)) {
                Write-Error "Script File $ScriptPath referenced in $TaskFile not found."
                break;
            }

            $this.Add(
                [CustomSandboxTask]::New(
                    $TaskJson.id, 
                    $TaskJson.name, 
                    $TaskJson.type, 
                    $TaskJson.dependencies, 
                    $TaskJson.requirements, 
                    $ScriptPath, 
                    $TaskJson.vars
                )
            )
        }
    }
}

function New-CustomSandboxTaskCollection {
    param(
        [string]$Path
    )

    $TaskCollection = [CustomSandboxTaskCollection]::New()
    $TaskCollection.LoadFromDirectory($Path)

    return $TaskCollection
}

function New-CustomSandboxTask {
    param(
        [ValidateNotNullOrEmpty()][string]$ID,
        [ValidateNotNullOrEmpty()][string]$Name,      
        [ValidateSet("preconfig","postconfig","config")]$Type = "config",
        [string[]]$Dependencies = @(),
        [string[]]$Requirements = @(),
        [string]$Script,
        [object[]]$Vars = @{}
    )

    return [CustomSandboxTask]::New($ID, $Name, $Type, $Dependencies, $Requirements, $Script, $Vars)
}