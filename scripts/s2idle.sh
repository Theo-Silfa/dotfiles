sudo sh -c '
sync
echo s2idle > /sys/power/mem_sleep
echo devices > /sys/power/pm_test
echo mem > /sys/power/state
echo none > /sys/power/pm_test
'

