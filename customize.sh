#!/system/bin/sh


ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "    Universal PerfMax v3.0"
ui_print "    Real Performance • All CPU • All Android"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""

if [ -d /data/adb/magisk ]; then
    ui_print "  Root Manager: Magisk"
elif [ -d /data/adb/ksu ]; then
    ui_print "  Root Manager: KernelSU"
elif [ -d /data/adb/ap ]; then
    ui_print "  Root Manager: APatch"
else
    ui_print "  Root Manager: Unknown"
fi

HW=$(getprop ro.hardware 2>/dev/null)
PLATFORM=$(getprop ro.board.platform 2>/dev/null)
CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
ui_print "  CPU: $HW ($PLATFORM) — $CORES cores"
ui_print "  Android: $(getprop ro.build.version.release) (API $API)"
ui_print ""

if [ "$API" -lt 21 ]; then
    abort "! Requires Android 5.0 (API 21) or higher."
fi

ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/common/functions.sh" 0 0 0755

ui_print ""
ui_print "- Module installed successfully!"
ui_print "- Performance tweaks will activate after reboot."
ui_print "- You will receive a notification when active."
ui_print ""

# ─── Send notification after install ───
if [ "$API" -ge 26 ]; then
    su -lp 2000 -c "cmd notification post -t 'Universal PerfMax' 'perfmax_install' 'Module installed! Reboot your device to activate performance profile.'" 2>/dev/null
else
    am broadcast -a android.intent.action.SHOW_TOAST --es android.intent.extra.TEXT "Universal PerfMax Installed! Please reboot." >/dev/null 2>&1
fi
