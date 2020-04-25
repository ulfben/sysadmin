# sysadmin
This repo holds various scripts and snippets for my Linux and Windows systems

## mirror_all_remotes.sh
Used to securely copy filesystems from remote servers to a local backup station.
To be used securely you need to set up a backup service account on all remote machines, allowed to authenticate only via public key. This account should be jailed to a specific folder (sftp jail via openssh is trivial to set up and works well with this script). The service account should additionally be restricted to the maximum degree: no password authentication, no sudo privileges, no write permissions on the server and ideally no shell either. 

## CleanComponentStore.bat and ClearWindowsUpdateCache.bat

Two scripts to reclaim some space from Windows 10. Run from elevated prompts to clean the component store (aka: the "WinSxS"-folder) and the Windows Update download cache. These scripts removes files that *should* be temporary but, for some reason, fill up my system drive over time. 

If you're on the hunt to reclaim more space from your Windows 10 installation, here's some further tips: 
1. [disable the Recycle Bin](https://www.tekrevue.com/tip/disable-recycle-bin-windows/) on all drives
2. [disable System Restore Points](https://www.howtogeek.com/howto/windows-vista/disable-system-restore-in-windows-vista/) on all drives (you don't need these since you *are* running your own backups)
3. [run Disk Cleanup](https://www.howtogeek.com/266337/what-should-i-remove-in-disk-cleanup-on-windows/)
4. [turn on filesystem compression](https://www.howtogeek.com/133264/how-to-use-ntfs-compression-and-when-you-might-want-to/) for the `%ProgramData%` and `%SystemRoot%\Installer`-folders. (= no risk ~15% space saving)
5. [use PatchCleaner](https://superuser.com/a/920713/190802) to move or delete orphaned installers from %SystemRoot%\Installer.
6. [redirect `%ProgramData%\Package Cache` to another partition](https://blogs.msdn.microsoft.com/heaths/2015/06/09/redirect-the-package-cache-using-registry-based-policy/)

## backup.sh:
A simple data backup script with grandfather-father-son rotation:
  - The rotation will do a daily backup Sunday through Friday.
  - On Saturday a weekly backup is done giving you four weekly backups a month.
  - The monthly backup is done on the first of the month, rotating two monthly backups (odd/even)

The archive rotation was inspired by [the Ubuntu server guide](https://help.ubuntu.com/lts/serverguide/backups.html) on the topic. My implementation:
- includes a database dump in every backup
- password protect the resulting archive file (7z, AES256)
- runs much faster. (multi-core friendly courtesy of pigz – a parallel implementation of gzip)
- offers time-stamped logging and bare minimum error handling (good for cron jobs)

## check-temperature.sh

Dumps all all thermal sensors to stdout, in Celcius. Use with `watch`for continuous monitoring: 
- `watch --interval=1 -d ./check-temperature.sh`
```
Every 1.0s: ./check-temperature.sh                                                 Wed Jan 10 17:53:27 2018

/sys/class/thermal/thermal_zone0/temp 30.0°C
/sys/class/thermal/thermal_zone1/temp 32.0°C
/sys/class/thermal/thermal_zone2/temp 32.0°C
/sys/class/thermal/thermal_zone3/temp 30.0°C
/sys/class/thermal/thermal_zone4/temp 30.0°C
```
