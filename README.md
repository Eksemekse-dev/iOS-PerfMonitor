# iOS Performance Overlay & Diagnostic Utility

A professional, system-level performance monitoring and diagnostic overlay designed for iOS applications running inside `LiveContainer`. Built as a standalone compiled dynamic library (`.dylib`), it utilizes native `mach` kernel APIs and low-level system calls to provide real-time hardware telemetry and stress-testing capabilities.

---

## Features

- **Floating PiP Monitor**: Real-time tracking of CPU usage, Resident Memory (RAM), and Thermal State. Fully draggable across the screen with auto-bounds correction.
- **Hidden by Default**: The monitor overlay is invisible on startup and can be toggled via a 4-finger gesture.
- **Advanced Diagnostic Dashboard**: A modern, glassmorphism-style full-screen menu displaying detailed system and app specifications.
- **Secure System Telemetry**: 
  - Device model identification (`hw.machine`).
  - iOS version tracking.
  - Isolated `bundleIdentifier` data partitioning.
  - Active anti-debug checks via `ptrace`.
- **RAM Stress-Test & Crash Recovery**: 
  - Gradual memory allocation utility to test system memory limits.
  - Persistent state logging per app container.
  - Automatic Out-Of-Memory (OOM) crash detection and reporting upon subsequent app launch.
- **Export & Sharing**: Native iOS share sheet integration (`UIActivityViewController`) for exporting diagnostic summaries.
- **Clipboard Integration**: One-tap value copying from any diagnostic tile with haptic feedback.
- **Rotation Safety**: Automatic orientation change suppression while the diagnostic menu is active to prevent layout shifts.

---

## Gesture Controls

- **4-Finger Tap**: Show or hide the floating Performance PiP monitor.
- **4-Finger Long Press (2s)**: Open the full-screen Performance Dashboard.

---

## Installation & Setup Guide

Follow these steps to properly install and configure the performance overlay within your application environment.

### Step 1
Download the latest compiled binary (`.dylib`) file from the repository Releases section.

### Step 2
![Step 2 Setup](help/2.heic)

### Step 3
![Step 3 Setup](help/3.heic)

### Step 4
![Step 4 Setup](help/4.heic)

### Step 5
![Step 5 Setup](help/5.heic)

---

## Technical Architecture

Compiled via `clang` for `iphoneos`, the library injects directly into the target process lifecycle, establishing an independent high-priority `UIWindow` (`UIWindowLevelAlert`) that persists across application view transitions without interfering with the host app's UI hierarchy.
