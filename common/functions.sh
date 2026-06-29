#!/system/bin/sh

MODDIR="${MODDIR:-/data/adb/modules/universal-perfmax}"
LOGFILE="$MODDIR/perfmax.log"

# ─────────────── Logging ───────────────

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log_section() {
    log "════════ $1 ════════"
}
write_sysfs() {
    local val="$1"
    local path="$2"
    if [ -f "$path" ]; then
        echo "$val" > "$path" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "  ✓ $path = $val"
            return 0
        else
            log "  ✗ $path = $val (write failed)"
            return 1
        fi
    else
        return 1
    fi
}

detect_cpu_vendor() {
    local hw=""
    hw=$(getprop ro.hardware 2>/dev/null)
    local platform
    platform=$(getprop ro.board.platform 2>/dev/null)
    local cpuinfo
    cpuinfo=$(grep -i "Hardware" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2)

    local combined="$hw $platform $cpuinfo"

    if echo "$combined" | grep -qi "qcom\|qualcomm\|SDM\|SM[0-9]\|MSM\|APQ\|kona\|lahaina\|taro\|crow\|kalama\|pineapple"; then
        echo "qualcomm"
    elif echo "$combined" | grep -qi "mt[0-9]\|mediatek\|mt6"; then
        echo "mediatek"
    elif echo "$combined" | grep -qi "exynos\|samsung\|universal\|samsungexynos"; then
        echo "exynos"
    elif echo "$combined" | grep -qi "tensor\|gs[0-9]\|whitechapel\|zuma\|ripcurrent"; then
        echo "tensor"
    elif echo "$combined" | grep -qi "unisoc\|spreadtrum\|ums\|SC[0-9]"; then
        echo "unisoc"
    else
        echo "unknown"
    fi
}

detect_root_manager() {
    if [ -d /data/adb/magisk ]; then
        echo "magisk"
    elif [ -d /data/adb/ksu ]; then
        echo "kernelsu"
    elif [ -d /data/adb/ap ]; then
        echo "apatch"
    else
        echo "unknown"
    fi
}

get_policy_dirs() {
    local found=0
    for p in /sys/devices/system/cpu/cpufreq/policy*; do
        if [ -d "$p" ]; then
            echo "$p"
            found=1
        fi
    done
    if [ "$found" = "0" ]; then
        for p in /sys/devices/system/cpu/cpu0/cpufreq; do
            [ -d "$p" ] && echo "$p"
        done
    fi
}

get_cpu_count() {
    grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "0"
}

governor_available() {
    local policy="$1"
    local gov="$2"
    [ -f "$policy/scaling_available_governors" ] || return 1
    grep -qw "$gov" "$policy/scaling_available_governors" 2>/dev/null
}

set_governor() {
    local policy="$1"
    local gov="$2"
    if governor_available "$policy" "$gov"; then
        echo "$gov" > "$policy/scaling_governor" 2>/dev/null
        log "  ✓ $(basename "$policy") governor → $gov"
        return 0
    fi
    return 1
}

find_cpu_thermal_zone() {
    for tz in /sys/class/thermal/thermal_zone*; do
        [ -d "$tz" ] || continue
        local type_name
        type_name=$(cat "$tz/type" 2>/dev/null)
        case "$type_name" in
            *cpu*|*CPU*|*soc*|*SOC*|*tsens_tz_sensor*|*mtktscpu*|*little*|*big*|*cluster*)
                echo "$tz/temp"
                return 0
                ;;
        esac
    done
    [ -f /sys/class/thermal/thermal_zone0/temp ] && echo "/sys/class/thermal/thermal_zone0/temp"
}

read_cpu_temp() {
    local tz_path
    tz_path=$(find_cpu_thermal_zone)
    [ -z "$tz_path" ] && echo "0" && return

    local raw
    raw=$(cat "$tz_path" 2>/dev/null)
    case "$raw" in
        ''|*[!0-9-]*) echo "0"; return ;;
    esac
    if [ "$raw" -gt 1000 ] 2>/dev/null; then
        echo $((raw / 1000))
    else
        echo "$raw"
    fi
}

send_notification() {
    local title="$1"
    local text="$2"
    local tag="${3:-perfmax}"
    local sdk
    sdk=$(getprop ro.build.version.sdk 2>/dev/null)
    sdk=$(echo "$sdk" | tr -dc '0-9')
    if [ -n "$sdk" ] && [ "$sdk" -ge 26 ] 2>/dev/null; then
        su -lp 2000 -c "cmd notification post -t '$title' '$tag' '$text'" 2>/dev/null
    else
        am broadcast -a android.intent.action.SHOW_TOAST --es android.intent.extra.TEXT "$title: $text" >/dev/null 2>&1
    fi
    log "Notification: $title — $text"
}

