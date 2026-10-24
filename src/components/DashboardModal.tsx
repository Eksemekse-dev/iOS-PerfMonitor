import React, { useState, useMemo } from 'react';
import { TelemetryData, PipSettings } from '../types.ts';
import { formatDec, triggerHaptic } from '../utils/telemetry.ts';
import {
  Smartphone,
  Settings,
  Layers,
  Bug,
  Cpu,
  Database,
  HardDrive,
  Gauge,
  Flame,
  Globe,
  Sliders,
  Palette,
  Eye,
  RotateCcw,
  Maximize2,
  Folder,
  FileText,
  FileCode,
  FileSpreadsheet,
  ChevronRight,
  ArrowUp,
  Share2,
  Copy,
  Check,
  Search,
  Zap,
  Activity,
  File,
  X,
  Home,
  BookOpen,
  Package,
} from 'lucide-react';

interface DashboardModalProps {
  telemetry: TelemetryData;
  settings: PipSettings;
  isOpen: boolean;
  onClose: () => void;
  onRunStressTest: () => void;
  onUpdateSettings: (newSettings: PipSettings) => void;
}

// Preset color options for quick picking
const COLOR_PRESETS = [
  { name: 'OLED Black', hex: '#000000' },
  { name: 'Dark Slate', hex: '#0f172a' },
  { name: 'Cyber Cyan', hex: '#083344' },
  { name: 'Neon Purple', hex: '#2e1065' },
  { name: 'Emerald', hex: '#064e3b' },
  { name: 'Crimson', hex: '#450a0a' },
  { name: 'Frosted Smoke', hex: '#262626' },
];

const ACCENT_PRESETS = [
  { name: 'Sky Cyan', hex: '#38bdf8' },
  { name: 'Emerald', hex: '#34d399' },
  { name: 'Violet', hex: '#a78bfa' },
  { name: 'Amber', hex: '#fbbf24' },
  { name: 'Rose', hex: '#fb7185' },
  { name: 'White', hex: '#ffffff' },
];

interface VirtualFile {
  name: string;
  type: 'dir' | 'file';
  size?: string;
  date?: string;
  content?: string;
  isImage?: boolean;
}

// Built-in non-root file system structure for realistic iOS browsing
const VIRTUAL_FS: Record<string, VirtualFile[]> = {
  '/var/mobile/Containers/Data/Application': [
    { name: 'com.livecontainer.iosperfmonitor', type: 'dir', date: 'Oct 24, 2026' },
    { name: 'com.apple.mobilesafari', type: 'dir', date: 'Oct 20, 2026' },
  ],
  '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor': [
    { name: 'Documents', type: 'dir', date: 'Today, 14:15' },
    { name: 'Library', type: 'dir', date: 'Today, 14:10' },
    { name: 'tmp', type: 'dir', date: 'Today, 14:28' },
    { name: 'SystemData', type: 'dir', date: 'Oct 22, 2026' },
  ],
  '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/Documents': [
    {
      name: 'perf_monitor_tutorial_v7.flag',
      type: 'file',
      size: '9 B',
      date: 'Today, 14:12',
      content: 'completed\nflag_version=7\nauto_dismiss_enabled=true\n',
    },
    {
      name: 'telemetry_session_log.json',
      type: 'file',
      size: '1.2 KB',
      date: 'Today, 14:25',
      content: '{\n  "session_id": "live-session-8821",\n  "app": "LiveContainer Guest",\n  "cpu_peak": 44.2,\n  "gpu_peak": 58.1,\n  "ram_peak_mb": 68.4,\n  "jit_status": "active"\n}',
    },
    {
      name: 'crash_reporting.plist',
      type: 'file',
      size: '412 B',
      date: 'Today, 13:50',
      content: '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n  <key>OOMProtectionEnabled</key>\n  <true/>\n  <key>MaxSafeRAM_MB</key>\n  <integer>3072</integer>\n</dict>\n</plist>',
    },
  ],
  '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/Library': [
    { name: 'Preferences', type: 'dir', date: 'Today, 14:02' },
    { name: 'Caches', type: 'dir', date: 'Today, 14:05' },
    { name: 'Application Support', type: 'dir', date: 'Oct 22, 2026' },
  ],
  '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/Library/Preferences': [
    {
      name: 'com.livecontainer.iosperfmonitor.plist',
      type: 'file',
      size: '864 B',
      date: 'Today, 14:28',
      content: '{\n  "perf_pip_opacity": 0.85,\n  "perf_pip_scale": 1.0,\n  "perf_pip_color_idx": 0,\n  "perf_show_cpu": true,\n  "perf_show_gpu": true,\n  "perf_show_ram": true,\n  "perf_show_temp": true,\n  "perf_show_fps": true,\n  "perf_dark_mode": true\n}',
    },
  ],
  '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/Library/Caches': [
    { name: 'Snapshots', type: 'dir', date: 'Today, 14:00' },
    {
      name: 'cached_gpu_shaders.bin',
      type: 'file',
      size: '148 KB',
      date: 'Today, 14:10',
      content: '[Binary AGX/Metal Compiled Shader Cache - 148,480 bytes]',
    },
  ],
  '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/tmp': [
    {
      name: 'active_monitor_buffer.tmp',
      type: 'file',
      size: '34 KB',
      date: 'Just now',
      content: 'PerfMonitor Ring Buffer: 120 samples recorded. Frametime jitter: 0.2ms.',
    },
  ],
  '/var/mobile/Containers/Bundle/Application/PerfMonitor.app': [
    {
      name: 'Info.plist',
      type: 'file',
      size: '1.4 KB',
      date: 'Oct 23, 2026',
      content: '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0">\n<dict>\n  <key>CFBundleIdentifier</key>\n  <string>com.livecontainer.iosperfmonitor</string>\n  <key>CFBundleName</key>\n  <string>PerfMonitor</string>\n  <key>CFBundleShortVersionString</key>\n  <string>3.0</string>\n</dict>\n</plist>',
    },
    {
      name: 'PerfMonitor.dylib',
      type: 'file',
      size: '141 KB',
      date: 'Oct 23, 2026',
      content: '[Mach-O 64-bit arm64 dynamically linked shared library, signed with ldid -S]',
    },
  ],
};

