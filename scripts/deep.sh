sudo sh -c '
    echo none > /sys/power/pm_test
    echo deep > /sys/power/mem_sleep
    sync
    echo mem > /sys/power/state
'
