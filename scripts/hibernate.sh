sudo sh -c '
    echo platform > /sys/power/disk
    echo disk > /sys/power/state
'