apply_cpu_performance() {
    log_section "CPU GOVERNOR TUNING"

    for policy in $(get_policy_dirs); do
        local pname
        pname=$(basename "$policy")
        if set_governor "$policy" "performance"; then
        elif set_governor "$policy" "schedutil"; then
            write_sysfs 200 "$policy/schedutil/up_rate_limit_us"
            write_sysfs 5000 "$policy/schedutil/down_rate_limit_us"
            write_sysfs 1 "$policy/schedutil/iowait_boost_enable"
        elif set_governor "$policy" "interactive"; then
            write_sysfs "20000 10000" "$policy/interactive/above_hispeed_delay"
            write_sysfs 90 "$policy/interactive/go_hispeed_load"
            write_sysfs 20000 "$policy/interactive/timer_rate"
        fi
        if [ -f "$policy/scaling_max_freq" ] && [ -f "$policy/cpuinfo_max_freq" ]; then
            local max_freq
            max_freq=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
            write_sysfs "$max_freq" "$policy/scaling_max_freq"
        fi
    done
}

apply_cpu_boost() {
    log_section "CPU BOOST"
    local vendor
    vendor=$(detect_cpu_vendor)
    local cores
    cores=$(get_cpu_count)

    case "$vendor" in
        qualcomm)
            write_sysfs 40 /sys/module/cpu_boost/parameters/input_boost_ms
            local boost_str=""
            local i=0
            while [ "$i" -lt "$cores" ]; do
                [ -n "$boost_str" ] && boost_str="$boost_str "
                local max_f
                max_f=$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq" 2>/dev/null)
                if [ -z "$max_f" ]; then
                    max_f="1400000"
                fi
                boost_str="${boost_str}${i}:${max_f}"
                i=$((i + 1))
            done
            write_sysfs "$boost_str" /sys/module/cpu_boost/parameters/input_boost_freq
            write_sysfs 1 /sys/module/cpu_boost/parameters/sched_boost_on_input
            ;;
        mediatek)
            write_sysfs 1 /proc/ppm/enabled
            write_sysfs "0 0" /proc/ppm/policy/ut_fix_freq_idx
            # EAS boost
            write_sysfs 100 /sys/devices/system/cpu/perf/enable
            ;;
        exynos)
            write_sysfs 1 /sys/devices/system/cpu/cpufreq/boost
            write_sysfs 1 /sys/power/cpufreq_max_limit
            ;;
        tensor)
            write_sysfs 1 /sys/devices/system/cpu/cpufreq/boost
            ;;
        unisoc)
            write_sysfs 1 /sys/devices/system/cpu/cpufreq/boost
            ;;
    esac
}

apply_task_scheduling() {
    log_section "TASK SCHEDULING"
    write_sysfs 1 /proc/sys/kernel/sched_util_clamp_min_rt_default
    write_sysfs 1024 /proc/sys/kernel/sched_util_clamp_min
    if [ -d /dev/cpuctl/top-app ]; then
        write_sysfs max /dev/cpuctl/top-app/cpu.uclamp.min
        write_sysfs max /dev/cpuctl/top-app/cpu.uclamp.max
        write_sysfs 50 /dev/cpuctl/foreground/cpu.uclamp.min
        write_sysfs max /dev/cpuctl/foreground/cpu.uclamp.max
        log "  Applied cgroup v2 uclamp"
    fi
    if [ -d /dev/stune/top-app ]; then
        write_sysfs 10 /dev/stune/top-app/schedtune.boost
        write_sysfs 1 /dev/stune/top-app/schedtune.prefer_idle
        write_sysfs 0 /dev/stune/background/schedtune.boost
        log "  Applied schedtune boost"
    fi
    write_sysfs 1000000 /proc/sys/kernel/sched_latency_ns
    write_sysfs 100000 /proc/sys/kernel/sched_min_granularity_ns
    write_sysfs 500000 /proc/sys/kernel/sched_wakeup_granularity_ns
    write_sysfs 0 /proc/sys/kernel/sched_child_runs_first
    write_sysfs 1 /proc/sys/kernel/sched_tunable_scaling
    write_sysfs 25 /proc/sys/kernel/sched_nr_migrate
}

apply_io_tweaks() {
    log_section "I/O SCHEDULER"

    for block in /sys/block/sd* /sys/block/mmcblk* /sys/block/dm-* /sys/block/nvme*; do
        [ -d "$block/queue" ] || continue
        local bname
        bname=$(basename "$block")
        write_sysfs 0 "$block/queue/iostats"
        write_sysfs 256 "$block/queue/read_ahead_kb"
        write_sysfs 128 "$block/queue/nr_requests"
        write_sysfs 0 "$block/queue/add_random"
        if [ -f "$block/queue/scheduler" ]; then
            local avail
            avail=$(cat "$block/queue/scheduler" 2>/dev/null)
            if echo "$avail" | grep -q "mq-deadline"; then
                write_sysfs "mq-deadline" "$block/queue/scheduler"
            elif echo "$avail" | grep -q "none"; then
                write_sysfs "none" "$block/queue/scheduler"
            elif echo "$avail" | grep -q "noop"; then
                write_sysfs "noop" "$block/queue/scheduler"
            fi
        fi

        log "  Block device: $bname optimized"
    done
}

