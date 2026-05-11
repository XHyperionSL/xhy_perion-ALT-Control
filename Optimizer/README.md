# 🌌 HYPERION MULTI-INSTANCE OPTIMIZER

![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-blue?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/Access-Administrator-red?style=for-the-badge&logo=windows-terminal)

A high-performance optimization utility designed specifically for managing multiple Roblox instances. Hyperion automatically detects your main account and aggressively optimizes background "Alt" accounts to maximize CPU and RAM efficiency.

---

## 🛠️ How It Works

This uses an intelligent instance detection system to ensure your gameplay remains smooth while bots or alts run silently in the background.

*   **Main Account Protection**: The **FIRST** Roblox window you open is automatically flagged as your "MAIN". Hyperion will never touch, minimize, or throttle this process.
*   **Alt Detection**: Every subsequent Roblox window opened after the first is marked as an "ALT".
*   **Aggressive Optimization**: After a 30-second loading grace period, ALTs are:
    *   Forced to minimize (reducing GPU load).
    *   Assigned to specific background CPU cores (preventing main-thread stutter).
    *   RAM-trimmed using aggressive memory management calls.

---

## 🚀 How To Use

1.  **Launch Main**: Open your **MAIN** Roblox account first and wait for it to fully load into the game.
2.  **Launch Alts**: Open all your **ALT** accounts.
3.  **Run Optimizer**: Double-click `RunOptimizer.bat`.
4.  **Grant Access**: Click **"Yes"** on the Administrator prompt. (Elevated privileges are required to manage process memory and CPU affinity).

---

## ⚙️ Configuration

Upon the first execution, a file named `HyperionOptimizer.config.json` will be generated in the root directory. You can customize the following parameters:

```json
{
  "memory_limit_mb": 512,
  "load_delay_seconds": 30,
  "cpu_core_limit": 2,
  "auto_minimize": true
}
```

*   **Memory Limits**: Control exactly how much RAM alts are allowed to consume.
*   **Optimization Delay**: Change how long Hyperion waits before throttling a new window.
*   **CPU Affinity**: Restrict bots to a specific number of cores to keep your primary cores free.

---

## 📋 Requirements

*   **Operating System**: Windows 10 or Windows 11.
*   **Privileges**: Administrator rights are **mandatory**.
*   **Hardware**: Recommended 8GB+ RAM for multi-instance stability.

---

<p align="center">
  <i>Optimized for performance. Built for power users.</i>
</p>
