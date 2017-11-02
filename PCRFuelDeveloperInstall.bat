@REM Should be run as Administrator
c:\windows\system32\windowspowershell\v1.0\powershell.exe -command "set-executionpolicy -scope currentuser remotesigned"
@REM c:\windows\system32\windowspowershell\v1.0\powershell.exe -command "set-executionpolicy remotesigned"
c:\windows\system32\windowspowershell\v1.0\powershell.exe .\PCRFuelDeveloperInstall.ps1

