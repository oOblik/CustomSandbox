<h2 align="center">
<img src="https://raw.githubusercontent.com/oOblik/CustomSandbox/main/Resources/cs-logo-sbs.png" width="800">

[![Latest Version](https://img.shields.io/github/release/oOblik/CustomSandbox?color=3FA9F5&label=latest%20version)](https://github.com/oOblik/CustomSandbox/releases/latest) [![Activity](https://img.shields.io/github/commit-activity/m/oOblik/CustomSandbox?color=3FA9F5)](https://github.com/oOblik/CustomSandbox/commits) [![Pull Requests](https://img.shields.io/github/issues-pr-closed/oOblik/CustomSandbox?color=3FA9F5)](https://github.com/oOblik/CustomSandbox/pulls)
</h2>

Do you frequently use [Windows Sandbox](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview) but are tired of having to install common utilities on every launch?

CustomSandbox is a PowerShell utility to facilitate quick automatic configuration of Windows Sandbox.

Write custom tasks to install software or configure Windows in the sandbox immediately after launch, and selectively choose which tasks to run.

## ✨ Features

- Configure the following Windows Sandbox features before launch:
  - Protected Mode
  - Networking
  - vGPU
  - Clipboard
  - Printer Redirection
  - Audio Input
  - Video Input
  - Maximum memory allocated to Windows Sandbox (based on available free memory)
- Custom configuration / software installation tasks

__Built-in tasks for installation of the following:__
  - 7-Zip
  - AdoptOpen Java JDK
  - AdoptOpen Java JRE
  - Apache OpenOffice
  - gg.cmd
  - Google Chrome
  - HxD Hex Editor
  - ManageEngine MIB Browser
  - Microsoft VS Code
  - Mozilla Firefox
  - Notepad++
  - Sysinternals BGInfo
  - Windows Terminal

__Chocolatey [Experimental]__ - Installs are cached/internalized and can be done with networking disabled.
  - Git
  - Google Chrome
  - Hex Rays IDA Disassembler (free)
  - Microsoft .NET Framework
  - ShareX
  - Windows Terminal

__WinGet [Experimental]__ - Networking is required as packages cannot be be caches/internalized and installed offline.
  - Windows Terminal

When possible, installation tasks pre-download and cache required installation files outside of the sandbox so they can be quickly re-used in successive runs, or installed if networking in the sandbox is disabled.

## ✅ Requirements

[Enable Windows Sandbox on Windows](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview#prerequisites)

⚠️ *DISCLAIMER:* _CustomSandbox has been tested with Windows 11 25H2 and PowerShell 5.1. While it should work from Windows 10 1903 or later, your results may vary._

## 💻 Installation / Usage

You can clone the repository with git:

```ps1
git clone https://github.com/oOblik/CustomSandbox.git
```
Or, download and extract with PowerShell.

```ps1
Invoke-WebRequest 'https://github.com/oOblik/CustomSandbox/releases/latest/download/CustomSandbox.zip' -OutFile .\CustomSandbox.zip
Expand-Archive .\CustomSandbox.zip .\
Remove-Item .\CustomSandbox.zip
```

```ps1
cd CustomSandbox

# Optional (only if needed)
Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
Get-ChildItem -Recurse *.ps1 | Unblock-File

# Launch
.\CustomSandbox.ps1
```

## 📸 Screenshots

<p align="center">
    <img src="https://raw.githubusercontent.com/oOblik/CustomSandbox/main/Resources/Screenshots/Sandbox.png" width="90%" /><br>
    <img src="https://raw.githubusercontent.com/oOblik/CustomSandbox/main/Resources/Screenshots/Launcher.png" width="90%" /><br>
    <img src="https://raw.githubusercontent.com/oOblik/CustomSandbox/main/Resources/Screenshots/Tasks.png" width="90%" /><br>
    <img src="https://raw.githubusercontent.com/oOblik/CustomSandbox/main/Resources/Screenshots/Configuring.png" width="90%" /><br>
</p>

## ➕ Contributing

Found a _bug_ or want a _new feature_? You can open a new `Issue` [here](https://github.com/oOblik/CustomSandbox/issues/new/choose).

## 📝 License

Licensed under the [MIT](LICENSE) license.