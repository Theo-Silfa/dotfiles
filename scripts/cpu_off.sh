sudo sh -eu -c '
cpus=""

restore_cpus() {
    for f in $cpus; do
        echo 1 > "$f" || :
    done
}
trap restore_cpus EXIT

sync
echo none > /sys/power/pm_test
echo deep > /sys/power/mem_sleep

for f in /sys/devices/system/cpu/cpu[0-9]*/online; do
    [ -f "$f" ] || continue
    [ "$(cat "$f")" = 1 ] || continue
    cpus="$cpus $f"
    echo 0 > "$f"
done

echo mem > /sys/power/state
'

