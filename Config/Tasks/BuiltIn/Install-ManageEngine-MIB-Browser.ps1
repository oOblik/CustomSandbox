param(
  [Parameter()]
  [string]$Action,
  [Parameter()]
  [bool]$ForceCache,
  [Parameter()]
  [object]$Vars
)

$OutPath = Join-Path $CSCachePath "ManageEngine_MibBrowser_64bit.exe"
$RunPath = Join-Path $Env:TEMP "ManageEngine_MibBrowser_64bit.exe"
$ConfigPath = Join-Path $Env:TEMP "Setup.iss"

$SilentConfigFile = @'
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{9C79392A-ACA0-4253-A57A-B29A53205273}-DlgOrder]
Dlg0={9C79392A-ACA0-4253-A57A-B29A53205273}-SdWelcome-0
Count=6
Dlg1={9C79392A-ACA0-4253-A57A-B29A53205273}-SdLicense-0
Dlg2={9C79392A-ACA0-4253-A57A-B29A53205273}-SdAskDestPath-0
Dlg3={9C79392A-ACA0-4253-A57A-B29A53205273}-SdSelectFolder-0
Dlg4={9C79392A-ACA0-4253-A57A-B29A53205273}-SdStartCopy-0
Dlg5={9C79392A-ACA0-4253-A57A-B29A53205273}-SdFinish-0
[{9C79392A-ACA0-4253-A57A-B29A53205273}-SdWelcome-0]
Result=1
[{9C79392A-ACA0-4253-A57A-B29A53205273}-SdLicense-0]
Result=1
[{9C79392A-ACA0-4253-A57A-B29A53205273}-SdAskDestPath-0]
szDir=C:\Program Files\
Result=1
[{9C79392A-ACA0-4253-A57A-B29A53205273}-SdSelectFolder-0]
szFolder=ManageEngine MibBrowser
Result=1
[{9C79392A-ACA0-4253-A57A-B29A53205273}-SdStartCopy-0]
Result=1
[Application]
Name=ManageEngine MibBrowser 5
Version=5.2
Company=ZOHO Corp.
Lang=0409
[{9C79392A-ACA0-4253-A57A-B29A53205273}-SdFinish-0]
Result=1
bOpt1=0
bOpt2=1

'@

switch ($Action) {
  "cache" {
    if (!$ForceCache -and (Test-Path $OutPath)) { break; }

    $DownloadURL = "https://download.manageengine.com/products/mibbrowser-free-tool/9229779/ManageEngine_MibBrowser_FreeTool_64bit.exe"
    Invoke-WebRequest -Uri $DownloadURL -OutFile $OutPath

    break;
  }

  "execute" {
    if (Test-Path $OutPath) {
      Copy-Item $OutPath -Destination $RunPath | Out-Null
      Set-Content -Path $ConfigPath -Value $SilentConfigFile -Force
      Start-Process -FilePath $RunPath -ArgumentList "/s /f1`"$ConfigPath`"" -WindowStyle Hidden -Wait
      Remove-Item -Path "$Env:PUBLIC\Desktop\ManageEngine*.lnk" -Force | Out-Null
    } else {
      Write-Host "Installer not found for task $($MyInvocation.MyCommand.Name)"
    }
    break;
  }

  default {
    Write-Host "Unknown action ($Action) on $($MyInvocation.MyCommand.Name)"
  }
}