export const DashboardModal: React.FC<DashboardModalProps> = ({
  telemetry,
  settings,
  isOpen,
  onClose,
  onRunStressTest,
  onUpdateSettings,
}) => {
  const [activeTab, setActiveTab] = useState<'diagnostics' | 'settings' | 'files'>('diagnostics');
  const [copiedToast, setCopiedToast] = useState<string | null>(null);

  // File Manager state
  const [currentPath, setCurrentPath] = useState<string>(
    '/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor'
  );
  const [fileSearchQuery, setFileSearchQuery] = useState<string>('');
  const [selectedFile, setSelectedFile] = useState<VirtualFile | null>(null);

  if (!isOpen) return null;

  const currentFolderItems = useMemo(() => {
    const list = VIRTUAL_FS[currentPath] || [];
    if (!fileSearchQuery.trim()) return list;
    return list.filter((i) => i.name.toLowerCase().includes(fileSearchQuery.toLowerCase()));
  }, [currentPath, fileSearchQuery]);

  const diagnosticSummary = `📊 PerfMonitor Diagnostics
------------------------
Device Model: ${telemetry.deviceModel}
iOS Version: ${telemetry.iosVersion}
Bundle ID: ${telemetry.bundleId}
Debugger Attached: ${telemetry.debuggerAttached ? 'Yes' : 'No'}
JIT Engine: Active
Memory+ Kernel: Active
App RAM Usage: ${formatDec(telemetry.ramMB)} MB
Total Device RAM: ${telemetry.totalDeviceRamMB} MB
CPU Usage: ${formatDec(telemetry.cpuUsage)}%
GPU Usage: ${formatDec(telemetry.gpuUsage)}%
Render FPS: ${formatDec(telemetry.fps)} FPS
Thermal State: ${telemetry.thermalState}`;

  const handleCopyRow = (val: string, label: string) => {
    triggerHaptic('light');
    navigator.clipboard.writeText(val).catch(() => {});
    showToast(`Copied ${label} to clipboard!`);
  };

  const handleShareSummary = async () => {
    triggerHaptic('light');
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'iOS PerfMonitor Diagnostics',
          text: diagnosticSummary,
        });
        return;
      } catch {
        // Fallback
      }
    }
    navigator.clipboard.writeText(diagnosticSummary).catch(() => {});
    showToast('Diagnostic summary copied to clipboard!');
  };

  const showToast = (msg: string) => {
    setCopiedToast(msg);
    setTimeout(() => {
      setCopiedToast(null);
    }, 2000);
  };

  const handleResetSettings = () => {
    triggerHaptic('medium');
    onUpdateSettings({
      opacity: 0.85,
      scale: 1.0,
      bgColor: '#000000',
      accentColor: '#38bdf8',
      showCpu: true,
      showGpu: true,
      showRam: true,
      showThermal: true,
      showFps: false,
      showModel: false,
    });
    showToast('Settings reset to default!');
  };

  const navigateUp = () => {
    triggerHaptic('light');
    const parts = currentPath.split('/').filter(Boolean);
    if (parts.length > 1) {
      parts.pop();
      const parent = '/' + parts.join('/');
      if (VIRTUAL_FS[parent]) {
        setCurrentPath(parent);
      } else {
        setCurrentPath('/var/mobile/Containers/Data/Application');
      }
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-2 sm:p-4 bg-black/60 backdrop-blur-xl animate-in fade-in duration-200">
      {/* Toast Notification */}
      {copiedToast && (
        <div className="absolute top-6 left-1/2 -translate-x-1/2 z-50 px-4 py-2 rounded-full bg-neutral-900/95 text-white text-xs font-semibold shadow-2xl border border-white/20 animate-in fade-in slide-in-from-top-2 flex items-center gap-2">
          <Check className="w-3.5 h-3.5 text-cyan-400" />
          <span>{copiedToast}</span>
        </div>
      )}

      {/* Main Container - iOS Settings Inset Grouped Style */}
      <div className="relative w-full max-w-lg h-[92vh] max-h-[740px] rounded-[38px] bg-[#000000]/90 text-white flex flex-col overflow-hidden shadow-2xl border border-white/15">
        
        {/* iOS Navigation Bar */}
        <div className="px-5 pt-4 pb-2.5 shrink-0 flex items-center justify-between border-b border-white/[0.08] bg-neutral-900/40 backdrop-blur-md">
          {/* Left Action (Share) */}
          <button
            onClick={handleShareSummary}
            title="Share Diagnostics"
            className="p-2 rounded-full text-cyan-400 hover:bg-white/10 active:scale-95 transition-all"
          >
            <Share2 className="w-5 h-5" />
          </button>

          {/* Center Navigation Title */}
          <div className="text-center">
            <h2 className="text-[17px] font-semibold text-white tracking-tight">
              Secret Menu
            </h2>
            <p className="text-[11px] font-medium text-neutral-400">
              Settings & Diagnostics
            </p>
          </div>

          {/* Right Action (Done Button) */}
          <button
            onClick={() => {
              triggerHaptic('light');
              onClose();
            }}
            className="px-3 py-1 rounded-full text-[15px] font-semibold text-cyan-400 hover:bg-cyan-500/10 active:scale-95 transition-all"
          >
            Done
          </button>
        </div>

        {/* Native iOS Segmented Control */}
        <div className="px-5 pt-3 pb-2 shrink-0">
          <div className="w-full p-1 rounded-xl bg-white/[0.09] flex items-center text-xs font-semibold">
            <button
              onClick={() => {
                triggerHaptic('light');
                setActiveTab('diagnostics');
              }}
              className={`flex-1 py-1.5 rounded-lg transition-all text-center ${
                activeTab === 'diagnostics'
                  ? 'bg-neutral-800 text-white shadow-md'
                  : 'text-neutral-400 hover:text-white'
              }`}
            >
              Diagnostics
            </button>
            <button
              onClick={() => {
                triggerHaptic('light');
                setActiveTab('settings');
              }}
              className={`flex-1 py-1.5 rounded-lg transition-all text-center ${
                activeTab === 'settings'
                  ? 'bg-neutral-800 text-white shadow-md'
                  : 'text-neutral-400 hover:text-white'
              }`}
            >
              PiP Settings
            </button>
            <button
              onClick={() => {
                triggerHaptic('light');
                setActiveTab('files');
              }}
              className={`flex-1 py-1.5 rounded-lg transition-all text-center flex items-center justify-center gap-1.5 ${
                activeTab === 'files'
                  ? 'bg-neutral-800 text-white shadow-md'
                  : 'text-neutral-400 hover:text-white'
              }`}
            >
              <Folder className="w-3.5 h-3.5" />
              <span>Files</span>
            </button>
          </div>
        </div>

        {/* ================= TAB 1: DIAGNOSTICS (iOS Inset Grouped) ================= */}
        {activeTab === 'diagnostics' && (
          <div className="flex-1 overflow-y-auto px-5 py-3 space-y-5">
            {/* Section 1: Device & Platform */}
            <div>
              <div className="px-3 pb-1.5 text-[12px] font-medium tracking-wider text-neutral-400 uppercase">
                Device & Hardware
              </div>
              <div className="rounded-2xl bg-neutral-900/80 border border-white/[0.08] overflow-hidden divide-y divide-white/[0.06]">
                {/* Row: Device Model */}
                <div
                  onClick={() => handleCopyRow(telemetry.deviceModel, 'Device Model')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-blue-500/20 text-blue-400 flex items-center justify-center">
                      <Smartphone className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">Device Model</span>
                  </div>
                  <span className="text-[14px] text-neutral-400 font-mono">
                    {telemetry.deviceModel}
                  </span>
                </div>

                {/* Row: iOS Version */}
                <div
                  onClick={() => handleCopyRow(telemetry.iosVersion, 'iOS Version')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-neutral-600/30 text-neutral-300 flex items-center justify-center">
                      <Settings className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">iOS Version</span>
                  </div>
                  <span className="text-[14px] text-neutral-400 font-mono">
                    {telemetry.iosVersion}
                  </span>
                </div>

                {/* Row: Bundle ID */}
                <div
                  onClick={() => handleCopyRow(telemetry.bundleId, 'Bundle ID')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-orange-500/20 text-orange-400 flex items-center justify-center">
                      <Layers className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">Bundle ID</span>
                  </div>
                  <span className="text-[13px] text-neutral-400 font-mono truncate max-w-[170px]">
                    {telemetry.bundleId}
                  </span>
                </div>

                {/* Row: JIT & Kernel */}
                <div
                  onClick={() => handleCopyRow('Active (JIT Enabled)', 'JIT Engine')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
                      <Zap className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">JIT Compilation</span>
                  </div>
                  <span className="text-[14px] text-emerald-400 font-semibold">
                    Enabled
                  </span>
                </div>
              </div>
            </div>

            {/* Section 2: Real-time Performance Vitals */}
            <div>
              <div className="px-3 pb-1.5 text-[12px] font-medium tracking-wider text-neutral-400 uppercase">
                Performance & Memory Vitals
              </div>
              <div className="rounded-2xl bg-neutral-900/80 border border-white/[0.08] overflow-hidden divide-y divide-white/[0.06]">
                {/* Row: CPU */}
                <div
                  onClick={() => handleCopyRow(`${formatDec(telemetry.cpuUsage)}%`, 'CPU')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-cyan-500/20 text-cyan-400 flex items-center justify-center">
                      <Cpu className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">CPU Usage</span>
                  </div>
                  <span className="text-[14px] font-bold text-cyan-400 font-mono">
                    {formatDec(telemetry.cpuUsage)}%
                  </span>
                </div>

                {/* Row: GPU Usage */}
                <div
                  onClick={() => handleCopyRow(`${formatDec(telemetry.gpuUsage)}%`, 'GPU')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-amber-500/20 text-amber-400 flex items-center justify-center">
                      <Activity className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">GPU Utilization</span>
                  </div>
                  <span className="text-[14px] font-bold text-amber-300 font-mono">
                    {formatDec(telemetry.gpuUsage)}%
                  </span>
                </div>

                {/* Row: App RAM */}
                <div
                  onClick={() => handleCopyRow(`${formatDec(telemetry.ramMB)} MB`, 'RAM')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-purple-500/20 text-purple-400 flex items-center justify-center">
                      <Database className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">Resident App RAM</span>
                  </div>
                  <span className="text-[14px] font-bold text-purple-300 font-mono">
                    {formatDec(telemetry.ramMB)} MB
                  </span>
                </div>

                {/* Row: Total Device RAM */}
                <div
                  onClick={() => handleCopyRow(`${telemetry.totalDeviceRamMB} MB`, 'Total RAM')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
                      <HardDrive className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">Physical Memory</span>
                  </div>
                  <span className="text-[14px] text-neutral-400 font-mono">
                    {telemetry.totalDeviceRamMB} MB
                  </span>
                </div>

                {/* Row: FPS */}
                <div
                  onClick={() => handleCopyRow(`${formatDec(telemetry.fps)} FPS`, 'FPS')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
                      <Gauge className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">DisplayLink FPS</span>
                  </div>
                  <span className="text-[14px] font-bold text-emerald-400 font-mono">
                    {formatDec(telemetry.fps)}
                  </span>
                </div>

                {/* Row: Thermal State */}
                <div
                  onClick={() => handleCopyRow(telemetry.thermalState, 'Thermal')}
                  className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-7 h-7 rounded-lg bg-rose-500/20 text-rose-400 flex items-center justify-center">
                      <Flame className="w-4 h-4" />
                    </div>
                    <span className="text-[15px] font-medium text-white">Thermal State</span>
                  </div>
                  <span className="text-[14px] font-bold text-neutral-300">
                    {telemetry.thermalState}
                  </span>
                </div>
              </div>
            </div>

            {/* Section 3: Diagnostic Action */}
            <div className="pt-2">
              <button
                onClick={() => {
                  triggerHaptic('medium');
                  onRunStressTest();
                }}
                className="w-full py-3.5 px-4 rounded-2xl bg-red-600 hover:bg-red-500 active:bg-red-700 text-white font-semibold text-[15px] transition-all flex items-center justify-center gap-2 active:scale-[0.98] shadow-lg shadow-red-950/40"
              >
                <Flame className="w-4 h-4" />
                <span>Run RAM Stress Test (OOM)</span>
              </button>
            </div>
          </div>
        )}

        {/* ================= TAB 2: PIP SETTINGS (iOS Inset Grouped) ================= */}
        {activeTab === 'settings' && (
          <div className="flex-1 overflow-y-auto px-5 py-3 space-y-5">
            {/* Live Preview Section */}
            <div>
              <div className="px-3 pb-1.5 text-[12px] font-medium tracking-wider text-neutral-400 uppercase">
                Live PiP Preview
              </div>
              <div className="p-4 rounded-2xl bg-neutral-900/80 border border-white/[0.08] flex flex-col items-center justify-center min-h-[140px] overflow-hidden">
                <div
                  style={{
                    backgroundColor: settings.bgColor,
                    opacity: settings.opacity,
                    borderColor: settings.accentColor,
                    transform: `scale(${settings.scale || 1.0})`,
                    transformOrigin: 'center center',
                  }}
                  className="w-40 rounded-[14px] p-2.5 border backdrop-blur-md shadow-2xl flex flex-col items-center justify-center text-[11px] font-mono font-semibold transition-all duration-150"
                >
                  {settings.showCpu && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-white/70">CPU:</span>
                      <span style={{ color: settings.accentColor }}>14.8%</span>
                    </div>
                  )}
                  {settings.showGpu && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-white/70">GPU:</span>
                      <span className="text-amber-300">28.5%</span>
                    </div>
                  )}
                  {settings.showRam && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-white/70">RAM:</span>
                      <span className="text-purple-300">52.4 MB</span>
                    </div>
                  )}
                  {settings.showThermal && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-white/70">Temp:</span>
                      <span className="text-emerald-400">Normal</span>
                    </div>
                  )}
                  {settings.showFps && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-white/70">FPS:</span>
                      <span className="text-emerald-400">60.0</span>
                    </div>
                  )}
                </div>
                <div className="text-[11px] text-neutral-400 font-mono mt-3">
                  Scale: {Math.round((settings.scale || 1.0) * 100)}% • Opacity: {Math.round(settings.opacity * 100)}%
                </div>
              </div>
            </div>

            {/* Sliders: Size & Opacity */}
            <div>
              <div className="px-3 pb-1.5 text-[12px] font-medium tracking-wider text-neutral-400 uppercase">
                Dimensions & Appearance
              </div>
              <div className="p-4 rounded-2xl bg-neutral-900/80 border border-white/[0.08] space-y-4">
                {/* Size Slider */}
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between text-[14px]">
                    <span className="font-medium text-white flex items-center gap-2">
                      <Maximize2 className="w-4 h-4 text-emerald-400" />
                      PiP Size Scale
                    </span>
                    <span className="font-mono font-bold text-emerald-400">
                      {Math.round((settings.scale || 1.0) * 100)}%
                    </span>
                  </div>
                  <input
                    type="range"
                    min="0.65"
                    max="1.35"
                    step="0.05"
                    value={settings.scale || 1.0}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, scale: parseFloat(e.target.value) })
                    }
                    className="w-full h-2 bg-neutral-800 rounded-lg appearance-none cursor-pointer accent-emerald-400"
                  />
                  <div className="flex justify-between text-[10px] text-neutral-500 font-mono">
                    <span>65% (Compact)</span>
                    <span>100% (Standard)</span>
                    <span>135% (Large)</span>
                  </div>
                </div>

                {/* Opacity Slider */}
                <div className="space-y-1.5 pt-2 border-t border-white/[0.06]">
                  <div className="flex items-center justify-between text-[14px]">
                    <span className="font-medium text-white flex items-center gap-2">
                      <Sliders className="w-4 h-4 text-cyan-400" />
                      PiP Opacity
                    </span>
                    <span className="font-mono font-bold text-cyan-400">
                      {Math.round(settings.opacity * 100)}%
                    </span>
                  </div>
                  <input
                    type="range"
                    min="0.2"
                    max="1.0"
                    step="0.05"
                    value={settings.opacity}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, opacity: parseFloat(e.target.value) })
                    }
                    className="w-full h-2 bg-neutral-800 rounded-lg appearance-none cursor-pointer accent-cyan-400"
                  />
                  <div className="flex justify-between text-[10px] text-neutral-500 font-mono">
                    <span>20% (Subtle)</span>
                    <span>50%</span>
                    <span>85%</span>
                    <span>100% (Solid)</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Color Presets */}
            <div>
              <div className="px-3 pb-1.5 text-[12px] font-medium tracking-wider text-neutral-400 uppercase">
                Background Color Theme
              </div>
              <div className="p-4 rounded-2xl bg-neutral-900/80 border border-white/[0.08]">
                <div className="grid grid-cols-3 gap-2.5">
                  {COLOR_PRESETS.map((color) => {
                    const isSelected = settings.bgColor.toLowerCase() === color.hex.toLowerCase();
                    return (
                      <button
                        key={color.name}
                        onClick={() => {
                          triggerHaptic('light');
                          onUpdateSettings({ ...settings, bgColor: color.hex });
                        }}
                        style={{ backgroundColor: color.hex }}
                        className={`h-10 rounded-xl px-2.5 flex items-center justify-between border text-[12px] font-medium transition-all ${
                          isSelected
                            ? 'border-cyan-400 ring-2 ring-cyan-400/40'
                            : 'border-white/20 hover:border-white/40'
                        }`}
                      >
                        <span className="truncate">{color.name}</span>
                        {isSelected && <Check className="w-3.5 h-3.5 text-cyan-400 shrink-0" />}
                      </button>
                    );
                  })}
                </div>
              </div>
            </div>

            {/* Visible Metrics Toggles (iOS Switch Style) */}
            <div>
              <div className="px-3 pb-1.5 text-[12px] font-medium tracking-wider text-neutral-400 uppercase">
                Visible Metrics in PiP
              </div>
              <div className="rounded-2xl bg-neutral-900/80 border border-white/[0.08] overflow-hidden divide-y divide-white/[0.06]">
                {/* CPU Toggle */}
                <div className="px-4 py-3 flex items-center justify-between">
                  <span className="text-[15px] font-medium text-white">Show CPU Usage</span>
                  <input
                    type="checkbox"
                    checked={settings.showCpu}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, showCpu: e.target.checked })
                    }
                    className="w-11 h-6 rounded-full appearance-none bg-neutral-700 checked:bg-cyan-500 transition-colors relative cursor-pointer before:content-[''] before:absolute before:top-0.5 before:left-0.5 before:w-5 before:h-5 before:rounded-full before:bg-white before:transition-transform checked:before:translate-x-5"
                  />
                </div>

                {/* GPU Toggle */}
                <div className="px-4 py-3 flex items-center justify-between">
                  <span className="text-[15px] font-medium text-white">Show GPU Usage</span>
                  <input
                    type="checkbox"
                    checked={settings.showGpu}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, showGpu: e.target.checked })
                    }
                    className="w-11 h-6 rounded-full appearance-none bg-neutral-700 checked:bg-amber-500 transition-colors relative cursor-pointer before:content-[''] before:absolute before:top-0.5 before:left-0.5 before:w-5 before:h-5 before:rounded-full before:bg-white before:transition-transform checked:before:translate-x-5"
                  />
                </div>

                {/* RAM Toggle */}
                <div className="px-4 py-3 flex items-center justify-between">
                  <span className="text-[15px] font-medium text-white">Show RAM Usage</span>
                  <input
                    type="checkbox"
                    checked={settings.showRam}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, showRam: e.target.checked })
                    }
                    className="w-11 h-6 rounded-full appearance-none bg-neutral-700 checked:bg-purple-500 transition-colors relative cursor-pointer before:content-[''] before:absolute before:top-0.5 before:left-0.5 before:w-5 before:h-5 before:rounded-full before:bg-white before:transition-transform checked:before:translate-x-5"
                  />
                </div>

                {/* Thermal Toggle */}
                <div className="px-4 py-3 flex items-center justify-between">
                  <span className="text-[15px] font-medium text-white">Show Thermal State</span>
                  <input
                    type="checkbox"
                    checked={settings.showThermal}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, showThermal: e.target.checked })
                    }
                    className="w-11 h-6 rounded-full appearance-none bg-neutral-700 checked:bg-rose-500 transition-colors relative cursor-pointer before:content-[''] before:absolute before:top-0.5 before:left-0.5 before:w-5 before:h-5 before:rounded-full before:bg-white before:transition-transform checked:before:translate-x-5"
                  />
                </div>

                {/* FPS Toggle */}
                <div className="px-4 py-3 flex items-center justify-between">
                  <span className="text-[15px] font-medium text-white">Show Render FPS</span>
                  <input
                    type="checkbox"
                    checked={settings.showFps}
                    onChange={(e) =>
                      onUpdateSettings({ ...settings, showFps: e.target.checked })
                    }
                    className="w-11 h-6 rounded-full appearance-none bg-neutral-700 checked:bg-emerald-500 transition-colors relative cursor-pointer before:content-[''] before:absolute before:top-0.5 before:left-0.5 before:w-5 before:h-5 before:rounded-full before:bg-white before:transition-transform checked:before:translate-x-5"
                  />
                </div>
              </div>
            </div>

            {/* Reset Button */}
            <div className="pt-1">
              <button
                onClick={handleResetSettings}
                className="w-full py-3 px-4 rounded-2xl bg-neutral-900 border border-white/10 hover:bg-neutral-800 text-neutral-300 font-medium text-[14px] transition-all flex items-center justify-center gap-2"
              >
                <RotateCcw className="w-4 h-4 text-neutral-400" />
                <span>Reset to Default Settings</span>
              </button>
            </div>
          </div>
        )}

        {/* ================= TAB 3: FILE MANAGER (Bez Root) ================= */}
        {activeTab === 'files' && (
          <div className="flex-1 overflow-y-auto px-5 py-3 space-y-4">
            {/* Quick Shortcuts Bar */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs">
              <button
                onClick={() => {
                  triggerHaptic('light');
                  setCurrentPath('/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor');
                }}
                className="px-2.5 py-1.5 rounded-lg bg-neutral-900 border border-white/10 text-cyan-400 font-medium flex items-center gap-1 shrink-0 hover:bg-neutral-800"
              >
                <Home className="w-3.5 h-3.5" />
                <span>Sandbox</span>
              </button>
              <button
                onClick={() => {
                  triggerHaptic('light');
                  setCurrentPath('/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/Documents');
                }}
                className="px-2.5 py-1.5 rounded-lg bg-neutral-900 border border-white/10 text-neutral-300 font-medium flex items-center gap-1 shrink-0 hover:bg-neutral-800"
              >
                <FileText className="w-3.5 h-3.5" />
                <span>Documents</span>
              </button>
              <button
                onClick={() => {
                  triggerHaptic('light');
                  setCurrentPath('/var/mobile/Containers/Data/Application/com.livecontainer.iosperfmonitor/Library');
                }}
                className="px-2.5 py-1.5 rounded-lg bg-neutral-900 border border-white/10 text-neutral-300 font-medium flex items-center gap-1 shrink-0 hover:bg-neutral-800"
              >
                <BookOpen className="w-3.5 h-3.5" />
                <span>Library</span>
              </button>
              <button
                onClick={() => {
                  triggerHaptic('light');
                  setCurrentPath('/var/mobile/Containers/Bundle/Application/PerfMonitor.app');
                }}
                className="px-2.5 py-1.5 rounded-lg bg-neutral-900 border border-white/10 text-purple-400 font-medium flex items-center gap-1 shrink-0 hover:bg-neutral-800"
              >
                <Package className="w-3.5 h-3.5" />
                <span>Bundle</span>
              </button>
            </div>

            {/* Current Path Bar & Up Button */}
            <div className="p-3 rounded-2xl bg-neutral-900/90 border border-white/[0.08] flex items-center justify-between gap-2">
              <div className="flex items-center gap-2 overflow-hidden flex-1">
                <Folder className="w-4 h-4 text-cyan-400 shrink-0" />
                <span className="text-[12px] font-mono text-neutral-300 truncate">
                  {currentPath}
                </span>
              </div>
              <button
                onClick={navigateUp}
                title="Go Up"
                className="p-1.5 rounded-lg bg-white/10 text-white hover:bg-white/20 active:scale-95 transition-all shrink-0"
              >
                <ArrowUp className="w-4 h-4" />
              </button>
            </div>

            {/* Search Input */}
            <div className="relative">
              <Search className="w-4 h-4 text-neutral-500 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search files in directory..."
                value={fileSearchQuery}
                onChange={(e) => setFileSearchQuery(e.target.value)}
                className="w-full pl-9 pr-4 py-2 rounded-xl bg-neutral-900 border border-white/10 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-cyan-500"
              />
            </div>

            {/* Files & Directories Inset List */}
            <div className="rounded-2xl bg-neutral-900/80 border border-white/[0.08] overflow-hidden divide-y divide-white/[0.06]">
              {currentFolderItems.length === 0 ? (
                <div className="p-6 text-center text-xs text-neutral-500">
                  Folder is empty or contents are restricted by iOS sandbox
                </div>
              ) : (
                currentFolderItems.map((item) => (
                  <div
                    key={item.name}
                    onClick={() => {
                      triggerHaptic('light');
                      if (item.type === 'dir') {
                        setCurrentPath(`${currentPath}/${item.name}`);
                      } else {
                        setSelectedFile(item);
                      }
                    }}
                    className="px-4 py-3 flex items-center justify-between active:bg-white/[0.06] cursor-pointer transition-colors"
                  >
                    <div className="flex items-center gap-3 overflow-hidden">
                      <div
                        className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${
                          item.type === 'dir'
                            ? 'bg-blue-500/20 text-blue-400'
                            : 'bg-neutral-800 text-neutral-300'
                        }`}
                      >
                        {item.type === 'dir' ? (
                          <Folder className="w-4 h-4" />
                        ) : (
                          <FileText className="w-4 h-4" />
                        )}
                      </div>
                      <div className="overflow-hidden">
                        <div className="text-[14px] font-medium text-white truncate">
                          {item.name}
                        </div>
                        <div className="text-[11px] text-neutral-500 font-mono">
                          {item.date || 'Regular file'}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                      {item.size && (
                        <span className="text-[12px] font-mono text-neutral-400">
                          {item.size}
                        </span>
                      )}
                      <ChevronRight className="w-4 h-4 text-neutral-600" />
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}

        {/* Footer info & GitHub button */}
        <div className="px-5 py-3 border-t border-white/[0.08] bg-neutral-950 flex items-center justify-between text-xs text-neutral-400">
          <span>Created by Eksemekse-dev with AI • v3.0</span>
          <a
            href="https://github.com/Eksemekse-dev/iOS-PerfMonitor"
            target="_blank"
            rel="noopener noreferrer"
            className="px-3 py-1.5 rounded-full bg-cyan-950 text-cyan-300 border border-cyan-500/30 font-semibold flex items-center gap-1.5 hover:bg-cyan-900 transition-colors"
          >
            <Globe className="w-3.5 h-3.5" />
            <span>GitHub</span>
          </a>
        </div>
      </div>

      {/* Quick File Preview Modal */}
      {selectedFile && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="w-full max-w-md max-h-[80vh] rounded-3xl bg-neutral-900 border border-white/20 p-5 flex flex-col shadow-2xl">
            <div className="flex items-center justify-between pb-3 border-b border-white/10">
              <div className="flex items-center gap-2 overflow-hidden">
                <FileText className="w-5 h-5 text-cyan-400 shrink-0" />
                <span className="text-sm font-semibold truncate text-white">
                  {selectedFile.name}
                </span>
              </div>
              <button
                onClick={() => setSelectedFile(null)}
                className="p-1 rounded-full text-neutral-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto py-3">
              <div className="text-[11px] font-mono text-neutral-400 mb-2">
                Size: {selectedFile.size || 'Unknown'} • Type: {selectedFile.name.split('.').pop()?.toUpperCase()}
              </div>
              <pre className="p-3 rounded-xl bg-black/60 text-emerald-400 font-mono text-xs overflow-x-auto whitespace-pre-wrap select-text leading-relaxed border border-white/5">
                {selectedFile.content || 'File binary contents cannot be displayed in text viewer.'}
              </pre>
            </div>

            <div className="pt-3 border-t border-white/10 flex justify-end gap-2">
              <button
                onClick={() => {
                  triggerHaptic('light');
                  if (selectedFile.content) {
                    navigator.clipboard.writeText(selectedFile.content);
                    showToast('File content copied!');
                  }
                }}
                className="px-3.5 py-1.5 rounded-xl bg-white/10 hover:bg-white/20 text-xs font-semibold text-white flex items-center gap-1.5"
              >
                <Copy className="w-3.5 h-3.5" />
                <span>Copy</span>
              </button>
              <button
                onClick={() => setSelectedFile(null)}
                className="px-4 py-1.5 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-xs font-semibold text-white"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
