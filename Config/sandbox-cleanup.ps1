$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Functions\Tasks.ps1"
. "$PSScriptRoot\Functions\Common.ps1"

$CSMountPath = $PSScriptRoot
$CSCachePath = Join-Path $CSMountPath "Cache"

Initialize-TLS

# Abort initial shutdown (probably wont work)
&"shutdown" /a

Write-Host 'Importing Tasks...'
$TaskPath = Join-Path $CSMountPath "Tasks"
$TaskCollection = New-CustomSandboxTaskCollection -Path $TaskPath
$TaskOptions = Get-Content -Path "$CSCachePath\EnabledTasks.json" -Raw | ConvertFrom-Json

$AllTasks = $TaskCollection.GetTasksWithDepFromList($TaskOptions)
$TaskCollection.Tasks = $TaskCollection.Tasks | Where-Object { $_.ID -in $AllTasks }

Invoke-ExecuteTaskList -TaskList $TaskCollection.Tasks -Type "Cleanup Tasks" -ExecuteAction "cleanup"

Write-Host 'Done'

# Now we can shutdown
&"shutdown" /s