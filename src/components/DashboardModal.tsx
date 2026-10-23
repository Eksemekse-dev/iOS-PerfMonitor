import React, { useState } from 'react';
import { TelemetryData, PipSettings } from '../types.ts';
import { formatDec, triggerHaptic } from '../utils/telemetry.ts';
import {
  Activity,
  Share2,
  XCircle,
  Smartphone,
  Settings2,
  Layers,
  Bug,
  Cpu,
  Database,
  HardDrive,
  Gauge,
  ExternalLink,
  Check,
  Flame,
  Globe,
  Sliders,
  Palette,
  Eye,
  RotateCcw,
  Maximize2,
} from 'lucide-react';

interface DashboardModalProps {
  telemetry: TelemetryData;
  settings: PipSettings;
  isOpen: boolean;
  onClose: () => void;
  onRunStressTest: () => void;
  onUpdateSettings: (newSettings: PipSettings) => void;
}

const COLOR_PRESETS = [
  { name: 'OLED Black', hex: '#000000' },
  { name: 'Dark Slate', hex: '#161822' },
  { name: 'Cyber Cyan', hex: '#083344' },
  { name: 'Neon Purple', hex: '#2e1065' },
  { name: 'Emerald', hex: '#064e3b' },
  { name: 'Crimson', hex: '#450a0a' },
  { name: 'Frosted Smoke', hex: '#262626' },
];

const ACCENT_PRESETS = [
  { name: 'Cyan', hex: '#38bdf8' },
  { name: 'Emerald', hex: '#34d399' },
  { name: 'Purple', hex: '#c084fc' },
  { name: 'Amber', hex: '#fbbf24' },
  { name: 'Rose', hex: '#fb7185' },
  { name: 'White', hex: '#ffffff' },
];

