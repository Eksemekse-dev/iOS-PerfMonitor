export interface TelemetryData {
  cpuUsage: number; // percentage, e.g. 14.8
  ramMB: number; // megabytes, e.g. 52.4
  thermalState: 'Normal' | 'Warm' | 'Hot' | 'Critical!';
  fps: number; // frames per second, e.g. 60
  deviceModel: string;
  iosVersion: string;
  bundleId: string;
  debuggerAttached: boolean;
  totalDeviceRamMB: number;
}

export interface StressTestState {
  status: 'idle' | 'running' | 'crashed' | 'completed';
  allocatedMB: number;
  maxMBReached?: number;
  timestamp?: number;
}

export interface DiagnosticItem {
  id: string;
  icon: string;
  title: string;
  value: string;
  detail?: string;
}
