function Get-FriendlySize {
  param([int]$MBytes)

  $bytes = $MBytes * 1024 * 1024

  $result = "{0} B" -f $bytes

  switch ($bytes) {
    { $_ -ge 1tb } {
      $result = "{0:n2} TB" -f ($_ / 1tb)
      break;
    }
    { $_ -ge 1gb } {
      $result = "{0:n2} GB" -f ($_ / 1gb)
      break;
    }
    { $_ -ge 1mb } {
      $result = "{0:n2} MB" -f ($_ / 1mb)
      break;
    }
    { $_ -ge 1kb } {
      $result = "{0:n2} KB" -f ($_ / 1Kb)
      break;
    }
  }

  return $result;
}

function Invoke-ExecuteTaskList {
  param(
    [object]$TaskList,
    [string]$Type
  )

  if ($TaskList) {

    $xml = @"
<toast scenario="incomingCall">
    <visual>
        <binding template="ToastGeneric">
            <text>Configuring sandbox...</text>
            <progress title="{progressTitle}" value="{progressValue}" valueStringOverride="{progressValueString}" status="{progressStatus}"/>
        </binding>
    </visual>
    <audio silent="true"/>
</toast>
"@

    $XmlDocument = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::new()
    $XmlDocument.loadXml($xml)
    $ToastNotification = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]::new($XmlDocument)
    $ToastNotification.Tag = $AppName
    $Dictionary = [System.Collections.Generic.Dictionary[String, String]]::new()
    $Dictionary.Add('progressTitle','')
    $Dictionary.Add('progressValue','0')
    $Dictionary.Add('progressValueString','Task 0/0')
    $Dictionary.Add('progressStatus',$Type)
    $ToastNotification.Data = [Windows.UI.Notifications.NotificationData]::new($Dictionary)
    $ToastNotification.Data.SequenceNumber = 1
    $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($ToastNotification)

    for ($Task = 0; $Task -lt $TaskList.Count; $Task++) {
      Write-Host "Running Task $($TaskList[$Task].Name)..."
      $Dictionary = [System.Collections.Generic.Dictionary[String, String]]::new()
      $Dictionary.Add('progressTitle',$TaskList[$Task].Name)
      $Dictionary.Add('progressValue',($Task + 1) / $TaskList.Count)
      $Dictionary.Add('progressValueString',"Task $($Task+1)/$($TaskList.Count)")
      $NotificationData = [Windows.UI.Notifications.NotificationData]::new($Dictionary)
      $NotificationData.SequenceNumber = 2
      [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Update($NotificationData,$AppName)

      $TaskList[$Task].ExecuteAction("execute",$false)
    }

    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Hide($ToastNotification)

  }

}

function Update-Wallpaper {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Position = 0,HelpMessage = "The path to the wallpaper file.")]
    [Alias("wallpaper")]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path = $(Get-ItemPropertyValue -Path 'HKCU:\Control Panel\Desktop\' -Name Wallpaper)
  )

  Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    using Microsoft.Win32;

    namespace Wallpaper
    {
        public class UpdateImage
        {
            [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]

            private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);

            public static void Refresh(string path)
            {
                SystemParametersInfo( 20, 0, path, 0x01 | 0x02 );
            }
        }
    }
"@

  Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperOriginX' -Value 0 -Force
  Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperOriginY' -Value 0 -Force
  Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'WallpaperStyle' -Value 2 -Force
  Set-ItemProperty 'HKCU:\Control Panel\Desktop\' -Name 'JPEGImportQuality' -Value 100 -Force

  if ($PSCmdlet.shouldProcess($path)) {
    [Wallpaper.UpdateImage]::Refresh($Path)
  }
}

function Hide-Icons {
  Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDesktop' -Value 1
}

function Show-Icons {
  Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDesktop' -Value 0
}

function Hide-Taskbar {
  $v = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3').Settings
  $v[8] = 3
  Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3' -Name 'Settings' -Value $v
}

function Show-Taskbar {
  $v = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3').Settings
  $v[8] = 2
  Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3' -Name 'Settings' -Value $v
}

function New-Shortcut {
  param(
    [string]$Path,
    [string]$TargetPath
  )

  $WshShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WshShell.CreateShortcut($Path)
  $Shortcut.TargetPath = $TargetPath
  $Shortcut.Save()
}

function Restart-Explorer {
  Get-Process explorer | Stop-Process -Force
}

function Show-Notification {
  [CmdletBinding()]
  param(
    [string]$Title = "CustomSandbox",
    [string][Parameter(ValueFromPipeline)] $Text
  )

  $TemplateXML = @"
<toast>
	<visual>
		<binding template="ToastGeneric">
			<text id="0"></text>
			<text id="1"></text>
		</binding>
	</visual>
</toast>
"@

  $TemplateContent = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::new()
  $TemplateContent.loadXml($TemplateXML)
  $TemplateContent.SelectSingleNode('//text[@id="0"]').InnerText = $Title
  $TemplateContent.SelectSingleNode('//text[@id="1"]').InnerText = $Text
  $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

  return [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($TemplateContent)
}

function Invoke-BlindFileDownload {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
  )

  $Request = [System.Net.HttpWebRequest]::Create($Url)
  $Request.Method = "HEAD"
  $Response = $Request.GetResponse()

  $FileUri = $Response.ResponseUri
  $Filename = [System.IO.Path]::GetFileName($FileUri.LocalPath);
  $Response.Close()

  $Destination = Join-Path $FolderPath $Filename

  Invoke-WebRequest -Uri $FileUri.AbsoluteUri -OutFile $Destination

  return $Filename
}


