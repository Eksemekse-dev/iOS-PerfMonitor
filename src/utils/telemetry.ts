import { TelemetryData } from '../types.ts';

// Detect or formulate realistic iOS device specs matching hw.machine
export function getInitialDeviceInfo(): Partial<TelemetryData> {
  const ua = navigator.userAgent;
  let deviceModel = 'iPhone15,2 (iPhone 14 Pro)';
  let iosVersion = '17.5.1';

  if (/iPhone/i.test(ua)) {
    const match = ua.match(/OS (\d+[._]\d+)/);
    if (match) {
      iosVersion = match[1].replace('_', '.');
    }
    // Apple device heuristics
    const ratio = window.devicePixelRatio;
    if (ratio >= 3) {
      deviceModel = 'iPhone16,1 (iPhone 15 Pro)';
    } else {
      deviceModel = 'iPhone14,5 (iPhone 13)';
    }
  } else if (/iPad/i.test(ua)) {
    deviceModel = 'iPad13,8 (iPad Pro 12.9" M1)';
    iosVersion = '17.5';
  } else if (/Macintosh/i.test(ua)) {
    deviceModel = 'iPhone15,3 (iPhone 14 Pro Max / Sim)';
  }

  // Device RAM detection (Navigator deviceMemory or 6144 MB typical for iPhone Pro)
  const navMemory = (navigator as unknown as { deviceMemory?: number }).deviceMemory;
  const totalDeviceRamMB = navMemory ? navMemory * 1024 : 6144;

  return {
    deviceModel,
    iosVersion,
    bundleId: 'com.livecontainer.iosperfmonitor',
    debuggerAttached: false,
    totalDeviceRamMB,
  };
}

// Format number with one decimal place
export function formatDec(num: number): string {
  return num.toFixed(1);
}

// Thermal state resolver based on CPU usage and allocated stress memory
export function calculateThermalState(cpu: number, ramMB: number): TelemetryData['thermalState'] {
  if (cpu > 85 || ramMB > 2500) {
    return 'Critical!';
  }
  if (cpu > 65 || ramMB > 1500) {
    return 'Hot';
  }
  if (cpu > 40 || ramMB > 800) {
    return 'Warm';
  }
  return 'Normal';
}

// Haptic feedback using Navigator vibrate if available
export function triggerHaptic(type: 'light' | 'medium' | 'heavy' = 'light') {
  if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
    try {
      const pattern = type === 'heavy' ? [40, 20, 60] : type === 'medium' ? 30 : 15;
      navigator.vibrate(pattern);
    } catch {
      // ignore
    }
  }
}
