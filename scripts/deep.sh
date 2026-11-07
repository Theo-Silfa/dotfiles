sudo sh -c '
sync
echo deep > /sys/power/mem_sleep
echo processors > /sys/power/pm_test
echo mem > /sys/power/state
echo none > /sys/power/pm_test
'

