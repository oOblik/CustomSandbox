class CustomSandboxTask{
  [ValidateNotNullOrEmpty()] [string]$ID
  [ValidateNotNullOrEmpty()] [string]$Name
  [ValidateSet("preconfig","postconfig","config")] $Type = "config"
  [string[]]$Dependencies = @()
  [string[]]$Requirements = @()
  [string]$Script = ""
  [object[]]$Vars = @{}
  [int]$ProcessOrder

  CustomSandboxTask ([string]$ID,[string]$Name,[string]$Type,[string[]]$Dependencies,[string[]]$Requirements,[string]$Script,[object]$Vars,[int]$ProcessOrder) {
    $this.Init($ID,$Name,$Type,$Dependencies,$Requirements,$Script,$Vars,$ProcessOrder);
  }

  hidden Init (
    [string]$ID,
    [string]$Name,
    [string]$Type,
    [string[]]$Dependencies,
    [string[]]$Requirements,
    [string]$Script,
    [object]$Vars,
    [int]$ProcessOrder
  ) {
    $this.ID = $ID
    $this.Name = $Name
    $this.Type = $Type
    $this.Dependencies = $Dependencies
    $this.Requirements = $Requirements
    $this.Script = $Script
    $this.Vars = $Vars
    $this.ProcessOrder = $ProcessOrder
  }

  [void] ExecuteAction (
    [string]$Action,
    [switch]$ForceCache
  ) {
    & "$($this.Script)" -Action $Action -ForceCache:$ForceCache -Vars $this.Vars
  }
}

class CustomSandboxTaskCollection{
  [CustomSandboxTask[]]$Tasks

  CustomSandboxTask () {}

  [void] Add ([CustomSandboxTask]$Task) {
    $this.Tasks += $Task
    $this.CalcProcessOrder()
  }

  [void] LoadFromDirectory ([string]$Path) {
    if (!(Test-Path $Path)) {
      Write-Error "Directory not found"
      return
    }

    $TaskFiles = Get-ChildItem -Path $Path -Include "*.json" -File -Recurse

    foreach ($TaskFile in $TaskFiles) {
      $TaskJson = Get-Content -Path $TaskFile.FullName | ConvertFrom-Json
      $ScriptPath = Join-Path $TaskFile.Directory $TaskJson.Script

      if (!(Test-Path $ScriptPath)) {
        Write-Error "Script File $ScriptPath referenced in $TaskFile not found."
        break;
      }

      $this.Add(
        [CustomSandboxTask]::new(
          $TaskJson.ID,
          $TaskJson.Name,
          $TaskJson.Type,
          $TaskJson.Dependencies,
          $TaskJson.Requirements,
          $ScriptPath,
          $TaskJson.Vars,
          0
        )
      )
    }

    $this.CalcProcessOrder()
  }

  [void] CalcProcessOrder () {

    $this.Tasks | ForEach-Object {
      $_.ProcessOrder = 0
    }

    $DepPasses = 0

    do {
      $Continue = $true

      for ($i = 0; $i -lt $this.Tasks.Count; $i++) {

        foreach ($Dep in $this.Tasks[$i].Dependencies) {

          $DepTask = $this.Tasks | Where-Object { $_.ID -eq $Dep }

          if ($DepTask.ProcessOrder -ge $this.Tasks[$i].ProcessOrder) {
            $DepTask.ProcessOrder = $this.Tasks[$i].ProcessOrder - 1
            $Continue = $false
          }

        }

      }

      $DepPasses++
    } while ($Continue -and $DepPasses -lt 1000)

    $this.Tasks = $this.Tasks | Sort-Object -Property ProcessOrder
  }
}

function New-CustomSandboxTaskCollection {
  param(
    [string]$Path
  )

  $TaskCollection = [CustomSandboxTaskCollection]::new()
  $TaskCollection.LoadFromDirectory($Path)

  return $TaskCollection | Sort-Object -Property ProcessOrder
}

function New-CustomSandboxTask {
  param(
    [ValidateNotNullOrEmpty()] [string]$ID,
    [ValidateNotNullOrEmpty()] [string]$Name,
    [ValidateSet("preconfig","postconfig","config")] $Type = "config",
    [string[]]$Dependencies = @(),
    [string[]]$Requirements = @(),
    [string]$Script,
    [object[]]$Vars = @{},
    [int]$ProcessOrder = 0
  )

  return [CustomSandboxTask]::new($ID,$Name,$Type,$Dependencies,$Requirements,$Script,$Vars,$ProcessOrder)
}
