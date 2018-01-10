#!/bin/bash
#check-temperature.sh - prints the value of all thermal sensors, in Celcius.
# use with watch for continuous monitoring:
#    watch --interval=1 -d ./check-temperature.sh
CELCIUS=$'\xc2\xb0'C
for i in /sys/class/thermal/*/temp
do
        fileName="$i"
        value=$(cat "$i")
	value=$(echo "$value/1000.0" | bc) #basic calculator
	printf "%s %.1f%s \\n" "$fileName" "$value" "$CELCIUS"
done
