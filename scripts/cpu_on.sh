sudo bash -c '
    for cpu in {1..7}; do
        echo 1 > "/sys/devices/system/cpu/cpu${cpu}/online"
    done
'

cat /sys/devices/system/cpu/online
