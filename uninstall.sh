#!/system/bin/sh

# Remove log
rm -f /data/adb/modules/universal-perfmax/perfmax.log


su -lp 2000 -c "cmd notification post -t 'Universal PerfMax' 'perfmax_remove' 'Module removed. Settings restored to defaults. Reboot recommended.'" 2>/dev/null
