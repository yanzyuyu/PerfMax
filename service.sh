#!/system/bin/sh

MODDIR="${0%/*}"
. "$MODDIR/common/functions.sh"

resetprop -w sys.boot_completed 0 2>/dev/null || {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done
}
sleep 5 

# ─── Initialize log ───
echo "═══════════════════════════════════════════════" > "$LOGFILE"
echo "  Universal PerfMax v3.0 — Performance Log" >> "$LOGFILE"
echo "  $(date)" >> "$LOGFILE"
echo "═══════════════════════════════════════════════" >> "$LOGFILE"
log ""
log "Device Info:"
log "  Hardware:     $(getprop ro.hardware)"
log "  Platform:     $(getprop ro.board.platform)"
log "  CPU Vendor:   $(detect_cpu_vendor)"
log "  CPU Cores:    $(get_cpu_count)"
log "  Android:      $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk))"
log "  Root Manager: $(detect_root_manager)"
log "  Kernel:       $(uname -r)"
log ""


apply_cpu_performance
apply_cpu_boost
apply_task_scheduling
apply_io_tweaks
apply_vm_tweaks
apply_net_tweaks
apply_fs_tweaks
apply_gpu_tweaks
apply_kernel_tweaks
─
log ""
log_section "COMPLETE"
TEMP=$(read_cpu_temp)
log "  CPU Temperature: ${TEMP}°C"
log "  All performance tweaks applied successfully."
log "  Module is active and running."

# ─── Send notification ───
send_notification "Universal PerfMax" "Performance profile is now active! CPU: $(detect_cpu_vendor) • Temp: ${TEMP}°C" "perfmax_boot"
