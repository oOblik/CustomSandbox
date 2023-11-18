class CustomSandboxTask{
  [ValidateNotNullOrEmpty()] [string]$ID
  [ValidateNotNullOrEmpty()] [string]$Name
  [ValidateSet("preconfig","postconfig","config")] $Type = "config"
  [string[]]$Dependencies = @()
  [string[]]$Requirements = @()
  [string]$Script = ""
  [object]$Vars = @{}

  CustomSandboxTask ([string]$ID,[string]$Name,[string]$Type,[string[]]$Dependencies,[string[]]$Requirements,[string]$Script,[object]$Vars) {
    $this.Init($ID,$Name,$Type,$Dependencies,$Requirements,$Script,$Vars);
  }

  hidden Init (
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

  [void] ExecuteAction (
    [string]$Action,
    [switch]$ForceCache
  ) {
    & "$($this.Script)" -Action $Action -ForceCache:$ForceCache -Vars $this.Vars
  }
}

function New-CustomSandboxTask {
  param(
    [ValidateNotNullOrEmpty()] [string]$ID,
    [ValidateNotNullOrEmpty()] [string]$Name,
    [ValidateSet("preconfig","postconfig","config")] $Type = "config",
    [string[]]$Dependencies = @(),
    [string[]]$Requirements = @(),
    [string]$Script,
    [object]$Vars = @{}
  )

  return [CustomSandboxTask]::new($ID,$Name,$Type,$Dependencies,$Requirements,$Script,$Vars)
}

class CustomSandboxTaskCollection{
  [CustomSandboxTask[]]$Tasks

  CustomSandboxTask () {}

  [void] Add ([CustomSandboxTask]$Task) {
    $this.Tasks += $Task
  }

  [void] LoadFromDirectory ([string]$Path) {
    if (!(Test-Path $Path)) {
      Write-Error "Directory not found"
      return
    }

    $TaskFiles = Get-ChildItem -Path $Path -Include "*.json" -File -Recurse

    foreach ($TaskFile in $TaskFiles) {
      try {
        $TaskJson = (Get-Content -Path $TaskFile.FullName -Raw) | ConvertFrom-Json
        $ScriptPath = Join-Path $TaskFile.Directory $TaskJson.script

        if (!(Test-Path $ScriptPath)) {
          Write-Error "Script File $ScriptPath referenced in $TaskFile not found."
          break;
        }

        $NewTask = New-CustomSandboxTask `
          -ID $TaskJson.ID `
          -Name $TaskJson.Name `
          -Type $TaskJson.Type `
          -Dependencies $TaskJson.Dependencies `
          -Requirements $TaskJson.Requirements `
          -Script $ScriptPath `
          -Vars $TaskJson.Vars

        $this.Add($NewTask)

      } catch {
        Write-Error "Failed to load task file $($TaskFile.FullName) $_"
      }
    }

    $this.CalcProcessOrder()
  }

  [void] CalcProcessOrder () {

    $DepOrder = @{}

    $this.Tasks | ForEach-Object {
      if($_.Dependencies) {
          if(-not $DepOrder.ContainsKey($_.ID)) {
              $DepOrder.add($_.ID, $_.Dependencies)
          }
      }
    }

    if($DepOrder.Keys.Count -gt 0) {
        $DependencyOrder = Get-TopologicalSort $DepOrder
        $this.Tasks = Sort-ObjectWithCustomList -InputObject $this.Tasks -Property ID -CustomList $DependencyOrder
    }

  }

  [string[]] GetTasksWithDepFromList ([string[]]$List) {
    $AllTasks = @()
    
    $this.Tasks | Where-Object { $_.ID -in $List } | ForEach-Object {
      if($_.ID -notin $AllTasks) {
        $AllTasks += $_.ID
      }
    }

    do {
      $StartCount = $AllTasks.Count
      $this.Tasks | Where-Object { $_.ID -in $AllTasks } | ForEach-Object {
        if($_.Dependencies) {
          $_.Dependencies | ForEach-Object {
            if($_ -notin $AllTasks) {
              $AllTasks += $_
            }
          }
        }
      }
    } while($AllTasks.Count -gt $StartCount)

    return $AllTasks
  } 
}

function New-CustomSandboxTaskCollection {
  param(
    [string]$Path
  )

  $TaskCollection = [CustomSandboxTaskCollection]::new()
  $TaskCollection.LoadFromDirectory($Path)

  return $TaskCollection
}
