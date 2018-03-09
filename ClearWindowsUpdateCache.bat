:: temporarily halts Windows Update and clears the cache from downloaded packages.
:: shouldn't be necessary, but the OS is not handling this correctly for me.
net stop wuauserv 
CD %Windir% 
CD SoftwareDistribution 
DEL /F /S /Q Download
net start wuauserv