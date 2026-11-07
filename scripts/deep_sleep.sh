sudo sh -c '
sync
echo none > /sys/power/pm_test
echo deep > /sys/power/mem_sleep
echo mem > /sys/power/state
'