# From: https://github.com/RamblingCookieMonster/PSDepend
# Copyright (c) 2016 Warren F.
# (MIT) License, see LICENSE


# Thanks to http://stackoverflow.com/questions/8982782/does-anyone-have-a-dependency-graph-and-topological-sorting-code-snippet-for-pow
# Input is a hashtable of @{ID = @(Depended,On,IDs);...}

function Get-TopologicalSort {
  param(
      [Parameter(Mandatory = $true, Position = 0)]
      [hashtable] $edgeList
  )

  # Make sure we can use HashSet
  Add-Type -AssemblyName System.Core

  # Clone it so as to not alter original
  $currentEdgeList = [hashtable] (Get-ClonedObject $edgeList)

  # algorithm from http://en.wikipedia.org/wiki/Topological_sorting#Algorithms
  $topologicallySortedElements = New-Object System.Collections.ArrayList
  $setOfAllNodesWithNoIncomingEdges = New-Object System.Collections.Queue

  $fasterEdgeList = @{}

  # Keep track of all nodes in case they put it in as an edge destination but not source
  $allNodes = New-Object -TypeName System.Collections.Generic.HashSet[object] -ArgumentList (,[object[]] $currentEdgeList.Keys)

  foreach($currentNode in $currentEdgeList.Keys) {
      $currentDestinationNodes = [array] $currentEdgeList[$currentNode]
      if($currentDestinationNodes.Length -eq 0) {
          $setOfAllNodesWithNoIncomingEdges.Enqueue($currentNode)
      }

      foreach($currentDestinationNode in $currentDestinationNodes) {
          if(!$allNodes.Contains($currentDestinationNode)) {
              [void] $allNodes.Add($currentDestinationNode)
          }
      }

      # Take this time to convert them to a HashSet for faster operation
      $currentDestinationNodes = New-Object -TypeName System.Collections.Generic.HashSet[object] -ArgumentList (,[object[]] $currentDestinationNodes )
      [void] $fasterEdgeList.Add($currentNode, $currentDestinationNodes)        
  }

  # Now let's reconcile by adding empty dependencies for source nodes they didn't tell us about
  foreach($currentNode in $allNodes) {
      if(!$currentEdgeList.ContainsKey($currentNode)) {
          [void] $currentEdgeList.Add($currentNode, (New-Object -TypeName System.Collections.Generic.HashSet[object]))
          $setOfAllNodesWithNoIncomingEdges.Enqueue($currentNode)
      }
  }

  $currentEdgeList = $fasterEdgeList

  while($setOfAllNodesWithNoIncomingEdges.Count -gt 0) {        
      $currentNode = $setOfAllNodesWithNoIncomingEdges.Dequeue()
      [void] $currentEdgeList.Remove($currentNode)
      [void] $topologicallySortedElements.Add($currentNode)

      foreach($currentEdgeSourceNode in $currentEdgeList.Keys) {
          $currentNodeDestinations = $currentEdgeList[$currentEdgeSourceNode]
          if($currentNodeDestinations.Contains($currentNode)) {
              [void] $currentNodeDestinations.Remove($currentNode)

              if($currentNodeDestinations.Count -eq 0) {
                  [void] $setOfAllNodesWithNoIncomingEdges.Enqueue($currentEdgeSourceNode)
              }                
          }
      }
  }

  if($currentEdgeList.Count -gt 0) {
      throw "Graph has at least one cycle!"
  }

  return $topologicallySortedElements
}

# Thanks to https://gallery.technet.microsoft.com/scriptcenter/Sort-With-Custom-List-07b1d93a
Function Sort-ObjectWithCustomList {
  Param (
      [parameter(ValueFromPipeline=$true)]
      [PSObject]
      $InputObject,

      [parameter(Position=1)]
      [String]
      $Property,

      [parameter()]
      [Object[]]
      $CustomList
  )
  Begin
  {
      # convert customList (array) to hash
      $hash = @{}
      $rank = 0
      $customList | Select-Object -Unique | ForEach-Object {
          $key = $_
          $hash.Add($key, $rank)
          $rank++
      }

      # create script block for sorting
      # items not in custom list will be last in sort order
      $sortOrder = {
          $key = if ($Property) { $_.$Property } else { $_ }
          $rank = $hash[$key]
          if ($rank -ne $null) {
              $rank
          } else {
              [System.Double]::PositiveInfinity
          }
      }

      # create a place to collect objects from pipeline
      # (I don't know how to match behavior of Sort's InputObject parameter)
      $objects = @()
  }
  Process
  {
      $objects += $InputObject
  }
  End
  {
      $objects | Sort-Object -Property $sortOrder
  }
}

# Idea from http://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell 
# borrowed from http://stackoverflow.com/questions/8982782/does-anyone-have-a-dependency-graph-and-topological-sorting-code-snippet-for-pow
function Get-ClonedObject {
  param($DeepCopyObject)
  $memStream = new-object IO.MemoryStream
  $formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
  $formatter.Serialize($memStream,$DeepCopyObject)
  $memStream.Position=0
  $formatter.Deserialize($memStream)
}