apply_vm_tweaks() {
    log_section "VIRTUAL MEMORY"
    write_sysfs 60 /proc/sys/vm/swappiness
    write_sysfs 80 /proc/sys/vm/vfs_cache_pressure
    write_sysfs 15 /proc/sys/vm/dirty_ratio
    write_sysfs 5 /proc/sys/vm/dirty_background_ratio
    write_sysfs 3000 /proc/sys/vm/dirty_expire_centisecs
    write_sysfs 500 /proc/sys/vm/dirty_writeback_centisecs
    write_sysfs 0 /proc/sys/vm/page-cluster
    write_sysfs 100 /proc/sys/vm/stat_interval
    write_sysfs 0 /proc/sys/vm/oom_dump_tasks
    write_sysfs 1 /proc/sys/vm/compact_unevictable_allowed
    local memtotal_kb
    memtotal_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [ -n "$memtotal_kb" ] && [ "$memtotal_kb" -gt 0 ] 2>/dev/null; then
        local extra_kb=$((memtotal_kb * 15 / 1000))
        write_sysfs "$extra_kb" /proc/sys/vm/extra_free_kbytes
    fi
}

apply_net_tweaks() {
    log_section "NETWORK STACK"
    write_sysfs "4096 87380 6291456" /proc/sys/net/ipv4/tcp_rmem
    write_sysfs "4096 65536 6291456" /proc/sys/net/ipv4/tcp_wmem
    write_sysfs 3 /proc/sys/net/ipv4/tcp_fastopen
    if [ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]; then
        local avail
        avail=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)
        if echo "$avail" | grep -q "bbr"; then
            write_sysfs "bbr" /proc/sys/net/ipv4/tcp_congestion_control
        elif echo "$avail" | grep -q "cubic"; then
            write_sysfs "cubic" /proc/sys/net/ipv4/tcp_congestion_control
        fi
    fi
    write_sysfs 60 /proc/sys/net/ipv4/tcp_keepalive_time
    write_sysfs 10 /proc/sys/net/ipv4/tcp_keepalive_intvl
    write_sysfs 5 /proc/sys/net/ipv4/tcp_keepalive_probes
    write_sysfs 1 /proc/sys/net/ipv4/tcp_ecn
    write_sysfs 1 /proc/sys/net/ipv4/tcp_timestamps
    write_sysfs 1 /proc/sys/net/ipv4/tcp_sack
}

apply_fs_tweaks() {
    log_section "FILESYSTEM"
    write_sysfs 524288 /proc/sys/fs/inotify/max_user_watches
    write_sysfs 256 /proc/sys/fs/inotify/max_user_instances
    write_sysfs 2097152 /proc/sys/fs/file-max
    write_sysfs 15 /proc/sys/fs/lease-break-time
}

apply_gpu_tweaks() {
    log_section "GPU TUNING"
    local vendor
    vendor=$(detect_cpu_vendor)

    case "$vendor" in
        qualcomm)
            for gpu in /sys/class/kgsl/kgsl-3d0; do
                [ -d "$gpu" ] || continue
                write_sysfs 1 "$gpu/force_clk_on"
                write_sysfs 0 "$gpu/bus_split"
                write_sysfs 1 "$gpu/force_bus_on"
                write_sysfs 1 "$gpu/force_rail_on"
                write_sysfs 0 "$gpu/throttling"
                write_sysfs 1 "$gpu/idle_timer"
                if [ -f "$gpu/devfreq/governor" ]; then
                    write_sysfs "msm-adreno-tz" "$gpu/devfreq/governor"
                fi
                log "  Adreno GPU optimized"
            done
            ;;
        mediatek)
            for gpu in /sys/devices/platform/*/mali /proc/mali; do
                [ -e "$gpu" ] || continue
                write_sysfs "always_on" "$gpu/power_policy" 2>/dev/null
                log "  Mali GPU (MediaTek) optimized"
            done
            write_sysfs 1 /proc/gpufreq/gpufreq_opp_stress_test 2>/dev/null
            ;;
        exynos|tensor)
            for gpu in /sys/devices/platform/*/gpu /sys/devices/platform/*/mali; do
                [ -d "$gpu" ] || continue
                write_sysfs "always_on" "$gpu/power_policy" 2>/dev/null
                write_sysfs 1 "$gpu/highspeed_load" 2>/dev/null
                log "  Mali GPU (Exynos/Tensor) optimized"
            done
            ;;
    esac
}───

apply_kernel_tweaks() {
    log_section "KERNEL MISC"

    write_sysfs 0 /sys/module/printk/parameters/console_suspend
    write_sysfs "off" /proc/sys/kernel/printk_devkmsg
    write_sysfs 0 /sys/kernel/debug/sched_debug 2>/dev/null

    if [ -d /sys/kernel/tracing ]; then
        write_sysfs 0 /sys/kernel/tracing/tracing_on
    elif [ -d /sys/kernel/debug/tracing ]; then
        write_sysfs 0 /sys/kernel/debug/tracing/tracing_on
    fi

    write_sysfs 1 /proc/sys/kernel/randomize_va_space

    write_sysfs 1 /proc/sys/kernel/perf_event_paranoid

    write_sysfs 1 /sys/module/rcutree/parameters/rcu_idle_gp_delay
}
