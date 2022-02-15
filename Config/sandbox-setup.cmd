@ECHO OFF

REM sandbox-setup.cmd
REM This code runs in the context of the Windows Sandbox

REM Set execution policy first so that a setup script can be run
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -Command "&{ Set-ExecutionPolicy Unrestricted -Force }"

REM Now run the true configuration script
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -File "C:\Config\sandbox-config.ps1"