export const DashboardModal: React.FC<DashboardModalProps> = ({
  telemetry,
  settings,
  isOpen,
  onClose,
  onRunStressTest,
  onUpdateSettings,
}) => {
  const [activeTab, setActiveTab] = useState<'diagnostics' | 'settings'>('diagnostics');
  const [copiedToast, setCopiedToast] = useState<string | null>(null);

  if (!isOpen) return null;

  const items = [
    {
      id: 'model',
      icon: <Smartphone className="w-5 h-5 text-cyan-400" />,
      title: 'Device Model',
      value: telemetry.deviceModel,
    },
    {
      id: 'version',
      icon: <Settings2 className="w-5 h-5 text-cyan-400" />,
      title: 'iOS Version',
      value: telemetry.iosVersion,
    },
    {
      id: 'bundle',
      icon: <Layers className="w-5 h-5 text-cyan-400" />,
      title: 'Bundle ID',
      value: telemetry.bundleId,
    },
    {
      id: 'debugger',
      icon: <Bug className="w-5 h-5 text-cyan-400" />,
      title: 'Debugger Attached',
      value: telemetry.debuggerAttached ? 'Yes (Connected)' : 'No (Clean)',
    },
    {
      id: 'kernel',
      icon: <Cpu className="w-5 h-5 text-cyan-400" />,
      title: 'Memory+ Kernel',
      value: 'Active',
    },
    {
      id: 'appRam',
      icon: <Database className="w-5 h-5 text-cyan-400" />,
      title: 'App RAM Usage',
      value: `${formatDec(telemetry.ramMB)} MB`,
    },
    {
      id: 'totalRam',
      icon: <HardDrive className="w-5 h-5 text-cyan-400" />,
      title: 'Total Device RAM',
      value: `${telemetry.totalDeviceRamMB} MB`,
    },
    {
      id: 'fps',
      icon: <Gauge className="w-5 h-5 text-cyan-400" />,
      title: 'Render Framerate',
      value: `${formatDec(telemetry.fps)} FPS`,
    },
    {
      id: 'thermal',
      icon: <Flame className="w-5 h-5 text-cyan-400" />,
      title: 'Thermal State',
      value: telemetry.thermalState,
    },
  ];

  const diagnosticSummary = `📊 PerfMonitor Diagnostics
------------------------
Device Model: ${telemetry.deviceModel}
iOS Version: ${telemetry.iosVersion}
Bundle ID: ${telemetry.bundleId}
Debugger Attached: ${telemetry.debuggerAttached ? 'Yes' : 'No'}
Memory+ Kernel: Active
App RAM Usage: ${formatDec(telemetry.ramMB)} MB
Total Device RAM: ${telemetry.totalDeviceRamMB} MB
Render FPS: ${formatDec(telemetry.fps)} FPS
Thermal State: ${telemetry.thermalState}`;

  const handleCopyRow = (val: string, label: string) => {
    triggerHaptic('light');
    navigator.clipboard.writeText(val).catch(() => {});
    showToast(`Copied ${label} to clipboard!`);
  };

  const handleShare = async () => {
    triggerHaptic('medium');
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'PerfMonitor Diagnostics',
          text: diagnosticSummary,
        });
        return;
      } catch {
        // Fallback to copy
      }
    }
    navigator.clipboard.writeText(diagnosticSummary);
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
      showRam: true,
      showThermal: true,
      showFps: false,
      showModel: false,
    });
    showToast('Settings reset to default!');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-5 bg-black/60 backdrop-blur-xl animate-in fade-in duration-200">
      {/* Container Card */}
      <div className="relative w-full max-w-[480px] max-h-[92vh] flex flex-col rounded-[26px] bg-[#1e1e22]/95 border border-white/15 shadow-2xl overflow-hidden backdrop-blur-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-4 pb-2 border-b border-white/10 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="p-1.5 rounded-lg bg-blue-500/20 text-blue-400 animate-pulse-slow">
              <Activity className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-[17px] font-bold text-white tracking-tight leading-tight">
                Performance Dashboard
              </h2>
              <div className="text-[11px] text-cyan-400 font-mono">LiveContainer Secret Menu</div>
            </div>
          </div>

          <div className="flex items-center gap-1.5">
            <button
              onClick={handleShare}
              title="Share Diagnostics"
              className="p-2 rounded-full text-blue-400 hover:bg-white/10 transition-colors active:scale-95"
            >
              <Share2 className="w-5 h-5" />
            </button>
            <button
              onClick={onClose}
              title="Close Dashboard"
              className="p-1 rounded-full text-white/50 hover:text-white transition-colors active:scale-95"
            >
              <XCircle className="w-7 h-7" />
            </button>
          </div>
        </div>

        {/* Tab Switcher */}
        <div className="px-5 pt-3 pb-2 flex gap-2 shrink-0 border-b border-white/5 bg-black/20">
          <button
            onClick={() => setActiveTab('diagnostics')}
            className={`flex-1 py-1.5 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all ${
              activeTab === 'diagnostics'
                ? 'bg-blue-600 text-white shadow-md'
                : 'bg-white/5 text-neutral-400 hover:text-white hover:bg-white/10'
            }`}
          >
            <Activity className="w-3.5 h-3.5" />
            <span>Diagnostics</span>
          </button>
          <button
            onClick={() => setActiveTab('settings')}
            className={`flex-1 py-1.5 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all ${
              activeTab === 'settings'
                ? 'bg-blue-600 text-white shadow-md'
                : 'bg-white/5 text-neutral-400 hover:text-white hover:bg-white/10'
            }`}
          >
            <Sliders className="w-3.5 h-3.5" />
            <span>PiP Settings</span>
          </button>
        </div>

        {/* Tab 1: Diagnostics */}
        {activeTab === 'diagnostics' ? (
          <>
            <div className="flex-1 overflow-y-auto px-4 py-3 space-y-2.5">
              {items.map((item) => (
                <button
                  key={item.id}
                  onClick={() => handleCopyRow(item.value, item.title)}
                  className="w-full flex items-center justify-between px-3.5 py-3 rounded-xl bg-white/[0.05] hover:bg-white/[0.09] active:bg-white/[0.14] border border-white/[0.06] transition-all text-left group"
                >
                  <div className="flex items-center gap-3">
                    <div className="p-1.5 rounded-lg bg-black/30 group-hover:scale-105 transition-transform">
                      {item.icon}
                    </div>
                    <span className="text-[13px] font-medium text-neutral-300">
                      {item.title}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-[13px] font-bold text-white font-mono tracking-tight">
                      {item.value}
                    </span>
                  </div>
                </button>
              ))}
            </div>

            {/* Action Button: Run RAM Stress Test */}
            <div className="px-4 pt-2 pb-3 shrink-0">
              <button
                onClick={() => {
                  triggerHaptic('medium');
                  onRunStressTest();
                }}
                className="w-full py-3 px-4 rounded-xl bg-red-600 hover:bg-red-500 active:bg-red-700 text-white font-bold text-[14px] shadow-lg shadow-red-950/40 transition-all flex items-center justify-center gap-2 active:scale-[0.98]"
              >
                <Flame className="w-4 h-4" />
                <span>Run RAM Stress Test (OOM)</span>
              </button>
            </div>
          </>
        ) : (
          /* Tab 2: PiP Customization Settings */
          <div className="flex-1 overflow-y-auto px-5 py-4 space-y-5 text-white">
            {/* Live Preview Box */}
            <div className="p-4 rounded-2xl bg-black/40 border border-white/10 flex flex-col items-center overflow-hidden">
              <div className="text-[11px] font-semibold text-neutral-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                <Eye className="w-3.5 h-3.5 text-cyan-400" />
                Podgląd PiP na żywo (Live Preview)
              </div>
              <div className="h-28 flex items-center justify-center">
                <div
                  style={{
                    backgroundColor: settings.bgColor,
                    opacity: settings.opacity,
                    borderColor: settings.accentColor,
                    transform: `scale(${settings.scale || 1.0})`,
                    transformOrigin: 'center center',
                  }}
                  className="w-36 rounded-[14px] p-2 border backdrop-blur-md shadow-lg flex flex-col items-center justify-center text-[11px] font-mono font-semibold transition-all duration-150"
                >
                  {settings.showCpu && (
                    <div className="flex items-center gap-1">
                      <span className="text-white/70">CPU:</span>
                      <span style={{ color: settings.accentColor }}>14.8%</span>
                    </div>
                  )}
                  {settings.showRam && (
                    <div className="flex items-center gap-1">
                      <span className="text-white/70">RAM:</span>
                      <span className="text-purple-300">52.4 MB</span>
                    </div>
                  )}
                  {settings.showThermal && (
                    <div className="flex items-center gap-1">
                      <span className="text-white/70">Temp:</span>
                      <span className="text-emerald-400">Normal</span>
                    </div>
                  )}
                  {settings.showFps && (
                    <div className="flex items-center gap-1">
                      <span className="text-white/70">FPS:</span>
                      <span className="text-emerald-400">60.0</span>
                    </div>
                  )}
                  {settings.showModel && (
                    <div className="flex items-center gap-1">
                      <span className="text-white/70">Dev:</span>
                      <span className="text-cyan-200">iPhone15</span>
                    </div>
                  )}
                </div>
              </div>
              <div className="text-[10px] text-neutral-400 font-mono mt-1">
                Kolor: {settings.bgColor} • Przeźroczystość: {Math.round(settings.opacity * 100)}% • Rozmiar: {Math.round((settings.scale || 1.0) * 100)}%
              </div>
            </div>

            {/* 1. Size / Scale Slider */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-neutral-200 flex items-center gap-2">
                  <Maximize2 className="w-4 h-4 text-emerald-400" />
                  Rozmiar nakładki PiP (Size Scale)
                </label>
                <span className="text-xs font-mono font-bold text-emerald-300 bg-emerald-950/60 px-2 py-0.5 rounded-md border border-emerald-500/30">
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
                <span>65% (Kompaktowy)</span>
                <span>100% (Standard)</span>
                <span>135% (Duży)</span>
              </div>
            </div>

            {/* 2. Opacity Slider */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-neutral-200 flex items-center gap-2">
                  <Sliders className="w-4 h-4 text-cyan-400" />
                  Przeźroczystość nakładki PiP (Opacity)
                </label>
                <span className="text-xs font-mono font-bold text-cyan-300 bg-cyan-950/60 px-2 py-0.5 rounded-md border border-cyan-500/30">
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
                <span>20% (Bardzo przeźroczysty)</span>
                <span>50%</span>
                <span>80%</span>
                <span>100% (Pełny)</span>
              </div>
            </div>

            {/* 2. Custom Background Color */}
            <div className="space-y-2.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-neutral-200 flex items-center gap-2">
                  <Palette className="w-4 h-4 text-purple-400" />
                  Dowolny kolor tła (Background Color)
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="color"
                    value={settings.bgColor}
                    onChange={(e) => onUpdateSettings({ ...settings, bgColor: e.target.value })}
                    className="w-8 h-8 rounded-lg cursor-pointer bg-transparent border border-white/20 p-0.5"
                    title="Wybierz dowolny kolor z palety RGB"
                  />
                  <span className="text-xs font-mono text-neutral-400">{settings.bgColor}</span>
                </div>
              </div>

              {/* Preset Color Swatches */}
              <div className="flex flex-wrap gap-2">
                {COLOR_PRESETS.map((preset) => (
                  <button
                    key={preset.hex}
                    onClick={() => {
                      triggerHaptic('light');
                      onUpdateSettings({ ...settings, bgColor: preset.hex });
                    }}
                    style={{ backgroundColor: preset.hex }}
                    className={`px-2.5 py-1.5 rounded-lg text-[11px] font-semibold border flex items-center gap-1.5 transition-all ${
                      settings.bgColor === preset.hex
                        ? 'border-white ring-2 ring-white/50 text-white shadow-md scale-105'
                        : 'border-white/20 text-neutral-300 hover:border-white/40'
                    }`}
                  >
                    <span>{preset.name}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* 3. Accent Highlight Color */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-neutral-200">
                  Kolor akcentu / wskaźników (Accent)
                </label>
                <input
                  type="color"
                  value={settings.accentColor}
                  onChange={(e) => onUpdateSettings({ ...settings, accentColor: e.target.value })}
                  className="w-7 h-7 rounded-lg cursor-pointer bg-transparent border border-white/20 p-0.5"
                  title="Wybierz kolor akcentu"
                />
              </div>
              <div className="flex flex-wrap gap-1.5">
                {ACCENT_PRESETS.map((acc) => (
                  <button
                    key={acc.hex}
                    onClick={() => {
                      triggerHaptic('light');
                      onUpdateSettings({ ...settings, accentColor: acc.hex });
                    }}
                    style={{ backgroundColor: acc.hex }}
                    className={`w-7 h-7 rounded-full border transition-all ${
                      settings.accentColor === acc.hex
                        ? 'border-white ring-2 ring-blue-400 scale-110 shadow-lg'
                        : 'border-white/20 hover:scale-105'
                    }`}
                    title={acc.name}
                  />
                ))}
              </div>
            </div>

            {/* 4. Selectable Display Info Toggles */}
            <div className="space-y-2.5">
              <label className="text-xs font-bold text-neutral-200 block">
                Wyświetlane informacje w PiP (Display Items)
              </label>

              <div className="space-y-2">
                {[
                  {
                    key: 'showCpu' as const,
                    title: 'Użycie procesora (CPU Usage %)',
                    desc: 'Obliczanie obciążenia rdzeni mach kernel',
                  },
                  {
                    key: 'showRam' as const,
                    title: 'Pamięć RAM aplikacji (RAM MB)',
                    desc: 'task_basic_info resident memory size',
                  },
                  {
                    key: 'showThermal' as const,
                    title: 'Stan termiczny (Thermal State / Temp)',
                    desc: 'Normal / Warm / Hot / Critical!',
                  },
                  {
                    key: 'showFps' as const,
                    title: 'Licznik klatek (Render FPS)',
                    desc: 'Płynność renderowania klatek na sekundę',
                  },
                  {
                    key: 'showModel' as const,
                    title: 'Model urządzenia (Device Model)',
                    desc: 'Identyfikator hw.machine (np. iPhone15,2)',
                  },
                ].map((item) => (
                  <label
                    key={item.key}
                    className="flex items-center justify-between p-3 rounded-xl bg-white/[0.04] border border-white/10 hover:bg-white/[0.08] cursor-pointer transition-colors"
                  >
                    <div>
                      <div className="text-xs font-semibold text-neutral-200">{item.title}</div>
                      <div className="text-[10px] text-neutral-400">{item.desc}</div>
                    </div>
                    <input
                      type="checkbox"
                      checked={settings[item.key]}
                      onChange={(e) => {
                        triggerHaptic('light');
                        onUpdateSettings({ ...settings, [item.key]: e.target.checked });
                      }}
                      className="w-5 h-5 rounded-md accent-blue-500 cursor-pointer"
                    />
                  </label>
                ))}
              </div>
            </div>

            {/* Reset Button */}
            <button
              onClick={handleResetSettings}
              className="w-full py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-neutral-300 text-xs font-semibold flex items-center justify-center gap-2 transition-colors active:scale-98"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Przywróć domyślne ustawienia PiP</span>
            </button>
          </div>
        )}

        {/* Footer: Created by Eksemekse-dev with AI + Planet/Globe GitHub Button */}
        <div className="flex items-center justify-between px-5 py-3.5 bg-black/40 border-t border-white/10 shrink-0">
          <span className="text-[11px] font-medium text-neutral-400">
            Created by Eksemekse-dev with AI
          </span>
          <a
            href="https://github.com/Eksemekse-dev/iOS-PerfMonitor"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-blue-600/20 hover:bg-blue-600/30 border border-blue-500/30 text-blue-400 hover:text-blue-300 font-bold text-xs transition-all active:scale-95"
            title="Open GitHub Repository"
          >
            <Globe className="w-3.5 h-3.5 text-blue-400" />
            <span>GitHub</span>
            <ExternalLink className="w-3 h-3 opacity-60 ml-0.5" />
          </a>
        </div>

        {/* Floating Toast Notification */}
        {copiedToast && (
          <div className="absolute bottom-20 left-1/2 -translate-x-1/2 px-4 py-2 rounded-full bg-black/90 border border-white/20 text-white text-xs font-semibold shadow-2xl flex items-center gap-1.5 animate-in fade-in zoom-in-95 pointer-events-none">
            <Check className="w-3.5 h-3.5 text-emerald-400" />
            <span>{copiedToast}</span>
          </div>
        )}
      </div>
    </div>
  );
};
