# Universal PerfMax

<p align="center">
  <b>Android Performance Optimization Module</b><br>
  CPU • GPU • RAM • I/O • Kernel • Network
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Android-5.0%2B-green?style=flat-square"/>
  <img src="https://img.shields.io/badge/Root-Magisk%20%7C%20KernelSU%20%7C%20APatch-blue?style=flat-square"/>
  <img src="https://img.shields.io/badge/Status-Stable-success?style=flat-square"/>
</p>

---

## Overview

Universal PerfMax is a root-based Android module that applies low-level system and kernel optimizations across multiple chipsets.

It dynamically adjusts CPU, GPU, memory, scheduler, and I/O behavior to prioritize maximum performance.

---

## Features

- CPU governor tuning with fallback handling  
- Multi-vendor CPU boost optimization  
- Advanced scheduler tuning (uclamp, schedtune)  
- RAM and virtual memory optimization  
- I/O scheduler and read-ahead tuning  
- GPU performance tuning (Adreno, Mali)  
- Network stack optimization  
- Kernel-level performance tweaks  
- Logging system  
- Boot-time execution  

---

## Compatibility

- Android 5.0 and above  
- Root required:
  - Magisk  
  - KernelSU  
  - APatch  

Supported chipsets:

- Qualcomm  
- MediaTek  
- Exynos  
- Google Tensor  
- Unisoc  

---

## Warning

This module applies aggressive performance tuning.

- It may increase device temperature  
- It may reduce battery life  
- It may cause instability on unsupported kernels  

**Use at your own risk.**  
You are responsible for any damage, data loss, or unexpected behavior.

---

## Tuned Components

### CPU
- Governor selection  
- Frequency scaling  
- Input boost  

### Scheduler
- uclamp tuning  
- schedtune boost  
- latency adjustments  

### Memory
- Swappiness  
- Dirty ratio  
- Cache pressure  
- Extra free memory  

### Storage (I/O)
- Scheduler selection  
- Read-ahead tuning  

### GPU
- Adreno tuning  
- Mali policy tuning  

### Network
- TCP buffer tuning  
- Congestion control  

### Kernel
- Disable tracing  
- Reduce logging overhead  

---

## Logging

Log file location:

```
/data/adb/modules/universal-perfmax/perfmax.log
```

---

## Installation

1. Flash via Magisk / KernelSU / APatch  
2. Reboot device  
3. Module will apply tweaks automatically on boot  

---

## Notes

Not all tweaks will apply on every device due to kernel differences.

This module prioritizes performance over power efficiency.

---

## Author

ynzyuyu

---

## Support

If you find this project useful, give it a star.
