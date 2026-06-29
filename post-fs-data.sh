#!/system/bin/sh

MODDIR="${0%/*}"

for block in /sys/block/sd* /sys/block/mmcblk* /sys/block/dm-*; do
    if [ -d "$block/queue" ]; then
        echo 0 > "$block/queue/iostats" 2>/dev/null
        echo 0 > "$block/queue/add_random" 2>/dev/null
        echo 256 > "$block/queue/read_ahead_kb" 2>/dev/null
    fi
done

echo 0 > /proc/sys/kernel/printk_devkmsg 2>/dev/null
if [ -d /sys/kernel/tracing ]; then
    echo 0 > /sys/kernel/tracing/tracing_on 2>/dev/null
fi
