# sysadmin
Various scripts and snippets for my Linux systems

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
