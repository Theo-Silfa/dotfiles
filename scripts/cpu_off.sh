sudo bash -c '
    for cpu in {1..7}; do
        echo 0 > "/sys/devices/system/cpu/cpu${cpu}/online" || exit 1
    done
'

cat /sys/devices/system/cpu/online
