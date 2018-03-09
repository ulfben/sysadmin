:: Run from elevated prompt to 
:: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder

:: manually run StartComponentCleanup to remove unused components immediately.
:: can take >20 minutes. 
Dism.exe /online /Cleanup-Image /StartComponentCleanup

:: remove all superseded versions of every component in the component store. 
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

:: remove backup files that are used to uninstall Service Packs. 
Dism.exe /online /Cleanup-Image /SPSuperseded